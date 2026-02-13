#!/usr/bin/env bash
# =============================================================================
#  Ubuntu 24.04 Post-Installation Script
#  Hardware : Beelink SER8 — AMD Ryzen™ 7 8845HS / Radeon 780M
#  Profile  : Development · Server / Homelab · Media & Gaming
#  Browsers : Google Chrome + Mozilla Firefox (native .deb)
#  Editor   : Visual Studio Code
#  GPU      : AMD Mesa open-source (stock Ubuntu 24.04)
# =============================================================================
#  Usage:
#    chmod +x beelink-ser8-postinstall.sh
#    sudo ./beelink-ser8-postinstall.sh
# =============================================================================

set -euo pipefail

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

log()     { echo -e "${GREEN}[✔]${RESET} $*"; }
info()    { echo -e "${CYAN}[→]${RESET} $*"; }
warn()    { echo -e "${YELLOW}[!]${RESET} $*"; }
err()     { echo -e "${RED}[✖]${RESET} $*" >&2; }
section() {
    echo ""
    echo -e "${BOLD}${CYAN}══════════════════════════════════════════════════${RESET}"
    echo -e "${BOLD}${CYAN}  $*${RESET}"
    echo -e "${BOLD}${CYAN}══════════════════════════════════════════════════${RESET}"
}

# =============================================================================
# 1. SAFETY CHECKS
# =============================================================================
section "1 · Safety Checks"

[[ $EUID -ne 0 ]] && { err "Run as root: sudo $0"; exit 1; }

REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(eval echo "~${REAL_USER}")
log "Running as root — target user: ${REAL_USER} (home: ${REAL_HOME})"

UBUNTU_VERSION=$(lsb_release -rs 2>/dev/null || echo "unknown")
[[ "$UBUNTU_VERSION" != "24.04" ]] && \
    warn "Designed for Ubuntu 24.04 (detected: ${UBUNTU_VERSION}). Proceed with caution."

log "Safety checks passed."

# =============================================================================
# 2. SYSTEM UPDATE & UPGRADE
# =============================================================================
section "2 · System Update & Upgrade"

export DEBIAN_FRONTEND=noninteractive

info "Updating package lists..."
apt-get update -qq

info "Upgrading installed packages..."
apt-get upgrade -y -qq

info "Running dist-upgrade..."
apt-get dist-upgrade -y -qq

log "System is up to date."

# =============================================================================
# 3. ESSENTIAL PACKAGES
# =============================================================================
section "3 · Essential Packages"

ESSENTIALS=(
    # Core utilities
    curl wget git htop btop neofetch
    vim nano tmux screen tree ncdu
    build-essential software-properties-common
    apt-transport-https ca-certificates gnupg lsb-release
    # Compression
    zip unzip p7zip-full p7zip-rar rar unrar
    # System inspection
    inxi lshw hwinfo pciutils usbutils cpu-checker
    net-tools nmap traceroute iperf3 mtr
    # File manager helpers
    gvfs-backends ffmpegthumbnailer
    # Fonts
    fonts-noto fonts-noto-cjk fonts-firacode
    # Python
    python3 python3-pip python3-venv pipx
    # Misc
    gdebi xdg-utils bash-completion
)

info "Installing essential packages..."
apt-get install -y -qq "${ESSENTIALS[@]}"
log "Essential packages installed."

# =============================================================================
# 4. KERNEL & FIRMWARE UPDATES
# =============================================================================
section "4 · Kernel & Firmware"

info "Installing linux-firmware (WiFi / BT / AMD firmware blobs)..."
apt-get install -y -qq linux-firmware

info "Installing fwupd (UEFI & device firmware updater)..."
apt-get install -y -qq fwupd

info "Refreshing firmware metadata..."
fwupdmgr refresh --force 2>/dev/null \
    || warn "fwupdmgr refresh skipped — run manually after reboot."

# Uncomment to install the HWE kernel (newer kernel on LTS):
# apt-get install -y -qq linux-generic-hwe-24.04

