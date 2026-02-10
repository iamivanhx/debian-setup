#!/bin/bash

##############################################################################
# Hyprland Automated Setup Script for Debian 13 Trixie
# Omarchy-inspired configuration with modern aesthetics
# 
# Features:
# - Beautiful animations and effects
# - Catppuccin Mocha color scheme
# - Optimized for AMD Ryzen 7 8845HS
# - Professional window management
# - Complete ecosystem (waybar, rofi, dunst, etc.)
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
║            Hyprland Setup - Omarchy Style                 ║
║            Beautiful, Fast, Professional                  ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_error "Please do not run this script as root. It will request sudo when needed."
    exit 1
fi

# Check sudo
if ! sudo -v; then
    print_error "This script requires sudo privileges."
    exit 1
fi

print_banner
print_msg "Starting Hyprland setup with Omarchy-inspired configuration..."

# Keep sudo alive
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# Update system
print_step "Updating system..."
sudo apt update && sudo apt upgrade -y

# Install essential packages
print_step "Installing essential packages..."
sudo apt install -y \
    build-essential git wget curl vim htop \
    firmware-linux firmware-amd-graphics amd64-microcode

# Install AMD GPU drivers
print_step "Installing AMD GPU drivers and Vulkan support..."
sudo apt install -y \
    mesa-vulkan-drivers libvulkan1 vulkan-tools xserver-xorg-video-amdgpu

# Enable 32-bit support
print_step "Enabling 32-bit support..."
sudo dpkg --add-architecture i386
sudo apt update
sudo apt install -y mesa-vulkan-drivers:i386 libvulkan1:i386

# Install Hyprland dependencies
print_step "Installing Hyprland dependencies..."
sudo apt install -y \
    meson cmake cmake-extras gettext ninja-build pkg-config \
    wayland-protocols libwayland-dev libxkbcommon-dev libpixman-1-dev \
    libdrm-dev libgbm-dev libudev-dev libseat-dev libinput-dev \
    libxcb-composite0-dev libxcb-dri3-dev libxcb-ewmh-dev \
    libxcb-icccm4-dev libxcb-present-dev libxcb-render-util0-dev \
    libxcb-res0-dev libxcb-xinput-dev libxcb1-dev libx11-xcb-dev \
    libtomlplusplus-dev libzip-dev librsvg2-dev libmagic-dev hwdata \
    glslang-tools libdisplay-info-dev libliftoff-dev libpango1.0-dev \
    libcairo2-dev jq libgles2-mesa-dev libegl1-mesa-dev libgl1-mesa-dri \
    xdg-desktop-portal-wlr xdg-desktop-portal-gtk polkit-kde-agent-1 \
    qt6-wayland

# Install Wayland ecosystem tools
print_step "Installing Wayland ecosystem tools..."
sudo apt install -y \
    grim slurp wl-clipboard cliphist \
    brightnessctl playerctl \
    pipewire wireplumber pipewire-audio pamixer \
    libnotify-bin dunst \
    rofi-wayland waybar \
    swaybg swaylock swayidle swayimg \
    foot thunar \
    network-manager-gnome \
    kitty \
    fonts-jetbrains-mono \
    fonts-font-awesome \
    qt5ct qt6ct \
    python3-pip \
    imagemagick \
    socat \
    jq \
    bc \
    wlogout \
    hyprpicker \
    wf-recorder

# Install additional fonts for Omarchy style
print_step "Installing additional fonts..."
sudo apt install -y \
    fonts-noto \
    fonts-noto-color-emoji \
    fonts-font-awesome \
    fonts-roboto

# Build and install Hyprland
print_step "Building Hyprland from source (this may take several minutes)..."
cd ~
if [ -d "Hyprland" ]; then
    print_warning "Hyprland directory exists, removing..."
    rm -rf Hyprland
fi

git clone --recursive https://github.com/hyprwm/Hyprland
cd Hyprland
make all
sudo make install

# Build and install hyprpaper
print_step "Building hyprpaper..."
cd ~
if [ -d "hyprpaper" ]; then
    rm -rf hyprpaper
fi

git clone https://github.com/hyprwm/hyprpaper
cd hyprpaper
make all
sudo make install

# Install hyprlock
print_step "Building hyprlock..."
cd ~
if [ -d "hyprlock" ]; then
    rm -rf hyprlock
fi

git clone https://github.com/hyprwm/hyprlock
cd hyprlock
cmake -B build
cmake --build build
sudo cmake --install build

# Create directory structure
print_step "Creating configuration directories..."
mkdir -p ~/.config/{hypr,waybar,dunst,rofi,kitty,wlogout}
mkdir -p ~/.config/hypr/{scripts,themes}
mkdir -p ~/.local/share/wallpapers
mkdir -p ~/.local/bin

# Download wallpaper
print_step "Downloading wallpaper..."
wget -O ~/.local/share/wallpapers/wallpaper.jpg \
    "https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=1920" || \
    print_warning "Failed to download wallpaper"

