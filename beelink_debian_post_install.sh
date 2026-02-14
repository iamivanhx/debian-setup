#!/usr/bin/env bash
# =============================================================================
#  Debian 13 (Trixie) — Post-Installation Script
#  Optimized for: Beelink SER8 (AMD Ryzen 7 8845HS / Radeon 780M iGPU)
#
#  Usage:
#    chmod +x debian13-postinstall-ser8.sh
#    sudo ./debian13-postinstall-ser8.sh
#
#  What this script does:
#    1.  APT sources (main + backports) & system update
#    2.  Backported kernel (latest linux-image from trixie-backports)
#    3.  Minimal GNOME desktop (GDM3 + core Shell, no bloat)
#    4.  Essential base packages
#    5.  AMD GPU / RDNA3 driver & firmware (780M iGPU)
#    6.  CPU microcode & power-management tuning (Ryzen 7 8845HS)
#    7.  Kernel parameters optimised for AMD Zen 4
#    8.  NVMe optimisations (I/O scheduler, power policy)
#    9.  Wi-Fi & Bluetooth firmware (Intel AX200/AX210 common on SER8)
#   10.  Audio (PipeWire + WirePlumber)
#   11.  Thermal sensors & monitoring
#   12.  Memory / swap tuning for mini-PC workloads
#   13.  Firmware update daemon (fwupd)
#   14.  Security hardening (UFW, fail2ban)
#   15.  Flatpak + Flathub
#   16.  Optional desktop extras (Firefox, VLC, GIMP, etc.)
#   17.  Optional developer tools
#   18.  Hardware video acceleration
#   19.  System services tuning
#   20.  Desktop environment extras (GNOME tweaks)
#   21.  zsh + Oh My Zsh + Starship (Gruvbox Rainbow) + Nerd Font
#   22.  Ubuntu look & feel (Gruvbox Minimal GTK theme, Yaru base, Dash-to-Dock)
#   23.  Final cleanup & reboot prompt
#
#  Tested against: Debian 13 "Trixie" (amd64)
# =============================================================================

set -euo pipefail

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GRN='\033[0;32m'
YLW='\033[1;33m'
BLU='\033[0;34m'
CYN='\033[0;36m'
RST='\033[0m'

# ── Helpers ───────────────────────────────────────────────────────────────────
info()    { echo -e "${BLU}[INFO]${RST}  $*"; }
success() { echo -e "${GRN}[OK]${RST}    $*"; }
warn()    { echo -e "${YLW}[WARN]${RST}  $*"; }
error()   { echo -e "${RED}[ERROR]${RST} $*" >&2; exit 1; }
step()    { echo -e "\n${CYN}══════════════════════════════════════════════${RST}"; \
            echo -e "${CYN}  $*${RST}"; \
            echo -e "${CYN}══════════════════════════════════════════════${RST}"; }

ask_yes_no() {
    local prompt="$1"
    local answer
    read -rp "$(echo -e "${YLW}[?]${RST} ${prompt} [y/N]: ")" answer
    [[ "${answer,,}" == "y" ]]
}

# ── Atomic config deployment (preserves existing configs with dated backup) ──
# Usage: deploy_config "/path/to/target" << 'EOF'
#          ...content...
#        EOF
deploy_config() {
    local target="$1"
    local parent_dir
    parent_dir="$(dirname "$target")"
    mkdir -p "$parent_dir"
    if [[ -f "$target" ]]; then
        local backup="${target}.bak.$(date +%Y%m%d_%H%M%S)"
        cp "$target" "$backup"
        info "Backed up ${target} → ${backup}"
    fi
    cat > "$target"
}

# ── Install packages with dry-run preflight check ────────────────────────────
safe_install() {
    local desc="$1"
    shift
    info "Installing: ${desc}..."
    if ! apt-get install -y --dry-run "$@" &>/dev/null; then
        warn "Preflight check flagged issues for: ${desc}. Attempting install anyway..."
    fi
    DEBIAN_FRONTEND=noninteractive apt-get install -y "$@" \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confold" \
        || warn "Some packages in '${desc}' could not be installed — continuing."
    success "${desc} installed."
}

# ── Trap for unexpected exits ─────────────────────────────────────────────────
LOGFILE="/var/log/debian13-postinstall-ser8.log"
trap 'echo -e "${RED}[FATAL]${RST} Script exited unexpectedly at line ${LINENO}. Check: ${LOGFILE}" >&2' ERR

# ── Root check ────────────────────────────────────────────────────────────────
[[ $EUID -ne 0 ]] && error "Please run as root: sudo $0"

# ── Logging ───────────────────────────────────────────────────────────────────
exec > >(tee -a "$LOGFILE") 2>&1
info "Full log available at: $LOGFILE"

# =============================================================================
# STEP 0 — OS DETECTION & HARDWARE FINGERPRINT
# =============================================================================
step "Step 0 — OS detection & hardware fingerprint"

# ── Distro check ─────────────────────────────────────────────────────────────
if [[ -f /etc/os-release ]]; then
    # shellcheck source=/dev/null
    source /etc/os-release
    DISTRO_CODENAME="${VERSION_CODENAME:-unknown}"
    info "Detected OS: ${PRETTY_NAME:-unknown} (codename: ${DISTRO_CODENAME})"
    if [[ "$DISTRO_CODENAME" != "trixie" && "$DISTRO_CODENAME" != "testing" ]]; then
        warn "This script targets Debian 13 Trixie. Detected: ${DISTRO_CODENAME}."
        warn "Some packages or paths may differ on your release."
        ask_yes_no "Continue anyway?" || exit 1
    fi
else
    warn "Cannot detect OS version (/etc/os-release missing) — proceeding anyway."
    DISTRO_CODENAME="trixie"
fi

# ── Hardware detection ────────────────────────────────────────────────────────
detect_hardware() {
    info "Detecting hardware..."

    CPU_MODEL=$(grep -m1 "model name" /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs || echo "unknown")
    GPU_DEVICE=$(lspci 2>/dev/null | grep -i "vga\|display\|3d" | cut -d: -f3 | head -1 | xargs || echo "unknown")
    NVME_DEVICES=$(lsblk -dno NAME,MODEL 2>/dev/null | grep -i nvme || echo "none detected")
    RAM_GB=$(awk '/MemTotal/ {printf "%.0f", $2/1024/1024}' /proc/meminfo 2>/dev/null || echo "?")

    info "CPU  : ${CPU_MODEL}"
    info "GPU  : ${GPU_DEVICE}"
    info "NVMe : ${NVME_DEVICES}"
    info "RAM  : ${RAM_GB} GB"

    # Soft-warn on CPU/GPU mismatch (script still works, just may be suboptimal)
    if [[ "$CPU_MODEL" != *"8845HS"* ]]; then
        warn "CPU does not appear to be the Ryzen 7 8845HS — some tuning params may be suboptimal."
    fi
    if [[ "$GPU_DEVICE" != *"AMD"* && "$GPU_DEVICE" != *"Radeon"* && "$GPU_DEVICE" != *"ATI"* ]]; then
        warn "AMD/Radeon GPU not detected — GPU-specific steps may be suboptimal."
    fi
    if [[ -z "$(lsblk -dno NAME 2>/dev/null | grep nvme)" ]]; then
        warn "No NVMe device detected — NVMe tuning will still be applied but may have no effect."
    fi
}
detect_hardware

# ── Determine real user early (reused across steps) ───────────────────────────
if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
    REAL_USER="$SUDO_USER"
    REAL_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
else
    REAL_USER="root"
    REAL_HOME="/root"
fi
info "Target user for shell/theme config: ${REAL_USER} (home: ${REAL_HOME})"

# =============================================================================
# STEP 1 — APT SOURCES (main + backports) & SYSTEM UPDATE
# =============================================================================
step "Step 1 — APT sources (main + backports) & system update"

info "Configuring APT sources with contrib, non-free & backports..."
deploy_config /etc/apt/sources.list << EOF
# Debian 13 Trixie — Main, Contrib, Non-Free, Non-Free-Firmware
deb http://deb.debian.org/debian ${DISTRO_CODENAME} main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian ${DISTRO_CODENAME} main contrib non-free non-free-firmware

# Security updates
deb http://security.debian.org/debian-security ${DISTRO_CODENAME}-security main contrib non-free non-free-firmware
deb-src http://security.debian.org/debian-security ${DISTRO_CODENAME}-security main contrib non-free non-free-firmware

# Updates
deb http://deb.debian.org/debian ${DISTRO_CODENAME}-updates main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian ${DISTRO_CODENAME}-updates main contrib non-free non-free-firmware