log "Kernel and firmware up to date."

# =============================================================================
# 5. AMD GPU — MESA OPEN-SOURCE (STOCK)
# =============================================================================
section "5 · AMD GPU — Mesa Open-Source (Radeon 780M)"

# Ubuntu 24.04 ships Mesa 24.x with solid RDNA 3 / 780M support.
# No third-party PPA needed — we ensure all relevant packages are present.

MESA_PKGS=(
    mesa-vulkan-drivers        # RADV Vulkan driver
    mesa-utils                 # glxinfo, glxgears
    vulkan-tools               # vulkaninfo
    libvulkan1
    libdrm-amdgpu1
    libgl1-mesa-dri
    libgles2
    libglx-mesa0
    xserver-xorg-video-amdgpu
)

info "Ensuring Mesa / Vulkan packages are present..."
apt-get install -y -qq "${MESA_PKGS[@]}"

# ── VA-API hardware video acceleration ───────────────────────────────────────
VAAPI_PKGS=(
    libva2 libva-drm2 libva-x11-2 libva-glx2
    vainfo
    mesa-va-drivers            # RADV VA-API for AMD
    mesa-vdpau-drivers         # VDPAU driver
    libvdpau1 libvdpau-va-gl1
    gstreamer1.0-vaapi
    ffmpeg
)

info "Installing VA-API / hardware video acceleration packages..."
apt-get install -y -qq "${VAAPI_PKGS[@]}"

# Force RADV VA-API driver system-wide
mkdir -p /etc/environment.d
cat > /etc/environment.d/99-vaapi-amd.conf <<'EOF'
# Hardware video acceleration — AMD Radeon 780M (Beelink SER8)
LIBVA_DRIVER_NAME=radeonsi
VDPAU_DRIVER=radeonsi
EOF

log "Mesa GPU stack + VA-API configured."
log "After reboot: run 'vainfo' and 'vulkaninfo --summary' to verify."

# =============================================================================
# 6. CPU POWER MANAGEMENT (AMD P-STATE)
# =============================================================================
section "6 · CPU Power Management — AMD P-state (Ryzen 7 8845HS)"

GRUB_CFG="/etc/default/grub"
GRUB_PARAM="amd_pstate=active"

if ! grep -q "$GRUB_PARAM" "$GRUB_CFG"; then
    info "Injecting '${GRUB_PARAM}' into GRUB cmdline..."
    sed -i "s/\(GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*\)\"/\1 ${GRUB_PARAM}\"/" "$GRUB_CFG"
    update-grub
    log "GRUB updated with AMD P-state active driver."
else
    log "AMD P-state already in GRUB config."
fi

info "Installing power-profiles-daemon (integrates with GNOME power menu)..."
apt-get install -y -qq power-profiles-daemon cpupower-gui
systemctl enable --now power-profiles-daemon 2>/dev/null || true

log "After reboot verify: cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver"
log "Expected output: amd-pstate-epp"

# =============================================================================
# 7. THERMAL MONITORING
# =============================================================================
section "7 · Thermal Monitoring"

apt-get install -y -qq lm-sensors psensor

info "Auto-detecting sensors..."
yes "" | sensors-detect --auto 2>/dev/null || true

log "Run 'sensors' after reboot to view CPU / GPU temperatures."

# =============================================================================
# 8. SSD OPTIMISATIONS (NVMe / fstrim)
# =============================================================================
section "8 · SSD Optimisations"

info "Enabling weekly fstrim for NVMe longevity..."
systemctl enable --now fstrim.timer

grep -q "noatime" /etc/fstab \
    && log "noatime already set in /etc/fstab." \
    || warn "Tip: Add 'noatime' to your NVMe mount options in /etc/fstab to reduce write amplification."

log "SSD optimisations done."

# =============================================================================
# 9. NETWORKING & BLUETOOTH
# =============================================================================
section "9 · Networking & Bluetooth"