# Create color scheme (Catppuccin Mocha)
print_step "Creating color scheme..."
cat > ~/.config/hypr/themes/mocha.conf << 'EOF'
# Catppuccin Mocha Colors
$rosewater = rgb(f5e0dc)
$flamingo = rgb(f2cdcd)
$pink = rgb(f5c2e7)
$mauve = rgb(cba6f7)
$red = rgb(f38ba8)
$maroon = rgb(eba0ac)
$peach = rgb(fab387)
$yellow = rgb(f9e2af)
$green = rgb(a6e3a1)
$teal = rgb(94e2d5)
$sky = rgb(89dceb)
$sapphire = rgb(74c7ec)
$blue = rgb(89b4fa)
$lavender = rgb(b4befe)

$text = rgb(cdd6f4)
$subtext1 = rgb(bac2de)
$subtext0 = rgb(a6adc8)

$overlay2 = rgb(9399b2)
$overlay1 = rgb(7f849c)
$overlay0 = rgb(6c7086)

$surface2 = rgb(585b70)
$surface1 = rgb(45475a)
$surface0 = rgb(313244)

$base = rgb(1e1e2e)
$mantle = rgb(181825)
$crust = rgb(11111b)
EOF

# Create Hyprland configuration
print_step "Creating Hyprland configuration..."
cat > ~/.config/hypr/hyprland.conf << 'EOF'
# Omarchy-inspired Hyprland Configuration
# https://github.com/omarchy

# Import color scheme
source = ~/.config/hypr/themes/mocha.conf

# Monitor configuration
monitor = ,preferred,auto,1

# Execute at launch
exec-once = waybar
exec-once = dunst
exec-once = hyprpaper
exec-once = /usr/lib/polkit-kde-authentication-agent-1
exec-once = nm-applet --indicator
exec-once = wl-paste --type text --watch cliphist store
exec-once = wl-paste --type image --watch cliphist store
exec-once = pipewire & wireplumber
exec-once = hypridle
exec-once = ~/.config/hypr/scripts/startup.sh

# Environment variables
env = XCURSOR_SIZE,24
env = XCURSOR_THEME,Bibata-Modern-Classic
env = QT_QPA_PLATFORMTHEME,qt6ct
env = QT_QPA_PLATFORM,wayland
env = QT_WAYLAND_DISABLE_WINDOWDECORATION,1
env = GDK_BACKEND,wayland,x11
env = SDL_VIDEODRIVER,wayland
env = CLUTTER_BACKEND,wayland
env = XDG_CURRENT_DESKTOP,Hyprland
env = XDG_SESSION_TYPE,wayland
env = XDG_SESSION_DESKTOP,Hyprland
env = MOZ_ENABLE_WAYLAND,1
env = WLR_NO_HARDWARE_CURSORS,1

# Input configuration
input {
    kb_layout = us
    kb_variant =
    kb_model =
    kb_options =
    kb_rules =

    follow_mouse = 1
    sensitivity = 0
    accel_profile = flat
    
    touchpad {
        natural_scroll = true
        disable_while_typing = true
        tap-to-click = true
        clickfinger_behavior = true
        scroll_factor = 0.5
    }
}

# General settings (Omarchy style)
general {
    gaps_in = 6
    gaps_out = 12
    border_size = 2
    
    # Catppuccin Mocha colors
    col.active_border = $mauve $pink 45deg
    col.inactive_border = $surface0
    
    layout = dwindle
    allow_tearing = false
    resize_on_border = true
}

# Group settings
group {
    col.border_active = $mauve $pink 45deg
    col.border_inactive = $surface0
    
    groupbar {
        font_size = 11
        gradients = true
        col.active = $mauve
        col.inactive = $surface0
    }
}

# Decoration (Omarchy aesthetic)
decoration {
    rounding = 12
    
    blur {
        enabled = true
        size = 6
        passes = 3
        new_optimizations = true
        xray = true
        ignore_opacity = false
        vibrancy = 0.1696
        brightness = 1.0
        contrast = 1.0
        noise = 0.02
    }
    
    drop_shadow = true
    shadow_range = 20
    shadow_render_power = 3
    shadow_ignore_window = true
    col.shadow = rgba(00000055)
    
    dim_inactive = false
    dim_strength = 0.05
}

# Animations (Smooth Omarchy style)
animations {
    enabled = true
    
    bezier = smoothOut, 0.36, 0, 0.66, -0.56
    bezier = smoothIn, 0.25, 1, 0.5, 1
    bezier = overshot, 0.05, 0.9, 0.1, 1.1
    bezier = linear, 0, 0, 1, 1
    
    animation = windows, 1, 5, overshot, slide
    animation = windowsOut, 1, 4, smoothOut, slide
    animation = windowsMove, 1, 4, overshot, slide
    animation = border, 1, 10, default
    animation = borderangle, 1, 100, linear, loop
    animation = fade, 1, 5, smoothIn
    animation = fadeDim, 1, 5, smoothIn
    animation = workspaces, 1, 6, overshot, slidevert
}

