#!/usr/bin/env python3
"""Exercise KPM signed metadata, rollback, package hash, and cache behavior."""
from __future__ import annotations

import base64
import hashlib
import json
import os
import shutil
import ssl
import stat
import subprocess
import tempfile
import threading
import unittest
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
KPM_SOURCE = ROOT / "out" / "packages" / "kpm" / "root" / "usr" / "bin" / "kpm"
SYSROOT = ROOT / "work" / "packages" / "kpm" / "sysroot"
SIGNER = ROOT / "tools" / "kumo-sign"
CA_BUNDLE = ROOT / "out" / "packages" / "ca-certificates" / "root" / "etc" / "ssl" / "certs" / "ca-certificates.crt"


def run(command: list[str], *, expected: int = 0) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode != expected:
        raise AssertionError(
            f"unexpected status {result.returncode} for {command!r}\n"
            f"stdout: {result.stdout}\nstderr: {result.stderr}"
        )
    return result


def fingerprint(public_key: Path) -> str:
    raw = bytes.fromhex("302a300506032b6570032100")
    der = subprocess.check_output(["openssl", "pkey", "-pubin", "-in", str(public_key), "-outform", "DER"])
    if not der.startswith(raw) or len(der) != len(raw) + 32:
        raise AssertionError("test key is not Ed25519")
    return "sha256:" + hashlib.sha256(der[len(raw):]).hexdigest()


class FixtureHandler(SimpleHTTPRequestHandler):
    directory_path: Path
    fail_snapshot = False

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(self.directory_path), **kwargs)

    def do_GET(self):
        if self.fail_snapshot and self.path.endswith("/snapshot.toml"):
            self.send_error(503, "test network failure")
            return
        super().do_GET()

    def log_message(self, _format, *_args):
        pass


class SignedRepositoryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if os.geteuid() != 0:
            raise unittest.SkipTest("run this integration test as root for its isolated chroot")
        for path in (KPM_SOURCE, SYSROOT / "lib" / "ld-linux-x86-64.so.2", CA_BUNDLE):
            if not path.exists():
                raise unittest.SkipTest(f"required built artifact is missing: {path}")

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="kumo-kpm-trust-")
        self.base = Path(self.temporary.name)
        self.key_dir = self.base / "keys"
        self.key_dir.mkdir()
        self.repository = self.base / "repository"
        (self.repository / "packages").mkdir(parents=True)
        self.root = self.base / "root"
        self.server_certificate = self.base / "server.pem"
        self.server_key = self.base / "server.key"
        self.private_key = self.key_dir / "release.key"
        self.public_key = self.key_dir / "release.pub"
        self.other_private_key = self.key_dir / "other.key"
        self.other_public_key = self.key_dir / "other.pub"
        self.generate_keys()
        self.key_id = fingerprint(self.public_key)
        self.other_key_id = fingerprint(self.other_public_key)
        self.create_https_certificate()
        self.prepare_chroot()
        installed_metadata = self.root / "var/lib/kumo/packages/kpm/metadata.toml"
        installed_metadata.parent.mkdir(parents=True)
        shutil.copy2(ROOT / "out/packages/kpm/metadata.toml", installed_metadata)
        self.server = ThreadingHTTPServer(("127.0.0.1", 0), FixtureHandler)
        FixtureHandler.directory_path = self.repository
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain(self.server_certificate, self.server_key)
        self.server.socket = context.wrap_socket(self.server.socket, server_side=True)
        self.server_thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.server_thread.start()
        self.url = f"https://127.0.0.1:{self.server.server_port}"
        self.write_config(self.key_id)

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.server_thread.join(timeout=3)
        self.temporary.cleanup()

    def generate_keys(self):
        for private, public in ((self.private_key, self.public_key),
                                (self.other_private_key, self.other_public_key)):
            run(["openssl", "genpkey", "-algorithm", "ED25519", "-out", str(private)])
            private.chmod(0o600)
            run(["openssl", "pkey", "-in", str(private), "-pubout", "-out", str(public)])

    def create_https_certificate(self):
        run([
            "openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1",
            "-keyout", str(self.server_key), "-out", str(self.server_certificate),
            "-subj", "/CN=127.0.0.1",
            "-addext", "basicConstraints=critical,CA:TRUE",
            "-addext", "subjectAltName=IP:127.0.0.1",
            "-addext", "keyUsage=critical,digitalSignature,keyCertSign,keyEncipherment",
        ])

    def prepare_chroot(self):
        for name in ("lib", "usr/lib"):
            shutil.copytree(SYSROOT / name, self.root / name, symlinks=True)
        binary = self.root / "usr/bin/kpm"
        binary.parent.mkdir(parents=True)
        shutil.copy2(KPM_SOURCE, binary)
        public_dir = self.root / "usr/share/kumo/keys"
        public_dir.mkdir(parents=True)
        shutil.copy2(self.public_key, public_dir / (self.key_id[7:] + ".pub"))
        shutil.copy2(self.other_public_key, public_dir / (self.other_key_id[7:] + ".pub"))
        ca_path = self.root / "etc/ssl/certs/ca-certificates.crt"
        ca_path.parent.mkdir(parents=True)
        ca_path.write_bytes(CA_BUNDLE.read_bytes() + b"\n" + self.server_certificate.read_bytes())
        (self.root / "etc/kumo").mkdir(parents=True)

    def write_config(self, key_id: str):
        config = (
            'architecture = "x86_64"\n\n'
            "[[repository]]\n"
            'name = "test"\n'
            f'url = "{self.url}"\n'
            'trust = "ed25519"\n'
            f'key_id = "{key_id}"\n'
            'channel = "stable"\n'
            "enabled = true\n"
        )
        (self.root / "etc/kumo/kpm.toml").write_text(config, encoding="utf-8")

    def run_kpm(self, *args: str, expected: int = 0) -> subprocess.CompletedProcess[str]:
        return run([
            "chroot", str(self.root), "/lib/ld-linux-x86-64.so.2",
            "--library-path", "/usr/lib:/lib", "/usr/bin/kpm", *args,
        ], expected=expected)

    def write_index(self, package: dict | None = None):
        packages = [package] if package else []
        repo = (
            "repository_format = 1\n\n"
            "[repository]\n"
            'name = "Kumo Test"\n'
            'channel = "stable"\n'
            'architecture = "x86_64"\n'
            "source_date_epoch = 1762128000\n"
            f"package_count = {len(packages)}\n"
        )
        index = [
            "format_version = 1",
            'architecture = "x86_64"',
            "source_date_epoch = 1762128000",
            f"package_count = {len(packages)}",
            "",
        ]
        if package:
            index.extend((
                "[[package]]",
                f'name = {json.dumps(package["name"])}',
                f'version = {json.dumps(package["version"])}',
                f'release = {package["release"]}',
                'architecture = "x86_64"',
                'description = "test package"',
                "runtime_dependencies = []",
                f'filename = {json.dumps(package["filename"])}',
                f'size = {package["size"]}',
                f'sha256 = "{package["sha256"]}"',
                "",
            ))
        (self.repository / "repo.toml").write_text(repo, encoding="utf-8")
        (self.repository / "index.toml").write_text("\n".join(index), encoding="utf-8")

    def sign(self, sequence: int):
        for name in ("snapshot.toml", "snapshot.toml.sig"):
            (self.repository / name).unlink(missing_ok=True)
        run([
            str(SIGNER), "sign", "--repository", str(self.repository),
            "--private-key", str(self.private_key), "--public-key", str(self.public_key),
            "--sequence", str(sequence),
        ])

    def sign_expired_snapshot(self, sequence: int):
        files = []
        for name in ("repo.toml", "index.toml"):
            data = (self.repository / name).read_bytes()
            files.append(
                "[[file]]\n"
                f"path = {json.dumps(name)}\n"
                f"size = {len(data)}\n"
                f"sha256 = {json.dumps(hashlib.sha256(data).hexdigest())}\n"
            )
        snapshot = (
            "format_version = 1\nchannel = \"stable\"\narchitecture = \"x86_64\"\n"
            f"sequence = {sequence}\nexpires = \"2020-01-01T00:00:00Z\"\n\n"
            + "\n".join(files)
        ).encode()
        snapshot_path = self.repository / "snapshot.toml"
        raw_signature = self.base / "expired.sig"
        snapshot_path.write_bytes(snapshot)
        run([
            "openssl", "pkeyutl", "-sign", "-rawin", "-inkey", str(self.private_key),
            "-in", str(snapshot_path), "-out", str(raw_signature),
        ])
        signature = (
            "format_version = 1\nalgorithm = \"Ed25519\"\n"
            f"key_id = {json.dumps(self.key_id)}\n"
            f"signature = {json.dumps(base64.b64encode(raw_signature.read_bytes()).decode())}\n"
        )
        (self.repository / "snapshot.toml.sig").write_text(signature, encoding="utf-8")

    def current_pointer(self) -> str:
        return os.readlink(self.root / "var/cache/kumo/kpm/repositories/test/current")

    def test_local_repository_add_remains_available(self):
        self.write_index()
        local_repository = self.root / "var/lib/kumo/repos/local"
        local_repository.parent.mkdir(parents=True)
        shutil.copytree(self.repository, local_repository)
        self.run_kpm("repo", "add", "local", "/var/lib/kumo/repos/local")
        repositories = self.run_kpm("repo", "list").stdout
        self.assertIn("local\t/var/lib/kumo/repos/local\tenabled\tlocal", repositories)

    def test_signed_metadata_rejections_and_cache_preservation(self):
        self.write_index()
        self.sign(3)
        self.run_kpm("repo", "refresh")
        original_pointer = self.current_pointer()

        original_index = (self.repository / "index.toml").read_bytes()
        (self.repository / "index.toml").write_bytes(original_index + b"# tampered\n")
        self.run_kpm("repo", "refresh", expected=1)
        self.assertEqual(self.current_pointer(), original_pointer)
        (self.repository / "index.toml").write_bytes(original_index)

        signature_path = self.repository / "snapshot.toml.sig"
        original_signature = signature_path.read_bytes()
        signature_path.write_bytes(original_signature.replace(b"signature = \"", b"signature = \"A", 1))
        self.run_kpm("repo", "refresh", expected=1)
        self.assertEqual(self.current_pointer(), original_pointer)
        signature_path.write_bytes(original_signature)

        self.write_config(self.other_key_id)
        self.run_kpm("repo", "refresh", expected=1)
        self.assertEqual(self.current_pointer(), original_pointer)
        self.write_config(self.key_id)

        self.sign_expired_snapshot(4)
        self.run_kpm("repo", "refresh", expected=1)
        self.assertEqual(self.current_pointer(), original_pointer)

        self.write_index()
        self.sign(2)
        self.run_kpm("repo", "refresh", expected=1)
        self.assertEqual(self.current_pointer(), original_pointer)

        self.write_index()
        self.sign(4)
        self.run_kpm("repo", "refresh")
        updated_pointer = self.current_pointer()
        self.assertNotEqual(updated_pointer, original_pointer)

        expected_archive = b"authenticated archive"
        corrupt_archive = bytes([expected_archive[0] ^ 1]) + expected_archive[1:]
        self.assertEqual(len(expected_archive), len(corrupt_archive))
        package = {
            "name": "probe", "version": "1.0", "release": 1,
            "filename": "probe-1.0-1-x86_64.kpkg",
            "size": len(expected_archive),
            "sha256": hashlib.sha256(expected_archive).hexdigest(),
        }
        self.write_index(package)
        (self.repository / "packages" / package["filename"]).write_bytes(expected_archive)
        self.sign(5)
        self.run_kpm("repo", "refresh")
        (self.repository / "packages" / package["filename"]).write_bytes(corrupt_archive)
        result = self.run_kpm("install", "probe", "--yes", expected=1)
        self.assertIn("SHA-256 mismatch", result.stderr)
        self.assertFalse((self.root / "var/lib/kumo/packages/probe/metadata.toml").exists())
        updated_pointer = self.current_pointer()

        FixtureHandler.fail_snapshot = True
        self.run_kpm("repo", "refresh", expected=1)
        FixtureHandler.fail_snapshot = False
        self.assertEqual(self.current_pointer(), updated_pointer)
        installed_metadata = self.root / "var/lib/kumo/packages/kpm/metadata.toml"
        self.assertEqual(
            self.run_kpm("list").stdout.splitlines()[0].split("\t")[0], "kpm"
        )
        self.assertEqual(
            installed_metadata.read_bytes(),
            (ROOT / "out/packages/kpm/metadata.toml").read_bytes(),
        )

        trust_state = self.root / "var/lib/kumo/kpm/trust/test.toml"
        trusted_state_contents = trust_state.read_bytes()
        self.assertEqual(trust_state.stat().st_uid, 0)
        self.assertEqual(stat.S_IMODE(trust_state.stat().st_mode), 0o644)
        shutil.rmtree(self.root / "var/cache/kumo/kpm/repositories/test")
        self.write_index()
        self.sign(4)
        rollback = self.run_kpm("repo", "refresh", expected=1)
        self.assertIn("rollback detected", rollback.stderr)
        self.assertIn("sequence=5", self.run_kpm("repo", "list").stdout)
        self.assertEqual(trust_state.read_bytes(), trusted_state_contents)


if __name__ == "__main__":
    unittest.main()