NET_PKGS=(
    network-manager-openvpn-gnome
    network-manager-vpnc
    wireguard
    blueman bluetooth bluez bluez-tools
    openssh-server
    samba                  # SMB/CIFS file sharing (homelab)
    avahi-daemon           # mDNS / .local hostname resolution
    nfs-common             # NFS client for NAS mounts
)

info "Installing networking & Bluetooth packages..."
apt-get install -y -qq "${NET_PKGS[@]}"

systemctl enable --now bluetooth
systemctl enable --now ssh
systemctl enable --now avahi-daemon

# Disable WiFi power-save (prevents latency spikes / disconnects on mini-PC)
WIFI_PM_CONF="/etc/NetworkManager/conf.d/wifi-powersave-off.conf"
if [[ ! -f "$WIFI_PM_CONF" ]]; then
    cat > "$WIFI_PM_CONF" <<'EOF'
[connection]
wifi.powersave = 2
EOF
    info "WiFi power-save disabled for improved latency."
fi

log "Networking & Bluetooth configured. SSH server enabled."

# =============================================================================
# 10. DEVELOPMENT TOOLS
# =============================================================================
section "10 · Development Tools"

DEV_PKGS=(
    # Build toolchain
    gcc g++ clang llvm cmake ninja-build make
    gdb valgrind strace ltrace
    # Version control
    git git-lfs
    # Scripting & languages
    python3 python3-pip python3-venv pipx
    nodejs npm
    # default-jdk
    # golang-go
    # Database CLIs
    # sqlite3 postgresql-client mysql-client redis-tools
    # HTTP / API tools
    httpie jq
    # GitHub CLI
    gh
    # Container helpers (rootless alternative to Docker)
    # podman buildah skopeo
    # Shell
    zsh
    # pyenv build dependencies
    libssl-dev libbz2-dev libreadline-dev libsqlite3-dev
    libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev
    libffi-dev liblzma-dev
)

info "Installing development tools..."
apt-get install -y -qq "${DEV_PKGS[@]}"

# ── Oh My Zsh ─────────────────────────────────────────────────────────────────
if [[ ! -d "${REAL_HOME}/.oh-my-zsh" ]]; then
    info "Installing Oh My Zsh for ${REAL_USER}..."
    sudo -u "$REAL_USER" bash -c \
        'RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"' \
        2>/dev/null || warn "Oh My Zsh install skipped (check network)."
fi

# ── nvm (Node Version Manager) ────────────────────────────────────────────────
if [[ ! -d "${REAL_HOME}/.nvm" ]]; then
    info "Installing nvm for ${REAL_USER}..."
    sudo -u "$REAL_USER" bash -c \
        'curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash' \
        2>/dev/null || warn "nvm install skipped (check network)."
fi

# ── pyenv ─────────────────────────────────────────────────────────────────────
if [[ ! -d "${REAL_HOME}/.pyenv" ]]; then
    info "Installing pyenv for ${REAL_USER}..."
    sudo -u "$REAL_USER" bash -c \
        'curl -fsSL https://pyenv.run | bash' \
        2>/dev/null || warn "pyenv install skipped (check network)."
fi

log "Development tools installed."

# =============================================================================
# 11. DOCKER ENGINE
# =============================================================================
# section "11 · Docker Engine"

# if command -v docker &>/dev/null; then
#     log "Docker already installed: $(docker --version)"
# else
#     info "Adding Docker repository..."
#     install -m 0755 -d /etc/apt/keyrings
#     curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
#         | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
#     chmod a+r /etc/apt/keyrings/docker.gpg

#     echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
# https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
#         > /etc/apt/sources.list.d/docker.list

#     apt-get update -qq
#     apt-get install -y -qq \
#         docker-ce docker-ce-cli containerd.io \
#         docker-buildx-plugin docker-compose-plugin

#     usermod -aG docker "$REAL_USER"
#     systemctl enable --now docker
#     log "Docker installed. Run 'newgrp docker' or re-login for group membership."
# fi