# Layouts
dwindle {
    pseudotile = true
    preserve_split = true
    smart_split = false
    smart_resizing = true
    force_split = 2
}

master {
    new_status = master
    new_on_top = false
    mfact = 0.5
}

# Gestures
gestures {
    workspace_swipe = true
    workspace_swipe_fingers = 3
    workspace_swipe_distance = 300
    workspace_swipe_cancel_ratio = 0.15
}

# Misc settings
misc {
    force_default_wallpaper = 0
    disable_hyprland_logo = true
    disable_splash_rendering = true
    mouse_move_enables_dpms = true
    key_press_enables_dpms = true
    vrr = 1
    enable_swallow = true
    swallow_regex = ^(kitty)$
    focus_on_activate = true
    animate_manual_resizes = true
    animate_mouse_windowdragging = true
}

# Window rules (Omarchy style)
windowrulev2 = float, class:^(pavucontrol)$
windowrulev2 = float, class:^(nm-connection-editor)$
windowrulev2 = float, class:^(blueman-manager)$
windowrulev2 = float, title:^(Picture-in-Picture)$
windowrulev2 = pin, title:^(Picture-in-Picture)$
windowrulev2 = opacity 0.95 0.85, class:^(kitty)$
windowrulev2 = opacity 0.95 0.85, class:^(thunar)$
windowrulev2 = opacity 0.95 0.85, class:^(code)$

# Floating windows
windowrulev2 = float, class:^(org.kde.polkit-kde-authentication-agent-1)$
windowrulev2 = float, class:^(zenity)$
windowrulev2 = float, title:^(File Operation Progress)$

# Layer rules
layerrule = blur, waybar
layerrule = blur, rofi
layerrule = blur, notifications
layerrule = ignorezero, notifications

# Keybindings
$mainMod = SUPER

# Application shortcuts
bind = $mainMod, Return, exec, kitty
bind = $mainMod, Q, killactive,
bind = $mainMod SHIFT, Q, exit,
bind = $mainMod, E, exec, thunar
bind = $mainMod, V, togglefloating,
bind = $mainMod, R, exec, pkill rofi || rofi -show drun
bind = $mainMod, P, pseudo,
bind = $mainMod, J, togglesplit,
bind = $mainMod, F, fullscreen, 0
bind = $mainMod SHIFT, F, fullscreen, 1
bind = $mainMod, G, togglegroup
bind = $mainMod, TAB, changegroupactive

# Window management
bind = $mainMod, left, movefocus, l
bind = $mainMod, right, movefocus, r
bind = $mainMod, up, movefocus, u
bind = $mainMod, down, movefocus, d

# Vim-style focus
bind = $mainMod, h, movefocus, l
bind = $mainMod, l, movefocus, r
bind = $mainMod, k, movefocus, u
bind = $mainMod, j, movefocus, d

# Move windows
bind = $mainMod SHIFT, left, movewindow, l
bind = $mainMod SHIFT, right, movewindow, r
bind = $mainMod SHIFT, up, movewindow, u
bind = $mainMod SHIFT, down, movewindow, d

bind = $mainMod SHIFT, h, movewindow, l
bind = $mainMod SHIFT, l, movewindow, r
bind = $mainMod SHIFT, k, movewindow, u
bind = $mainMod SHIFT, j, movewindow, d

# Resize windows
bind = $mainMod CTRL, left, resizeactive, -50 0
bind = $mainMod CTRL, right, resizeactive, 50 0
bind = $mainMod CTRL, up, resizeactive, 0 -50
bind = $mainMod CTRL, down, resizeactive, 0 50

bind = $mainMod CTRL, h, resizeactive, -50 0
bind = $mainMod CTRL, l, resizeactive, 50 0
bind = $mainMod CTRL, k, resizeactive, 0 -50
bind = $mainMod CTRL, j, resizeactive, 0 50

# Switch workspaces
bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3
bind = $mainMod, 4, workspace, 4
bind = $mainMod, 5, workspace, 5
bind = $mainMod, 6, workspace, 6
bind = $mainMod, 7, workspace, 7
bind = $mainMod, 8, workspace, 8
bind = $mainMod, 9, workspace, 9
bind = $mainMod, 0, workspace, 10

# Move window to workspace
bind = $mainMod SHIFT, 1, movetoworkspace, 1
bind = $mainMod SHIFT, 2, movetoworkspace, 2
bind = $mainMod SHIFT, 3, movetoworkspace, 3
bind = $mainMod SHIFT, 4, movetoworkspace, 4
bind = $mainMod SHIFT, 5, movetoworkspace, 5
bind = $mainMod SHIFT, 6, movetoworkspace, 6
bind = $mainMod SHIFT, 7, movetoworkspace, 7
bind = $mainMod SHIFT, 8, movetoworkspace, 8
bind = $mainMod SHIFT, 9, movetoworkspace, 9
bind = $mainMod SHIFT, 0, movetoworkspace, 10

