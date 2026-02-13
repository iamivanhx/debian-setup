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
#    1.  System update & essential base packages
#    2.  AMD GPU / RDNA3 driver & firmware (780M iGPU)
#    3.  CPU microcode & power-management tuning (Ryzen 7 8845HS)
#    4.  Kernel parameters optimised for AMD Zen 4
#    5.  Thermal & fan control (fwupd, thermald, sensors)
#    6.  NVMe optimisations (I/O scheduler, power policy)
#    7.  Wi-Fi & Bluetooth firmware (Intel AX200/AX210 common on SER8)
#    8.  Audio (PipeWire + WirePlumber)
#    9.  Flatpak + Flathub
#   10.  Optional desktop extras (Firefox, VLC, GIMP, etc.)
#   11.  Swappiness & memory tuning for mini-PC workloads
#   12.  Security hardening (UFW, fail2ban)
#   13.  Developer tools (optional)
#   14.  Gaming optimisations (optional)
#   15.  Hardware video acceleration
#   16.  System services tuning
#   17.  Desktop environment extras
#   18.  zsh + Oh My Zsh + Starship (Gruvbox Rainbow) + Nerd Font
#   19.  Gaming optimisations (optional)
#   20.  Final cleanup & reboot prompt
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

# ── Root check ────────────────────────────────────────────────────────────────
[[ $EUID -ne 0 ]] && error "Please run as root: sudo $0"

# ── Debian 13 check ───────────────────────────────────────────────────────────
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    if [[ "$VERSION_CODENAME" != "trixie" && "$VERSION_CODENAME" != "testing" ]]; then
        warn "This script targets Debian 13 Trixie. Detected: ${VERSION_CODENAME}."
        ask_yes_no "Continue anyway?" || exit 1
    fi
else
    warn "Cannot detect OS version — proceeding anyway."
fi

LOGFILE="/var/log/debian13-postinstall-ser8.log"
exec > >(tee -a "$LOGFILE") 2>&1
info "Full log available at: $LOGFILE"

# =============================================================================
# STEP 1 — APT SOURCES & SYSTEM UPDATE
# =============================================================================
step "Step 1 — APT sources & system update"

# Enable contrib and non-free repositories (needed for firmware)
info "Configuring APT sources with contrib & non-free..."
cat > /etc/apt/sources.list << 'EOF'
# Debian 13 Trixie — Main, Contrib, Non-Free, Non-Free-Firmware
deb http://deb.debian.org/debian trixie main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian trixie main contrib non-free non-free-firmware

# Security updates
deb http://security.debian.org/debian-security trixie-security main contrib non-free non-free-firmware
deb-src http://security.debian.org/debian-security trixie-security main contrib non-free non-free-firmware

# Trixie updates
deb http://deb.debian.org/debian trixie-updates main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian trixie-updates main contrib non-free non-free-firmware
EOF

info "Running apt update + full upgrade..."
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get full-upgrade -y \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold"

success "System updated."

# =============================================================================
# STEP 2 — ESSENTIAL BASE PACKAGES
# =============================================================================
step "Step 2 — Essential base packages"

BASE_PKGS=(
    # Core utilities
    curl wget git vim nano htop btop fastfetch
    build-essential cmake pkg-config
    apt-transport-https ca-certificates gnupg lsb-release
    # Archive tools
    zip unzip p7zip-full tar gzip bzip2 xz-utils zstd
    # Filesystem
    ntfs-3g exfatprogs dosfstools btrfs-progs
    # Network
    net-tools iproute2 iw rfkill openssh-client
    nmap traceroute iputils-ping dnsutils
    # Hardware info
    lshw hwinfo pciutils usbutils dmidecode inxi
    # Monitoring
    iotop iftop powertop nvtop sysstat
    # Misc
    bash-completion command-not-found software-properties-common
    python3 python3-pip python3-venv
    jq tree tmux screen fzf ripgrep fd-find bat
)

info "Installing base packages..."
DEBIAN_FRONTEND=noninteractive apt-get install -y "${BASE_PKGS[@]}"
success "Base packages installed."

# =============================================================================
# STEP 3 — AMD GPU DRIVER & FIRMWARE (Radeon 780M / RDNA 3)
# =============================================================================
step "Step 3 — AMD GPU firmware & drivers (Radeon 780M / RDNA 3)"

AMD_GPU_PKGS=(
    firmware-amd-graphics       # Radeon 780M iGPU firmware blobs
    libdrm-amdgpu1              # DRM userspace library
    xserver-xorg-video-amdgpu   # Xorg DDX driver (for X11 setups)
    mesa-vulkan-drivers         # Vulkan (radv) for AMD
    mesa-va-drivers             # VA-API hardware video decode
    libva-utils                 # vainfo tool
    vulkan-tools                # vulkaninfo tool
    radeontop                   # GPU monitoring
    rocm-smi                    # ROCm system management CLI (binary pkg name in Trixie)
)

info "Installing AMD GPU firmware and Mesa drivers..."
DEBIAN_FRONTEND=noninteractive apt-get install -y "${AMD_GPU_PKGS[@]}" || \
    warn "Some AMD GPU packages may not be available in current repos — skipping missing ones."

# Ensure amdgpu kernel module is loaded at boot
if ! grep -q "amdgpu" /etc/modules; then
    echo "amdgpu" >> /etc/modules
    info "Added amdgpu to /etc/modules."
fi

