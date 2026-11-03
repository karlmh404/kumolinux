# Kumo Linux

Kumo Linux is an independent Linux distribution under active development.

The current milestone is the **0.0.1 bootstrap**, codename **Sora**. It builds an x86_64 GNU/Linux cross-toolchain, Linux kernel, and temporary static BusyBox initramfs entirely from pinned upstream source. Ubuntu under WSL is a build host only and is not part of Kumo.

```bash
make setup
make all
make run
```

This is not yet Kumo's permanent userspace. It provides only the minimal serial-console bootstrap needed to establish the independent build foundation.

See [bootstrap instructions](docs/bootstrap.md) and [architecture](docs/architecture.md).