# Backports — latest kernels, Mesa, firmware, and other updated packages.
# Packages here are NOT installed automatically; use -t ${DISTRO_CODENAME}-backports
# or the explicit pin in /etc/apt/preferences.d/. Only the kernel (Step 2) pulls
# from here by default.
deb http://deb.debian.org/debian ${DISTRO_CODENAME}-backports main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian ${DISTRO_CODENAME}-backports main contrib non-free non-free-firmware
EOF

# Pin backports at low priority (200) so regular upgrades never pull them in.
# Individual packages that should come from backports are targeted explicitly
# with -t ${DISTRO_CODENAME}-backports at install time.
deploy_config /etc/apt/preferences.d/99-backports-pin << EOF
Package: *
Pin: release a=${DISTRO_CODENAME}-backports
Pin-Priority: 200
EOF

info "Running single coordinated apt update + full upgrade..."
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get full-upgrade -y \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold"
success "System updated. Backports repo enabled (pinned at priority 200)."

# =============================================================================
# STEP 2 — BACKPORTED KERNEL (latest linux-image from trixie-backports)
# =============================================================================
step "Step 2 — Backported kernel installation"

# Why backports?
#   The Ryzen 7 8845HS (Zen 4 / Phoenix) and the Radeon 780M (RDNA 3 / GFX1103)
#   benefit significantly from newer kernels: improved amd_pstate CPPC support,
#   better firmware-loading paths for the 780M, upstream DRM/amdgpu fixes, and
#   newer power-management patches that land in mainline well before Trixie stable.
#
# Strategy:
#   1. Query which linux-image-amd64 version is available in backports.
#   2. Install that meta-package (+ matching headers) with -t backports.
#   3. Also pull firmware-amd-graphics from backports — it ships newer GPU blobs
#      that the backported kernel may need.
#   4. Pin the installed kernel so future unattended-upgrades won't downgrade it.
#   5. Regenerate GRUB so the new kernel is the default entry.

info "Querying latest kernel available in ${DISTRO_CODENAME}-backports..."

# Resolve the exact version available in backports (e.g. 6.12.0+1~bpo13+1)
BPO_KERNEL_VERSION=$(apt-cache policy linux-image-amd64 \
    -t "${DISTRO_CODENAME}-backports" 2>/dev/null \
    | grep "Candidate:" | awk '{print $2}')

if [[ -z "$BPO_KERNEL_VERSION" || "$BPO_KERNEL_VERSION" == "(none)" ]]; then
    warn "No backported kernel found in ${DISTRO_CODENAME}-backports — skipping kernel upgrade."
    warn "Ensure the backports repo is reachable and run: apt-get update"
else
    info "Backported kernel candidate: linux-image-amd64 ${BPO_KERNEL_VERSION}"

    # Install meta-packages from backports.
    # Package breakdown:
    #   linux-image-amd64    — meta-package tracking the latest amd64 kernel in the repo
    #   linux-headers-amd64  — meta-package pulling in matching versioned headers
    #   firmware-amd-graphics — backported GPU firmware blobs (780M needs newer ones)
    #   dkms                 — Dynamic Kernel Module Support (rebuilds out-of-tree
    #                          modules automatically on kernel upgrades)
    #   make gcc             — build toolchain required by DKMS to compile modules;
    #                          these are standard packages that exist in Trixie main
    #
    # NOTE: There is NO "linux-compiler-gcc-*" package in Debian Trixie.
    # DKMS uses the system GCC (gcc meta-package → gcc-14 on Trixie) directly.
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        -t "${DISTRO_CODENAME}-backports" \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confold" \
        linux-image-amd64 \
        linux-headers-amd64 \
        firmware-amd-graphics

    # Install DKMS build dependencies from the standard (non-backports) repo.
    # gcc, make, and dkms are in Trixie main and do not need -t backports.
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confold" \
        dkms \
        gcc \
        make

    # Pin linux-image-amd64 and linux-headers-amd64 to the backports track so
    # future `apt upgrade` runs continue pulling kernel updates from backports
    # rather than regressing to the Trixie stable kernel version.
    deploy_config /etc/apt/preferences.d/98-backports-kernel << EOF
# Keep kernel meta-packages on the trixie-backports track
Package: linux-image-amd64 linux-headers-amd64
Pin: release a=${DISTRO_CODENAME}-backports
Pin-Priority: 900
EOF

    # Determine the concrete kernel version string that was just installed
    # (e.g. "6.12.0-0.deb12.6+1") for the GRUB default entry.
    INSTALLED_BPO_KERNEL=$(dpkg -l 'linux-image-[0-9]*' 2>/dev/null \
        | awk '/^ii/ {print $2}' \
        | sort -V | tail -1 \
        | sed 's/linux-image-//')
    info "Installed kernel version: ${INSTALLED_BPO_KERNEL:-<detecting after dpkg>}"

    # Rebuild initramfs for the new kernel (update-initramfs is called by dpkg
    # hooks, but we force it here to guarantee completion in non-interactive mode)
    if [[ -n "$INSTALLED_BPO_KERNEL" ]]; then
        update-initramfs -u -k "$INSTALLED_BPO_KERNEL" 2>/dev/null \
            || warn "update-initramfs returned non-zero — check /var/log/kern.log after reboot."
    fi

    # Regenerate GRUB config so the new kernel appears first
    update-grub 2>/dev/null || true

    success "Backported kernel installed: ${INSTALLED_BPO_KERNEL:-linux-image-amd64 (latest)}."
    info "  → The new kernel will be active after reboot (Step 23 offers a reboot prompt)."
    info "  → To verify after reboot: uname -r"
fi

# =============================================================================
# STEP 3 — MINIMAL GNOME DESKTOP
# =============================================================================
step "Step 3 — Minimal GNOME desktop installation"

# Philosophy: install the smallest viable GNOME that gives a usable Wayland
# session with GDM3, without pulling in the full gnome-core or task-gnome-desktop
# bloat (LibreOffice, games, evolution, etc.).
#
# Package breakdown:
#   gnome-shell          — the compositor/shell itself (Wayland + Mutter)
#   gdm3                 — GNOME Display Manager (login screen)
#   gnome-session        — session manager (needed to start gnome-shell properly)
#   gnome-settings-daemon — background daemon for power, display, input settings
#   gnome-control-center — Settings app (essential for usability)
#   gnome-terminal       — default terminal (lightweight, integrates well)
#   nautilus             — Files app (drag-and-drop, desktop icons integration)
#   gnome-text-editor    — simple text editor (replaces gedit in GNOME 45+)
#   gvfs gvfs-backends   — virtual filesystem (USB automount, network shares)
#   xdg-utils            — xdg-open and MIME type handling
#   xdg-user-dirs        — creates ~/Desktop, ~/Downloads, etc. on first login
#   polkitd              — policy kit daemon (renamed from polkit in Trixie)
#   pkexec               — run commands with polkit authorization
#   network-manager      — Wi-Fi / Ethernet management (nm-applet in GNOME)
#   network-manager-gnome — NM system tray applet
#   gnome-keyring        — secrets/password manager integrated into GNOME
#   gsettings-desktop-schemas — required GSettings schemas for desktop behaviour
#   adwaita-icon-theme   — default GNOME icon set
#   fonts-cantarell      — default GNOME UI font

GNOME_MINIMAL_PKGS=(
    # Core shell + session
    gnome-shell
    gnome-session
    gnome-settings-daemon
    gdm3
    # Essential apps (minimal set — more added in later steps)
    gnome-control-center
    gnome-terminal
    nautilus
    gnome-text-editor
    # System integration
    gvfs
    gvfs-backends
    xdg-utils
    xdg-user-dirs
    xdg-user-dirs-gtk
    polkitd
    pkexec
    # Note: polkit-gnome was dropped from Debian Trixie.
    # polkitd provides the D-Bus authority; GNOME Shell uses its own built-in
    # auth agent for desktop sessions (no separate agent package needed).
    # Networking
    network-manager
    network-manager-gnome
    # Keyring / auth
    gnome-keyring
    libpam-gnome-keyring
    # Schemas + themes + fonts
    gsettings-desktop-schemas
    adwaita-icon-theme
    fonts-cantarell
    # Accessibility (required for GNOME session to start cleanly)
    at-spi2-core
    # Wayland XDG portal (required for Flatpak, screen capture, file chooser)
    xdg-desktop-portal
    xdg-desktop-portal-gnome
    # Dconf editor backend
    dconf-cli
)

info "Installing minimal GNOME packages..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" \
    "${GNOME_MINIMAL_PKGS[@]}" \
    || warn "One or more GNOME packages could not be installed — check apt output above."