# ── Portainer CE (Docker web UI — great for homelab) ─────────────────────────
# if ! docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^portainer$"; then
#     info "Deploying Portainer CE (Docker management UI)..."
#     docker volume create portainer_data 2>/dev/null || true
#     docker run -d \
#         --name portainer \
#         --restart=always \
#         -p 9000:9000 \
#         -v /var/run/docker.sock:/var/run/docker.sock \
#         -v portainer_data:/data \
#         portainer/portainer-ce:latest 2>/dev/null \
#         || warn "Portainer deploy skipped — Docker may not be running yet. Re-run after reboot."
#     log "Portainer → http://localhost:9000"
# fi

# =============================================================================
# 12. VISUAL STUDIO CODE
# =============================================================================
section "12 · Visual Studio Code"

if command -v code &>/dev/null; then
    log "VS Code already installed."
else
    info "Adding Microsoft VS Code repository..."
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
        | gpg --dearmor -o /etc/apt/keyrings/microsoft.gpg
    chmod a+r /etc/apt/keyrings/microsoft.gpg

    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] \
https://packages.microsoft.com/repos/code stable main" \
        > /etc/apt/sources.list.d/vscode.list

    apt-get update -qq
    apt-get install -y -qq code
    log "VS Code installed."
fi

# ── Recommended extensions ────────────────────────────────────────────────────
# VSCODE_EXTENSIONS=(
#     ms-python.python
#     ms-vscode-remote.remote-ssh
#     ms-vscode-remote.remote-containers
#     ms-azuretools.vscode-docker
#     eamodio.gitlens
#     esbenp.prettier-vscode
#     dbaeumer.vscode-eslint
#     redhat.vscode-yaml
#     ms-vscode.cpptools
#     golang.go
# )

# info "Installing VS Code extensions for ${REAL_USER}..."
# for EXT in "${VSCODE_EXTENSIONS[@]}"; do
#     sudo -u "$REAL_USER" code --install-extension "$EXT" --force 2>/dev/null \
#         || warn "Extension skipped (display may not be active): $EXT"
# done
# log "VS Code extensions installed."

# =============================================================================
# 13. BROWSERS — GOOGLE CHROME + FIREFOX (native .deb)
# =============================================================================
section "13 · Browsers — Google Chrome & Firefox"

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

# ── Firefox — native .deb (removes snap version) ──────────────────────────────
if snap list firefox &>/dev/null 2>&1; then
    info "Removing Firefox snap and replacing with native .deb..."
    snap remove --purge firefox 2>/dev/null || true
fi

if ! dpkg -l firefox 2>/dev/null | grep -q "^ii"; then
    info "Adding Mozilla Team PPA for Firefox .deb..."
    add-apt-repository -y ppa:mozillateam/ppa 2>/dev/null

    # Pin the PPA above the Ubuntu snap redirect
    cat > /etc/apt/preferences.d/mozilla-firefox <<'EOF'
Package: *
Pin: release o=LP-PPA-mozillateam
Pin-Priority: 1001
EOF
    apt-get update -qq
    apt-get install -y -qq firefox
    log "Firefox (native .deb) installed."
else
    log "Firefox .deb already installed."
fi

info "Firefox VA-API tip: In about:config set  media.ffmpeg.vaapi.enabled = true"

# =============================================================================
# 14. MULTIMEDIA CODECS
# =============================================================================
section "14 · Multimedia Codecs"

info "Pre-accepting MS Core Fonts EULA..."
echo "ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true" \
    | debconf-set-selections

CODEC_PKGS=(
    ubuntu-restricted-extras
    gstreamer1.0-plugins-base
    gstreamer1.0-plugins-good
    gstreamer1.0-plugins-bad
    gstreamer1.0-plugins-ugly
    gstreamer1.0-libav
    gstreamer1.0-tools
    vlc
    mpv
    handbrake          # Video transcoding GUI
    obs-studio         # Streaming / screen recording
)

apt-get install -y -qq "${CODEC_PKGS[@]}"
log "Multimedia codecs, VLC, MPV, HandBrake, OBS Studio installed."

