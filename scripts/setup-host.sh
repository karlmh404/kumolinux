#!/usr/bin/env bash
set -euo pipefail
source "$(cd -- "$(dirname -- "$0")" && pwd)/common.sh"
[[ "$(uname -s)" == Linux ]] || die 'Linux build host required'
[[ "$(uname -m)" == x86_64 ]] || die 'x86_64 build host required'
log "kernel: $(uname -r)"; log "CPUs: $(nproc)"; free -h; df -h "$REPO_ROOT"
if grep -qi microsoft /proc/sys/kernel/osrelease; then log 'WSL: detected (WSL 2 kernel expected)'; else log 'WSL: not detected'; fi
packages=(
  build-essential gcc g++ gperf bison flex texinfo help2man
  libtool libtool-bin autoconf automake libncurses-dev
  python3 python3-dev python3-setuptools git curl wget rsync cpio
  xz-utils bzip2 gzip tar patch file bc kmod libssl-dev libelf-dev
  dwarves qemu-system-x86 qemu-utils ninja-build cmake pkg-config gawk zstd e2fsprogs
)
tools=(gcc g++ make gperf bison flex makeinfo help2man libtool libtoolize
  autoconf automake python3 git curl wget rsync cpio xz bzip2 gzip tar
  patch file bc kmod qemu-system-x86_64 qemu-img ninja cmake pkg-config gawk zstd mke2fs)
missing=(); for t in "${tools[@]}"; do command -v "$t" >/dev/null || missing+=("$t"); done
if ((${#missing[@]})); then
  log "missing host build tools: ${missing[*]}"
  log 'Ubuntu packages are host dependencies only; none are copied into Kumo.'
  if ! sudo -n true 2>/dev/null; then
    printf '[kumo] sudo credentials are required. Run interactively:\n' >&2
    printf '  sudo apt-get update && sudo apt-get install -y' >&2
    printf ' %q' "${packages[@]}" >&2
    printf '\n' >&2
    exit 2
  fi
  sudo apt-get update
  sudo apt-get install -y "${packages[@]}"
fi
if [[ -r /dev/kvm && -w /dev/kvm ]]; then log 'KVM acceleration: available'; else log 'KVM acceleration: unavailable; QEMU will use TCG'; fi

