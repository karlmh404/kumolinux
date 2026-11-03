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

display_args=()
if [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]]; then
  display_args=(-display default)
elif [[ -n "${KUMO_GRAPHICS_DISPLAY:-}" ]]; then
  display_args=(-display "$KUMO_GRAPHICS_DISPLAY")
else
  display_args=(-display none -vnc :1)
fi

exec qemu-system-x86_64 "${accel[@]}" -machine q35 -vga none -m "${KUMO_MEMORY:-2G}" \
  -smp "${KUMO_CPUS:-2}" -kernel "$kernel" -initrd "$initrd" \
  -drive "file=$disk,format=raw,if=virtio,cache=writeback" \
  -netdev user,id=kumo-net -device virtio-net-pci,netdev=kumo-net \
  -device virtio-gpu-pci \
  -device virtio-keyboard-pci \
  -device virtio-mouse-pci \
  -serial mon:stdio \
  "${display_args[@]}" \
  -append 'console=ttyS0 console=tty1 rdinit=/sbin/init root=/dev/vda rw panic=-1 systemd.show_status=yes' \
  -no-reboot