# Enable GDM3 as the default display manager
info "Enabling GDM3 display manager..."
# Debconf pre-answer to avoid interactive DM selection dialog
echo "/usr/sbin/gdm3" > /etc/X11/default-display-manager
DEBIAN_FRONTEND=noninteractive dpkg-reconfigure gdm3 2>/dev/null || true
systemctl enable gdm3.service
systemctl set-default graphical.target

# Enable NetworkManager (replaces ifupdown for desktop use)
info "Enabling NetworkManager..."
systemctl enable NetworkManager.service

# Disable ifupdown management of the primary interface so NM takes over.
# We only disable managed=false if the file already exists from a base install.
NM_CONF="/etc/NetworkManager/NetworkManager.conf"
if [[ -f "$NM_CONF" ]]; then
    if grep -q "managed=false" "$NM_CONF"; then
        sed -i 's/managed=false/managed=true/' "$NM_CONF"
        info "NetworkManager: set managed=true for desktop interfaces."
    fi
fi

# Create a NetworkManager config that manages all Ethernet/Wi-Fi interfaces
deploy_config /etc/NetworkManager/conf.d/10-managed.conf << 'EOF'
[main]
# Let NetworkManager manage all interfaces (desktop mode)
plugins=ifupdown,keyfile

[ifupdown]
managed=true
EOF

# Disable /etc/network/interfaces management of non-loopback interfaces
# to prevent conflicts between ifupdown and NetworkManager
if [[ -f /etc/network/interfaces ]]; then
    # Back up and leave only the loopback entry
    cp /etc/network/interfaces /etc/network/interfaces.bak_preNM
    deploy_config /etc/network/interfaces << 'EOF'
# This file intentionally left minimal.
# NetworkManager manages all interfaces (see /etc/NetworkManager/).
# Loopback is still managed here as required.
auto lo
iface lo inet loopback
EOF
    info "Reduced /etc/network/interfaces to loopback-only (NM handles the rest)."
fi

# XDG user directories — create them now for the real user
if [[ "$REAL_USER" != "root" ]]; then
    sudo -u "$REAL_USER" xdg-user-dirs-update 2>/dev/null || true
    info "XDG user directories created for ${REAL_USER}."
fi

success "Step 3 complete — minimal GNOME desktop installed."
info "  → GDM3 set as default display manager."
info "  → Boot target: graphical.target (GUI login on next reboot)."
info "  → NetworkManager will manage Wi-Fi and Ethernet after reboot."
warn "  → Do NOT reboot yet — hardware drivers and audio are installed in later steps."

# =============================================================================
# STEP 4 — ESSENTIAL BASE PACKAGES
# =============================================================================
step "Step 4 — Essential base packages"

BASE_ESSENTIAL=(
    curl wget git vim nano htop btop fastfetch
    build-essential cmake pkg-config
    apt-transport-https ca-certificates gnupg lsb-release
)
BASE_ARCHIVE=(
    zip unzip p7zip-full tar gzip bzip2 xz-utils zstd
)
BASE_FILESYSTEM=(
    ntfs-3g exfatprogs dosfstools btrfs-progs
)
BASE_NETWORK=(
    net-tools iproute2 iw rfkill openssh-client
    nmap traceroute iputils-ping dnsutils
)
BASE_HWINFO=(
    lshw hwinfo pciutils usbutils dmidecode inxi
)
BASE_MONITOR=(
    iotop iftop powertop nvtop sysstat
)
BASE_MISC=(
    bash-completion command-not-found software-properties-common
    python3 python3-pip python3-venv
    jq tree tmux screen fzf ripgrep fd-find bat
)

safe_install "core utilities"      "${BASE_ESSENTIAL[@]}"
safe_install "archive tools"       "${BASE_ARCHIVE[@]}"
safe_install "filesystem tools"    "${BASE_FILESYSTEM[@]}"
safe_install "network tools"       "${BASE_NETWORK[@]}"
safe_install "hardware info tools" "${BASE_HWINFO[@]}"
safe_install "monitoring tools"    "${BASE_MONITOR[@]}"
safe_install "misc utilities"      "${BASE_MISC[@]}"

# =============================================================================
# STEP 5 — AMD GPU DRIVER & FIRMWARE (Radeon 780M / RDNA 3)
# =============================================================================
step "Step 5 — AMD GPU firmware & drivers (Radeon 780M / RDNA 3)"

AMD_GPU_PKGS=(
    firmware-amd-graphics       # Radeon 780M iGPU firmware blobs
    libdrm-amdgpu1              # DRM userspace library
    xserver-xorg-video-amdgpu   # Xorg DDX driver (for X11 setups)
    mesa-vulkan-drivers         # Vulkan (radv) for AMD
    mesa-va-drivers             # VA-API hardware video decode
    libva-utils                 # vainfo tool
    vulkan-tools                # vulkaninfo tool
    radeontop                   # GPU monitoring (AMD-specific, in Trixie main)
)

safe_install "AMD GPU firmware and Mesa drivers" "${AMD_GPU_PKGS[@]}"

# Ensure amdgpu kernel module is loaded at boot
if ! grep -q "^amdgpu" /etc/modules; then
    echo "amdgpu" >> /etc/modules
    info "Added amdgpu to /etc/modules."
fi

# Wayland: ensure GBM backend is preferred for AMD
mkdir -p /etc/environment.d
deploy_config /etc/environment.d/80-amd-wayland.conf << 'EOF'
# Force AMD GBM backend for Wayland compositors
GBM_BACKEND=amdgpu
__GLX_VENDOR_LIBRARY_NAME=mesa
LIBVA_DRIVER_NAME=radeonsi
AMD_VULKAN_ICD=RADV
# ROCm/HIP for GPU compute (optional)
ROC_ENABLE_PRE_VEGA=1
EOF

success "AMD GPU drivers configured."

# =============================================================================
# STEP 6 — CPU MICROCODE & POWER MANAGEMENT (Ryzen 7 8845HS / Zen 4)
# =============================================================================
step "Step 6 — AMD CPU microcode & power management"

safe_install "AMD CPU power tools" \
    amd64-microcode \
    cpupower \
    linux-cpupower \
    powertop \
    thermald \
    acpid \
    acpi \
    lm-sensors

# cpupower — set governor to schedutil (best for Zen 4 with boost)
info "Configuring CPU frequency scaling (schedutil governor)..."
deploy_config /etc/default/cpupower << 'EOF'
# CPU frequency governor for AMD Ryzen 7 8845HS (Zen 4)
# schedutil: kernel-integrated, respects AMD boost correctly
START_OPTS="--governor schedutil"
STOP_OPTS=""
EOF

systemctl enable cpupower.service 2>/dev/null || true
success "CPU power management configured."

# =============================================================================
# STEP 7 — KERNEL PARAMETERS (GRUB)
# =============================================================================
step "Step 7 — Kernel parameters (GRUB)"

GRUB_FILE="/etc/default/grub"

# Kernel cmdline params for Ryzen 7 8845HS + SER8:
#   amd_pstate=active  : Active P-State driver (Zen 4 native CPPC)
#   idle=nomwait       : Prevent mwait C-state issues on some BIOSes
#   nowatchdog         : Disable NMI watchdog (saves ~1 CPU wake/sec)
#   loglevel=3         : Quiet boot (suppress non-critical kernel messages)
#   mitigations=auto   : Keep default Spectre/Meltdown mitigations
KERNEL_PARAMS="amd_pstate=active idle=nomwait nowatchdog loglevel=3 mitigations=auto"

if [[ -f "$GRUB_FILE" ]]; then
    info "Backing up GRUB config..."
    cp "$GRUB_FILE" "${GRUB_FILE}.bak_$(date +%Y%m%d_%H%M%S)"

    # Safe replacement: build the full line, then replace atomically
    NEW_CMDLINE="GRUB_CMDLINE_LINUX_DEFAULT=\"quiet splash ${KERNEL_PARAMS}\""

    if grep -q '^GRUB_CMDLINE_LINUX_DEFAULT=' "$GRUB_FILE"; then
        # Use | as delimiter to avoid issues with spaces and slashes in the value
        sed -i.bak "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|${NEW_CMDLINE}|" "$GRUB_FILE"
    else
        echo "$NEW_CMDLINE" >> "$GRUB_FILE"
    fi

    # Enable GRUB timeout (useful for dual-boot; harmless otherwise)
    if grep -q '^GRUB_TIMEOUT=' "$GRUB_FILE"; then
        sed -i 's|^GRUB_TIMEOUT=.*|GRUB_TIMEOUT=5|' "$GRUB_FILE"
    else
        echo "GRUB_TIMEOUT=5" >> "$GRUB_FILE"
    fi

    info "Updating GRUB..."
    update-grub
    success "Kernel parameters updated."
