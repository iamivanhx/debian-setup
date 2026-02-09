#! bin/bash
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
# - Basic utilities and tools
##############################################################################
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
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
║   Debian 13 Trixie Post-Installation Setup                ║
║   Optimized for Beelink SER8 (AMD Ryzen 7 8845HS)         ║
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
    print_step "Checking sudo priviliges..."

    # Check if sudo is installed
    if ! command -v sudo &> /dev/null; then
        print_error "sudo is not installed on this system."
        print_error ""
        print_error "Please run the following commands as root:"
        print_error " su -"
        print_error " apt update"
        print_error " apt install -y sudo"
        print_error " usermod -aG sudo $USER"
        print_error " exit"
        print_error ""
        print_error "Then log out, log back in, and run this script again."
        exit 1
    fi 

    # Check if user is in sudo group
    if ! groups | grep -q '\bsudo\b'; then
        print_error "User '$USER' is not in the sudo group"
        print_error ""
        print_error "Please run the following commands as root:"
        print_error " su -"
        print_error " apt update"
        print_error " apt install -y sudo"
        print_error " usermod -aG sudo $USER"
        print_error " exit"
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
        htop \
        btop \
        neofetch \
        tmux \
        tree \
        zip \
        unzip \
        p7zip-full \
        software-properties-common \
        apt-transport-https \
        ca-certificates \
        gnupg \
        lsb-release \
        dkms \
        linux-headers-$(uname -r)

    print_success "Essential packages installed!"
}

# Install AMD firmware and drivers
install_amd_support() {
    print_step "Installing AMD and GPU drivers..."

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

    # Enable 32-but support for gaming/compatibility
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
    
    # Enable network manager
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
        rar \
        unrar \
        arj \
        cabextract \
        file-roller
    
    print_success "Compression tools installed!"
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
            npm
        
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

# Install fonts
install_fonts() {
    print_step "Installing fonts..."
    
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
        fonts-jetbrains-mono \
        ttf-mscorefonts-installer
    
    # Update font cache
    fc-cache -fv
    
    print_success "Fonts installed!"
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
✓ Fonts
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

Next Steps:
-----------
1. Reboot the system to apply all changes:
   sudo reboot

2. Run system info script:
   ~/sysinfo.sh

3. Verify AMD GPU drivers:
   vulkaninfo | grep "deviceName"
   vainfo

4. Check audio:
   pavucontrol

5. Install Hyprland (if desired):
   ~/hyprland-setup.sh

Useful Commands:
----------------
- Check system temps: sensors
- Monitor system: btop
- Power stats: sudo powertop
- Network manager: nmtui
- System info: ~/sysinfo.sh

========================================
EOF
    
    print_success "Report generated at: $REPORT_FILE"
}

# Main installation flow
main() {
    print_banner

    check_root
    check_sudo

    print_msg "Starting Post-Installation Setup..."
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
    install_dev_tools
    install_monitoring_tools
    install_filesystem_tools
    install_fonts
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
    print_warning "IMPORTANT: Please reboot your system for all changes to take effect."
    echo ""

    read -p "Do you want to reboot now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_msg "Rebooting in 5 seconds... (Press Ctrl+C to cancel)"
        sleep 5
        sudo reboot
    else
        print_msg "Please remember to reboot later: sudo reboot"
    fi
}

# Run main function
main

chmod +x ~/debian-post-install.sh