# Wayland: ensure GBM backend is preferred for AMD
mkdir -p /etc/environment.d
cat > /etc/environment.d/80-amd-wayland.conf << 'EOF'
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
# STEP 4 — CPU MICROCODE & POWER MANAGEMENT (Ryzen 7 8845HS / Zen 4)
# =============================================================================
step "Step 4 — AMD CPU microcode & power management"

info "Installing AMD microcode and power tools..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
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
cat > /etc/default/cpupower << 'EOF'
# CPU frequency governor for AMD Ryzen 7 8845HS (Zen 4)
# schedutil: kernel-integrated, respects AMD boost correctly
START_OPTS="--governor schedutil"
STOP_OPTS=""
EOF

# Enable cpupower service
systemctl enable cpupower.service 2>/dev/null || true

# AMD P-State driver — enable for Ryzen 8000 series
# amd_pstate=active gives the OS full P-State control (best efficiency)
GRUB_CMDLINE_ADDITIONS="amd_pstate=active"

success "CPU power management configured."

# =============================================================================
# STEP 5 — KERNEL PARAMETERS (GRUB)
# =============================================================================
step "Step 5 — Kernel parameters (GRUB)"

GRUB_FILE="/etc/default/grub"

if [[ -f "$GRUB_FILE" ]]; then
    info "Backing up GRUB config..."
    cp "$GRUB_FILE" "${GRUB_FILE}.bak_$(date +%Y%m%d_%H%M%S)"

    # Build optimised kernel cmdline for Ryzen 7 8845HS + SER8
    # ─ amd_pstate=active      : Active P-State driver (Zen 4 native)
    # ─ amd_iommu=off          : Disable IOMMU if not using VMs (lower latency)
    # ─ idle=nomwait           : Prevent mwait C-state issues on some BIOSes
    # ─ pcie_aspm=off          : Avoid NVMe/PCIe ASPM quirks on Beelink firmware
    # ─ mitigations=auto       : Keep default Spectre/Meltdown mitigations
    # ─ loglevel=3             : Quiet boot
    # ─ nowatchdog             : Disable NMI watchdog (saves ~1 CPU wake/sec)
    NEW_CMDLINE='GRUB_CMDLINE_LINUX_DEFAULT="quiet splash amd_pstate=active idle=nomwait nowatchdog loglevel=3 mitigations=auto"'

    if grep -q '^GRUB_CMDLINE_LINUX_DEFAULT=' "$GRUB_FILE"; then
        sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|${NEW_CMDLINE}|" "$GRUB_FILE"
    else
        echo "$NEW_CMDLINE" >> "$GRUB_FILE"
    fi

    # Enable GRUB timeout (useful for dual-boot)
    sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=5/' "$GRUB_FILE"

    info "Updating GRUB..."
    update-grub
    success "Kernel parameters updated."
else
    warn "GRUB config not found at ${GRUB_FILE} — skipping."
fi

# =============================================================================
# STEP 6 — NVMe OPTIMISATION
# =============================================================================
step "Step 6 — NVMe I/O optimisation"

info "Configuring NVMe I/O scheduler and power policy..."

# Use mq-deadline scheduler for NVMe (best latency/throughput balance)
cat > /etc/udev/rules.d/60-nvme-ioscheduler.rules << 'EOF'
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
# STEP 7 — WI-FI & BLUETOOTH FIRMWARE
# =============================================================================
step "Step 7 — Wi-Fi & Bluetooth firmware"

WIFI_PKGS=(
    firmware-iwlwifi          # Intel AX200/AX210 (most common in SER8)
    firmware-realtek          # Fallback: some SER8 variants use Realtek
    firmware-atheros          # Fallback: Atheros adapters
    wireless-tools
    wpasupplicant
    rfkill
    bluetooth
    bluez
    bluez-tools
    # Note: BT audio is handled by libspa-0.2-bluetooth (installed in PipeWire step)
)

info "Installing Wi-Fi & Bluetooth firmware..."
DEBIAN_FRONTEND=noninteractive apt-get install -y "${WIFI_PKGS[@]}" || \
    warn "Some wireless firmware packages unavailable — check manually."

# Enable Bluetooth service
systemctl enable bluetooth.service
systemctl start bluetooth.service

success "Wi-Fi & Bluetooth firmware installed."

# =============================================================================
# STEP 8 — AUDIO (PipeWire + WirePlumber)
# =============================================================================
step "Step 8 — PipeWire audio stack"

AUDIO_PKGS=(
    pipewire
    pipewire-alsa
    pipewire-audio
    pipewire-jack
    pipewire-pulse
    wireplumber
    libspa-0.2-bluetooth
    libspa-0.2-jack
    gstreamer1.0-pipewire
    pavucontrol              # GUI volume control
    alsa-utils
    alsa-firmware-loaders
    sof-firmware             # Sound Open Firmware (needed for AMD SOF audio)
    # Note: pulseaudio-module-bluetooth is NOT installed — PipeWire handles BT
    # directly via libspa-0.2-bluetooth. Mixing PulseAudio modules with PipeWire
    # causes conflicts in Trixie.
)

info "Installing PipeWire audio stack..."
DEBIAN_FRONTEND=noninteractive apt-get install -y "${AUDIO_PKGS[@]}"

# The Ryzen 8845HS uses SOF (Sound Open Firmware) for audio — ensure loaded
if ! grep -q "snd_sof" /etc/modules; then
    echo "snd_sof_pci_intel_cnl" >> /etc/modules 2>/dev/null || true
    echo "snd_sof_amd_acp" >> /etc/modules 2>/dev/null || true