else
    warn "GRUB config not found at ${GRUB_FILE} — skipping. (systemd-boot or other bootloader?)"
fi

# =============================================================================
# STEP 8 — NVMe OPTIMISATION
# =============================================================================
step "Step 8 — NVMe I/O optimisation"

info "Configuring NVMe I/O scheduler and power policy..."
deploy_config /etc/udev/rules.d/60-nvme-ioscheduler.rules << 'EOF'
# I/O scheduler for NVMe SSDs — mq-deadline balances latency & throughput
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="mq-deadline"
# Allow NVMe autonomous power state transitions (APST) — saves ~0.5–1W idle
ACTION=="add", SUBSYSTEM=="nvme", ATTR{power/control}="auto"
EOF

# Trim: enable weekly fstrim timer
systemctl enable fstrim.timer
systemctl start fstrim.timer
success "NVMe optimisations applied."

# =============================================================================
# STEP 9 — WI-FI & BLUETOOTH FIRMWARE
# =============================================================================
step "Step 9 — Wi-Fi & Bluetooth firmware"

safe_install "Wi-Fi & Bluetooth firmware" \
    firmware-iwlwifi \
    firmware-realtek \
    firmware-atheros \
    wireless-tools \
    wpasupplicant \
    rfkill \
    bluetooth \
    bluez \
    bluez-tools

systemctl enable bluetooth.service
systemctl start bluetooth.service
success "Wi-Fi & Bluetooth firmware installed."

# =============================================================================
# STEP 10 — AUDIO (PipeWire + WirePlumber)
# =============================================================================
step "Step 10 — PipeWire audio stack"

# Note: pulseaudio-module-bluetooth is NOT installed — PipeWire handles BT
# directly via libspa-0.2-bluetooth. Mixing PulseAudio modules with PipeWire
# causes conflicts in Trixie.
safe_install "PipeWire audio stack" \
    pipewire \
    pipewire-alsa \
    pipewire-audio \
    pipewire-jack \
    pipewire-pulse \
    wireplumber \
    libspa-0.2-bluetooth \
    libspa-0.2-jack \
    gstreamer1.0-pipewire \
    pavucontrol \
    alsa-utils \
    sof-firmware

# The Ryzen 8845HS uses SOF (Sound Open Firmware) for audio
if ! grep -q "snd_sof_amd_acp" /etc/modules 2>/dev/null; then
    echo "snd_sof_amd_acp" >> /etc/modules
fi

success "PipeWire audio stack installed."

# =============================================================================
# STEP 11 — THERMAL SENSORS & MONITORING
# =============================================================================
step "Step 11 — Thermal sensors & hardware monitoring"

safe_install "thermal monitoring tools" \
    lm-sensors \
    fancontrol \
    i2c-tools \
    stress-ng

# Autodetect sensor modules (suppress prompts with --auto)
sensors-detect --auto > /dev/null 2>&1 || true
success "Thermal monitoring tools installed. Run 'sensors' to check temps."

# =============================================================================
# STEP 12 — MEMORY / SWAP TUNING
# =============================================================================
step "Step 12 — Memory & swap tuning"

info "Applying sysctl optimisations for mini-PC workloads..."
deploy_config /etc/sysctl.d/99-ser8-tuning.conf << 'EOF'
# ── Memory management ─────────────────────────────────────────────────────
# Lower swappiness — keep more data in RAM (SER8 has 32/64GB DDR5)
vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
vm.overcommit_memory = 1

# ── Network performance ───────────────────────────────────────────────────
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.core.netdev_max_backlog = 16384
net.core.somaxconn = 8192
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_slow_start_after_idle = 0

# ── File system ───────────────────────────────────────────────────────────
fs.inotify.max_user_watches = 524288
fs.file-max = 2097152

# ── Kernel misc ───────────────────────────────────────────────────────────
kernel.nmi_watchdog = 0
kernel.sched_autogroup_enabled = 1
EOF

sysctl --system > /dev/null
success "Sysctl tuning applied."

# zram swap (better than a swap file for systems with ample RAM)
info "Setting up zram swap..."
safe_install "zram swap" zram-tools

deploy_config /etc/default/zramswap << 'EOF'
# zram — compressed swap in RAM (good for Ryzen 8845HS w/ fast DDR5)
ALGO=zstd
PERCENT=25
PRIORITY=100
EOF

systemctl enable zramswap.service
systemctl restart zramswap.service || true
success "zram swap configured (25% of RAM, zstd compression)."

# =============================================================================
# STEP 13 — FIRMWARE UPDATE (fwupd)
# =============================================================================
step "Step 13 — Firmware update daemon (fwupd)"

safe_install "fwupd" fwupd

info "Refreshing firmware metadata..."
fwupdmgr refresh --force 2>/dev/null \
    || warn "fwupd metadata refresh failed (no internet or no updates available)."

info "To check for firmware updates later, run: fwupdmgr get-updates && fwupdmgr update"
success "fwupd installed."

# =============================================================================
# STEP 14 — SECURITY HARDENING
# =============================================================================
step "Step 14 — Basic security hardening"

safe_install "firewall & intrusion prevention" ufw fail2ban

# UFW — sensible defaults for a mini-PC (no exposed services by default)
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh comment "SSH access"
ufw --force enable

deploy_config /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime  = 3600
findtime = 600
maxretry = 5
backend  = systemd

[sshd]
enabled = true
port    = ssh
EOF

systemctl enable fail2ban
systemctl restart fail2ban
success "UFW + fail2ban configured."

# =============================================================================
# STEP 15 — FLATPAK & FLATHUB
# =============================================================================
step "Step 15 — Flatpak + Flathub"

safe_install "Flatpak" flatpak

info "Adding Flathub remote..."
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# GNOME Software integration (optional, silently skip if unavailable)
DEBIAN_FRONTEND=noninteractive apt-get install -y gnome-software-plugin-flatpak 2>/dev/null || true
success "Flatpak + Flathub configured."

# =============================================================================
# STEP 16 — OPTIONAL: DESKTOP APPLICATIONS
# =============================================================================
step "Step 16 — Optional desktop applications"

if ask_yes_no "Install common desktop apps (Firefox, VLC, GIMP, gnome-tweaks, etc.)?"; then
    safe_install "common desktop apps" \
        firefox-esr \
        vlc \
        gnome-tweaks \
        gparted \
        timeshift \
        copyq \
        flameshot
fi

# ── Google Chrome ─────────────────────────────────────────────────────────────
if ask_yes_no "Install Google Chrome?"; then
    if command -v google-chrome &>/dev/null; then
        info "Google Chrome already installed — skipping."
    else
        info "Downloading Google Chrome..."
        TMP_DEB=$(mktemp /tmp/chrome-XXXXXX.deb)
        curl -fsSL \
            --connect-timeout 30 \
            --retry 3 \
            --retry-delay 5 \
            "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb" \
            -o "$TMP_DEB"
        DEBIAN_FRONTEND=noninteractive apt-get install -y "$TMP_DEB"
        rm -f "$TMP_DEB"
        success "Google Chrome installed."
    fi
fi

# =============================================================================
# STEP 17 — OPTIONAL: DEVELOPER TOOLS
# =============================================================================
step "Step 17 — Optional developer tools"

if ask_yes_no "Install developer tools (VS Code, Node.js LTS, Go)?"; then

    # VS Code
    info "Adding Microsoft APT repository for VS Code..."
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
        | gpg --dearmor -o /etc/apt/keyrings/microsoft.gpg
    deploy_config /etc/apt/sources.list.d/vscode.list << 'EOF'
deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main
EOF
    apt-get update -qq
    safe_install "Visual Studio Code" code

    # Node.js LTS (via NodeSource)
    info "Adding NodeSource repository (LTS)..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - > /dev/null
    safe_install "Node.js LTS" nodejs

    # Go (from Debian repos — latest stable is usually up-to-date in Trixie)
    safe_install "Go language" golang

    success "Developer tools installed."
fi

# =============================================================================
# STEP 18 — OPTIONAL: GAMING OPTIMISATIONS (commented out by default)
# =============================================================================
# Uncomment this entire block to enable gaming support.
#
# step "Step 18 — Optional gaming optimisations"
# if ask_yes_no "Install gaming support (Steam, Lutris, MangoHud, GameMode, Proton)?"; then
#     dpkg --add-architecture i386
#     apt-get update -qq
#     safe_install "gaming packages" \
#         steam lutris mangohud gamemode gamescope \
#         libgamemode0 libgamemodeauto0 \
#         mesa-vulkan-drivers:i386 \
#         libvulkan1 libvulkan1:i386 \
#         vulkan-validationlayers
#
#     systemctl --user enable gamemoded 2>/dev/null || true
#
#     cat >> /etc/security/limits.conf << 'EOF'
# # Gaming: increase file descriptor limits
# *    soft nofile 524288
# *    hard nofile 524288
# EOF
#     success "Gaming packages installed."
#     info "Steam launch option: gamemoderun %command%"
# fi

