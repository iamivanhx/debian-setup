#!/bin/bash

##############################################################################
# Debian 13 Trixie Post-Installation Setup Script
# For Beelink SER8 AMD Ryzen 7 8845HS
#
# This script handles:
# - Sudo configuration check
# - System updates
# - Essential packages installation
# - AMD GPU drivers and firmware
# - Network configuration
# - Zsh and Oh My Zsh installation
# - Starship prompt (modern alternative to Powerlevel10k)
# - Nerd Fonts
# - Basic utilities and tools
##############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored messages
print_msg() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_step() {
    echo -e "${CYAN}[STEP]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# ASCII Banner
print_banner() {
    echo -e "${MAGENTA}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║   Debian 13 Trixie Post-Installation Setup               ║
║   Optimized for Beelink SER8 (AMD Ryzen 7 8845HS)        ║
║   with Zsh + Starship                                     ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Check if running as root
check_root() {
    if [ "$EUID" -eq 0 ]; then
        print_error "Please do not run this script as root."
        print_error "The script will request sudo privileges when needed."
        exit 1
    fi
}

# Check and setup sudo
check_sudo() {
    print_step "Checking sudo privileges..."
    
    # Check if sudo is installed
    if ! command -v sudo &> /dev/null; then
        print_error "sudo is not installed on this system."
        print_error ""
        print_error "Please run the following commands as root:"
        print_error "  su -"
        print_error "  apt update"
        print_error "  apt install -y sudo"
        print_error "  usermod -aG sudo $USER"
        print_error "  exit"
        print_error ""
        print_error "Then log out, log back in, and run this script again."
        exit 1
    fi
    
    # Check if user is in sudo group
    if ! groups | grep -q '\bsudo\b'; then
        print_error "User '$USER' is not in the sudo group."
        print_error ""
        print_error "Please run the following commands as root:"
        print_error "  su -"
        print_error "  usermod -aG sudo $USER"
        print_error "  exit"
        print_error ""
        print_error "Then log out, log back in, and run this script again."
        exit 1
    fi
    
    # Test sudo access
    if ! sudo -n true 2>/dev/null; then
        print_warning "Testing sudo access (you may need to enter your password)..."
        if ! sudo -v; then
            print_error "Failed to obtain sudo privileges."
            exit 1
        fi
    fi
    
    print_success "Sudo access confirmed!"
}

# Update system
update_system() {
    print_step "Updating system packages..."
    
    sudo apt update
    sudo apt upgrade -y
    sudo apt dist-upgrade -y
    
    print_success "System updated successfully!"
}

# Install essential packages
install_essentials() {
    print_step "Installing essential packages..."
    
    sudo apt install -y \
        build-essential \
        git \
        wget \
        curl \
        vim \
        nano \
        htop \
        btop \
        fastfetch \
        tmux \
        tree \
        zip \
        unzip \
        p7zip-full \
        apt-transport-https \
        ca-certificates \
        gnupg \
        lsb-release \
        dkms \
        linux-headers-$(uname -r) \
        jq
    
    print_success "Essential packages installed!"
}

# Install AMD firmware and drivers
install_amd_support() {
    print_step "Installing AMD firmware and GPU drivers..."
    
    # Install AMD firmware packages
    sudo apt install -y \
        firmware-linux \
        firmware-linux-nonfree \
        firmware-amd-graphics \
        amd64-microcode
    
    # Install Mesa and Vulkan drivers
    sudo apt install -y \
        mesa-utils \
        mesa-vulkan-drivers \
        mesa-va-drivers \
        mesa-vdpau-drivers \
        libvulkan1 \
        vulkan-tools \
        vulkan-validationlayers \
        libva-mesa-driver \
        libvdpau-va-gl1 \
        xserver-xorg-video-amdgpu \
        vainfo \
        vdpauinfo
    
    # Enable 32-bit support for gaming/compatibility
    print_msg "Enabling 32-bit architecture support..."
    sudo dpkg --add-architecture i386
    sudo apt update
    
    sudo apt install -y \
        mesa-vulkan-drivers:i386 \
        libvulkan1:i386 \
        mesa-utils:i386 \
        libgl1-mesa-dri:i386
    
    print_success "AMD drivers and firmware installed!"
}

# Install network tools
install_network_tools() {
    print_step "Installing network tools..."
    
    sudo apt install -y \
        network-manager \
        network-manager-gnome \
        wpasupplicant \
        wireless-tools \
        net-tools \
        iproute2 \
        dnsutils \
        traceroute \
        tcpdump \
        nmap \
        iperf3 \
        ethtool \
        bridge-utils \
        vlan
    
    # Enable NetworkManager
    sudo systemctl enable NetworkManager
    sudo systemctl start NetworkManager
    
    print_success "Network tools installed!"
}

# Install audio support
install_audio_support() {
    print_step "Installing audio support (PipeWire)..."
    
    sudo apt install -y \
        pipewire \
        pipewire-audio \
        pipewire-pulse \
        pipewire-alsa \
        pipewire-jack \
        wireplumber \
        pavucontrol \
        alsa-utils \
        pulseaudio-utils
    
    # Enable PipeWire services
    systemctl --user --now enable pipewire pipewire-pulse wireplumber 2>/dev/null || true
    
    print_success "Audio support installed!"
}

# Install Bluetooth support
install_bluetooth() {
    print_step "Installing Bluetooth support..."
    
    sudo apt install -y \
        bluetooth \
        bluez \
        bluez-tools \
        blueman
    
    sudo systemctl enable bluetooth
    sudo systemctl start bluetooth
    
    print_success "Bluetooth support installed!"
}

# Install compression and archive tools
install_compression_tools() {
    print_step "Installing compression and archive tools..."
    
    sudo apt install -y \
        gzip \
        bzip2 \
        xz-utils \
        lz4 \
        zstd \
        unrar \
        arj \
        cabextract \
        file-roller
    
    print_success "Compression tools installed!"
}

# Install fonts (including Nerd Fonts)
install_fonts() {
    print_step "Installing fonts (including Nerd Fonts)..."
    
    # Install standard fonts
    sudo apt install -y \
        fonts-liberation \
        fonts-liberation2 \
        fonts-dejavu \
        fonts-noto \
        fonts-noto-color-emoji \
        fonts-roboto \
        fonts-ubuntu \
        fonts-font-awesome \
        fonts-powerline \
        fonts-firacode \
        fonts-hack \
        fonts-cascadia-code \
        ttf-mscorefonts-installer
    
    # Install Nerd Fonts
    print_msg "Installing Nerd Fonts..."
    
    # Create fonts directory
    mkdir -p ~/.local/share/fonts
    
    # Download and install popular Nerd Fonts
    NERD_FONTS_VERSION="v3.1.1"
    FONTS_DIR="$HOME/.local/share/fonts/NerdFonts"
    mkdir -p "$FONTS_DIR"
    
    # Array of Nerd Fonts to install
    declare -a NERD_FONTS=(
        "JetBrainsMono"
        "FiraCode"
        "Hack"
        "Meslo"
        "RobotoMono"
        "UbuntuMono"
        "CascadiaCode"
        "SourceCodePro"
    )
    
    print_msg "Downloading Nerd Fonts (this may take a few minutes)..."
    
    for FONT in "${NERD_FONTS[@]}"; do
        print_msg "Installing ${FONT} Nerd Font..."
        
        FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONTS_VERSION}/${FONT}.zip"
        TEMP_ZIP="/tmp/${FONT}.zip"
        
        if wget -q "$FONT_URL" -O "$TEMP_ZIP"; then
            unzip -qo "$TEMP_ZIP" -d "$FONTS_DIR/${FONT}" 2>/dev/null
            rm "$TEMP_ZIP"
            print_msg "✓ ${FONT} installed"
        else
            print_warning "Failed to download ${FONT}, skipping..."
        fi
    done
    
    # Update font cache
    print_msg "Updating font cache..."
    fc-cache -fv
    
    print_success "Fonts installed successfully!"
}

# Install Zsh
install_zsh() {
    print_step "Installing Zsh..."
    
    sudo apt install -y zsh
    
    print_success "Zsh installed!"
}

# Install Oh My Zsh
install_oh_my_zsh() {
    print_step "Installing Oh My Zsh..."
    
    # Check if Oh My Zsh is already installed
    if [ -d "$HOME/.oh-my-zsh" ]; then
        print_warning "Oh My Zsh is already installed. Skipping..."
        return
    fi
    
    # Download and install Oh My Zsh
    print_msg "Downloading Oh My Zsh..."
    
    # Use unattended installation
    export RUNZSH=no
    export CHSH=no
    
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    
    print_success "Oh My Zsh installed!"
}

# Install Zsh plugins
install_zsh_plugins() {
    print_step "Installing Zsh plugins..."
    
    ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
    
    # Install zsh-autosuggestions
    if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
        print_msg "Installing zsh-autosuggestions..."
        git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
    fi
    
    # Install zsh-syntax-highlighting
    if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
        print_msg "Installing zsh-syntax-highlighting..."
        git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
    fi
    
    # Install zsh-completions
    if [ ! -d "$ZSH_CUSTOM/plugins/zsh-completions" ]; then
        print_msg "Installing zsh-completions..."
        git clone https://github.com/zsh-users/zsh-completions "$ZSH_CUSTOM/plugins/zsh-completions"
    fi
    
    # Install fast-syntax-highlighting
    if [ ! -d "$ZSH_CUSTOM/plugins/fast-syntax-highlighting" ]; then
        print_msg "Installing fast-syntax-highlighting..."
        git clone https://github.com/zdharma-continuum/fast-syntax-highlighting "$ZSH_CUSTOM/plugins/fast-syntax-highlighting"
    fi
    
    print_success "Zsh plugins installed!"
}

# Install Starship
install_starship() {
    print_step "Installing Starship prompt..."
    
    # Check if Starship is already installed
    if command -v starship &> /dev/null; then
        print_warning "Starship is already installed. Updating..."
        curl -sS https://starship.rs/install.sh | sh -s -- -y
    else
        print_msg "Downloading and installing Starship..."
        curl -sS https://starship.rs/install.sh | sh -s -- -y
    fi
    
    print_success "Starship installed!"
}

# Configure Starship
configure_starship() {
    print_step "Configuring Starship..."
    
    # Create Starship config directory
    mkdir -p ~/.config
    
    # Create a custom Starship configuration
    cat > ~/.config/starship.toml << 'STARSHIP_CONFIG'
# Starship Configuration
# Get editor completions based on the config schema
"$schema" = 'https://starship.rs/config-schema.json'

format = """
[](color_orange)\
$os\
$username\
[](bg:color_yellow fg:color_orange)\
$directory\
[](fg:color_yellow bg:color_aqua)\
$git_branch\
$git_status\
[](fg:color_aqua bg:color_blue)\
$c\
$cpp\
$rust\
$golang\
$nodejs\
$php\
$java\
$kotlin\
$haskell\
$python\
[](fg:color_blue bg:color_bg3)\
$docker_context\
$conda\
$pixi\
[](fg:color_bg3 bg:color_bg1)\
$time\
[ ](fg:color_bg1)\
$line_break$character"""

palette = 'gruvbox_dark'

[palettes.gruvbox_dark]
color_fg0 = '#fbf1c7'
color_bg1 = '#3c3836'
color_bg3 = '#665c54'
color_blue = '#458588'
color_aqua = '#689d6a'
color_green = '#98971a'
color_orange = '#d65d0e'
color_purple = '#b16286'
color_red = '#cc241d'
color_yellow = '#d79921'

[os]
disabled = false
style = "bg:color_orange fg:color_fg0"

[os.symbols]
Windows = "󰍲"
Ubuntu = "󰕈"
SUSE = ""
Raspbian = "󰐿"
Mint = "󰣭"
Macos = "󰀵"
Manjaro = ""
Linux = "󰌽"
Gentoo = "󰣨"
Fedora = "󰣛"
Alpine = ""
Amazon = ""
Android = ""
AOSC = ""
Arch = "󰣇"
Artix = "󰣇"
EndeavourOS = ""
CentOS = ""
Debian = "󰣚"
Redhat = "󱄛"
RedHatEnterprise = "󱄛"
Pop = ""

[username]
show_always = true
style_user = "bg:color_orange fg:color_fg0"
style_root = "bg:color_orange fg:color_fg0"
format = '[ $user ]($style)'

[directory]
style = "fg:color_fg0 bg:color_yellow"
format = "[ $path ]($style)"
truncation_length = 3
truncation_symbol = "…/"

[directory.substitutions]
"Documents" = "󰈙 "
"Downloads" = " "
"Music" = "󰝚 "
"Pictures" = " "
"Developer" = "󰲋 "

[git_branch]
symbol = ""
style = "bg:color_aqua"
format = '[[ $symbol $branch ](fg:color_fg0 bg:color_aqua)]($style)'

[git_status]
style = "bg:color_aqua"
format = '[[($all_status$ahead_behind )](fg:color_fg0 bg:color_aqua)]($style)'

[nodejs]
symbol = ""
style = "bg:color_blue"
format = '[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)'

[c]
symbol = " "
style = "bg:color_blue"
format = '[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)'

[cpp]
symbol = " "
style = "bg:color_blue"
format = '[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)'

[rust]
symbol = ""
style = "bg:color_blue"
format = '[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)'

[golang]
symbol = ""
style = "bg:color_blue"
format = '[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)'

[php]
symbol = ""
style = "bg:color_blue"
format = '[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)'

[java]
symbol = ""
style = "bg:color_blue"
format = '[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)'

[kotlin]
symbol = ""
style = "bg:color_blue"
format = '[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)'

[haskell]
symbol = ""
style = "bg:color_blue"
format = '[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)'

[python]
symbol = ""
style = "bg:color_blue"
format = '[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)'

[docker_context]
symbol = ""
style = "bg:color_bg3"
format = '[[ $symbol( $context) ](fg:#83a598 bg:color_bg3)]($style)'

[conda]
style = "bg:color_bg3"
format = '[[ $symbol( $environment) ](fg:#83a598 bg:color_bg3)]($style)'

[pixi]
style = "bg:color_bg3"
format = '[[ $symbol( $version)( $environment) ](fg:color_fg0 bg:color_bg3)]($style)'

[time]
disabled = false
time_format = "%R"
style = "bg:color_bg1"
format = '[[  $time ](fg:color_fg0 bg:color_bg1)]($style)'

[line_break]
disabled = false

[character]
disabled = false
success_symbol = '[](bold fg:color_green)'
error_symbol = '[](bold fg:color_red)'
vimcmd_symbol = '[](bold fg:color_green)'
vimcmd_replace_one_symbol = '[](bold fg:color_purple)'
vimcmd_replace_symbol = '[](bold fg:color_purple)'
vimcmd_visual_symbol = '[](bold fg:color_yellow)'
STARSHIP_CONFIG
    
    print_success "Starship configured!"
}

# Configure Zsh with Starship
configure_zsh() {
    print_step "Configuring Zsh with Starship..."
    
    # Backup existing .zshrc if it exists
    if [ -f "$HOME/.zshrc" ]; then
        print_msg "Backing up existing .zshrc..."
        cp "$HOME/.zshrc" "$HOME/.zshrc.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Create new .zshrc with Oh My Zsh and Starship
    cat > "$HOME/.zshrc" << 'ZSHRC'
# Path to oh-my-zsh installation
export ZSH="$HOME/.oh-my-zsh"

# Set theme to blank (Starship will handle the prompt)
ZSH_THEME=""

# Plugins
plugins=(
    git
    sudo
    zsh-autosuggestions
    zsh-syntax-highlighting
    zsh-completions
    fast-syntax-highlighting
    colored-man-pages
    command-not-found
    extract
    history
    copypath
    copyfile
    copybuffer
    dirhistory
    web-search
    jsontools
)

# Load Oh My Zsh
source $ZSH/oh-my-zsh.sh

# User configuration

# Preferred editor
export EDITOR='vim'

# Compilation flags
export ARCHFLAGS="-arch x86_64"

# Starship prompt
eval "$(starship init zsh)"

# Aliases
alias update='sudo apt update && sudo apt upgrade -y'
alias install='sudo apt install'
alias remove='sudo apt remove'
alias search='apt search'
alias clean='sudo apt autoremove -y && sudo apt autoclean'
alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias grep='grep --color=auto'
alias zshconfig='vim ~/.zshrc'
alias ohmyzsh='vim ~/.oh-my-zsh'
alias starshipconfig='vim ~/.config/starship.toml'
alias sysinfo='~/sysinfo.sh'

# Git aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph --decorate'
alias gd='git diff'
alias gco='git checkout'
alias gb='git branch'

# Docker aliases (if Docker is installed)
alias dps='docker ps'
alias dpsa='docker ps -a'
alias di='docker images'
alias dex='docker exec -it'
alias dlog='docker logs -f'
alias dstop='docker stop $(docker ps -q)'
alias drm='docker rm $(docker ps -aq)'

# System monitoring aliases
alias cpu='btop'
alias temp='sensors'
alias ports='sudo netstat -tulanp'
alias myip='curl ifconfig.me'

# Custom functions
mkcd() {
    mkdir -p "$1" && cd "$1"
}

extract() {
    if [ -f $1 ] ; then
        case $1 in
            *.tar.bz2)   tar xjf $1     ;;
            *.tar.gz)    tar xzf $1     ;;
            *.bz2)       bunzip2 $1     ;;
            *.rar)       unrar e $1     ;;
            *.gz)        gunzip $1      ;;
            *.tar)       tar xf $1      ;;
            *.tbz2)      tar xjf $1     ;;
            *.tgz)       tar xzf $1     ;;
            *.zip)       unzip $1       ;;
            *.Z)         uncompress $1  ;;
            *.7z)        7z x $1        ;;
            *)     echo "'$1' cannot be extracted via extract()" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

