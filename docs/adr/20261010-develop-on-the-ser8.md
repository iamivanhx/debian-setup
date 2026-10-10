# lilypad is developed on the SER8 and tested in VMs on it, amd64 only

The plan was to iterate in an arm64 VM on the Mac first and then do a clean install on the SER8. That forced every dev-layer step to support both amd64 and arm64, and it ruled out or weakened tools that ship x86_64 only (Walker, Elephant, the 1Password desktop app). Instead, lilypad is developed on the SER8 itself, and every run that changes a system is proven first in a **test VM**: an amd64 KVM virtual machine on the SER8, using virtio-gpu with virgl. Only then is it applied to the SER8. amd64 is the only architecture. The SER8 isn't in daily use yet, so it can be the test bed. A VM on the target exercises the same architecture, kernel and Mesa stack, and hardware, LUKS and NVMe could never be proven in a VM on the Mac anyway.

## Considered Options

- **arm64 VM on the Mac (UTM with QEMU and virgl).** Rejected: the dual-architecture cost shapes every tool choice, for a VM that is a different architecture from the target.
- **Containers (`debian:trixie`) for step tests.** Not adopted: a container can't run the desktop, systemd as PID 1, or anything at the kernel level. Lint and the bats unit tests with stubbed commands still run on the host and in CI, because they change nothing.
- **VirtualBox, on the Mac or on the SER8.** Rejected. On Apple Silicon it runs only arm64 guests. Its Linux guest adapter uses `vmwgfx`, where accelerated Hyprland clients fail (Hyprland#16175). On the SER8 it needs out-of-tree kernel modules and competes with KVM.

## Consequences

- A bad step can break the machine it is being fixed from. "Test VM first, then host" is a hard rule, and recovery from a TTY is part of the plan.
- The `vm-arm64` machine profile becomes an amd64 test-VM profile.
- Hardware, LUKS and NVMe steps are still proven only on the SER8 itself.