# =============================================================================
# STEP 19 — HARDWARE VIDEO ACCELERATION VERIFICATION
# =============================================================================
step "Step 19 — Hardware video acceleration"

safe_install "VA-API and hardware video decode" \
    mesa-va-drivers \
    libva-utils \
    gstreamer1.0-vaapi \
    ffmpeg \
    mpv

info "Verifying VA-API support (AMD 780M)..."
vainfo 2>/dev/null || warn "vainfo check deferred — run manually after reboot: vainfo"
success "Hardware video acceleration configured."

# =============================================================================
# STEP 20 — SYSTEM SERVICES TUNING
# =============================================================================
step "Step 20 — Systemd & journald tuning"

info "Tuning journald logging..."
mkdir -p /etc/systemd/journald.conf.d
deploy_config /etc/systemd/journald.conf.d/99-ser8.conf << 'EOF'
[Journal]
# Cap journal size to 500MB
SystemMaxUse=500M
# Forward to /dev/kmsg for dmesg visibility
ForwardToKMsg=no
# Compress journal
Compress=yes
EOF

info "Disabling rarely needed services on a mini-PC..."
DISABLE_SERVICES=(
    ModemManager.service        # No cellular modem
    avahi-daemon.service        # mDNS (disable if not needed on local network)
)
for svc in "${DISABLE_SERVICES[@]}"; do
    systemctl disable "$svc" 2>/dev/null && info "Disabled: $svc" || true
done

mkdir -p /etc/systemd/system.conf.d
deploy_config /etc/systemd/system.conf.d/99-timeouts.conf << 'EOF'
[Manager]
DefaultTimeoutStopSec=15s
DefaultTimeoutStartSec=30s
EOF

systemctl daemon-reload
success "Systemd tuning applied."

# =============================================================================
# STEP 21 — DESKTOP ENVIRONMENT EXTRAS (if GNOME detected)
# =============================================================================
step "Step 21 — Desktop environment tweaks"

if command -v gnome-shell &>/dev/null; then
    info "GNOME detected — applying GNOME-specific tweaks..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        gnome-shell-extension-manager \
        gnome-shell-extensions \
        gnome-tweaks \
        dconf-editor \
        gnome-browser-connector 2>/dev/null || true

    if [[ -n "${SUDO_USER:-}" ]]; then
        sudo -u "$SUDO_USER" \
            DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u "$SUDO_USER")/bus" \
            dbus-launch gsettings set \
                org.gnome.settings-daemon.plugins.power power-button-action 'suspend' \
            2>/dev/null || true
        sudo -u "$SUDO_USER" \
            DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u "$SUDO_USER")/bus" \
            dbus-launch gsettings set \
                org.gnome.mutter experimental-features "['scale-monitor-framebuffer']" \
            2>/dev/null || true
    fi
    success "GNOME tweaks applied."

elif command -v plasmashell &>/dev/null; then
    info "KDE Plasma detected — installing KDE extras..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        plasma-widgets-addons \
        kde-plasma-desktop \
        powerdevil \
        kscreen 2>/dev/null || true
    success "KDE tweaks applied."
fi

# =============================================================================
# STEP 22 — ZSH + OH MY ZSH + STARSHIP (GRUVBOX RAINBOW) + NERD FONT
# =============================================================================
step "Step 22 — zsh + Oh My Zsh + Starship (Gruvbox Rainbow) + JetBrainsMono Nerd Font"

info "Configuring shell environment for user: ${REAL_USER} (home: ${REAL_HOME})"

# ── 20.1  Install zsh and dependencies ──────────────────────────────────────
safe_install "zsh and font dependencies" \
    zsh zsh-common git curl wget fontconfig unzip xfonts-utils

# ── 20.2  Set zsh as default shell ──────────────────────────────────────────
info "Setting zsh as default shell for ${REAL_USER}..."
chsh -s "$(command -v zsh)" "$REAL_USER"
success "Default shell changed to zsh."

# ── 20.3  Install JetBrainsMono Nerd Font (system-wide) ─────────────────────
info "Installing JetBrainsMono Nerd Font (system-wide)..."
FONT_DIR="/usr/local/share/fonts/jetbrainsmono-nerd"
mkdir -p "$FONT_DIR"

# Fetch latest Nerd Fonts release tag; fall back to known stable version
NF_VERSION=$(curl -fsSL --connect-timeout 10 \
    https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest \
    2>/dev/null | grep '"tag_name"' | head -1 | cut -d'"' -f4 || true)
NF_VERSION="${NF_VERSION:-v3.2.1}"
info "Nerd Fonts version: ${NF_VERSION}"

FONT_ZIP="/tmp/JetBrainsMono-NF.zip"
curl -fsSL \
    --connect-timeout 30 \
    --retry 3 \
    --retry-delay 5 \
    "https://github.com/ryanoasis/nerd-fonts/releases/download/${NF_VERSION}/JetBrainsMono.zip" \
    -o "$FONT_ZIP"

unzip -o -q "$FONT_ZIP" -d "$FONT_DIR"
rm -f "$FONT_ZIP"

# Remove Windows-only variants (keep Linux TTF/OTF)
find "$FONT_DIR" -name '*Windows*' -delete 2>/dev/null || true

fc-cache -f "$FONT_DIR"
success "JetBrainsMono Nerd Font installed to ${FONT_DIR}."
info "  → Set 'JetBrainsMono Nerd Font' in your terminal emulator to display Starship glyphs."

# ── 20.4  Install Oh My Zsh (unattended) ────────────────────────────────────
info "Installing Oh My Zsh for ${REAL_USER}..."
OMZ_DIR="${REAL_HOME}/.oh-my-zsh"

if [[ -d "$OMZ_DIR" ]]; then
    warn "Oh My Zsh already exists at ${OMZ_DIR} — updating instead."
    sudo -u "$REAL_USER" git -C "$OMZ_DIR" pull --rebase --quiet || true
else
    sudo -u "$REAL_USER" bash -c \
        'RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
         sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"'
fi
success "Oh My Zsh installed."

ZSH_CUSTOM_DIR="${REAL_HOME}/.oh-my-zsh/custom"

# ── 20.5  Install Oh My Zsh plugins ─────────────────────────────────────────
info "Installing Oh My Zsh plugins..."

declare -A OMZ_PLUGINS=(
    ["zsh-autosuggestions"]="https://github.com/zsh-users/zsh-autosuggestions.git"
    ["fast-syntax-highlighting"]="https://github.com/zdharma-continuum/fast-syntax-highlighting.git"
    ["zsh-autocomplete"]="https://github.com/marlonrichert/zsh-autocomplete.git"
    ["you-should-use"]="https://github.com/MichaelAquilina/zsh-you-should-use.git"
)

for plugin in "${!OMZ_PLUGINS[@]}"; do
    plugin_dir="${ZSH_CUSTOM_DIR}/plugins/${plugin}"
    if [[ ! -d "$plugin_dir" ]]; then
        sudo -u "$REAL_USER" git clone --depth=1 \
            "${OMZ_PLUGINS[$plugin]}" "$plugin_dir"
        success "Plugin installed: ${plugin}"
    else
        info "Plugin already present: ${plugin}"
    fi
done

# ── 20.6  Install Starship prompt ────────────────────────────────────────────
info "Installing Starship prompt (latest release)..."
curl -fsSL https://starship.rs/install.sh | sh -s -- --yes
success "Starship installed: $(starship --version 2>/dev/null || echo 'check /usr/local/bin/starship')"

# ── 20.7  Apply Gruvbox Rainbow preset ───────────────────────────────────────
info "Applying Starship Gruvbox Rainbow preset..."
STARSHIP_CFG_DIR="${REAL_HOME}/.config"
STARSHIP_CFG="${STARSHIP_CFG_DIR}/starship.toml"

sudo -u "$REAL_USER" mkdir -p "$STARSHIP_CFG_DIR"
sudo -u "$REAL_USER" starship preset gruvbox-rainbow -o "$STARSHIP_CFG"

# Append Debian symbol block (safe append — only affects [os.symbols])
cat >> "$STARSHIP_CFG" << 'TOML'

# ── Debian symbol (added by post-install script) ────────────────────────────
[os.symbols]
Debian = "󰣚"
Windows = "󰍲"
Ubuntu = "󰕈"
SUSE = ""
Raspbian = "󰐿"
Mint = "󰣭"
Macos = "󰀵"
Manjaro = ""
Linux = "󰌽"
Gentoo = "󰣨"
Fedora = "󰣛"
Alpine = ""
Amazon = ""
Android = ""
Arch = "󰣇"
Artix = "󰣇"
CentOS = ""
EndeavourOS = ""
Redhat = "󱄛"
NixOS = "󱄅"
TOML