# Colorful man pages
export MANPAGER="sh -c 'col -bx | bat -l man -p'"

# Better history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS

# Auto-completion enhancements
autoload -U compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# Welcome message
if [[ -o interactive ]]; then
    echo ""
    echo "Welcome to $(hostname)!"
    echo "Kernel: $(uname -r)"
    echo "Starship prompt active 🚀"
    echo ""
fi
ZSHRC
    
    print_success "Zsh configured with Starship!"
}

# Change default shell to Zsh
change_shell_to_zsh() {
    print_step "Changing default shell to Zsh..."
    
    # Check current shell
    if [ "$SHELL" = "$(which zsh)" ]; then
        print_warning "Default shell is already Zsh. Skipping..."
        return
    fi
    
    # Change shell
    print_msg "Changing default shell to Zsh (you may need to enter your password)..."
    chsh -s "$(which zsh)"
    
    print_success "Default shell changed to Zsh!"
    print_warning "You need to log out and log back in for the shell change to take effect."
}

# Install development tools
install_dev_tools() {
    print_step "Installing development tools..."
    
    read -p "Do you want to install development tools (compilers, debuggers, etc.)? (y/n) " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo apt install -y \
            gcc \
            g++ \
            gdb \
            make \
            cmake \
            autoconf \
            automake \
            pkg-config \
            libtool \
            valgrind \
            clang \
            lldb \
            python3 \
            python3-pip \
            python3-venv \
            nodejs \
            npm \
            bat \
            eza \
            ripgrep \
            fd-find
        
        print_success "Development tools installed!"
    else
        print_msg "Skipping development tools installation."
    fi
}