fi

success "PipeWire audio stack installed."

# =============================================================================
# STEP 9 — THERMAL SENSORS & MONITORING
# =============================================================================
step "Step 9 — Thermal sensors & hardware monitoring"

info "Detecting sensors..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    lm-sensors \
    fancontrol \
    i2c-tools \
    stress-ng
    # Note: s-tui is not in Trixie stable repos; install via pip3: pip3 install s-tui

# Autodetect sensor modules
sensors-detect --auto > /dev/null 2>&1 || true

success "Thermal monitoring tools installed. Run 'sensors' to check temps."

# =============================================================================
# STEP 10 — MEMORY / SWAP TUNING
# =============================================================================
step "Step 10 — Memory & swap tuning"

info "Applying sysctl optimisations for mini-PC workloads..."

cat > /etc/sysctl.d/99-ser8-tuning.conf << 'EOF'
# ── Memory management ─────────────────────────────────────────────────────
# Lower swappiness — keep more data in RAM (SER8 has 32/64GB DDR5)
vm.swappiness = 10

# Increase dirty page cache pressure tolerance
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5

# Reduce memory overcommit aggressiveness
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
DEBIAN_FRONTEND=noninteractive apt-get install -y zram-tools

cat > /etc/default/zramswap << 'EOF'
# zram — compressed swap in RAM (good for Ryzen 8845HS w/ fast DDR5)
ALGO=zstd
PERCENT=25
PRIORITY=100
EOF

systemctl enable zramswap.service
systemctl restart zramswap.service || true

success "zram swap configured (25% of RAM, zstd compression)."

# =============================================================================
# STEP 11 — FIRMWARE UPDATE (fwupd)
# =============================================================================
step "Step 11 — Firmware update daemon (fwupd)"

DEBIAN_FRONTEND=noninteractive apt-get install -y fwupd

info "Refreshing firmware metadata..."
fwupdmgr refresh --force 2>/dev/null || warn "fwupd metadata refresh failed (no internet or no updates)."

info "To check for firmware updates later, run: fwupdmgr get-updates && fwupdmgr update"
success "fwupd installed."

# =============================================================================
# STEP 12 — SECURITY HARDENING
# =============================================================================
step "Step 12 — Basic security hardening"

info "Installing UFW firewall..."
DEBIAN_FRONTEND=noninteractive apt-get install -y ufw fail2ban

# UFW — sensible defaults
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh comment "SSH access"
ufw --force enable

info "Configuring fail2ban..."
cat > /etc/fail2ban/jail.local << 'EOF'
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
# STEP 13 — FLATPAK & FLATHUB
# =============================================================================
step "Step 13 — Flatpak + Flathub"

DEBIAN_FRONTEND=noninteractive apt-get install -y flatpak

info "Adding Flathub remote..."
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# If GNOME is installed, add gnome-software-plugin-flatpak
DEBIAN_FRONTEND=noninteractive apt-get install -y gnome-software-plugin-flatpak 2>/dev/null || true

success "Flatpak + Flathub configured."

# =============================================================================
# STEP 14 — OPTIONAL: DESKTOP APPLICATIONS
# =============================================================================
step "Step 14 — Optional desktop applications"

if ask_yes_no "Install common desktop apps (Firefox, VLC, GIMP, LibreOffice, Thunderbird)?"; then
    DESKTOP_PKGS=(
        firefox-esr
        vlc
        # gimp
        # libreoffice
        # thunderbird
        # gedit
        gnome-tweaks
        gparted
        timeshift
        copyq           # clipboard manager
        flameshot       # screenshot tool
    )
    DEBIAN_FRONTEND=noninteractive apt-get install -y "${DESKTOP_PKGS[@]}" || \
        warn "Some desktop packages could not be installed."
    success "Desktop applications installed."
fi

# ── Google Chrome ─────────────────────────────────────────────────────────────
if command -v google-chrome &>/dev/null; then
    log "Google Chrome already installed."
else
    info "Downloading Google Chrome..."
    TMP_DEB=$(mktemp /tmp/chrome-XXXXXX.deb)
    curl -fsSL "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb" -o "$TMP_DEB"
    apt-get install -y -qq "$TMP_DEB"
    rm -f "$TMP_DEB"
    log "Google Chrome installed."
fi

# =============================================================================
# STEP 15 — OPTIONAL: DEVELOPER TOOLS
# =============================================================================
step "Step 15 — Optional developer tools"

if ask_yes_no "Install developer tools (Docker, VS Code, Node.js, Go)?"; then

    # Docker CE
    # info "Installing Docker..."
    # install -m 0755 -d /etc/apt/keyrings
    # curl -fsSL https://download.docker.com/linux/debian/gpg \
    #     | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    # chmod a+r /etc/apt/keyrings/docker.gpg
    # echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] \
    #     https://download.docker.com/linux/debian trixie stable" \
    #     > /etc/apt/sources.list.d/docker.list
    # apt-get update -qq
    # DEBIAN_FRONTEND=noninteractive apt-get install -y \
    #     docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    # systemctl enable docker
    # if [[ -n "${SUDO_USER:-}" ]]; then
    #     usermod -aG docker "$SUDO_USER"
    #     info "Added $SUDO_USER to docker group."
    # fi

    # VS Code
    info "Installing Visual Studio Code..."
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
        | gpg --dearmor -o /etc/apt/keyrings/microsoft.gpg
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] \
        https://packages.microsoft.com/repos/code stable main" \
        > /etc/apt/sources.list.d/vscode.list
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y code

    # Node.js LTS (via NodeSource)
    info "Installing Node.js LTS..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - > /dev/null
    DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs

    # Go
    info "Installing Go..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y golang

    success "Developer tools installed."
