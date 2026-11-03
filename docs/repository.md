# Kumo package repository

The static repository format is versioned independently from `.kpkg`:

```text
stable/x86_64/
├── repo.toml
├── index.toml
└── packages/*.kpkg
```

`repo.toml` declares repository format, channel, and architecture. `index.toml`
contains sorted package records with canonical filenames, byte sizes, and
SHA-256 hashes. The same index is used by local and HTTPS repositories.

Generate and validate the publish tree from canonical build artifacts:

```sh
./tools/kumo-repo build --channel stable --arch x86_64 out/public-repo
```

This writes `out/public-repo/stable/x86_64`. It does not include build caches
or source archives. A local repository can still be generated with
`./tools/kumo-repo build out/repository/x86_64`.

KPM local repositories use `path`; remote repositories use an HTTPS `url`.
Configure only one for each repository:

```toml
architecture = "x86_64"

[[repository]]
name = "base"
url = "https://OWNER.github.io/REPOSITORY/kumo/stable/x86_64"
enabled = true
```

KPM requires TLS certificate and hostname verification, keeps validated
metadata under `/var/cache/kumo/kpm/repositories`, and verifies each cached or
downloaded package's size and SHA-256 before use.

The Actions workflow publishes when a GitHub Release is published. Upload the
canonical `.kpkg` files from `out/packages` as release assets; the workflow
uses those existing artifacts to generate the Pages tree and does not rebuild
the toolchain or packages. Enable GitHub Pages for the repository with
**GitHub Actions** as its deployment source. The public URL is then
`https://OWNER.github.io/REPOSITORY/kumo/stable/x86_64`.

Validate a generated tree locally:

```sh
./tools/kumo-repo build --channel stable --arch x86_64 out/public-repo
```

The generator verifies each package archive against its metadata and records
the archive size and SHA-256 in the deterministic index.
