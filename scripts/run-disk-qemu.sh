#!/usr/bin/env bash
set -euo pipefail
source "$(cd -- "$(dirname -- "$0")" && pwd)/common.sh"
need qemu-system-x86_64
kernel="$OUT_DIR/boot/vmlinuz-kumo"
initrd="$OUT_DIR/boot/initramfs-kumo.cpio.gz"
disk="$OUT_DIR/images/kumo-root.img"
[[ -f "$kernel" && -f "$initrd" && -f "$disk" ]] || die 'disk boot artifacts missing; run make disk'
accel=(-accel tcg,thread=multi)
[[ -r /dev/kvm && -w /dev/kvm ]] && accel=(-enable-kvm -cpu host)
exec qemu-system-x86_64 "${accel[@]}" -machine q35 -m "${KUMO_MEMORY:-2G}" \
  -smp "${KUMO_CPUS:-2}" -kernel "$kernel" -initrd "$initrd" \
  -drive "file=$disk,format=raw,if=virtio,cache=writeback" \
  -netdev user,id=kumo-net -device virtio-net-pci,netdev=kumo-net \
  -append 'console=ttyS0 rdinit=/sbin/init root=/dev/vda rw panic=-1 systemd.show_status=yes' \
  -nographic -no-reboot