fi

# =============================================================================
# STEP 16 — OPTIONAL: GAMING OPTIMISATIONS
# =============================================================================
# step "Step 16 — Optional gaming optimisations"

# if ask_yes_no "Install gaming optimisations (Steam, Lutris, MangoHud, GameMode, Proton)?"; then

#     # Enable i386 architecture for Steam
#     dpkg --add-architecture i386
#     apt-get update -qq

#     GAMING_PKGS=(
#         steam
#         lutris
#         mangohud
#         gamemode
#         gamescope
#         libgamemode0
#         libgamemodeauto0
#         # Vulkan extras
#         mesa-vulkan-drivers:i386
#         libvulkan1
#         libvulkan1:i386
#         vulkan-validationlayers
#     )

#     DEBIAN_FRONTEND=noninteractive apt-get install -y "${GAMING_PKGS[@]}" || \
#         warn "Some gaming packages unavailable — check manually."

#     # GameMode service
#     systemctl --user enable gamemoded 2>/dev/null || true

#     # Increase max open files for games
#     cat >> /etc/security/limits.conf << 'EOF'
# # Gaming: increase file descriptor limits
# *    soft nofile 524288
# *    hard nofile 524288
# EOF

#     success "Gaming packages installed."
#     info "For best gaming performance on Radeon 780M, use: gamemoderun %command% in Steam launch options."
# fi

# =============================================================================
# STEP 17 — HARDWARE VIDEO ACCELERATION VERIFICATION
# =============================================================================
step "Step 17 — Hardware video acceleration"

VAAPI_PKGS=(
    mesa-va-drivers
    libva-utils
    gstreamer1.0-vaapi
    ffmpeg
    mpv                        # Hardware-accelerated media player
)

info "Installing VA-API and hardware video decode tools..."
DEBIAN_FRONTEND=noninteractive apt-get install -y "${VAAPI_PKGS[@]}"

info "Verifying VA-API support (AMD 780M)..."
vainfo 2>/dev/null || warn "vainfo check deferred — run manually after reboot."

success "Hardware video acceleration configured."

# =============================================================================
# STEP 18 — SYSTEM SERVICES TUNING
# =============================================================================
step "Step 18 — Systemd & journald tuning"

info "Tuning journald logging..."
mkdir -p /etc/systemd/journald.conf.d
cat > /etc/systemd/journald.conf.d/99-ser8.conf << 'EOF'
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
    ModemManager.service           # No cellular modem
    avahi-daemon.service           # Optional: mDNS (disable if not needed)
    whoopsie.service               # Ubuntu crash reporter (may not exist)
)
for svc in "${DISABLE_SERVICES[@]}"; do
    systemctl disable "$svc" 2>/dev/null && info "Disabled: $svc" || true
done

# Reduce systemd timeout
mkdir -p /etc/systemd/system.conf.d
cat > /etc/systemd/system.conf.d/99-timeouts.conf << 'EOF'
[Manager]
DefaultTimeoutStopSec=15s
DefaultTimeoutStartSec=30s
EOF

systemctl daemon-reload
success "Systemd tuning applied."

# =============================================================================
# STEP 19 — DESKTOP ENVIRONMENT EXTRAS (if GNOME detected)
# =============================================================================
step "Step 19 — Desktop environment tweaks"

if command -v gnome-shell &>/dev/null; then
    info "GNOME detected — applying GNOME-specific tweaks..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        gnome-shell-extension-manager \
        gnome-shell-extensions \
        gnome-tweaks \
        dconf-editor \
        gnome-browser-connector 2>/dev/null || true
        # Note: chrome-gnome-shell is a dummy transitional pkg in Trixie

    # Set power button action to suspend (not power off — SER8 always-on usage)
    if [[ -n "${SUDO_USER:-}" ]]; then
        sudo -u "$SUDO_USER" dbus-launch gsettings set org.gnome.settings-daemon.plugins.power \
            power-button-action 'suspend' 2>/dev/null || true
        # Fractional scaling for HiDPI displays
        sudo -u "$SUDO_USER" dbus-launch gsettings set org.gnome.mutter \
            experimental-features "['scale-monitor-framebuffer']" 2>/dev/null || true
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
# STEP 20 — ZSH + OH MY ZSH + STARSHIP (GRUVBOX RAINBOW) + NERD FONT
# =============================================================================
step "Step 20 — zsh + Oh My Zsh + Starship (Gruvbox Rainbow) + JetBrainsMono Nerd Font"

# ── 20.1  Determine the real user (not root) ────────────────────────────────
# The script runs as root via sudo; SUDO_USER holds the actual username.
# If run directly as root (e.g. in a live installer), fallback to root itself.
if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
    REAL_USER="$SUDO_USER"
    REAL_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
else
    REAL_USER="root"
    REAL_HOME="/root"
fi
info "Configuring shell environment for user: ${REAL_USER} (home: ${REAL_HOME})"

