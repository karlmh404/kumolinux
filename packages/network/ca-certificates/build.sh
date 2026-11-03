#!/usr/bin/env bash
set -euo pipefail
bundle="$KUMO_BUILD/cacert.pem"
curl --fail --location --retry 3 --output "$bundle" https://curl.se/ca/cacert-2026-10-20.pem
printf '%s  %s\n' 796f1389bfea13c0ed78f663b765baaff54a508e5483786bd6ece73c5e3e3cbe "$bundle" | sha256sum --check --status
install -Dm644 "$bundle" "$KUMO_DESTDIR/etc/ssl/certs/ca-certificates.crt"