# Special workspaces
bind = $mainMod, S, togglespecialworkspace, magic
bind = $mainMod SHIFT, S, movetoworkspace, special:magic

# Mouse bindings
bindm = $mainMod, mouse:272, movewindow
bindm = $mainMod, mouse:273, resizewindow
bind = $mainMod, mouse_down, workspace, e+1
bind = $mainMod, mouse_up, workspace, e-1

# Screenshots
bind = , Print, exec, grim -g "$(slurp)" - | wl-copy && notify-send "Screenshot" "Area copied to clipboard"
bind = SHIFT, Print, exec, grim - | wl-copy && notify-send "Screenshot" "Screen copied to clipboard"
bind = $mainMod, Print, exec, grim -g "$(slurp)" ~/Pictures/Screenshots/$(date +'%Y-%m-%d_%H-%M-%S').png && notify-send "Screenshot" "Saved to Pictures/Screenshots"

# Screen recording
bind = $mainMod, F9, exec, ~/.config/hypr/scripts/record.sh

# Clipboard
bind = $mainMod, C, exec, cliphist list | rofi -dmenu | cliphist decode | wl-copy

# Color picker
bind = $mainMod SHIFT, C, exec, hyprpicker -a

# Media keys
bindl = , XF86AudioPlay, exec, playerctl play-pause
bindl = , XF86AudioNext, exec, playerctl next
bindl = , XF86AudioPrev, exec, playerctl previous
bindl = , XF86AudioStop, exec, playerctl stop
bindl = , XF86AudioMute, exec, pamixer -t && notify-send "Audio" "Muted: $(pamixer --get-mute)"
bindl = , XF86AudioLowerVolume, exec, pamixer -d 5 && notify-send "Volume" "$(pamixer --get-volume)%"
bindl = , XF86AudioRaiseVolume, exec, pamixer -i 5 && notify-send "Volume" "$(pamixer --get-volume)%"

# Brightness
bindl = , XF86MonBrightnessUp, exec, brightnessctl set +5% && notify-send "Brightness" "$(brightnessctl g)"
bindl = , XF86MonBrightnessDown, exec, brightnessctl set 5%- && notify-send "Brightness" "$(brightnessctl g)"

# Lock screen
bind = $mainMod, L, exec, hyprlock

# Logout menu
bind = $mainMod SHIFT, E, exec, wlogout -b 2

# Reload waybar
bind = $mainMod SHIFT, R, exec, killall waybar && waybar &
EOF

# Create hyprpaper configuration
print_step "Creating hyprpaper configuration..."
cat > ~/.config/hypr/hyprpaper.conf << 'EOF'
preload = ~/.local/share/wallpapers/wallpaper.jpg
wallpaper = ,~/.local/share/wallpapers/wallpaper.jpg

splash = false
ipc = on
EOF

# Create hyprlock configuration
print_step "Creating hyprlock configuration..."
cat > ~/.config/hypr/hyprlock.conf << 'EOF'
# Catppuccin Mocha
$rosewater = rgb(f5e0dc)
$flamingo = rgb(f2cdcd)
$pink = rgb(f5c2e7)
$mauve = rgb(cba6f7)
$red = rgb(f38ba8)
$maroon = rgb(eba0ac)
$peach = rgb(fab387)
$yellow = rgb(f9e2af)
$green = rgb(a6e3a1)
$teal = rgb(94e2d5)
$sky = rgb(89dceb)
$sapphire = rgb(74c7ec)
$blue = rgb(89b4fa)
$lavender = rgb(b4befe)
$text = rgb(cdd6f4)
$subtext1 = rgb(bac2de)
$subtext0 = rgb(a6adc8)
$overlay2 = rgb(9399b2)
$overlay1 = rgb(7f849c)
$overlay0 = rgb(6c7086)
$surface2 = rgb(585b70)
$surface1 = rgb(45475a)
$surface0 = rgb(313244)
$base = rgb(1e1e2e)
$mantle = rgb(181825)
$crust = rgb(11111b)

background {
    monitor =
    path = ~/.local/share/wallpapers/wallpaper.jpg
    blur_passes = 3
    blur_size = 8
    brightness = 0.5
}

input-field {
    monitor =
    size = 300, 50
    outline_thickness = 2
    dots_size = 0.2
    dots_spacing = 0.2
    dots_center = true
    outer_color = $mauve
    inner_color = $base
    font_color = $text
    fade_on_empty = false
    placeholder_text = <span foreground="##$textAlpha">Password...</span>
    hide_input = false
    position = 0, -120
    halign = center
    valign = center
}

