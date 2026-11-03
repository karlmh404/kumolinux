#!/usr/bin/env bash
set -euo pipefail
source "$(cd -- "$(dirname -- "$0")" && pwd)/common.sh"; need qemu-system-x86_64
kernel="$OUT_DIR/boot/vmlinuz-kumo"; initrd="$OUT_DIR/boot/initramfs-kumo.cpio.gz"
[[ -f "$kernel" && -f "$initrd" ]] || die 'boot artifacts missing; run make all'
accel=(-accel tcg,thread=multi); [[ -r /dev/kvm && -w /dev/kvm ]] && accel=(-enable-kvm -cpu host)
exec qemu-system-x86_64 "${accel[@]}" -machine q35 -m "${KUMO_MEMORY:-2G}" -smp "${KUMO_CPUS:-2}" -kernel "$kernel" -initrd "$initrd" -append 'console=ttyS0 rdinit=/sbin/init panic=-1' -nographic -no-reboot