# ── 20.2  Install zsh and required APT dependencies ─────────────────────────
info "Installing zsh and required dependencies..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    zsh \
    zsh-common \
    git \
    curl \
    wget \
    fontconfig \
    unzip \
    xfonts-utils

# ── 20.3  Set zsh as the default shell for the real user ────────────────────
info "Setting zsh as default shell for ${REAL_USER}..."
chsh -s "$(which zsh)" "$REAL_USER"
success "Default shell changed to zsh."

# ── 20.4  Install JetBrainsMono Nerd Font (required for Starship glyphs) ────
info "Installing JetBrainsMono Nerd Font (system-wide)..."
FONT_DIR="/usr/local/share/fonts/jetbrainsmono-nerd"
mkdir -p "$FONT_DIR"

# Fetch latest Nerd Fonts release tag from GitHub API
NF_VERSION=$(curl -fsSL https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest \
    | grep '"tag_name"' | head -1 | cut -d'"' -f4)
# Fallback to a known stable version if API is unavailable
NF_VERSION="${NF_VERSION:-v3.2.1}"
info "Nerd Fonts version: ${NF_VERSION}"

FONT_ZIP="/tmp/JetBrainsMono-NF.zip"
curl -fsSL \
    "https://github.com/ryanoasis/nerd-fonts/releases/download/${NF_VERSION}/JetBrainsMono.zip" \
    -o "$FONT_ZIP"

unzip -o -q "$FONT_ZIP" -d "$FONT_DIR"
rm -f "$FONT_ZIP"

# Remove Windows-only variants (keep Linux TTF/OTF)
find "$FONT_DIR" -name '*Windows*' -delete 2>/dev/null || true

# Refresh font cache system-wide
fc-cache -f "$FONT_DIR"
success "JetBrainsMono Nerd Font installed to ${FONT_DIR}."
info "  → Set 'JetBrainsMono Nerd Font' in your terminal emulator to display Starship glyphs correctly."

# ── 20.5  Install Oh My Zsh (unattended, for the real user) ─────────────────
info "Installing Oh My Zsh for ${REAL_USER}..."
OMZ_DIR="${REAL_HOME}/.oh-my-zsh"

if [[ -d "$OMZ_DIR" ]]; then
    warn "Oh My Zsh already exists at ${OMZ_DIR} — skipping install, will update instead."
    sudo -u "$REAL_USER" git -C "$OMZ_DIR" pull --rebase --quiet || true
else
    # Install Oh My Zsh without starting an interactive zsh session
    sudo -u "$REAL_USER" bash -c \
        'RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
         sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"'
fi
success "Oh My Zsh installed."

# Convenience variable used by plugin clone commands below
ZSH_CUSTOM_DIR="${REAL_HOME}/.oh-my-zsh/custom"

# ── 20.6  Install Oh My Zsh plugins ─────────────────────────────────────────
info "Installing Oh My Zsh plugins..."

# Plugin: zsh-autosuggestions — suggests commands from history as you type
if [[ ! -d "${ZSH_CUSTOM_DIR}/plugins/zsh-autosuggestions" ]]; then
    sudo -u "$REAL_USER" git clone --depth=1 \
        https://github.com/zsh-users/zsh-autosuggestions.git \
        "${ZSH_CUSTOM_DIR}/plugins/zsh-autosuggestions"
    success "Plugin installed: zsh-autosuggestions"
else
    info "Plugin already present: zsh-autosuggestions"
fi

# Plugin: zsh-syntax-highlighting — colour-codes commands as you type
if [[ ! -d "${ZSH_CUSTOM_DIR}/plugins/zsh-syntax-highlighting" ]]; then
    sudo -u "$REAL_USER" git clone --depth=1 \
        https://github.com/zsh-users/zsh-syntax-highlighting.git \
        "${ZSH_CUSTOM_DIR}/plugins/zsh-syntax-highlighting"
    success "Plugin installed: zsh-syntax-highlighting"
else
    info "Plugin already present: zsh-syntax-highlighting"
fi

# Plugin: fast-syntax-highlighting — faster alternative to zsh-syntax-highlighting
if [[ ! -d "${ZSH_CUSTOM_DIR}/plugins/fast-syntax-highlighting" ]]; then
    sudo -u "$REAL_USER" git clone --depth=1 \
        https://github.com/zdharma-continuum/fast-syntax-highlighting.git \
        "${ZSH_CUSTOM_DIR}/plugins/fast-syntax-highlighting"
    success "Plugin installed: fast-syntax-highlighting"
else
    info "Plugin already present: fast-syntax-highlighting"
fi

# Plugin: zsh-autocomplete — real-time tab completion as you type
if [[ ! -d "${ZSH_CUSTOM_DIR}/plugins/zsh-autocomplete" ]]; then
    sudo -u "$REAL_USER" git clone --depth=1 \
        https://github.com/marlonrichert/zsh-autocomplete.git \
        "${ZSH_CUSTOM_DIR}/plugins/zsh-autocomplete"
    success "Plugin installed: zsh-autocomplete"
else
    info "Plugin already present: zsh-autocomplete"
fi

# Plugin: zsh-you-should-use — reminds you to use existing aliases
if [[ ! -d "${ZSH_CUSTOM_DIR}/plugins/you-should-use" ]]; then
    sudo -u "$REAL_USER" git clone --depth=1 \
        https://github.com/MichaelAquilina/zsh-you-should-use.git \
        "${ZSH_CUSTOM_DIR}/plugins/you-should-use"
    success "Plugin installed: you-should-use"