label {
    monitor =
    text = cmd[update:1000] echo "$(date +'%A, %B %d')"
    color = $text
    font_size = 22
    font_family = JetBrains Mono
    position = 0, 300
    halign = center
    valign = center
}

label {
    monitor =
    text = cmd[update:1000] echo "$(date +'%H:%M')"
    color = $text
    font_size = 95
    font_family = JetBrains Mono Extrabold
    position = 0, 200
    halign = center
    valign = center
}

label {
    monitor =
    text = Hi, $USER
    color = $text
    font_size = 18
    font_family = JetBrains Mono
    position = 0, 50
    halign = center
    valign = center
}
EOF

# Create hypridle configuration
print_step "Creating hypridle configuration..."
cat > ~/.config/hypr/hypridle.conf << 'EOF'
general {
    lock_cmd = pidof hyprlock || hyprlock
    before_sleep_cmd = loginctl lock-session
    after_sleep_cmd = hyprctl dispatch dpms on
}

listener {
    timeout = 300
    on-timeout = brightnessctl -s set 10
    on-resume = brightnessctl -r
}

listener {
    timeout = 600
    on-timeout = loginctl lock-session
}

listener {
    timeout = 900
    on-timeout = hyprctl dispatch dpms off
    on-resume = hyprctl dispatch dpms on
}

listener {
    timeout = 1800
    on-timeout = systemctl suspend
}
EOF

# Install hypridle
print_step "Building hypridle..."
cd ~
if [ -d "hypridle" ]; then
    rm -rf hypridle
fi

git clone https://github.com/hyprwm/hypridle
cd hypridle
cmake -B build
cmake --build build
sudo cmake --install build

# Create Waybar configuration (Omarchy style)
print_step "Creating Waybar configuration..."
cat > ~/.config/waybar/config << 'EOF'
{
    "layer": "top",
    "position": "top",
    "height": 40,
    "spacing": 4,
    "margin-top": 8,
    "margin-left": 12,
    "margin-right": 12,
    
    "modules-left": ["hyprland/workspaces", "hyprland/window"],
    "modules-center": ["clock"],
    "modules-right": ["pulseaudio", "network", "cpu", "memory", "temperature", "backlight", "battery", "tray"],
    
    "hyprland/workspaces": {
        "format": "{icon}",
        "on-click": "activate",
        "format-icons": {
            "1": "一",
            "2": "二",
            "3": "三",
            "4": "四",
            "5": "五",
            "6": "六",
            "7": "七",
            "8": "八",
            "9": "九",
            "10": "十",
            "urgent": "",
            "active": "",
            "default": ""
        },
        "persistent-workspaces": {
            "*": 5
        }
    },
    
    "hyprland/window": {
        "max-length": 50,
        "separate-outputs": true
    },
    
    "clock": {
        "format": "{:%H:%M  %a %d %b}",
        "tooltip-format": "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>",
        "format-alt": "{:%Y-%m-%d}"
    },
    
    "cpu": {
        "format": "  {usage}%",
        "tooltip": true,
        "interval": 2
    },
    
    "memory": {
        "format": "  {}%",
        "tooltip-format": "RAM: {used:0.1f}G / {total:0.1f}G"
    },
    
    "temperature": {
        "critical-threshold": 80,
        "format": "{icon} {temperatureC}°C",
        "format-icons": ["", "", "", "", ""]
    },
    
    "backlight": {
        "format": "{icon} {percent}%",
        "format-icons": ["", "", "", "", "", "", "", "", ""],
        "on-scroll-up": "brightnessctl set +5%",
        "on-scroll-down": "brightnessctl set 5%-"
    },
    
    "battery": {
        "states": {
            "warning": 30,
            "critical": 15
        },
        "format": "{icon} {capacity}%",
        "format-charging": " {capacity}%",
        "format-plugged": " {capacity}%",
        "format-icons": ["", "", "", "", ""]
    },
    
    "network": {
        "format-wifi": "  {essid}",
        "format-ethernet": "  {ipaddr}",
        "tooltip-format": "{ifname} via {gwaddr}",
        "format-linked": "  {ifname} (No IP)",
        "format-disconnected": "  Disconnected",
        "format-alt": "{ifname}: {ipaddr}/{cidr}"
    },
    
    "pulseaudio": {
        "format": "{icon} {volume}%",
        "format-bluetooth": "{icon}  {volume}%",
        "format-bluetooth-muted": "  {icon}",
        "format-muted": "  Muted",
        "format-icons": {
            "headphone": "",
            "hands-free": "",
            "headset": "",
            "phone": "",
            "portable": "",
            "car": "",
            "default": ["", "", ""]
        },
        "on-click": "pavucontrol"
    },
    
    "tray": {
        "icon-size": 18,
        "spacing": 10
    }
}
EOF

cat > ~/.config/waybar/style.css << 'EOF'
* {
    border: none;
    border-radius: 0;
    font-family: "JetBrainsMono Nerd Font", "Font Awesome 6 Free";
    font-size: 13px;
    min-height: 0;
}