# =============================================================================
# 15. SERVER / HOMELAB TOOLS
# =============================================================================
# section "15 · Server & Homelab Tools"

# HOMELAB_PKGS=(
#     nginx                           # Web / reverse proxy
#     certbot python3-certbot-nginx   # Let's Encrypt TLS
#     prometheus-node-exporter        # Prometheus metrics endpoint
#     cockpit                         # Web-based server management UI
#     smartmontools                   # NVMe / HDD health (smartctl -a /dev/nvme0)
#     hdparm
#     virt-manager libvirt-daemon-system qemu-kvm bridge-utils   # KVM virtualisation
#     mergerfs                        # JBOD storage pooling
#     nfs-kernel-server               # NFS server (serve shares to other machines)
#     cron logrotate
# )

# info "Installing homelab / server packages..."
# apt-get install -y -qq "${HOMELAB_PKGS[@]}"

# systemctl enable --now nginx            2>/dev/null || true
# systemctl enable --now cockpit.socket  2>/dev/null || true

# # Add user to libvirt & kvm groups for virtualisation
# usermod -aG libvirt,kvm "$REAL_USER"

# log "Homelab tools installed."
# log "Cockpit web UI  → https://localhost:9090"
# log "Portainer UI    → http://localhost:9000"

# =============================================================================
# 16. GAMING — GameMode & MangoHud
# =============================================================================
# section "16 · Gaming — GameMode & MangoHud"

# # Enable 32-bit architecture (required for Wine / some Steam games)
# dpkg --add-architecture i386
# apt-get update -qq

# GAMING_PKGS=(
#     gamemode           # On-demand CPU performance governor for games
#     gamescope          # Micro-compositor / upscaling for games
#     mangohud           # In-game FPS / CPU / GPU / VRAM overlay
#     lutris             # Cross-platform game launcher
#     wine wine32 wine64 winetricks
# )

# info "Installing gaming packages..."
# apt-get install -y -qq "${GAMING_PKGS[@]}"

# usermod -aG gamemode "$REAL_USER" 2>/dev/null || true

# # Steam (uncomment if you want Steam as a Flatpak):
# # sudo -u "$REAL_USER" flatpak install -y flathub com.valvesoftware.Steam

# log "GameMode, MangoHud, Lutris, and Wine installed."
# log "Launch games with:  gamemoderun mangohud <game>"

# =============================================================================
# 17. FLATPAK + FLATHUB
# =============================================================================
section "17 · Flatpak + Flathub"

apt-get install -y -qq flatpak gnome-software-plugin-flatpak

if ! flatpak remote-list 2>/dev/null | grep -q flathub; then
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    log "Flathub repository added."
else
    log "Flathub already configured."
fi

# Popular Flatpaks — uncomment to install:
# sudo -u "$REAL_USER" flatpak install -y flathub com.valvesoftware.Steam
# sudo -u "$REAL_USER" flatpak install -y flathub com.spotify.Client
# sudo -u "$REAL_USER" flatpak install -y flathub com.discordapp.Discord
# sudo -u "$REAL_USER" flatpak install -y flathub org.libreoffice.LibreOffice
# sudo -u "$REAL_USER" flatpak install -y flathub org.gimp.GIMP

log "Flatpak + Flathub configured. Browse more apps in GNOME Software."

# =============================================================================
# 18. GNOME TWEAKS & DESKTOP POLISH
# =============================================================================
section "18 · GNOME Tweaks & Desktop"

apt-get install -y -qq \
    gnome-tweaks gnome-shell-extension-manager \
    dconf-editor gnome-shell-extensions

_dconf() { sudo -u "$REAL_USER" dconf write "$1" "$2" 2>/dev/null || true; }

