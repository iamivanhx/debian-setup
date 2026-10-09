# arm64 VM for Hyprland on Apple Silicon

> Research note for [Research: arm64 VM for Hyprland on Apple Silicon](https://github.com/iamivanhx/debian-setup/issues/31),
> part of [Map: Hyprland dev environment refactor (SER8 replaces the Mac)](https://github.com/iamivanhx/debian-setup/issues/26).
> Desk research only, as of 2026-10-09. Nothing was installed or run on the Mac.
> Host in question: M3 Pro, macOS 27. Guest: Debian 13 (trixie) arm64.

## Question

How should an arm64 Debian trixie VM run on the Mac so that a Hyprland desktop
works in it, and so that a fresh install can be driven automatically to prove a
run? Which hypervisor is primary, which is the fallback, and what can the VM not
prove?

## Answer

- **Primary: UTM on its QEMU backend with a `virtio-gpu-gl-pci` display
  (virgl).** It is the only free option with working 3D for Linux guests on Apple
  Silicon that has a public record of Hyprland running on it. It can be driven
  from the CLI (`utmctl` plus AppleScript), it imports an existing disk image, and
  you can reset it with `utmctl clone` or `utmctl start --disposable`. UTM 5.x
  adds `utmctl snapshot`, but 5.x is still beta.
- **Fallback: Lima with `vmType: vz` (Apple Virtualization.framework) and
  `video.display: vz`.** It has no 3D, so Hyprland renders on llvmpipe. Lima is
  fully headless and CLI-native, and it runs cloud-init itself. It doesn't depend
  on UTM. Before switching tools, try the cheap middle step: keep UTM and set the
  display to `virtio-gpu-pci` (GL off), which also gives llvmpipe.
- **Guest image for both:** Debian's `debian-13-generic-arm64.qcow2`, seeded
  through a NoCloud `cidata` ISO, with Hyprland from `trixie-backports`. **Not
  `genericcloud`**: that image ships Debian's cloud kernel, which is built with
  `CONFIG_DRM` off, so it has no virtio-gpu driver and no Hyprland.
- **Rejected:** VMware Fusion. It is free, and it is the one option with real
  OpenGL 4.3 for arm64 Linux, but Hyprland's dmabuf import is broken on
  `vmwgfx`, so accelerated clients fail. Parallels: there are no Hyprland
  reports, and its CLI is only in the paid Pro edition. Tart: Apple's
  Virtualization.framework (VZ) graphics only, like Lima, but under a non-OSI
  licence and with no cloud-init story. Homebrew QEMU: no GL display on macOS.

## What Hyprland needs from the guest GPU

These are the requirements the hypervisor comparison is judged against.

- **GLES 3.0 at minimum.** Hyprland asks EGL for a GLES 3.2 context, retries 3.0,
  and asserts if both fail
  ([`src/render/OpenGL.cpp` at v0.55.2, lines 198–219](https://github.com/hyprwm/Hyprland/blob/v0.55.2/src/render/OpenGL.cpp#L198-L219)).
- **EGL `KHR_platform_gbm` or `EXT_platform_device`**, plus the GL extension
  `GL_EXT_texture_format_BGRA8888`, both hard asserts (same file, around the
  `RASSERT` calls after context creation).
- **A KMS device with a display output.** Hyprland "requires by default that your
  graphics card has at least one display output". The wiki also says
  virtio-gpu is fine: "it provides an emulated screen output. You can therefore,
  and as many have already, use Hyprland normally with it"
  ([Hyprland wiki: Virtual GPU](https://wiki.hypr.land/Configuring/Advanced-and-Cool/Virtual-GPU/)).
- **Software rendering is a handled case, not a crash.** The renderer detects
  `llvmpipe`/`softpipe` and switches to `glFinish()` for sync
  ([`src/render/GLRenderer.cpp` at v0.55.2](https://github.com/hyprwm/Hyprland/blob/v0.55.2/src/render/GLRenderer.cpp)).
  A 2026-08 report shows Hyprland 0.56.1 running on "virtio-gpu, 2D only (no
  virgl/venus), under libkrun on an Apple Silicon host … mesa llvmpipe"
  ([hyprwm/Hyprland#16077](https://github.com/hyprwm/Hyprland/issues/16077)).
- **VMs get a software cursor.** The kernel hides cursor planes from atomic
  clients on virtio-gpu, vmwgfx and qxl unless the client sets
  `DRM_CLIENT_CAP_CURSOR_PLANE_HOTSPOT`. Aquamarine doesn't set it: the PR that
  would have was closed unmerged
  ([hyprwm/aquamarine#372](https://github.com/hyprwm/aquamarine/pull/372)). Expect
  `cursor:no_hardware_cursors` behaviour in every VM below.
- **Official stance on VMs:** "YMMV, this is not officially supported." The wiki's
  VM recipe is libvirt with SPICE `gl.enable=yes` (virgl) on a Linux host
  ([Hyprland wiki: Installation → Running In a VM](https://wiki.hypr.land/Getting-Started/Installation/)).

## Debian side

- **Hyprland isn't in trixie proper.** It is in `trixie-backports` at
  `0.55.2+ds-1~bpo13+1` with an arm64 build, and forky/sid carry 0.56.2
  ([Debian madison: hyprland](https://qa.debian.org/madison.php?package=hyprland&text=on);
  [packages.debian.org/trixie/hyprland](https://packages.debian.org/trixie/hyprland)
  shows "Package not available in this suite"). Backports matches the map's
  source order (Debian, then backports).
- **Mesa:** trixie ships 25.0.7, and backports has 26.1.x
  ([madison: mesa](https://qa.debian.org/madison.php?package=mesa&text=on&s=trixie,trixie-backports)).
  The arm64 `libgl1-mesa-dri` ships `virtio_gpu_dri.so`, `vmwgfx_dri.so` and
  `kms_swrast_dri.so`
  ([file list](https://packages.debian.org/trixie/arm64/libgl1-mesa-dri/filelist)),
  and `mesa-vulkan-drivers` ships the Venus ICD `libvulkan_virtio.so`
  ([file list](https://packages.debian.org/trixie/arm64/mesa-vulkan-drivers/filelist)).
  Every guest GPU path below is covered by stock trixie packages.
- **Cloud images:** `cloud.debian.org/images/cloud/trixie/latest/` has
  `debian-13-{generic,genericcloud,nocloud}-arm64.qcow2`. Debian describes
  `genericcloud` as "Identical to generic but with a reduced set of hardware
  drivers in the kernel", and `nocloud` as "Does not run cloud-init and boots
  directly to a root prompt"
  ([Debian Official Cloud Images](https://cloud.debian.org/images/cloud/)).
- **The kernel flavour is the trap.** The image build maps `genericcloud` to the FAI
  class `LINUX_VARIANT_CLOUD`, and `generic` and `nocloud` to `LINUX_VARIANT_BASE`
  ([debian-cloud-images `image.yaml`](https://salsa.debian.org/cloud-team/debian-cloud-images/-/blob/master/src/debian_cloud_images/resources/image.yaml)).
  On arm64 that is `linux-image-cloud-arm64` versus `linux-image-arm64`
  ([`package_config/ARM64`](https://salsa.debian.org/cloud-team/debian-cloud-images/-/blob/master/config_space/13/package_config/ARM64)).
  The `cloud-arm64` flavour is built from `config.cloud`
  ([`arm64/defines.toml`](https://salsa.debian.org/kernel-team/linux/-/blob/debian/6.12/trixie/debian/config/arm64/defines.toml)),
  which has `# CONFIG_DRM is not set`
  ([`config.cloud`](https://salsa.debian.org/kernel-team/linux/-/blob/debian/6.12/trixie/debian/config/config.cloud)).
  **Lima's stock `debian-13` template uses `genericcloud`**
  ([`templates/_images/debian-13.yaml`](https://github.com/lima-vm/lima/blob/master/templates/_images/debian-13.yaml)),
  so it must be overridden.
- **Unattended installer path:** the arm64 netinst can be preseeded through a
  `preseed.cfg` in the initrd root, `preseed/file=`, or `url=` with
  `auto=true priority=critical` on the kernel command line
  ([Installation Guide arm64, B.2](https://www.debian.org/releases/trixie/arm64/apbs02.en.html)).
  On UEFI arm64 the command line means editing the GRUB entry or remastering the
  ISO's initrd, so the cloud image plus a `cidata` seed is simpler to drive. This
  is a trade-off: the cloud image isn't the base system the SER8 gets from the
  netinst in `docs/install.md` (see Gaps).

## Comparison

| Option | Linux-guest GPU path | Hyprland evidence | Unattended trixie arm64 | Snapshots / reset | Headless CLI | Licence / cost |
|---|---|---|---|---|---|---|
| **UTM, QEMU backend** | virtio-gpu-gl (virgl). The renderer is ANGLE, or Apple Core OpenGL 4.1 in 5.x. Venus Vulkan 1.3 arrives in 5.x ([v5.0.6 notes](https://github.com/utmapp/UTM/releases/tag/v5.0.6)). The wizard picks `virtio-gpu-gl-pci` for Linux when GL is on ([`VMWizardState.swift`](https://github.com/utmapp/UTM/blob/main/Platform/Shared/VMWizardState.swift)). VirGL is "experimental", Linux-only ([UTM docs: Display](https://docs.getutm.app/settings-qemu/devices/display/)) | Works: Omarchy 4 (Hyprland) as a daily driver on UTM 4.7.5 QEMU with virgl. Electron needs `--use-angle=vulkan` ([dchersey/omarchy-apple-silicon-utm](https://github.com/dchersey/omarchy-apple-silicon-utm), community). Open virglrenderer bugs on the Apple Core OpenGL renderer with Hyprland and kitty ([UTM#7944](https://github.com/utmapp/UTM/issues/7944)). 5.0.6 notes: "Linux desktop rendering in Vulkan does not work … use the older VirGL Gallium driver" | Import the cloud qcow2 and attach a `cidata` ISO: an AppleScript drive's `source` is "An existing file to use as the source image" ([`UTM.sdef`](https://github.com/utmapp/UTM/blob/main/Scripting/UTM.sdef)). Or boot the netinst with preseed | 4.7.5 stable: `utmctl clone`, `start --disposable` ("Run VM as a snapshot and do not save changes") ([`UTMCtl.swift` @ v4.7.5](https://github.com/utmapp/UTM/blob/v4.7.5/utmctl/UTMCtl.swift)). 5.0.6 beta: `utmctl snapshot` list/create/restore ([`UTMCtl.swift` @ v5.0.6](https://github.com/utmapp/UTM/blob/v5.0.6/utmctl/UTMCtl.swift)) | `utmctl` wraps AppleScript: start, stop, exec, file push/pull, ip-address (exec/file/IP need the QEMU guest agent) ([UTM docs: Scripting](https://docs.getutm.app/scripting/scripting/), [cheat sheet](https://docs.getutm.app/scripting/cheat-sheet/)). Headless means deleting the display, and "UTM needs to be open" ([UTM docs: Headless](https://docs.getutm.app/advanced/headless/)) | Apache-2.0, free. The App Store build is identical and paid ([mac.getutm.app](https://mac.getutm.app/)) |
| **UTM, Apple Virtualization backend** | virtio-gpu 2D only: "There is no GPU acceleration under AVF" ([UTM discussion #5482](https://github.com/utmapp/UTM/discussions/5482)) | llvmpipe path (see requirements) | Same as UTM QEMU | 5.0.6: snapshots for Apple VMs on macOS 27; "Run without saving changes" on macOS 27 ([v5.0.6 notes](https://github.com/utmapp/UTM/releases/tag/v5.0.6)) | Same as UTM QEMU | Same |
| **Lima `vz`** | Virtualization.framework virtio-gpu 2D. Lima attaches `VirtioGraphicsDeviceConfiguration` at 1920×1200 when `video.display` is `vz`/`default` ([`pkg/driver/vz/vm_darwin.go`](https://github.com/lima-vm/lima/blob/master/pkg/driver/vz/vm_darwin.go)) | llvmpipe path. #16077 is the closest match (2D virtio-gpu plus llvmpipe on Apple Silicon, though under libkrun) | Native: Lima boots cloud images and runs cloud-init. The `debian-13` template exists but uses `genericcloud`, so point `images:` at `generic` | `limactl snapshot` is experimental, and its test skips with "vmType vz does not implement snapshots" ([experimental.md](https://github.com/lima-vm/lima/blob/master/website/content/en/docs/releases/experimental.md), [`snapshot.bats`](https://github.com/lima-vm/lima/blob/master/hack/bats/tests/snapshot.bats)). Reset with `limactl clone` ([`clone.go`](https://github.com/lima-vm/lima/blob/master/cmd/limactl/clone.go)) or delete and recreate from the cached image | Fully CLI, no app. `vz` is the default on macOS ≥ 13.5 since v1.0 ([Lima docs: VM types](https://lima-vm.io/docs/config/vmtype/)) | Apache-2.0, free. Latest v2.2.1, 2026-10-03 |
| **VMware Fusion** | `vmwgfx`/SVGA: "OpenGL 4.3 … in Linux arm64 virtual machines on Apple Silicon Macs" ([Fusion 13.0 release notes, archived](https://web.archive.org/web/2023/https://docs.vmware.com/en/VMware-Fusion/13.0/rn/vmware-fusion-130-release-notes/index.html)) | **Broken with 3D on.** On vmwgfx, Hyprland's `drmCloseBufferHandle()` fails (EINVAL) for prime-imported surfaces, so "every GPU-accelerated Wayland client … fails". Reproduced on 0.56.2. The workaround is `LIBGL_ALWAYS_SOFTWARE=1` or an out-of-tree patch ([Hyprland#16175](https://github.com/hyprwm/Hyprland/issues/16175), closed by bot, not fixed) | Netinst with preseed. No first-party cloud-image import found | `vmrun snapshot` / `revertToSnapshot` ([Fusion vmrun docs](https://docs.vmware.com/en/VMware-Fusion/13/com.vmware.fusion.using.doc/GUID-24F54E24-EFB0-4E94-8A07-2AD791F0E497.html)) | `vmrun … nogui`. `runProgramInGuest` needs Tools | Free for all use since 2024-11-11, with no support tickets ([VMware blog](https://blogs.vmware.com/cloud-foundation/2024/11/11/vmware-fusion-and-workstation-are-now-free-for-all-users/)). Download needs a Broadcom account. macOS 27 host support not confirmed |
| **Parallels Desktop** | VirGL on virtio-gpu, on by default for new ARM Linux VMs, "works even without Parallels Tools" ([KB 128518](https://kb.parallels.com/en/128518)). "OpenGL 4.1 (Compatibility Profile)" for Linux guests ([PD 27 guide: Graphics](https://docs.parallels.com/landing/pdfm-ug/parallels-desktop-for-mac-27-users-guide/parallels-desktop-preferences-and-virtual-machine-settings/virtual-machine-settings/hardware-settings/graphics-settings)) | None found | Netinst with preseed | `prlctl` covers "snapshot management" and "cloning operations" | CLI only "In Pro and Business/Enterprise Editions" ([developer guide](https://docs.parallels.com/landing/parallels-desktop-developers-guide/command-line-interface-utility)) | Pro and Business are "available only as annual subscriptions" ([buy page](https://www.parallels.com/products/desktop/buy/)). List price not captured from a primary source |
| **Tart** | Virtualization.framework, so 2D only (same as Lima `vz`) | llvmpipe path | Create with `--linux` and boot an ISO. Prebuilt Debian OCI images. No cloud-init in its docs ([Tart quick start](https://tart.run/quick-start/)) | `tart clone` (APFS copy). `--suspendable` | `tart run --no-graphics` ([`Run.swift`](https://github.com/cirruslabs/tart/blob/main/Sources/tart/Commands/Run.swift)) | Fair Source: free on personal machines, and orgs up to 100 cores ([Tart licensing](https://tart.run/licensing/)) |
| **Homebrew QEMU, Lima `qemu`** | 2D only on macOS. Upstream `ui/cocoa.m` has no GL path, and the Homebrew formula pulls `libepoxy`/`mesa` only on Linux ([`qemu.rb`](https://github.com/Homebrew/homebrew-core/blob/main/Formula/q/qemu.rb)). QEMU's own host-requirements table for virgl and venus lists Linux hosts ([QEMU docs: virtio-gpu](https://gitlab.com/qemu-project/qemu/-/blob/master/docs/system/devices/virtio/virtio-gpu.rst)) | llvmpipe path | As Lima | Lima `qemu` supports snapshots (experimental) | As Lima. Lima warns that a QEMU display window hurts performance on macOS ([`templates/default.yaml`](https://github.com/lima-vm/lima/blob/master/templates/default.yaml)) | GPL, free |
| **Lima `krunkit` / libkrun** | Venus Vulkan for compute. Lima pitches it at GPU compute (llama.cpp), not a display ([Lima docs: Krunkit](https://github.com/lima-vm/lima/blob/master/website/content/en/docs/config/vmtype/krunkit.md)) | #16077 ran Hyprland on libkrun's 2D virtio-gpu, through a custom harness | As Lima | As Lima `qemu` | Experimental | Apache-2.0 |

## Recommendation

### Primary: UTM, QEMU backend, virgl

1. Base image: `debian-13-generic-arm64.qcow2`, checked against Debian's published
   `SHA512SUMS`, imported as the VirtIO boot drive. Attach a NoCloud `cidata` ISO
   as a removable drive. The seed creates the user, installs the SSH key, and
   enables `trixie-backports`. Leave the bootstrap (`git clone` and `./run.sh`)
   to the harness, so the run under test stays the real bootstrap.
2. Display: `virtio-gpu-gl-pci`, GL on. Leave Venus/Vulkan off for the desktop:
   UTM's own notes say Linux desktop rendering over Vulkan doesn't work yet.
3. Reset: keep a stopped "golden" VM and `utmctl clone` it per run, or
   `utmctl start --disposable`. Move to `utmctl snapshot` when UTM 5 goes stable.
   Today it is only in the 5.0.6 beta, whose snapshot scripting API already
   changed once between 5.0.5 and 5.0.6.
4. Drive: `utmctl start`, then SSH over the shared network, or `utmctl exec`
   with the QEMU guest agent. Collect proof over SSH: `hyprctl` and a `grim`
   screenshot from inside the session. UTM.app has to be running, so this is a
   logged-in-desktop harness, not a CI-runner harness.

**Why primary:** it is the only free path with 3D for Linux guests on this Mac,
and the only one with public Hyprland-on-it evidence. It also covers every
automation step from the CLI.

### Fallback: Lima `vz` with llvmpipe

Use it when virgl misrenders (UTM#7944-class bugs) or UTM regresses on macOS 27.
Override `images:` to the `generic` arm64 image, set `video.display: vz`, and
reset with `limactl clone` or delete-and-start. Within UTM, the step before
switching tools is `virtio-gpu-pci` (GL off), which gives the same llvmpipe
path with the same automation.

Caveats: Lima injects its own cloud-init (a host-named user, the guest agent,
mounts unless `--mount-none`), so its guest is less like a stock install than
the UTM import. llvmpipe tests correctness, not performance.

## What the VM can't test

- **SER8 hardware.** amdgpu with `firmware-amd-graphics`, `amd64-microcode`,
  fwupd, power-profiles-daemon, real outputs (VRR, HDR, multi-monitor, scaling
  at true DPI), hardware cursor planes, suspend/resume, Wi-Fi/Bluetooth, and
  audio hardware. In any VM above, Hyprland runs with a software cursor and
  virgl or llvmpipe, so GPU behaviour and performance aren't representative.
- **LUKS on the second NVMe and the recovery flow.** A second virtual disk can
  exercise `cryptsetup` and the unlock logic, but not the NVMe device names, the
  TRIM behaviour, or the netinst partitioning from `docs/install.md`.
- **amd64-only artifacts in today's modules.** Each needs an arch switch before
  the dev layer runs on arm64:
  - `modules/60-dev.sh:86` VS Code `os=linux-deb-x64`. An arm64 deb exists:
    `os=linux-deb-arm64` resolves to `code_…_arm64.deb`.
  - `modules/60-dev.sh:106` lazydocker `Linux_x86_64`. `Linux_arm64` is published
    ([releases](https://github.com/jesseduffield/lazydocker/releases/latest)).
  - `modules/40-desktop.sh:30` Ghostty `_amd64_trixie.deb`. `_arm64_trixie.deb`
    is published ([releases](https://github.com/mkasberg/ghostty-ubuntu/releases/latest)).
  - `modules/10-hardware.sh` `linux-image-amd64`, `firmware-amd-graphics`,
    `amd64-microcode`. These are machine layer, so they stay SER8-only.
- **Host-keyboard fidelity.** macOS and UTM intercept some modifier chords
  (Omarchy-on-UTM reports SUPER+CTRL and SUPER+ALT are swallowed). The VM can't
  validate the full keybinding set.

## Gaps

- **No first-hand Hyprland-on-UTM run on Debian.** The evidence is an Arch
  (Omarchy) guide and a FreeBSD bug report, and the guide doesn't name the
  renderer (ANGLE or Core OpenGL) or the display device. Which GLES version the
  guest gets under each UTM renderer wasn't established. A community comment
  claims virgl in UTM exposes only OpenGL 2.1
  ([omarchy discussion #452](https://github.com/omacom/omarchy/discussions/452));
  the newer guide contradicts it. Settle it with `eglinfo` in the first VM.
- **UTM 4.7.5 on macOS 27.** 4.7.5 (2026-01-03) predates macOS 27, and only the
  5.0.x betas mention macOS 27. Compatibility of the stable build isn't confirmed.
- **Hyprland 0.55.2 (backports) on llvmpipe in a VZ guest** hasn't been seen
  directly. #16077 is 0.56.1 under libkrun. The renderer's llvmpipe handling is
  in 0.55.2, but nobody has confirmed an end-to-end run.
- **Parallels:** no Hyprland reports, no guest GLES version, no list price from a
  primary source. Not pursued further, given the Pro-only CLI.
- **VMware Fusion:** no confirmation of macOS 27 host support for 26H1. The
  vmwgfx dmabuf bug's status upstream (discussion #12966) wasn't followed.
- **Cloud image versus netinst base.** The packages that differ between the
  `generic` cloud image (cloud-init, `grub-cloud-arm64`, no tasksel "standard")
  and a netinst "standard system utilities" install weren't enumerated. If the
  bootstrap depends on anything netinst installs, the VM harness needs a preseed
  path or an explicit package list. That belongs to the VM test harness fog patch.
- **Mesa auto-selecting zink** when Venus is enabled in UTM 5 wasn't checked
  against trixie's Mesa 25.0.7. Keep Venus off until checked.
