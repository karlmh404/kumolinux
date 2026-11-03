# Kumo package repository

The static repository format is versioned independently from `.kpkg`:

```text
stable/x86_64/
├── repo.toml
├── index.toml
├── snapshot.toml
├── snapshot.toml.sig
└── packages/*.kpkg
```

`repo.toml` declares repository format, channel, and architecture. `index.toml`
contains sorted package records with canonical filenames, byte sizes, and
SHA-256 hashes. The detached Ed25519 signature authenticates a snapshot that
binds the exact sizes and SHA-256 hashes of both metadata files, as well as the
channel, architecture, sequence, and UTC expiration.

Generate and validate the publish tree from canonical build artifacts:

```sh
./tools/kumo-repo build --channel stable --arch x86_64 out/public-repo
```

This writes `out/public-repo/stable/x86_64`. It does not include build caches
or source archives. A local repository can still be generated with
`./tools/kumo-repo build out/repository/x86_64`.

Create the offline release key once. Keep its private half outside the checkout
and never upload it, add it to the root filesystem, or place it in CI:

```sh
./tools/kumo-sign keygen
```

By default the private key is written under
`~/.config/kumo/signing/kumo-release.key` with mode `0600`; only the public key
is committed under `rootfs/base-overlay/usr/share/kumo/keys/`. Losing the
private key requires rotating the committed trust root and all repository
configurations. Do not store it in cloud backups.

After building the stable repository, sign it locally. The signer validates all
package sizes and hashes, increases the prior sequence, writes a 90-day
expiration, and verifies its own output:

```sh
./tools/kumo-repo build --channel stable --arch x86_64 out/public-repo
./tools/kumo-sign sign --repository out/public-repo/stable/x86_64 \
  --private-key ~/.config/kumo/signing/kumo-release.key
./tools/kumo-sign verify --repository out/public-repo/stable/x86_64 \
  --public-key rootfs/base-overlay/usr/share/kumo/keys/KEY_HASH.pub
```

`KEY_HASH` is the 64-character lowercase hex portion of the `sha256:` key ID.

KPM local repositories use `path` and explicitly use local trust. HTTPS
repositories must pin a key ID that is present in the installed Kumo trust
store:

```toml
architecture = "x86_64"

[[repository]]
name = "base"
url = "https://OWNER.github.io/REPOSITORY/kumo/stable/x86_64"
trust = "ed25519"
key_id = "sha256:PUBLIC_KEY_SHA256"
channel = "stable"
enabled = true
```

KPM verifies the Ed25519 signature and authorized key before parsing metadata,
then checks the snapshot hashes, expiration, channel, architecture, and
monotonically increasing sequence. It commits a refreshed snapshot by atomically
switching the cache pointer, so a failed refresh leaves the previous trusted
metadata intact. The high-water sequence is stored separately under
`/var/lib/kumo/kpm/trust/` as protected root-owned state, so clearing the
metadata cache cannot enable rollback. KPM also requires TLS certificate and hostname verification, and
validates package size and SHA-256 before use. Local/file repositories remain
available for offline bundles and are not represented as publisher-signed.

Upload the canonical `.kpkg` files from `out/packages` and the signed
`snapshot.toml` plus `snapshot.toml.sig` as release assets. The Actions workflow
rebuilds the deterministic index from the package assets, verifies the signed
snapshot with the committed public key, then publishes Pages; it never needs
the private key. Enable GitHub Pages with **GitHub Actions** as its deployment
source. The public URL is then
`https://OWNER.github.io/REPOSITORY/kumo/stable/x86_64`.

Validate a generated tree locally:

```sh
./tools/kumo-repo build --channel stable --arch x86_64 out/public-repo
./tools/kumo-sign verify --repository out/public-repo/stable/x86_64 \
  --public-key rootfs/base-overlay/usr/share/kumo/keys/KEY_HASH.pub
```

The generator verifies each package archive against its metadata and records
the archive size and SHA-256 in the deterministic index.

The KPM integration test exercises local repositories and rejects altered
metadata/signatures, an unauthorized key, expired and rolled-back snapshots,
and package hash mismatches. It also checks that a failed network refresh
preserves the root-owned cache pointer and installed package database. Run it
on a Linux host as root after building the KPM package:

```sh
python3 tests/kpm-trust-integration.py
```