_dconf /org/gnome/desktop/interface/clock-show-seconds              true
_dconf /org/gnome/desktop/interface/clock-show-weekday              true
_dconf /org/gnome/desktop/interface/enable-hot-corners              false
_dconf /org/gnome/desktop/interface/color-scheme                   "'prefer-dark'"
_dconf /org/gnome/desktop/wm/preferences/button-layout             "'appmenu:minimize,maximize,close'"
# Prevent sleep when plugged in (ideal for a mini-PC that stays on)
_dconf /org/gnome/settings-daemon/plugins/power/sleep-inactive-ac-timeout      0
_dconf /org/gnome/settings-daemon/plugins/power/sleep-inactive-battery-timeout 1800
# Disable mouse natural scroll; enable for touchpad
_dconf /org/gnome/desktop/peripherals/mouse/natural-scroll          false
_dconf /org/gnome/desktop/peripherals/touchpad/natural-scroll       true

log "GNOME tweaks applied (dark mode, no sleep on AC, window buttons, clock)."

# =============================================================================
# 19. AUTOMATIC SECURITY UPDATES
# =============================================================================
section "19 · Automatic Security Updates"

apt-get install -y -qq unattended-upgrades

cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF

systemctl enable --now unattended-upgrades
log "Automatic security updates enabled."

# =============================================================================
# 20. STARSHIP PROMPT — GRUVBOX RAINBOW PRESET
# =============================================================================
section "20 · Starship Prompt — Gruvbox Rainbow"

# ── Dependencies ──────────────────────────────────────────────────────────────
# Starship requires a Nerd Font to render its powerline glyphs and icons.
# We install JetBrains Mono Nerd Font (system-wide) from the official release.
# The Gruvbox Rainbow preset also uses the [os] module which requires
# Nerd Font symbols for distro logos.

NERD_FONT_VERSION="v3.3.0"
NERD_FONT_NAME="JetBrainsMono"
NERD_FONT_DIR="/usr/local/share/fonts/NerdFonts/${NERD_FONT_NAME}"

if fc-list | grep -qi "JetBrainsMono Nerd Font"; then
    log "JetBrains Mono Nerd Font already installed."
else
    info "Downloading JetBrains Mono Nerd Font ${NERD_FONT_VERSION}..."
    mkdir -p "$NERD_FONT_DIR"
    TMP_FONT_ZIP=$(mktemp /tmp/nerd-font-XXXXXX.zip)
    curl -fsSL \
        "https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONT_VERSION}/${NERD_FONT_NAME}.zip" \
        -o "$TMP_FONT_ZIP"

    info "Extracting Nerd Font to ${NERD_FONT_DIR}..."
    unzip -q -o "$TMP_FONT_ZIP" -d "$NERD_FONT_DIR"
    rm -f "$TMP_FONT_ZIP"

    info "Refreshing font cache..."
    fc-cache -fv "$NERD_FONT_DIR" > /dev/null
    log "JetBrains Mono Nerd Font installed."
fi

# ── Install Starship binary ───────────────────────────────────────────────────
if command -v starship &>/dev/null; then
    log "Starship already installed: $(starship --version)"
else
    info "Installing Starship (latest) to /usr/local/bin..."
    curl -fsSL https://starship.rs/install.sh \
        | sh -s -- --yes --bin-dir /usr/local/bin
    log "Starship installed: $(starship --version)"
fi

# ── Apply Gruvbox Rainbow preset ──────────────────────────────────────────────
info "Applying Gruvbox Rainbow preset for ${REAL_USER}..."

STARSHIP_CFG_DIR="${REAL_HOME}/.config"
STARSHIP_CFG="${STARSHIP_CFG_DIR}/starship.toml"
mkdir -p "$STARSHIP_CFG_DIR"

# Back up any existing config
if [[ -f "$STARSHIP_CFG" ]]; then
    cp "$STARSHIP_CFG" "${STARSHIP_CFG}.bak.$(date +%Y%m%d%H%M%S)"
    warn "Existing starship.toml backed up."
fi

# Apply the preset as the real user (starship must be in PATH)
sudo -u "$REAL_USER" \
    /usr/local/bin/starship preset gruvbox-rainbow \
    -o "$STARSHIP_CFG"