window#waybar {
    background-color: rgba(30, 30, 46, 0.9);
    color: #cdd6f4;
    transition-property: background-color;
    transition-duration: 0.5s;
    border-radius: 12px;
}

#workspaces {
    margin: 0 5px;
}

#workspaces button {
    padding: 0 8px;
    background-color: transparent;
    color: #585b70;
    border-radius: 8px;
    transition: all 0.3s ease;
}

#workspaces button:hover {
    background-color: rgba(203, 166, 247, 0.2);
    color: #cba6f7;
}

#workspaces button.active {
    background-color: #cba6f7;
    color: #1e1e2e;
}

#workspaces button.urgent {
    background-color: #f38ba8;
    color: #1e1e2e;
}

#window {
    margin: 0 10px;
    padding: 0 10px;
    color: #89b4fa;
    font-weight: bold;
}

#clock {
    padding: 0 15px;
    color: #f5c2e7;
    font-weight: bold;
    border-radius: 8px;
    background-color: rgba(203, 166, 247, 0.1);
}

#battery,
#cpu,
#memory,
#temperature,
#backlight,
#network,
#pulseaudio,
#tray {
    padding: 0 12px;
    margin: 0 3px;
    border-radius: 8px;
    background-color: rgba(49, 50, 68, 0.6);
    color: #cdd6f4;
}

#battery.charging, #battery.plugged {
    color: #a6e3a1;
    background-color: rgba(166, 227, 161, 0.15);
}

#battery.warning:not(.charging) {
    background-color: rgba(249, 226, 175, 0.15);
    color: #f9e2af;
}

#battery.critical:not(.charging) {
    background-color: rgba(243, 139, 168, 0.15);
    color: #f38ba8;
    animation: blink 0.5s linear infinite alternate;
}

@keyframes blink {
    to {
        background-color: rgba(243, 139, 168, 0.3);
    }
}

#cpu {
    color: #89dceb;
    background-color: rgba(137, 220, 235, 0.15);
}

#memory {
    color: #a6e3a1;
    background-color: rgba(166, 227, 161, 0.15);
}

#temperature {
    color: #fab387;
    background-color: rgba(250, 179, 135, 0.15);
}

#backlight {
    color: #f9e2af;
    background-color: rgba(249, 226, 175, 0.15);
}

#network {
    color: #94e2d5;
    background-color: rgba(148, 226, 213, 0.15);
}

#pulseaudio {
    color: #89b4fa;
    background-color: rgba(137, 180, 250, 0.15);
}

#pulseaudio.muted {
    color: #6c7086;
    background-color: rgba(108, 112, 134, 0.15);
}

#tray {
    background-color: rgba(49, 50, 68, 0.6);
}

tooltip {
    background: rgba(30, 30, 46, 0.95);
    border: 2px solid #cba6f7;
    border-radius: 8px;
}

tooltip label {
    color: #cdd6f4;
}
EOF

# Create Kitty configuration (Catppuccin Mocha)
print_step "Creating Kitty configuration..."
cat > ~/.config/kitty/kitty.conf << 'EOF'
# Font configuration
font_family      JetBrainsMono Nerd Font
bold_font        auto
italic_font      auto
bold_italic_font auto
font_size 11.0

# Cursor
cursor_shape beam
cursor_beam_thickness 1.5
cursor_blink_interval 0.5

# Window
background_opacity 0.95
window_padding_width 8
confirm_os_window_close 0
enabled_layouts tall:bias=50;full_size=1;mirrored=false

# Catppuccin Mocha Theme
foreground              #CDD6F4
background              #1E1E2E
selection_foreground    #1E1E2E
selection_background    #F5E0DC

cursor                  #F5E0DC
cursor_text_color       #1E1E2E

url_color               #F5E0DC

active_border_color     #B4BEFE
inactive_border_color   #6C7086
bell_border_color       #F9E2AF

wayland_titlebar_color system

active_tab_foreground   #11111B
active_tab_background   #CBA6F7
inactive_tab_foreground #CDD6F4
inactive_tab_background #181825
tab_bar_background      #11111B

mark1_foreground #1E1E2E
mark1_background #B4BEFE
mark2_foreground #1E1E2E
mark2_background #CBA6F7
mark3_foreground #1E1E2E
mark3_background #74C7EC

# black
color0 #45475A
color8 #585B70

# red
color1 #F38BA8
color9 #F38BA8

# green
color2  #A6E3A1
color10 #A6E3A1

# yellow
color3  #F9E2AF
color11 #F9E2AF

# blue
color4  #89B4FA
color12 #89B4FA

# magenta
color5  #F5C2E7
color13 #F5C2E7

# cyan
color6  #94E2D5
color14 #94E2D5

# white
color7  #BAC2DE
color15 #A6ADC8
EOF