chown "${REAL_USER}:${REAL_USER}" "$STARSHIP_CFG" 2>/dev/null || true
success "Gruvbox Rainbow preset written to ${STARSHIP_CFG}."

# ── 20.8  Write .zshrc ───────────────────────────────────────────────────────
info "Writing ${REAL_HOME}/.zshrc ..."
ZSHRC="${REAL_HOME}/.zshrc"
[[ -f "$ZSHRC" ]] && cp "$ZSHRC" "${ZSHRC}.bak_$(date +%Y%m%d_%H%M%S)"

sudo -u "$REAL_USER" tee "$ZSHRC" > /dev/null << 'ZSHRC_EOF'
# ============================================================
#  ~/.zshrc — Zsh configuration
#  Oh My Zsh + Starship (Gruvbox Rainbow) + Nerd Font
# ============================================================

# ── Oh My Zsh installation path ─────────────────────────────
export ZSH="$HOME/.oh-my-zsh"

# ── Theme: none (Starship replaces the OMZ theme) ───────────
ZSH_THEME=""

# ── History ─────────────────────────────────────────────────
HISTSIZE=10000
SAVEHIST=10000
HISTFILE="$HOME/.zsh_history"
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
setopt SHARE_HISTORY

# ── Oh My Zsh plugins ────────────────────────────────────────
# NOTE: fast-syntax-highlighting replaces zsh-syntax-highlighting (don't use both)
plugins=(
    git
    sudo
    history-substring-search
    colored-man-pages
    command-not-found
    fzf
    zsh-autosuggestions
    fast-syntax-highlighting
    zsh-autocomplete
    you-should-use
)

source "$ZSH/oh-my-zsh.sh"

# ── zsh-autosuggestions style ────────────────────────────────
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#665c54,underline"
ZSH_AUTOSUGGEST_STRATEGY=(history completion)

# ── Key bindings ─────────────────────────────────────────────
# Accept autosuggestion with → arrow
bindkey '→' autosuggest-accept
bindkey '^[[C' autosuggest-accept
# History search with ↑/↓
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

# ── Useful aliases ───────────────────────────────────────────
alias ls='ls --color=auto'
alias ll='ls -alF --color=auto'
alias la='ls -A --color=auto'
alias l='ls -CF --color=auto'
alias grep='grep --color=auto'
alias df='df -h'
alias du='du -sh'
alias free='free -h'
alias update='sudo apt update && sudo apt full-upgrade -y && sudo apt autoremove -y'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Use bat instead of cat if available
if command -v bat &>/dev/null; then
    alias cat='bat --style=plain'
fi

# Use fd instead of find if available
if command -v fdfind &>/dev/null; then
    alias fd='fdfind'
fi

# ── Starship prompt ──────────────────────────────────────────
# Must be the LAST line of .zshrc
eval "$(starship init zsh)"
ZSHRC_EOF

chown "${REAL_USER}:${REAL_USER}" "$ZSHRC"

# ── 20.9  Ownership sanity check ────────────────────────────────────────────
chown -R "${REAL_USER}:${REAL_USER}" \
    "${REAL_HOME}/.oh-my-zsh" \
    "${REAL_HOME}/.config/starship.toml" \
    2>/dev/null || true

success "Step 20 complete — zsh + Oh My Zsh + Starship (Gruvbox Rainbow) configured."
warn "Open a new terminal session to activate zsh. If it doesn't auto-start, run: zsh"

# =============================================================================
# STEP 23 — UBUNTU LOOK & FEEL
#   Yaru theme (GTK + Shell + Icons + Cursor + Sound)
#   Ubuntu font family
#   Dash-to-Dock + AppIndicator + Desktop Icons NG
#   gsettings to wire everything together
# =============================================================================
step "Step 23 — Desktop look & feel (Gruvbox Minimal GTK theme, Yaru base, Ubuntu fonts, Dash-to-Dock)"

if ! command -v gnome-shell &>/dev/null; then
    warn "GNOME Shell not detected — skipping desktop look & feel step."
else

# ── Determine look-and-feel target user ─────────────────────────────────────
LOOK_USER="$REAL_USER"
LOOK_HOME="$REAL_HOME"

# Helper: run gsettings as the real user via their dbus session
run_gsettings() {
    sudo -u "$LOOK_USER" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u "$LOOK_USER")/bus" \
        gsettings "$@" 2>/dev/null || true
}

# ── 23.1  Yaru base packages (GTK engine + icons + sound used as fallback) ──
info "Installing Yaru base packages..."
safe_install "Yaru theme base" \
    yaru-theme-gtk \
    yaru-theme-gnome-shell \
    yaru-theme-icon \
    yaru-theme-sound \
    gnome-themes-extra \
    adwaita-icon-theme \
    gtk2-engines-murrine \
    gtk2-engines-pixbuf

# ── 23.2  Papirus icon theme (best companion for Gruvbox) ────────────────────
# Papirus ships a Gruvbox-coloured folder variant via papirus-folders.
info "Installing Papirus icon theme..."
safe_install "Papirus icon theme" papirus-icon-theme

# Apply Gruvbox orange folder colour to Papirus via papirus-folders script
# The script is bundled inside the papirus-icon-theme package in Trixie.
if command -v papirus-folders &>/dev/null; then
    papirus-folders --color yaru --theme Papirus-Dark 2>/dev/null || true
    info "Papirus folders: set to Gruvbox-compatible orange palette."
fi

# ── 23.3  Ubuntu fonts ───────────────────────────────────────────────────────
safe_install "Ubuntu font family" fonts-ubuntu fonts-ubuntu-console
fc-cache -f

# ── 23.4  GNOME Shell extensions ─────────────────────────────────────────────
safe_install "GNOME Shell extensions" \
    gnome-shell-extension-dashtodock \
    gnome-shell-extension-desktop-icons-ng \
    gnome-shell-extension-appindicator \
    gnome-shell-extension-user-theme \
    gnome-shell-extension-manager \
    gnome-tweaks

# ── 23.5  Gruvbox Minimal GTK + GNOME Shell theme ────────────────────────────
# Source: https://github.com/Fausto-Korpsvart/Gruvbox-GTK-Theme
# Provides:  GTK 3/4 theming, libadwaita recolouring, GNOME Shell theme,
#            and a matching GDM background. The "Minimal" variant strips
#            transparency/blur so it stays crisp and performant on iGPU hardware.
#
# Colour palette used (Gruvbox dark, hard contrast):
#   bg0_h  #1d2021   bg0    #282828   bg1    #3c3836
#   fg0    #fbf1c7   fg1    #ebdbb2
#   orange #d65d0e   red    #cc241d   green  #98971a
#   yellow #d79921   blue   #458588   purple #b16286   aqua   #689d6a

info "Installing Gruvbox-GTK-Theme (Minimal variant)..."

GRUVBOX_THEME_DIR="/usr/share/themes/Gruvbox-Dark-BL"   # BL = Border-Left (Minimal style)
GRUVBOX_REPO_URL="https://github.com/Fausto-Korpsvart/Gruvbox-GTK-Theme"
GRUVBOX_TMP="/tmp/gruvbox-gtk-theme"

# Clone the repo (shallow, no history needed)
if [[ -d "$GRUVBOX_TMP" ]]; then
    rm -rf "$GRUVBOX_TMP"
fi