# Install system monitoring tools
install_monitoring_tools() {
    print_step "Installing system monitoring tools..."
    
    sudo apt install -y \
        htop \
        btop \
        iotop \
        nethogs \
        iftop \
        ncdu \
        glances \
        lm-sensors \
        smartmontools \
        sysstat \
        psmisc \
        lsof
    
    # Detect sensors
    print_msg "Detecting hardware sensors..."
    sudo sensors-detect --auto
    
    print_success "Monitoring tools installed!"
}

# Install file system tools
install_filesystem_tools() {
    print_step "Installing file system tools..."
    
    sudo apt install -y \
        e2fsprogs \
        btrfs-progs \
        xfsprogs \
        f2fs-tools \
        dosfstools \
        mtools \
        ntfs-3g \
        exfat-fuse \
        exfatprogs \
        gparted \
        cryptsetup \
        lvm2
    
    print_success "File system tools installed!"
}

# Configure system performance
configure_performance() {
    print_step "Configuring system performance..."
    
    # Enable AMD P-State driver for better power management
    if ! grep -q "amd_pstate=active" /etc/default/grub; then
        print_msg "Enabling AMD P-State driver..."
        sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 amd_pstate=active"/' /etc/default/grub
        sudo update-grub
        print_warning "GRUB updated. Reboot required for changes to take effect."
    fi
    
    # Configure swappiness for better performance
    print_msg "Optimizing swappiness..."
    echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.conf
    sudo sysctl -p
    
    # Configure I/O scheduler for NVMe
    print_msg "Setting up I/O scheduler for NVMe..."
    cat << 'EOF' | sudo tee /etc/udev/rules.d/60-ioschedulers.rules
# Set deadline scheduler for NVMe devices
ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/scheduler}="none"
EOF
    
    print_success "Performance optimizations applied!"
}

