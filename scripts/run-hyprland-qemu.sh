#!/usr/bin/env bash
set -euo pipefail
source "$(cd -- "$(dirname -- "$0")" && pwd)/common.sh"
need qemu-system-x86_64
kernel="$OUT_DIR/boot/vmlinuz-kumo"
initrd="$OUT_DIR/boot/initramfs-kumo.cpio.gz"
disk="${KUMO_DISK:-$OUT_DIR/images/kumo-root.img}"
disk_format="${KUMO_DISK_FORMAT:-raw}"
graphics_mode="${KUMO_GRAPHICS_MODE:-2d}"
[[ -f "$kernel" && -f "$initrd" && -f "$disk" ]] || die "disk boot artifacts missing; run make disk"
accel=(-accel tcg,thread=multi)
[[ -r /dev/kvm && -w /dev/kvm ]] && accel=(-enable-kvm -cpu host)

if [[ -n "${KUMO_GRAPHICS_DISPLAY:-}" ]]; then
  display_args=(-display "$KUMO_GRAPHICS_DISPLAY")
elif [[ "$graphics_mode" == virgl ]]; then
  display_args=(-display gtk,gl=on)
elif [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]]; then
  display_args=(-display default)
else
  display_args=(-display gtk)
fi

case "$graphics_mode" in
  2d) gpu_args=(-device virtio-gpu-pci) ;;
  virgl)
    qemu-system-x86_64 -device help | grep -q 'virtio-gpu-gl-pci' ||
      die "QEMU lacks virtio-gpu-gl-pci support; use KUMO_GRAPHICS_MODE=2d"
    gpu_args=(-device virtio-gpu-gl-pci)
    ;;
  *) die "unknown KUMO_GRAPHICS_MODE '$graphics_mode' (expected 2d or virgl)" ;;
esac
log "graphics mode: $graphics_mode; display: ${display_args[*]:1}"

exec qemu-system-x86_64 "${accel[@]}" -machine q35 -vga none -m "${KUMO_MEMORY:-2G}" \
  -smp "${KUMO_CPUS:-2}" -kernel "$kernel" -initrd "$initrd" \
  -drive "file=$disk,format=$disk_format,if=virtio,cache=writeback" \
  -netdev user,id=kumo-net -device virtio-net-pci,netdev=kumo-net \
  "${gpu_args[@]}" \
  -device virtio-keyboard-pci \
  -device virtio-mouse-pci \
  -serial mon:stdio \
  "${display_args[@]}" \
  -append "console=ttyS0 console=tty1 rdinit=/sbin/init root=/dev/vda rw panic=-1 systemd.show_status=yes" \
  -no-reboot