else
    info "Plugin already present: you-should-use"
fi

# ── 20.7  Install Starship prompt (latest binary via official installer) ─────
info "Installing Starship prompt (latest release)..."
# The official installer places the binary in /usr/local/bin
curl -fsSL https://starship.rs/install.sh | sh -s -- --yes
success "Starship installed: $(starship --version 2>/dev/null || echo 'check /usr/local/bin/starship')"

# ── 20.8  Apply Gruvbox Rainbow preset ───────────────────────────────────────
info "Applying Starship Gruvbox Rainbow preset..."
STARSHIP_CFG_DIR="${REAL_HOME}/.config"
STARSHIP_CFG="${STARSHIP_CFG_DIR}/starship.toml"

# Create config dir owned by the real user
sudo -u "$REAL_USER" mkdir -p "$STARSHIP_CFG_DIR"

# Apply preset — this fetches and writes the official gruvbox-rainbow config
sudo -u "$REAL_USER" starship preset gruvbox-rainbow -o "$STARSHIP_CFG"

# Add Debian symbol to os.symbols (not in the default preset)
# Appended safely — toml block will only override [os.symbols] values
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

chown "$REAL_USER":"$REAL_USER" "$STARSHIP_CFG" 2>/dev/null || true
success "Gruvbox Rainbow preset written to ${STARSHIP_CFG}."

# ── 20.9  Write .zshrc (Oh My Zsh theme=none so Starship takes over) ─────────
info "Writing ${REAL_HOME}/.zshrc ..."
ZSHRC="${REAL_HOME}/.zshrc"

# Back up existing .zshrc if present
[[ -f "$ZSHRC" ]] && cp "$ZSHRC" "${ZSHRC}.bak_$(date +%Y%m%d_%H%M%S)"

# Write a clean, well-commented .zshrc
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
# NOTE: zsh-syntax-highlighting and fast-syntax-highlighting should
#       NOT both be active at the same time — using fast-syntax-highlighting.
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

chown "$REAL_USER":"$REAL_USER" "$ZSHRC"
success ".zshrc written to ${ZSHRC}."

# ── 20.10  Ownership sanity check ───────────────────────────────────────────
chown -R "$REAL_USER":"$REAL_USER" \
    "${REAL_HOME}/.oh-my-zsh" \
    "${REAL_HOME}/.config/starship.toml" \
    2>/dev/null || true

success "Step 20 complete — zsh + Oh My Zsh + Starship (Gruvbox Rainbow) fully configured."
warn "Open a new terminal session to activate zsh. If it doesn't start automatically, run: zsh"

# =============================================================================
# STEP 21 — UBUNTU LOOK & FEEL
#   Yaru theme (GTK + Shell + Icons + Cursor + Sound)
#   Ubuntu font family
#   Dash-to-Dock + AppIndicator + Desktop Icons NG
#   gsettings to wire everything together
# =============================================================================
step "Step 21 — Ubuntu look & feel (Yaru theme, Ubuntu fonts, Dash-to-Dock)"

# Only applies to GNOME — skip silently on other DEs
if ! command -v gnome-shell &>/dev/null; then
    warn "GNOME Shell not detected — skipping Ubuntu look & feel step."
else

# ── 21.1  Determine real user (same logic as Step 20) ───────────────────────
if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
    LOOK_USER="$SUDO_USER"
    LOOK_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
else
    LOOK_USER="root"
    LOOK_HOME="/root"
fi

# Helper: run gsettings as the real user (needs dbus session)
run_gsettings() {
    sudo -u "$LOOK_USER" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u "$LOOK_USER")/bus" \
        gsettings "$@" 2>/dev/null || true
}

# ── 21.2  Install Yaru theme packages ───────────────────────────────────────
info "Installing Yaru theme packages (GTK, Shell, Icons, Cursor, Sound)..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    yaru-theme-gtk \
    yaru-theme-gnome-shell \
    yaru-theme-icon \
    yaru-theme-sound \
    yaru-theme-unity \
    gnome-themes-extra \
    adwaita-icon-theme-full \
    gtk2-engines-murrine \
    gtk2-engines-pixbuf
success "Yaru theme packages installed."

# ── 21.3  Install Ubuntu font family ────────────────────────────────────────
info "Installing Ubuntu font family..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    fonts-ubuntu \
    fonts-ubuntu-console
fc-cache -f
success "Ubuntu fonts installed."

# ── 21.4  Install GNOME Shell extensions ────────────────────────────────────
info "Installing GNOME Shell extensions..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    gnome-shell-extension-dashtodock \
    gnome-shell-extension-desktop-icons-ng \
    gnome-shell-extension-appindicator \
    gnome-shell-extension-user-theme \
    gnome-shell-extension-manager \
    gnome-tweaks
success "GNOME Shell extensions installed."

# ── 21.5  Apply gsettings — theme, fonts, dock, extensions ──────────────────
info "Applying gsettings (Yaru-dark theme, Ubuntu fonts, dock layout)..."

# ── Theme & icons ─────────────────────────────────────────────────────────
run_gsettings set org.gnome.desktop.interface gtk-theme       'Yaru-dark'
run_gsettings set org.gnome.desktop.interface icon-theme      'Yaru-dark'
run_gsettings set org.gnome.desktop.interface cursor-theme    'Yaru'
run_gsettings set org.gnome.desktop.interface cursor-size     24

