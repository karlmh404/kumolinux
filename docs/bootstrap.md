# Building the 0.0.1 bootstrap

Run inside Ubuntu WSL 2 from this repository:

```bash
make setup
make fetch
make toolchain
make kernel
make busybox
make rootfs
make image
make run
```

`make all` builds everything needed to boot. The first toolchain build is CPU-, RAM-, disk-, and network-intensive. Correct archives remain in `cache/distfiles`; interrupted build trees remain under `work` where crosstool-NG can resume.

If `/dev/kvm` is unavailable or inaccessible, `make run` automatically selects multithreaded TCG. Exit QEMU with `Ctrl-A`, then `X`.

Checksum failure is intentionally fatal. A corrupt existing cache file is never overwritten: remove that specific file after inspection, then run `make fetch` again. `make clean` preserves downloads and the expensive toolchain; `make distclean` removes generated work and output but preserves downloads.