if git clone --depth=1 \
    --single-branch --branch main \
    "$GRUVBOX_REPO_URL" "$GRUVBOX_TMP" 2>/dev/null; then

    # ── Install GTK 2/3/4 themes ───────────────────────────────────────────
    # The repo ships pre-built theme directories under themes/
    # Copy all Gruvbox-Dark variants to /usr/share/themes/
    if [[ -d "${GRUVBOX_TMP}/themes" ]]; then
        find "${GRUVBOX_TMP}/themes" -maxdepth 1 -type d -name 'Gruvbox*' \
            | while read -r theme_dir; do
                theme_name="$(basename "$theme_dir")"
                rm -rf "/usr/share/themes/${theme_name}"
                cp -r "$theme_dir" "/usr/share/themes/${theme_name}"
                info "Installed GTK theme: ${theme_name}"
              done
    fi

    # ── Install GNOME Shell theme ──────────────────────────────────────────
    # Shell themes live under themes/<variant>/gnome-shell/
    # We use the Gruvbox-Dark-BL-GS (BL = no roundness, GS = GNOME Shell)
    # Copy to /usr/share/themes so the User Theme extension can find it.
    GNOME_SHELL_THEME_SRC="${GRUVBOX_TMP}/themes/Gruvbox-Dark-BL"
    if [[ -d "${GNOME_SHELL_THEME_SRC}/gnome-shell" ]]; then
        info "GNOME Shell theme is bundled inside Gruvbox-Dark-BL — already installed."
    fi

    # ── Install wallpaper(s) included in the repo ──────────────────────────
    GRUVBOX_WALLPAPER_DIR="/usr/share/backgrounds/gruvbox"
    mkdir -p "$GRUVBOX_WALLPAPER_DIR"
    if [[ -d "${GRUVBOX_TMP}/wallpapers" ]]; then
        cp -r "${GRUVBOX_TMP}/wallpapers"/. "$GRUVBOX_WALLPAPER_DIR/"
        info "Gruvbox wallpapers installed to ${GRUVBOX_WALLPAPER_DIR}."
    elif [[ -d "${GRUVBOX_TMP}/backgrounds" ]]; then
        cp -r "${GRUVBOX_TMP}/backgrounds"/. "$GRUVBOX_WALLPAPER_DIR/"
        info "Gruvbox backgrounds installed to ${GRUVBOX_WALLPAPER_DIR}."
    fi

    rm -rf "$GRUVBOX_TMP"
    success "Gruvbox-GTK-Theme installed (Dark-BL / Minimal variant)."
else
    warn "Could not clone Gruvbox-GTK-Theme from GitHub."
    warn "You can install it manually later from: ${GRUVBOX_REPO_URL}"
    warn "Falling back to Yaru-dark for all theme settings."
    GRUVBOX_INSTALL_FAILED=true
fi

GRUVBOX_INSTALL_FAILED="${GRUVBOX_INSTALL_FAILED:-false}"

# ── Resolve theme names to use (Gruvbox if available, Yaru-dark fallback) ─
if [[ "$GRUVBOX_INSTALL_FAILED" == "true" ]]; then
    GTK_THEME="Yaru-dark"
    SHELL_THEME="Yaru-dark"
    ICON_THEME="Yaru-dark"
    CURSOR_THEME="Yaru"
    info "Using fallback theme: Yaru-dark"
else
    GTK_THEME="Gruvbox-Dark-BL"
    SHELL_THEME="Gruvbox-Dark-BL"
    ICON_THEME="Papirus-Dark"
    CURSOR_THEME="Yaru"      # Yaru cursor is clean and neutral — Gruvbox has no cursor theme
    info "Using Gruvbox-Dark-BL (Minimal) + Papirus-Dark icons."
fi

# ── 23.6  Apply gsettings ─────────────────────────────────────────────────────
info "Applying gsettings (${GTK_THEME} theme, Ubuntu fonts, dock layout)..."

# Theme & icons
run_gsettings set org.gnome.desktop.interface gtk-theme         "$GTK_THEME"
run_gsettings set org.gnome.desktop.interface icon-theme        "$ICON_THEME"
run_gsettings set org.gnome.desktop.interface cursor-theme      "$CURSOR_THEME"
run_gsettings set org.gnome.desktop.interface cursor-size       24

# Shell theme (requires User Theme extension to be enabled)
run_gsettings set org.gnome.shell.extensions.user-theme name   "$SHELL_THEME"

# Sound theme (Yaru — no Gruvbox-specific sound theme exists)
run_gsettings set org.gnome.desktop.sound theme-name           'Yaru'
run_gsettings set org.gnome.desktop.sound event-sounds         true

# Ubuntu fonts (warm, readable — pairs well with Gruvbox warm tones)
run_gsettings set org.gnome.desktop.interface font-name           'Ubuntu 11'
run_gsettings set org.gnome.desktop.interface document-font-name  'Ubuntu 11'
run_gsettings set org.gnome.desktop.interface monospace-font-name 'Ubuntu Mono 13'
run_gsettings set org.gnome.desktop.wm.preferences titlebar-font  'Ubuntu Bold 11'

# Dark mode + text rendering
run_gsettings set org.gnome.desktop.interface color-scheme      'prefer-dark'
run_gsettings set org.gnome.desktop.interface font-antialiasing 'rgba'
run_gsettings set org.gnome.desktop.interface font-hinting      'slight'

# XCURSOR_SIZE for Wayland/X11 consistency
grep -q "XCURSOR_SIZE" /etc/environment \
    || echo "XCURSOR_SIZE=24" >> /etc/environment

# Workspaces & window controls
run_gsettings set org.gnome.desktop.wm.preferences button-layout  'appmenu:minimize,maximize,close'
run_gsettings set org.gnome.mutter dynamic-workspaces              true
run_gsettings set org.gnome.desktop.wm.preferences num-workspaces 4

# Hot corners
run_gsettings set org.gnome.desktop.interface enable-hot-corners   true

# Night Light — Gruvbox warm tones pair perfectly with a low colour temperature
run_gsettings set org.gnome.settings-daemon.plugins.color night-light-enabled           true
run_gsettings set org.gnome.settings-daemon.plugins.color night-light-schedule-automatic true
run_gsettings set org.gnome.settings-daemon.plugins.color night-light-temperature       3700

# Dash-to-Dock — minimal config (transparent, auto-hide, Gruvbox-neutral)
DTD="org.gnome.shell.extensions.dash-to-dock"
run_gsettings set $DTD dock-position       'BOTTOM'
run_gsettings set $DTD dock-fixed          false
run_gsettings set $DTD autohide            true
run_gsettings set $DTD intellihide         true
run_gsettings set $DTD extend-height       false
run_gsettings set $DTD dash-max-icon-size  48
run_gsettings set $DTD icon-size-fixed     true
run_gsettings set $DTD show-trash          true
run_gsettings set $DTD show-mounts         true
run_gsettings set $DTD click-action        'focus-or-previews'
run_gsettings set $DTD scroll-action       'cycle-windows'
run_gsettings set $DTD transparency-mode   'FIXED'
run_gsettings set $DTD background-opacity  0.75
run_gsettings set $DTD custom-theme-shrink true

# ── 23.7  Enable GNOME Shell extensions ──────────────────────────────────────
info "Enabling GNOME Shell extensions..."

CURRENT_EXTS=$(sudo -u "$LOOK_USER" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u "$LOOK_USER")/bus" \
    gsettings get org.gnome.shell enabled-extensions 2>/dev/null \
    || echo "@as []")

EXTS_TO_ENABLE=(
    "dash-to-dock@micxgx.gmail.com"
    "ding@rastersoft.com"
    "[email protected]"
    "user-theme@gnome-shell-extensions.gcampax.github.com"
)

NEW_EXTS="$CURRENT_EXTS"
for ext in "${EXTS_TO_ENABLE[@]}"; do
    if ! echo "$NEW_EXTS" | grep -q "$ext"; then
        NEW_EXTS=$(echo "$NEW_EXTS" | sed "s/\]$/, '$ext'\]/")
        NEW_EXTS=$(echo "$NEW_EXTS" | sed "s/@as \[\]/['$ext']/")
    fi
done

run_gsettings set org.gnome.shell enabled-extensions "$NEW_EXTS" \
    || warn "Could not set enabled-extensions (no active GNOME session) — extensions activate on next login."

success "Extensions enabled (take effect on next GNOME login)."

# ── 23.8  Wallpaper ──────────────────────────────────────────────────────────
info "Setting wallpaper..."
# Prefer a Gruvbox wallpaper if we installed them; fall back to GNOME amber, then Debian default
GRUVBOX_WALLPAPER_DIR="/usr/share/backgrounds/gruvbox"

find_gruvbox_wallpaper() {
    # Look for a dark wallpaper: prefer png/jpg named *dark*, *bg*, or any image
    find "$GRUVBOX_WALLPAPER_DIR" -type f \
        \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) \
        2>/dev/null | sort | head -1
}

GRUVBOX_WP=""
if [[ -d "$GRUVBOX_WALLPAPER_DIR" ]]; then
    GRUVBOX_WP=$(find_gruvbox_wallpaper)
fi

if [[ -n "$GRUVBOX_WP" ]]; then
    run_gsettings set org.gnome.desktop.background picture-uri      "file://${GRUVBOX_WP}"
    run_gsettings set org.gnome.desktop.background picture-uri-dark "file://${GRUVBOX_WP}"
    run_gsettings set org.gnome.desktop.background picture-options  'zoom'
    info "Gruvbox wallpaper set: ${GRUVBOX_WP}"