# Shell theme (requires User Theme extension to be enabled first — done below)
run_gsettings set org.gnome.shell.extensions.user-theme name 'Yaru-dark' 2>/dev/null || true

# ── Sound theme ────────────────────────────────────────────────────────────
run_gsettings set org.gnome.desktop.sound theme-name          'Yaru'
run_gsettings set org.gnome.desktop.sound event-sounds        true

# ── Ubuntu fonts ───────────────────────────────────────────────────────────
run_gsettings set org.gnome.desktop.interface font-name        'Ubuntu 11'
run_gsettings set org.gnome.desktop.interface document-font-name 'Ubuntu 11'
run_gsettings set org.gnome.desktop.interface monospace-font-name 'Ubuntu Mono 13'
run_gsettings set org.gnome.desktop.wm.preferences titlebar-font 'Ubuntu Bold 11'

# ── Colour scheme (dark mode) ──────────────────────────────────────────────
run_gsettings set org.gnome.desktop.interface color-scheme    'prefer-dark'

# ── Text rendering ─────────────────────────────────────────────────────────
run_gsettings set org.gnome.desktop.interface font-antialiasing 'rgba'
run_gsettings set org.gnome.desktop.interface font-hinting     'slight'

# ── XCURSOR_SIZE for Wayland/X11 consistency ──────────────────────────────
grep -q "XCURSOR_SIZE" /etc/environment \
    || echo "XCURSOR_SIZE=24" >> /etc/environment

# ── Workspaces ─────────────────────────────────────────────────────────────
run_gsettings set org.gnome.desktop.wm.preferences button-layout 'appmenu:minimize,maximize,close'
run_gsettings set org.gnome.mutter dynamic-workspaces          true
run_gsettings set org.gnome.desktop.wm.preferences num-workspaces 4

# ── Hot corners ────────────────────────────────────────────────────────────
run_gsettings set org.gnome.desktop.interface enable-hot-corners true

# ── Night Light (Ubuntu-style warm evening tone) ───────────────────────────
run_gsettings set org.gnome.settings-daemon.plugins.color night-light-enabled true
run_gsettings set org.gnome.settings-daemon.plugins.color night-light-schedule-automatic true
run_gsettings set org.gnome.settings-daemon.plugins.color night-light-temperature 4000

# ── Dash-to-Dock configuration (Ubuntu dock style) ────────────────────────
# Position: bottom, auto-hide, extend to edges, fixed icon size 48px
DTD="org.gnome.shell.extensions.dash-to-dock"
run_gsettings set $DTD dock-position        'BOTTOM'
run_gsettings set $DTD dock-fixed           false
run_gsettings set $DTD autohide             true
run_gsettings set $DTD intellihide          true
run_gsettings set $DTD extend-height        false
run_gsettings set $DTD dash-max-icon-size   48
run_gsettings set $DTD icon-size-fixed      true
run_gsettings set $DTD show-trash           true
run_gsettings set $DTD show-mounts          true
run_gsettings set $DTD click-action         'focus-or-previews'
run_gsettings set $DTD scroll-action        'cycle-windows'
run_gsettings set $DTD transparency-mode    'FIXED'
run_gsettings set $DTD background-opacity   0.8
run_gsettings set $DTD custom-theme-shrink  true

# ── Enable GNOME Shell extensions ─────────────────────────────────────────
info "Enabling GNOME Shell extensions..."

# Get current enabled extension list and append ours
CURRENT_EXTS=$(sudo -u "$LOOK_USER" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u "$LOOK_USER")/bus" \
    gsettings get org.gnome.shell enabled-extensions 2>/dev/null \
    || echo "@as []")

# Extension UUIDs
EXTS_TO_ENABLE=(
    "dash-to-dock@micxgx.gmail.com"
    "ding@rastersoft.com"
    "[email protected]"
    "user-theme@gnome-shell-extensions.gcampax.github.com"
)

# Build new extension list by merging current + new (deduped)
NEW_EXTS="$CURRENT_EXTS"
for ext in "${EXTS_TO_ENABLE[@]}"; do
    if ! echo "$NEW_EXTS" | grep -q "$ext"; then
        NEW_EXTS=$(echo "$NEW_EXTS" | sed "s/\]$/, '$ext'\]/")
        # Handle empty list edge case
        NEW_EXTS=$(echo "$NEW_EXTS" | sed "s/@as \[\]/['$ext']/")
    fi
done

run_gsettings set org.gnome.shell enabled-extensions "$NEW_EXTS" 2>/dev/null || \
    warn "Could not set enabled-extensions (no active GNOME session) — extensions will activate on next login."

success "Extensions enabled (will take effect on next GNOME login)."

# ── 21.6  Wallpaper — Ubuntu-style amber gradient ────────────────────────
info "Setting default wallpaper..."
# Use Debian 13 Trixie default wallpaper (Ceratopsian) as base
# but apply Ubuntu-style amber overlay via dconf if available
WALLPAPER_LIGHT="/usr/share/backgrounds/gnome/amber-l.jxl"
WALLPAPER_DARK="/usr/share/backgrounds/gnome/amber-d.jxl"
WALLPAPER_DEBIAN_LIGHT="/usr/share/images/desktop-base/desktop-background"
WALLPAPER_DEBIAN_DARK="/usr/share/images/desktop-base/desktop-background"

# Install desktop-base for Trixie wallpaper
DEBIAN_FRONTEND=noninteractive apt-get install -y desktop-base 2>/dev/null || true

