SHELL := /bin/bash
.DEFAULT_GOAL := all

.PHONY: setup fetch toolchain kernel busybox rootfs image run packages repo base disk run-disk all clean distclean
setup:
	./scripts/setup-host.sh
fetch:
	./scripts/fetch-sources.sh
toolchain: fetch
	./scripts/build-toolchain.sh
kernel: toolchain fetch
	./scripts/build-kernel.sh
busybox: toolchain fetch
	./scripts/build-busybox.sh
rootfs: busybox
	./scripts/build-rootfs.sh
image: rootfs
	./scripts/build-initramfs.sh
run: image kernel
	./scripts/run-qemu.sh
packages: toolchain
	./tools/kumo-build base
	./tools/kumo-build package kumo-hello-extra
repo: packages
	./tools/kumo-repo build out/repository/x86_64
base: repo
	./tools/kumo-rootfs assemble base
disk: base image kernel
	./scripts/build-disk.sh
run-disk:
	@if [[ ! -f out/images/kumo-root.img ]]; then $(MAKE) disk; fi
	./scripts/run-disk-qemu.sh
all: image kernel
clean:
	./scripts/clean.sh
distclean:
	./scripts/clean.sh --distclean