else
    # Fallback chain: GNOME amber → Debian default
    DEBIAN_FRONTEND=noninteractive apt-get install -y desktop-base gnome-backgrounds 2>/dev/null || true
    WALLPAPER_LIGHT="/usr/share/backgrounds/gnome/amber-l.jxl"
    WALLPAPER_DARK="/usr/share/backgrounds/gnome/amber-d.jxl"
    WALLPAPER_DEBIAN="/usr/share/images/desktop-base/desktop-background"

    if [[ -f "$WALLPAPER_LIGHT" ]]; then
        run_gsettings set org.gnome.desktop.background picture-uri      "file://${WALLPAPER_LIGHT}"
        run_gsettings set org.gnome.desktop.background picture-uri-dark "file://${WALLPAPER_DARK}"
    elif [[ -f "$WALLPAPER_DEBIAN" ]]; then
        run_gsettings set org.gnome.desktop.background picture-uri      "file://${WALLPAPER_DEBIAN}"
        run_gsettings set org.gnome.desktop.background picture-uri-dark "file://${WALLPAPER_DEBIAN}"
    fi
    run_gsettings set org.gnome.desktop.background picture-options 'zoom'
    info "Gruvbox wallpapers not found — using fallback wallpaper."
fi

# ── 23.9  GDM login screen theme ─────────────────────────────────────────────
info "Applying ${GTK_THEME} to GDM login screen..."
if [[ -d /etc/gdm3 ]]; then
    mkdir -p /etc/dconf/db/gdm.d
    deploy_config /etc/dconf/db/gdm.d/01-gruvbox-look << EOF
[org/gnome/desktop/interface]
gtk-theme='${GTK_THEME}'
icon-theme='${ICON_THEME}'
cursor-theme='${CURSOR_THEME}'
font-name='Ubuntu 11'
color-scheme='prefer-dark'

[org/gnome/desktop/background]
picture-options='zoom'
EOF
    dconf update 2>/dev/null || true
    success "GDM theme set to ${GTK_THEME}."
else
    warn "GDM not found — skipping login screen theming."
fi

# ── 23.10  GTK4 / libadwaita override (Gruvbox recolour) ─────────────────────
# GNOME 45+ apps use libadwaita and ignore GTK themes by default.
# The Gruvbox-GTK-Theme ships a gtk4 directory for this; we symlink it into
# the user's ~/.config/gtk-4.0/ so libadwaita apps pick it up.
if [[ "$GRUVBOX_INSTALL_FAILED" == "false" ]]; then
    info "Applying Gruvbox GTK4 / libadwaita recolour..."
    GRUVBOX_GTK4_SRC="/usr/share/themes/${GTK_THEME}/gtk-4.0"
    USER_GTK4_DIR="${LOOK_HOME}/.config/gtk-4.0"

    if [[ -d "$GRUVBOX_GTK4_SRC" ]]; then
        sudo -u "$LOOK_USER" mkdir -p "$USER_GTK4_DIR"
        # Link assets and gtk.css — overwrite existing links
        for f in gtk.css gtk-dark.css assets; do
            src="${GRUVBOX_GTK4_SRC}/${f}"
            dst="${USER_GTK4_DIR}/${f}"
            [[ -e "$src" ]] || continue
            sudo -u "$LOOK_USER" ln -sfn "$src" "$dst"
            info "  Linked: ${dst} → ${src}"
        done
        chown -h "${LOOK_USER}:${LOOK_USER}" \
            "${USER_GTK4_DIR}/gtk.css" \
            "${USER_GTK4_DIR}/gtk-dark.css" \
            "${USER_GTK4_DIR}/assets" 2>/dev/null || true
        success "GTK4 / libadwaita recolour applied for ${LOOK_USER}."
    else
        warn "GTK4 directory not found in ${GTK_THEME} — libadwaita apps will use default colours."
        warn "Path checked: ${GRUVBOX_GTK4_SRC}"
    fi
fi

success "Step 23 complete — Gruvbox Minimal desktop theme applied."
info "  → Active theme  : ${GTK_THEME} (GTK 3/4 + GNOME Shell)"
info "  → Icon theme    : ${ICON_THEME}"
info "  → Font          : Ubuntu 11 / Ubuntu Mono 13"
info "  → Log out and back in (or reboot) to see the full theme."
info "  → Shell theme: GNOME Tweaks → Appearance → Shell → ${SHELL_THEME}"
info "  → To try other Gruvbox variants: GNOME Tweaks → Appearance → Applications"

fi  # end GNOME check

# =============================================================================
# STEP 24 — FINAL CLEANUP
# =============================================================================
step "Step 24 — Final cleanup"

info "Removing unused packages and cleaning APT cache..."
apt-get autoremove -y
apt-get autoclean -y
apt-get clean

success "Cleanup complete."

# ── Remove ERR trap now that we're done ───────────────────────────────────────
trap - ERR

# =============================================================================
# SUMMARY
# =============================================================================
echo ""
echo -e "${GRN}╔══════════════════════════════════════════════════════════════╗${RST}"
echo -e "${GRN}║     Debian 13 Post-Install Complete — Beelink SER8          ║${RST}"
echo -e "${GRN}╠══════════════════════════════════════════════════════════════╣${RST}"
echo -e "${GRN}║  ✓  Hardware detected & verified                            ║${RST}"
echo -e "${GRN}║  ✓  APT sources: main + backports (pinned at priority 200)  ║${RST}"
echo -e "${GRN}║  ✓  Backported kernel installed (latest from backports)     ║${RST}"
echo -e "${GRN}║  ✓  Minimal GNOME desktop (GDM3 + Wayland + NM)            ║${RST}"
echo -e "${GRN}║  ✓  Base packages installed (grouped, dry-run preflight)    ║${RST}"
echo -e "${GRN}║  ✓  AMD Radeon 780M (RDNA 3) drivers & firmware             ║${RST}"
echo -e "${GRN}║  ✓  Ryzen 7 8845HS microcode + amd_pstate=active            ║${RST}"
echo -e "${GRN}║  ✓  GRUB kernel parameters (safe atomic replace)            ║${RST}"
echo -e "${GRN}║  ✓  NVMe I/O scheduler (mq-deadline) + TRIM timer          ║${RST}"
echo -e "${GRN}║  ✓  Wi-Fi (Intel AX) & Bluetooth firmware                  ║${RST}"
echo -e "${GRN}║  ✓  PipeWire + SOF audio                                   ║${RST}"
echo -e "${GRN}║  ✓  zram swap (25%, zstd)                                  ║${RST}"
echo -e "${GRN}║  ✓  sysctl network & memory tuning                         ║${RST}"
echo -e "${GRN}║  ✓  fwupd firmware update daemon                           ║${RST}"
echo -e "${GRN}║  ✓  UFW firewall + fail2ban                                ║${RST}"
echo -e "${GRN}║  ✓  Flatpak + Flathub                                      ║${RST}"
echo -e "${GRN}║  ✓  zsh + Oh My Zsh + Starship Gruvbox Rainbow             ║${RST}"
echo -e "${GRN}║  ✓  JetBrainsMono Nerd Font (system-wide)                  ║${RST}"
echo -e "${GRN}║  ✓  Gruvbox-Dark-BL (Minimal) GTK/Shell + Papirus-Dark icons  ║${RST}"
echo -e "${GRN}║  ✓  APT cache cleaned up                                   ║${RST}"
echo -e "${GRN}╠══════════════════════════════════════════════════════════════╣${RST}"
echo -e "${YLW}║  NEXT STEPS (after reboot):                                  ║${RST}"
echo -e "${YLW}║  • Verify kernel : uname -r  (should show backported ver.)  ║${RST}"
echo -e "${YLW}║  • Open new terminal → zsh/Starship loads automatically     ║${RST}"
echo -e "${YLW}║  • Set terminal font to: JetBrainsMono Nerd Font            ║${RST}"
echo -e "${YLW}║  • Log out & back in to activate Yaru Shell + Dash-to-Dock  ║${RST}"
echo -e "${YLW}║  • If Shell theme missing: Tweaks→Appearance→Shell→Gruvbox-Dark-BL ║${RST}"
echo -e "${YLW}║  • Run: sensors           (thermal sensor readings)          ║${RST}"
echo -e "${YLW}║  • Run: fwupdmgr update   (BIOS/firmware updates)           ║${RST}"
echo -e "${YLW}║  • Run: vainfo            (verify hardware video decode)     ║${RST}"
echo -e "${YLW}║  • Check: ${LOGFILE} ║${RST}"
echo -e "${GRN}╚══════════════════════════════════════════════════════════════╝${RST}"
echo ""

if ask_yes_no "Reboot now to apply all changes (strongly recommended)?"; then
    info "Rebooting in 5 seconds..."
    sleep 5
    reboot
else
    warn "Reboot skipped. Please reboot manually when ready."
    info "Run: sudo reboot"
fi