# Install power management tools
install_power_management() {
    print_step "Installing power management tools..."
    
    sudo apt install -y \
        tlp \
        tlp-rdw \
        powertop \
        acpi \
        acpid
    
    # Enable TLP
    sudo systemctl enable tlp
    sudo systemctl start tlp
    
    print_success "Power management tools installed!"
}

# Clean up
cleanup() {
    print_step "Cleaning up..."
    
    sudo apt autoremove -y
    sudo apt autoclean
    sudo apt clean
    
    print_success "Cleanup complete!"
}

# Create system info script
create_sysinfo_script() {
    print_step "Creating system information script..."
    
    cat > ~/sysinfo.sh << 'SYSINFO'
#!/bin/bash

echo "========================================="
echo "System Information"
echo "========================================="
echo ""
echo "Hostname: $(hostname)"
echo "Kernel: $(uname -r)"
echo "OS: $(lsb_release -d | cut -f2)"
echo "Shell: $SHELL"
echo ""
echo "CPU: $(lscpu | grep "Model name" | cut -d: -f2 | xargs)"
echo "CPU Cores: $(nproc)"
echo ""
echo "RAM: $(free -h | awk '/^Mem:/ {print $2}')"
echo "Swap: $(free -h | awk '/^Swap:/ {print $2}')"
echo ""
echo "GPU:"
lspci | grep -i vga
echo ""
echo "Disk Usage:"
df -h | grep -E '^/dev/'
echo ""
echo "Network Interfaces:"
ip -brief addr show
echo ""
echo "AMD P-State Status:"
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver 2>/dev/null || echo "Not available"
echo ""
echo "Temperature Sensors:"
sensors 2>/dev/null || echo "Run 'sudo sensors-detect' first"
echo ""
echo "Starship Version:"
starship --version 2>/dev/null || echo "Not installed"
echo ""
echo "Installed Nerd Fonts:"
fc-list | grep -i "nerd" | wc -l
echo "Nerd Fonts installed"
echo "========================================="
SYSINFO
    
    chmod +x ~/sysinfo.sh
    
    print_success "System info script created at ~/sysinfo.sh"
}