chown "${REAL_USER}:${REAL_USER}" "$STARSHIP_CFG"
log "Gruvbox Rainbow preset written to ${STARSHIP_CFG}"

# ── Shell integration ─────────────────────────────────────────────────────────
# Adds 'eval "$(starship init <shell>)"' to ~/.bashrc and ~/.zshrc
# (idempotent — skipped if already present)

STARSHIP_INIT_BASH='eval "$(starship init bash)"'
STARSHIP_INIT_ZSH='eval "$(starship init zsh)"'

BASHRC="${REAL_HOME}/.bashrc"
ZSHRC="${REAL_HOME}/.zshrc"

if ! grep -qF "starship init bash" "$BASHRC" 2>/dev/null; then
    echo ""                              >> "$BASHRC"
    echo "# Starship prompt"            >> "$BASHRC"
    echo "$STARSHIP_INIT_BASH"          >> "$BASHRC"
    chown "${REAL_USER}:${REAL_USER}" "$BASHRC"
    log "Starship init added to ~/.bashrc"
else
    log "Starship already initialised in ~/.bashrc"
fi

if [[ -f "$ZSHRC" ]]; then
    if ! grep -qF "starship init zsh" "$ZSHRC" 2>/dev/null; then
        echo ""                             >> "$ZSHRC"
        echo "# Starship prompt"           >> "$ZSHRC"
        echo "$STARSHIP_INIT_ZSH"          >> "$ZSHRC"
        chown "${REAL_USER}:${REAL_USER}" "$ZSHRC"
        log "Starship init added to ~/.zshrc"
    else
        log "Starship already initialised in ~/.zshrc"
    fi
fi

log "Starship + Gruvbox Rainbow configured."
warn "Remember to set your terminal font to 'JetBrainsMono Nerd Font' in your terminal's profile settings."

# =============================================================================
# 21. FINAL CLEANUP & REBOOT PROMPT
# =============================================================================
section "20 · Final Cleanup"

info "Removing orphaned packages..."
apt-get autoremove -y -qq
apt-get autoclean -y -qq

# ── Post-install summary ──────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${GREEN}║  🎉  Post-installation complete!                             ║${RESET}"
echo -e "${BOLD}${GREEN}║     Beelink SER8 — Ubuntu 24.04 LTS                          ║${RESET}"
echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "${BOLD}After reboot — verify your setup:${RESET}"
echo ""
echo -e "${CYAN}  Hardware / GPU${RESET}"
echo "  vainfo                              → VA-API hardware video decode"
echo "  vulkaninfo --summary                → Vulkan / Radeon 780M info"
echo "  cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver"
echo "                                      → expected: amd-pstate-epp"
echo "  sensors                             → CPU / GPU temperatures"
echo "  smartctl -a /dev/nvme0              → NVMe health"
echo ""
echo -e "${CYAN}  Firmware${RESET}"
echo "  fwupdmgr get-updates                → check for BIOS / device firmware"
echo "  fwupdmgr update                     → apply firmware updates"
echo ""
echo -e "${CYAN}  Web UIs${RESET}"
echo "  http://localhost:9000               → Portainer (Docker management)"
echo "  https://localhost:9090              → Cockpit (server management)"
echo ""
echo -e "${CYAN}  Docker${RESET}"
echo "  newgrp docker && docker run hello-world  → smoke-test Docker"
echo ""
echo -e "${CYAN}  Gaming${RESET}"
echo "  gamemoderun mangohud <game>         → launch with perf overlay"
echo ""
echo -e "${CYAN}  Firefox VA-API${RESET}"
echo "  about:config → media.ffmpeg.vaapi.enabled = true"
echo ""

read -rp "$(echo -e "${YELLOW}Reboot now? [y/N]: ${RESET}")" REBOOT_ANSWER
if [[ "${REBOOT_ANSWER,,}" == "y" ]]; then
    log "Rebooting in 5 seconds... (Ctrl+C to cancel)"
    sleep 5
    reboot
else
    log "Script finished. Please reboot when ready — some changes require it."
fi