# Create Dunst configuration (Catppuccin Mocha)
print_step "Creating Dunst configuration..."
cat > ~/.config/dunst/dunstrc << 'EOF'
[global]
    monitor = 0
    follow = mouse
    width = 350
    height = 300
    origin = top-right
    offset = 15x50
    scale = 0
    notification_limit = 0
    progress_bar = true
    progress_bar_height = 10
    progress_bar_frame_width = 1
    progress_bar_min_width = 150
    progress_bar_max_width = 300
    indicate_hidden = yes
    transparency = 10
    separator_height = 2
    padding = 12
    horizontal_padding = 12
    text_icon_padding = 0
    frame_width = 2
    frame_color = "#cba6f7"
    separator_color = frame
    sort = yes
    idle_threshold = 120
    font = JetBrainsMono Nerd Font 11
    line_height = 0
    markup = full
    format = "<b>%s</b>\n%b"
    alignment = left
    vertical_alignment = center
    show_age_threshold = 60
    ellipsize = middle
    ignore_newline = no
    stack_duplicates = true
    hide_duplicate_count = false
    show_indicators = yes
    icon_position = left
    min_icon_size = 32
    max_icon_size = 48
    sticky_history = yes
    history_length = 20
    browser = /usr/bin/xdg-open
    always_run_script = true
    title = Dunst
    class = Dunst
    corner_radius = 12
    ignore_dbusclose = false
    force_xwayland = false
    force_xinerama = false
    mouse_left_click = close_current
    mouse_middle_click = do_action, close_current
    mouse_right_click = close_all

[experimental]
    per_monitor_dpi = false

[urgency_low]
    background = "#1e1e2e"
    foreground = "#cdd6f4"
    timeout = 5

[urgency_normal]
    background = "#1e1e2e"
    foreground = "#cdd6f4"
    timeout = 10

[urgency_critical]
    background = "#1e1e2e"
    foreground = "#f38ba8"
    frame_color = "#f38ba8"
    timeout = 0
EOF

# Create Rofi configuration (Catppuccin Mocha)
print_step "Creating Rofi configuration..."
mkdir -p ~/.config/rofi

cat > ~/.config/rofi/config.rasi << 'EOF'
configuration {
    modi: "drun,run,window";
    show-icons: true;
    terminal: "kitty";
    drun-display-format: "{icon} {name}";
    location: 0;
    disable-history: false;
    hide-scrollbar: true;
    display-drun: "   Apps ";
    display-run: "   Run ";
    display-window: " 﩯  Window";
    display-Network: " 󰤨  Network";
    sidebar-mode: true;
}

@theme "catppuccin-mocha"
EOF

cat > ~/.config/rofi/catppuccin-mocha.rasi << 'EOF'
* {
    bg-col:  #1e1e2e;
    bg-col-light: #1e1e2e;
    border-col: #cba6f7;
    selected-col: #313244;
    blue: #89b4fa;
    fg-col: #cdd6f4;
    fg-col2: #f38ba8;
    grey: #6c7086;
    width: 600;
    font: "JetBrainsMono Nerd Font 12";
}

element-text, element-icon , mode-switcher {
    background-color: inherit;
    text-color: inherit;
}

window {
    height: 460px;
    border: 2px;
    border-color: @border-col;
    background-color: @bg-col;
    border-radius: 12px;
}

mainbox {
    background-color: @bg-col;
}

inputbar {
    children: [prompt,entry];
    background-color: @bg-col;
    border-radius: 8px;
    padding: 8px;
    margin: 12px;
}

prompt {
    background-color: @blue;
    padding: 8px;
    text-color: @bg-col;
    border-radius: 8px;
    margin: 0px 8px 0px 0px;
}

textbox-prompt-colon {
    expand: false;
    str: ":";
}

entry {
    padding: 8px;
    background-color: @bg-col;
    text-color: @fg-col;
}

listview {
    border: 0px 0px 0px;
    padding: 6px 12px 6px;
    margin: 0px 0px 12px;
    columns: 1;
    lines: 8;
    background-color: @bg-col;
}

element {
    padding: 8px;
    background-color: @bg-col;
    text-color: @fg-col;
    border-radius: 8px;
}

element-icon {
    size: 25px;
}

element selected {
    background-color: @selected-col;
    text-color: @fg-col2;
}

mode-switcher {
    spacing: 0;
}

button {
    padding: 10px;
    background-color: @bg-col-light;
    text-color: @grey;
    vertical-align: 0.5; 
    horizontal-align: 0.5;
}

button selected {
    background-color: @bg-col;
    text-color: @blue;
}

message {
    background-color: @bg-col-light;
    margin: 2px;
    padding: 2px;
    border-radius: 5px;
}

textbox {
    padding: 6px;
    margin: 20px 0px 0px 20px;
    text-color: @blue;
    background-color: @bg-col-light;
}
EOF