# Generate summary report
generate_report() {
    print_step "Generating installation report..."
    
    REPORT_FILE=~/post-install-report.txt
    
    cat > $REPORT_FILE << EOF
========================================
Debian 13 Trixie Post-Installation Report
Generated: $(date)
========================================

System Information:
-------------------
Hostname: $(hostname)
Kernel: $(uname -r)
OS: $(lsb_release -d | cut -f2)
User: $USER
Shell: $SHELL

Installed Components:
---------------------
✓ System updates applied
✓ Essential packages installed
✓ AMD GPU drivers and firmware
✓ Network tools
✓ Audio support (PipeWire)
✓ Bluetooth support
✓ Compression tools
✓ System monitoring tools
✓ File system tools
✓ Standard fonts
✓ Nerd Fonts (JetBrains Mono, FiraCode, Hack, Meslo, etc.)
✓ Zsh shell
✓ Oh My Zsh framework
✓ Starship prompt (Rust-based, fast!)
✓ Zsh plugins (autosuggestions, syntax-highlighting, completions)
✓ Power management (TLP)
✓ Performance optimizations

AMD GPU Information:
--------------------
$(lspci | grep -i vga)

Network Interfaces:
-------------------
$(ip -brief addr show)

Disk Information:
-----------------
$(df -h | grep -E '^/dev/')

Memory Information:
-------------------
$(free -h)

Starship Information:
---------------------
Version: $(starship --version 2>/dev/null || echo "Not installed")
Config: ~/.config/starship.toml

Zsh Configuration:
------------------
Default shell: $SHELL
Oh My Zsh: $([ -d "$HOME/.oh-my-zsh" ] && echo "Installed" || echo "Not installed")
Starship: $(command -v starship &>/dev/null && echo "Installed" || echo "Not installed")

Next Steps:
-----------
1. Log out and log back in for shell changes to take effect

2. Customize Starship prompt (optional):
   Edit: ~/.config/starship.toml
   Presets: https://starship.rs/presets/

3. Reboot the system to apply all changes:
   sudo reboot

4. Run system info script:
   ~/sysinfo.sh

5. Verify AMD GPU drivers:
   vulkaninfo | grep "deviceName"
   vainfo

6. Check audio:
   pavucontrol

7. Test Nerd Font icons in your terminal:
   echo -e "\uf120 \uf0c8 \uf0c7 \uf0c9 \uf0e7"

8. Install Hyprland (if desired):
   ~/hyprland-setup.sh

Useful Commands:
----------------
- Check system temps: sensors
- Monitor system: btop
- Power stats: sudo powertop
- Network manager: nmtui
- System info: ~/sysinfo.sh
- Zsh config: zshconfig
- Starship config: starshipconfig
- Update system: update (alias)
- Show my IP: myip

Zsh Aliases Available:
----------------------
update          - Update system packages
install         - Install packages
ll              - Detailed list
sysinfo         - Show system info
gs/ga/gc        - Git shortcuts
cpu             - Launch btop
temp            - Show temperatures
myip            - Show public IP
starshipconfig  - Edit Starship config

Starship Features:
------------------
✓ Lightning fast (written in Rust)
✓ Minimal dependencies
✓ Cross-platform
✓ Highly customizable
✓ Git status integration
✓ Programming language detection
✓ Custom symbols and icons
✓ Command duration display

Learn More:
-----------
- Starship docs: https://starship.rs
- Presets: https://starship.rs/presets/
- Configuration: https://starship.rs/config/

========================================
EOF
    
    print_success "Report generated at: $REPORT_FILE"
}

