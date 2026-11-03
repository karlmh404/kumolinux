# Bootstrap architecture

```text
Windows
  |
  v
WSL Ubuntu build host (host tools only)
  |
  v
Kumo bootstrap build system
  |-- Kumo cross toolchain
  |   |-- binutils
  |   |-- GCC
  |   |-- Linux API headers
  |   `-- glibc
  |-- Linux kernel
  `-- bootstrap BusyBox rootfs
          |
          v
       Kumo Linux
```

Ubuntu is not part of Kumo, and Kumo is not derived from Ubuntu or another distribution. Target binaries are built from official upstream source with the Kumo cross compiler. No host root filesystem, package database, binary, library, or configuration is copied into the target.

BusyBox is temporary bootstrap infrastructure. systemd and the permanent GNU userspace belong to later milestones. Kumo will eventually own its package recipes, repositories, release infrastructure, update system, installer, desktop defaults, and engineering platform; none are claimed or stubbed here.