# Create wlogout configuration
print_step "Creating wlogout configuration..."
cat > ~/.config/wlogout/layout << 'EOF'
{
    "label" : "lock",
    "action" : "hyprlock",
    "text" : "Lock",
    "keybind" : "l"
}
{
    "label" : "logout",
    "action" : "hyprctl dispatch exit",
    "text" : "Logout",
    "keybind" : "e"
}
{
    "label" : "shutdown",
    "action" : "systemctl poweroff",
    "text" : "Shutdown",
    "keybind" : "s"
}
{
    "label" : "reboot",
    "action" : "systemctl reboot",
    "text" : "Reboot",
    "keybind" : "r"
}
EOF

cat > ~/.config/wlogout/style.css << 'EOF'
* {
    background-image: none;
    font-family: "JetBrainsMono Nerd Font";
}

window {
    background-color: rgba(30, 30, 46, 0.9);
}

button {
    background-color: #313244;
    color: #cdd6f4;
    border: 2px solid #cba6f7;
    border-radius: 12px;
    background-repeat: no-repeat;
    background-position: center;
    background-size: 25%;
    margin: 20px;
    transition: all 0.3s ease;
}

button:focus, button:active, button:hover {
    background-color: #cba6f7;
    color: #1e1e2e;
    outline-style: none;
}

#lock {
    background-image: image(url("/usr/share/wlogout/icons/lock.png"));
}

#logout {
    background-image: image(url("/usr/share/wlogout/icons/logout.png"));
}

#shutdown {
    background-image: image(url("/usr/share/wlogout/icons/shutdown.png"));
}

#reboot {
    background-image: image(url("/usr/share/wlogout/icons/reboot.png"));
}
EOF

# Create helper scripts
print_step "Creating helper scripts..."

mkdir -p ~/Pictures/Screenshots

cat > ~/.config/hypr/scripts/startup.sh << 'EOF'
#!/bin/bash

# Wait for desktop to be ready
sleep 2

# Set GTK theme (if you install one later)
# gsettings set org.gnome.desktop.interface gtk-theme "Catppuccin-Mocha-Standard-Mauve-Dark"
# gsettings set org.gnome.desktop.interface icon-theme "Papirus-Dark"

# Set cursor theme
# gsettings set org.gnome.desktop.interface cursor-theme "Bibata-Modern-Classic"

echo "Startup complete"
EOF

chmod +x ~/.config/hypr/scripts/startup.sh

cat > ~/.config/hypr/scripts/record.sh << 'EOF'
#!/bin/bash

if pgrep -x "wf-recorder" > /dev/null; then
    killall -INT wf-recorder
    notify-send "Recording" "Recording stopped"
else
    wf-recorder -f ~/Videos/recording_$(date +%Y-%m-%d_%H-%M-%S).mp4 &
    notify-send "Recording" "Recording started"
fi
EOF

chmod +x ~/.config/hypr/scripts/record.sh

# Enable pipewire service
print_step "Enabling pipewire services..."
systemctl --user enable --now pipewire pipewire-pulse wireplumber 2>/dev/null || true

# Create .xinitrc for starting Hyprland
print_step "Creating session startup files..."
echo "exec Hyprland" > ~/.xinitrc

print_msg ""
print_success "============================================="
print_success "  Hyprland setup complete (Omarchy style)!  "
print_success "============================================="
print_msg ""
print_msg "Features installed:"
print_msg "  ✓ Hyprland with Omarchy-inspired config"
print_msg "  ✓ Catppuccin Mocha color scheme"
print_msg "  ✓ Waybar with beautiful styling"
print_msg "  ✓ Rofi application launcher"
print_msg "  ✓ Dunst notifications"
print_msg "  ✓ Hyprlock screen locker"
print_msg "  ✓ Hypridle idle management"
print_msg "  ✓ Wlogout logout menu"
print_msg "  ✓ All necessary utilities"
print_msg ""
print_msg "Key bindings:"
print_msg "  SUPER + Return        - Terminal (Kitty)"
print_msg "  SUPER + R             - App launcher (Rofi)"
print_msg "  SUPER + E             - File manager (Thunar)"
print_msg "  SUPER + Q             - Close window"
print_msg "  SUPER + L             - Lock screen"
print_msg "  SUPER + SHIFT + E     - Logout menu"
print_msg "  SUPER + F             - Fullscreen"
print_msg "  SUPER + V             - Toggle floating"
print_msg "  SUPER + G             - Toggle group"
print_msg "  SUPER + 1-10          - Switch workspace"
print_msg "  SUPER + SHIFT + 1-10  - Move to workspace"
print_msg "  SUPER + C             - Clipboard history"
print_msg "  SUPER + SHIFT + C     - Color picker"
print_msg "  SUPER + F9            - Screen recording"
print_msg "  Print                 - Screenshot area"
print_msg "  SHIFT + Print         - Screenshot screen"
print_msg ""
print_msg "To start Hyprland:"
print_msg "  Hyprland"
print_msg ""
print_warning "Reboot recommended for best experience"