# Main installation flow
main() {
    print_banner
    
    check_root
    check_sudo
    
    print_msg "Starting post-installation setup..."
    echo ""
    
    # Keep sudo alive
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
    
    update_system
    install_essentials
    install_amd_support
    install_network_tools
    install_audio_support
    install_bluetooth
    install_compression_tools
    install_fonts
    install_zsh
    install_oh_my_zsh
    install_zsh_plugins
    install_starship
    configure_starship
    configure_zsh
    change_shell_to_zsh
    install_dev_tools
    install_monitoring_tools
    install_filesystem_tools
    configure_performance
    install_power_management
    cleanup
    create_sysinfo_script
    generate_report
    
    echo ""
    print_success "====================================================="
    print_success "  Post-installation setup completed successfully!  "
    print_success "====================================================="
    echo ""
    print_msg "Installation report saved to: ~/post-install-report.txt"
    print_msg "System info script created at: ~/sysinfo.sh"
    echo ""
    print_warning "IMPORTANT NEXT STEPS:"
    print_warning "1. Log out and log back in for Zsh to become your default shell"
    print_warning "2. Starship will be active immediately on first terminal launch"
    print_warning "3. Reboot your system for all changes to take effect"
    echo ""
    print_msg "Starship customization:"
    print_msg "  - Edit config: starshipconfig"
    print_msg "  - Browse presets: https://starship.rs/presets/"
    echo ""
    
    read -p "Do you want to reboot now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_msg "Rebooting in 5 seconds... (Press Ctrl+C to cancel)"
        sleep 5
        sudo reboot
    else
        print_msg "Please remember to:"
        print_msg "  1. Log out and log back in (for Zsh)"
        print_msg "  2. Reboot later: sudo reboot"
    fi
}

# Run main function
main


chmod +x ~/debian-post-install.sh