# Prefer amber GNOME wallpaper (ships with gnome-backgrounds) if available
DEBIAN_FRONTEND=noninteractive apt-get install -y gnome-backgrounds 2>/dev/null || true

if [[ -f "$WALLPAPER_LIGHT" ]]; then
    run_gsettings set org.gnome.desktop.background picture-uri       "file://${WALLPAPER_LIGHT}"
    run_gsettings set org.gnome.desktop.background picture-uri-dark  "file://${WALLPAPER_DARK}"
elif [[ -f "$WALLPAPER_DEBIAN_LIGHT" ]]; then
    run_gsettings set org.gnome.desktop.background picture-uri       "file://${WALLPAPER_DEBIAN_LIGHT}"
    run_gsettings set org.gnome.desktop.background picture-uri-dark  "file://${WALLPAPER_DEBIAN_DARK}"
fi
run_gsettings set org.gnome.desktop.background picture-options   'zoom'

# ── 21.7  GDM login screen theme (Yaru-dark) ─────────────────────────────
info "Applying Yaru-dark to GDM login screen..."
# GDM background is set via /etc/gdm3/greeter.dconf-defaults
if [[ -d /etc/gdm3 ]]; then
    mkdir -p /etc/dconf/db/gdm.d
    cat > /etc/dconf/db/gdm.d/01-ubuntu-look << 'EOF'
[org/gnome/desktop/interface]
gtk-theme='Yaru-dark'
icon-theme='Yaru-dark'
cursor-theme='Yaru'
font-name='Ubuntu 11'
color-scheme='prefer-dark'

[org/gnome/desktop/background]
picture-options='zoom'
EOF
    dconf update 2>/dev/null || true
    success "GDM theme set to Yaru-dark."
else
    warn "GDM not found — skipping login screen theming."
fi

success "Step 21 complete — Ubuntu look & feel applied."
info "  → Log out and back in (or reboot) to see Dash-to-Dock and the Yaru Shell theme."
info "  → If the Shell theme doesn't apply, open GNOME Tweaks → Appearance → Shell → select Yaru-dark."

fi  # end GNOME check

# =============================================================================
# STEP 22 — FINAL CLEANUP
# =============================================================================
step "Step 22 — Final cleanup"

info "Cleaning up APT cache..."
apt-get autoremove -y
apt-get autoclean -y
apt-get clean

success "Cleanup complete."

# =============================================================================
# SUMMARY
# =============================================================================
echo ""
echo -e "${GRN}╔══════════════════════════════════════════════════════════════╗${RST}"
echo -e "${GRN}║     Debian 13 Post-Install Complete — Beelink SER8          ║${RST}"
echo -e "${GRN}╠══════════════════════════════════════════════════════════════╣${RST}"
echo -e "${GRN}║  ✓  System updated & base packages installed                ║${RST}"
echo -e "${GRN}║  ✓  AMD Radeon 780M (RDNA 3) drivers & firmware             ║${RST}"
echo -e "${GRN}║  ✓  Ryzen 7 8845HS microcode + amd_pstate=active            ║${RST}"
echo -e "${GRN}║  ✓  GRUB kernel parameters optimised                        ║${RST}"
echo -e "${GRN}║  ✓  NVMe I/O scheduler + TRIM timer                         ║${RST}"
echo -e "${GRN}║  ✓  Wi-Fi (Intel AX) & Bluetooth firmware                   ║${RST}"
echo -e "${GRN}║  ✓  PipeWire + SOF audio                                    ║${RST}"
echo -e "${GRN}║  ✓  zram swap (25%, zstd)                                   ║${RST}"
echo -e "${GRN}║  ✓  sysctl network & memory tuning                          ║${RST}"
echo -e "${GRN}║  ✓  fwupd firmware update daemon                            ║${RST}"
echo -e "${GRN}║  ✓  UFW firewall + fail2ban                                 ║${RST}"
echo -e "${GRN}║  ✓  Flatpak + Flathub                                       ║${RST}"
echo -e "${GRN}║  ✓  zsh + Oh My Zsh + Starship Gruvbox Rainbow              ║${RST}"
echo -e "${GRN}║  ✓  JetBrainsMono Nerd Font (system-wide)                   ║${RST}"
echo -e "${GRN}║  ✓  Yaru-dark theme + Ubuntu fonts + Dash-to-Dock           ║${RST}"
echo -e "${GRN}╠══════════════════════════════════════════════════════════════╣${RST}"
echo -e "${YLW}║  NEXT STEPS:                                                 ║${RST}"
echo -e "${YLW}║  • Open new terminal → zsh/Starship will load automatically  ║${RST}"
echo -e "${YLW}║  • Set terminal font to: JetBrainsMono Nerd Font             ║${RST}"
echo -e "${YLW}║  • Log out & back in to activate Yaru Shell + Dash-to-Dock  ║${RST}"
echo -e "${YLW}║  • If Shell theme missing: Tweaks→Appearance→Shell→Yaru-dark ║${RST}"
echo -e "${YLW}║  • Run: sensors-detect (thermal sensor setup)                ║${RST}"
echo -e "${YLW}║  • Run: fwupdmgr update (BIOS/firmware updates)              ║${RST}"
echo -e "${YLW}║  • Run: vainfo (verify hardware video decode)                ║${RST}"
echo -e "${YLW}║  • Check: /var/log/debian13-postinstall-ser8.log             ║${RST}"
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