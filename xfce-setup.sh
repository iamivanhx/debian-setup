#!/bin/bash

##############################################################################
# XFCE Desktop Setup Script for Debian 13 Trixie
# Modern, Beautiful, Lightweight XFCE Configuration
# 
# Features:
# - Catppuccin Mocha theme
# - Modern icon pack (Papirus)
# - Beautiful cursor theme
# - Optimized panel layout
# - Plank dock
# - Picom compositor for effects
# - Modern GTK applications
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
║        Modern XFCE Desktop Setup for Debian 13            ║
║        Beautiful • Fast • Customizable                    ║
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
print_msg "Starting modern XFCE desktop setup..."

# Keep sudo alive
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# Update system
print_step "Updating system..."
sudo apt update && sudo apt upgrade -y

# Install XFCE desktop and components
print_step "Installing XFCE desktop environment..."
sudo apt install -y \
    xfce4 \
    xfce4-goodies \
    xfce4-terminal \
    xfce4-screenshooter \
    xfce4-taskmanager \
    xfce4-power-manager \
    xfce4-pulseaudio-plugin \
    xfce4-whiskermenu-plugin \
    xfce4-weather-plugin \
    xfce4-clipman-plugin \
    xfce4-cpugraph-plugin \
    xfce4-systemload-plugin \
    xfce4-netload-plugin \
    xfce4-sensors-plugin \
    xfce4-notifyd \
    thunar \
    thunar-archive-plugin \
    thunar-media-tags-plugin \
    thunar-volman \
    tumbler \
    ristretto \
    parole \
    mousepad

# Install display manager
print_step "Installing LightDM display manager..."
sudo apt install -y \
    lightdm \
    lightdm-gtk-greeter \
    lightdm-gtk-greeter-settings

# Install compositor and effects
print_step "Installing Picom compositor for visual effects..."
sudo apt install -y \
    picom \
    xfce4-compositor

# Install essential applications
print_step "Installing essential applications..."
sudo apt install -y \
    firefox-esr \
    gnome-software \
    gnome-disk-utility \
    file-roller \
    gvfs \
    gvfs-backends \
    gvfs-fuse \
    udisks2 \
    network-manager-gnome \
    pulseaudio \
    pavucontrol \
    blueman \
    redshift-gtk \
    gparted \
    plank \
    rofi \
    feh \
    numlockx \
    xdotool \
    wmctrl \
    nitrogen

# Install theme dependencies
print_step "Installing theme and customization tools..."
sudo apt install -y \
    gtk2-engines-murrine \
    gtk2-engines-pixbuf \
    gnome-themes-extra \
    gnome-icon-theme \
    git \
    wget \
    curl \
    unzip \
    python3-pip \
    imagemagick

# Create directories
print_step "Creating theme directories..."
mkdir -p ~/.themes
mkdir -p ~/.icons
mkdir -p ~/.local/share/fonts
mkdir -p ~/.config/{picom,rofi,plank}
mkdir -p ~/Pictures/Wallpapers

# Install Papirus icon theme
print_step "Installing Papirus icon theme..."
sudo apt install -y papirus-icon-theme

# Install Catppuccin GTK theme
print_step "Installing Catppuccin GTK theme..."
cd /tmp
if [ -d "catppuccin-gtk" ]; then
    rm -rf catppuccin-gtk
fi

git clone https://github.com/catppuccin/gtk.git catppuccin-gtk
cd catppuccin-gtk

# Install all variants (Mocha, Macchiato, Frappe, Latte)
python3 install.py mocha -a mauve --zip
unzip -o dist/Catppuccin-Mocha-Standard-Mauve-Dark.zip -d ~/.themes/

python3 install.py mocha -a pink --zip
unzip -o dist/Catppuccin-Mocha-Standard-Pink-Dark.zip -d ~/.themes/

print_success "Catppuccin theme installed!"

# Install Bibata cursor theme
print_step "Installing Bibata cursor theme..."
cd /tmp
BIBATA_VERSION="v2.0.6"
wget -q "https://github.com/ful1e5/Bibata_Cursor/releases/download/${BIBATA_VERSION}/Bibata-Modern-Classic.tar.xz"
tar -xf Bibata-Modern-Classic.tar.xz
mv Bibata-Modern-Classic ~/.icons/

wget -q "https://github.com/ful1e5/Bibata_Cursor/releases/download/${BIBATA_VERSION}/Bibata-Modern-Ice.tar.xz"
tar -xf Bibata-Modern-Ice.tar.xz
mv Bibata-Modern-Ice ~/.icons/

print_success "Bibata cursor theme installed!"

# Download modern wallpaper
print_step "Downloading wallpapers..."
cd ~/Pictures/Wallpapers

# Download a collection of beautiful wallpapers
wget -q -O wallpaper1.jpg "https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=1920" || true
wget -q -O wallpaper2.jpg "https://images.unsplash.com/photo-1557683316-973673baf926?w=1920" || true
wget -q -O wallpaper3.jpg "https://images.unsplash.com/photo-1553095066-5014bc7b7f2d?w=1920" || true

# Set a default if downloads failed
if [ ! -f wallpaper1.jpg ]; then
    convert -size 1920x1080 gradient:#1e1e2e-#313244 wallpaper1.jpg
fi

print_success "Wallpapers downloaded!"

# Configure Picom
print_step "Configuring Picom compositor..."
cat > ~/.config/picom/picom.conf << 'EOF'
# Picom configuration for modern XFCE

# Backend
backend = "glx";
glx-no-stencil = true;
glx-no-rebind-pixmap = true;
use-damage = true;

# Shadows
shadow = true;
shadow-radius = 12;
shadow-opacity = 0.75;
shadow-offset-x = -12;
shadow-offset-y = -12;

shadow-exclude = [
    "name = 'Notification'",
    "class_g = 'Conky'",
    "class_g ?= 'Notify-osd'",
    "class_g = 'Cairo-clock'",
    "_GTK_FRAME_EXTENTS@:c",
    "class_g = 'firefox' && argb"
];

# Opacity
inactive-opacity = 0.95;
active-opacity = 1.0;
frame-opacity = 1.0;
inactive-opacity-override = false;

opacity-rule = [
    "100:class_g = 'firefox'",
    "100:class_g = 'Gimp'",
    "95:class_g = 'Thunar'",
    "95:class_g = 'Mousepad'",
    "95:class_g = 'Xfce4-terminal'"
];

# Fading
fading = true;
fade-in-step = 0.03;
fade-out-step = 0.03;
fade-delta = 5;

# Blur
blur-method = "dual_kawase";
blur-strength = 5;
blur-background = true;
blur-background-frame = true;
blur-background-fixed = true;

blur-background-exclude = [
    "window_type = 'dock'",
    "window_type = 'desktop'",
    "_GTK_FRAME_EXTENTS@:c"
];

# Rounded corners
corner-radius = 12;
rounded-corners-exclude = [
    "window_type = 'dock'",
    "window_type = 'desktop'",
    "class_g = 'Polybar'",
    "class_g = 'Plank'"
];

# General settings
vsync = true;
mark-wmwin-focused = true;
mark-ovredir-focused = true;
detect-rounded-corners = true;
detect-client-opacity = true;
detect-transient = true;
use-ewmh-active-win = true;

# Window type settings
wintypes:
{
    tooltip = { fade = true; shadow = true; opacity = 0.95; focus = true; full-shadow = false; };
    dock = { shadow = false; clip-shadow-above = true; }
    dnd = { shadow = false; }
    popup_menu = { opacity = 0.95; }
    dropdown_menu = { opacity = 0.95; }
};
EOF

print_success "Picom configured!"

# Configure Rofi
print_step "Configuring Rofi launcher..."
cat > ~/.config/rofi/config.rasi << 'EOF'
configuration {
    modi: "drun,run,window";
    show-icons: true;
    terminal: "xfce4-terminal";
    drun-display-format: "{icon} {name}";
    location: 0;
    disable-history: false;
    hide-scrollbar: true;
    display-drun: "   Apps ";
    display-run: "   Run ";
    display-window: " 﩯  Window ";
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
EOF

print_success "Rofi configured!"

# Configure Plank dock
print_step "Configuring Plank dock..."
mkdir -p ~/.config/plank/dock1

cat > ~/.config/plank/dock1/settings << 'EOF'
[PlankDockPreferences]
DockItems=firefox.desktoplaunch;;thunar.desktoplaunch;;xfce4-terminal.desktoplaunch;;
HideMode=3
Theme=Transparent
IconSize=48
Position=3
Alignment=0
ItemsAlignment=0
EOF

print_success "Plank configured!"

# Create XFCE configuration
print_step "Configuring XFCE settings..."

# Create configuration directory
mkdir -p ~/.config/xfce4/xfconf/xfce-perchannel-xml

# Configure XFCE window manager
cat > ~/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="theme" type="string" value="Catppuccin-Mocha-Standard-Mauve-Dark"/>
    <property name="title_font" type="string" value="JetBrainsMono Nerd Font Bold 10"/>
    <property name="use_compositing" type="bool" value="false"/>
    <property name="easy_click" type="string" value="Super"/>
    <property name="box_move" type="bool" value="false"/>
    <property name="box_resize" type="bool" value="false"/>
    <property name="button_layout" type="string" value="O|HMC"/>
    <property name="button_offset" type="int" value="0"/>
    <property name="button_spacing" type="int" value="0"/>
    <property name="click_to_focus" type="bool" value="true"/>
    <property name="focus_delay" type="int" value="250"/>
    <property name="focus_hint" type="bool" value="true"/>
    <property name="focus_new" type="bool" value="true"/>
    <property name="placement_ratio" type="int" value="20"/>
    <property name="popup_opacity" type="int" value="100"/>
    <property name="raise_delay" type="int" value="250"/>
    <property name="raise_on_click" type="bool" value="true"/>
    <property name="raise_on_focus" type="bool" value="false"/>
    <property name="raise_with_any_button" type="bool" value="true"/>
    <property name="repeat_urgent_blink" type="bool" value="false"/>
    <property name="show_dock_shadow" type="bool" value="true"/>
    <property name="show_frame_shadow" type="bool" value="true"/>
    <property name="show_popup_shadow" type="bool" value="true"/>
    <property name="snap_to_border" type="bool" value="true"/>
    <property name="snap_to_windows" type="bool" value="false"/>
    <property name="snap_width" type="int" value="10"/>
    <property name="theme" type="string" value="Catppuccin-Mocha-Standard-Mauve-Dark"/>
    <property name="title_alignment" type="string" value="center"/>
    <property name="title_font" type="string" value="JetBrainsMono Nerd Font Bold 10"/>
    <property name="title_horizontal_offset" type="int" value="0"/>
    <property name="titleless_maximize" type="bool" value="false"/>
    <property name="title_shadow_active" type="string" value="false"/>
    <property name="title_shadow_inactive" type="string" value="false"/>
    <property name="urgent_blink" type="bool" value="false"/>
    <property name="workspace_count" type="int" value="4"/>
    <property name="wrap_cycle" type="bool" value="true"/>
    <property name="wrap_layout" type="bool" value="true"/>
    <property name="wrap_resistance" type="int" value="10"/>
    <property name="wrap_windows" type="bool" value="true"/>
    <property name="workspace_names" type="array">
      <value type="string" value="Workspace 1"/>
      <value type="string" value="Workspace 2"/>
      <value type="string" value="Workspace 3"/>
      <value type="string" value="Workspace 4"/>
    </property>
  </property>
</channel>
EOF

# Configure XFCE desktop
cat > ~/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="monitoreDP-1" type="empty">
        <property name="workspace0" type="empty">
          <property name="color-style" type="int" value="0"/>
          <property name="image-style" type="int" value="5"/>
          <property name="last-image" type="string" value="${HOME}/Pictures/Wallpapers/wallpaper1.jpg"/>
        </property>
      </property>
    </property>
  </property>
</channel>
EOF

# Configure XFCE UI settings
cat > ~/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="Catppuccin-Mocha-Standard-Mauve-Dark"/>
    <property name="IconThemeName" type="string" value="Papirus-Dark"/>
    <property name="DoubleClickTime" type="int" value="400"/>
    <property name="DoubleClickDistance" type="int" value="5"/>
    <property name="DndDragThreshold" type="int" value="8"/>
    <property name="CursorBlink" type="bool" value="true"/>
    <property name="CursorBlinkTime" type="int" value="1200"/>
    <property name="SoundThemeName" type="string" value="default"/>
    <property name="EnableEventSounds" type="bool" value="false"/>
    <property name="EnableInputFeedbackSounds" type="bool" value="false"/>
  </property>
  <property name="Xft" type="empty">
    <property name="DPI" type="int" value="-1"/>
    <property name="Antialias" type="int" value="1"/>
    <property name="Hinting" type="int" value="1"/>
    <property name="HintStyle" type="string" value="hintslight"/>
    <property name="RGBA" type="string" value="rgb"/>
  </property>
  <property name="Gtk" type="empty">
    <property name="CanChangeAccels" type="bool" value="false"/>
    <property name="ColorPalette" type="string" value="black:white:gray50:red:purple:blue:light blue:green:yellow:orange:lavender:brown:goldenrod4:dodger blue:pink:light green:gray10:gray30:gray75:gray90"/>
    <property name="FontName" type="string" value="Noto Sans 10"/>
    <property name="MonospaceFontName" type="string" value="JetBrainsMono Nerd Font 10"/>
    <property name="IconSizes" type="string" value=""/>
    <property name="KeyThemeName" type="string" value=""/>
    <property name="ToolbarStyle" type="string" value="icons"/>
    <property name="ToolbarIconSize" type="int" value="3"/>
    <property name="MenuImages" type="bool" value="true"/>
    <property name="ButtonImages" type="bool" value="true"/>
    <property name="MenuBarAccel" type="string" value="F10"/>
    <property name="CursorThemeName" type="string" value="Bibata-Modern-Classic"/>
    <property name="CursorThemeSize" type="int" value="24"/>
    <property name="DecorationLayout" type="string" value="menu:minimize,maximize,close"/>
  </property>
</channel>
EOF

# Configure XFCE panel
cat > ~/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-panel" version="1.0">
  <property name="configver" type="int" value="2"/>
  <property name="panels" type="array">
    <value type="int" value="1"/>
    <property name="panel-1" type="empty">
      <property name="position" type="string" value="p=8;x=0;y=0"/>
      <property name="length" type="uint" value="100"/>
      <property name="position-locked" type="bool" value="true"/>
      <property name="size" type="uint" value="40"/>
      <property name="plugin-ids" type="array">
        <value type="int" value="1"/>
        <value type="int" value="2"/>
        <value type="int" value="3"/>
        <value type="int" value="4"/>
        <value type="int" value="5"/>
        <value type="int" value="6"/>
        <value type="int" value="7"/>
        <value type="int" value="8"/>
        <value type="int" value="9"/>
        <value type="int" value="10"/>
        <value type="int" value="11"/>
      </property>
      <property name="background-style" type="uint" value="0"/>
      <property name="background-alpha" type="uint" value="85"/>
      <property name="enter-opacity" type="uint" value="100"/>
      <property name="leave-opacity" type="uint" value="85"/>
      <property name="mode" type="uint" value="0"/>
    </property>
  </property>
  <property name="plugins" type="empty">
    <property name="plugin-1" type="string" value="whiskermenu"/>
    <property name="plugin-2" type="string" value="separator">
      <property name="style" type="uint" value="0"/>
    </property>
    <property name="plugin-3" type="string" value="pager"/>
    <property name="plugin-4" type="string" value="separator">
      <property name="style" type="uint" value="0"/>
    </property>
    <property name="plugin-5" type="string" value="tasklist">
      <property name="show-labels" type="bool" value="true"/>
      <property name="grouping" type="uint" value="1"/>
    </property>
    <property name="plugin-6" type="string" value="separator">
      <property name="style" type="uint" value="0"/>
      <property name="expand" type="bool" value="true"/>
    </property>
    <property name="plugin-7" type="string" value="systray">
      <property name="show-frame" type="bool" value="false"/>
      <property name="size-max" type="uint" value="22"/>
    </property>
    <property name="plugin-8" type="string" value="pulseaudio"/>
    <property name="plugin-9" type="string" value="power-manager-plugin"/>
    <property name="plugin-10" type="string" value="notification-plugin"/>
    <property name="plugin-11" type="string" value="clock">
      <property name="digital-format" type="string" value="%H:%M %p"/>
      <property name="tooltip-format" type="string" value="%A %d %B %Y"/>
    </property>
  </property>
</channel>
EOF

# Configure XFCE terminal
print_step "Configuring XFCE Terminal..."
mkdir -p ~/.config/xfce4/terminal

cat > ~/.config/xfce4/terminal/terminalrc << 'EOF'
[Configuration]
FontName=JetBrainsMono Nerd Font 11
MiscAlwaysShowTabs=FALSE
MiscBell=FALSE
MiscBellUrgent=FALSE
MiscBordersDefault=TRUE
MiscCursorBlinks=TRUE
MiscCursorShape=TERMINAL_CURSOR_SHAPE_BLOCK
MiscDefaultGeometry=80x24
MiscInheritGeometry=FALSE
MiscMenubarDefault=FALSE
MiscMouseAutohide=FALSE
MiscMouseWheelZoom=TRUE
MiscToolbarDefault=FALSE
MiscConfirmClose=TRUE
MiscCycleTabs=TRUE
MiscTabCloseButtons=TRUE
MiscTabCloseMiddleClick=TRUE
MiscTabPosition=GTK_POS_TOP
MiscHighlightUrls=TRUE
MiscMiddleClickOpensUri=FALSE
MiscCopyOnSelect=FALSE
MiscShowRelaunchDialog=TRUE
MiscRewrapOnResize=TRUE
MiscUseShiftArrowsToScroll=FALSE
MiscSlimTabs=FALSE
MiscNewTabAdjacent=FALSE
MiscSearchDialogOpacity=100
MiscShowUnsafePasteDialog=TRUE
ScrollingLines=10000
ColorForeground=#cdd6f4
ColorBackground=#1e1e2e
ColorCursor=#f5e0dc
ColorPalette=#45475a;#f38ba8;#a6e3a1;#f9e2af;#89b4fa;#f5c2e7;#94e2d5;#bac2de;#585b70;#f38ba8;#a6e3a1;#f9e2af;#89b4fa;#f5c2e7;#94e2d5;#a6adc8
TabActivityColor=#89b4fa
BackgroundMode=TERMINAL_BACKGROUND_TRANSPARENT
BackgroundDarkness=0.95
EOF

# Create autostart entries
print_step "Creating autostart entries..."
mkdir -p ~/.config/autostart

# Picom autostart
cat > ~/.config/autostart/picom.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Picom
Comment=Compositor for X11
Exec=picom --config ~/.config/picom/picom.conf
Terminal=false
Hidden=false
EOF

# Plank autostart
cat > ~/.config/autostart/plank.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Plank
Comment=Stupidly simple dock
Exec=plank
Terminal=false
Hidden=false
EOF

# Numlockx autostart
cat > ~/.config/autostart/numlockx.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=NumLockX
Comment=Enable NumLock on startup
Exec=numlockx on
Terminal=false
Hidden=false
EOF

# Create custom keybindings script
print_step "Setting up custom keybindings..."
cat > ~/.config/xfce4/set-keybindings.sh << 'EOF'
#!/bin/bash

# Custom keybindings for XFCE

# Rofi launcher
xfconf-query -c xfce4-keyboard-shortcuts -p '/commands/custom/<Super>space' -n -t string -s 'rofi -show drun'
xfconf-query -c xfce4-keyboard-shortcuts -p '/commands/custom/<Super>r' -n -t string -s 'rofi -show run'

# Screenshot
xfconf-query -c xfce4-keyboard-shortcuts -p '/commands/custom/Print' -n -t string -s 'xfce4-screenshooter -r'
xfconf-query -c xfce4-keyboard-shortcuts -p '/commands/custom/<Shift>Print' -n -t string -s 'xfce4-screenshooter -w'

# Terminal
xfconf-query -c xfce4-keyboard-shortcuts -p '/commands/custom/<Super>Return' -n -t string -s 'xfce4-terminal'

# File manager
xfconf-query -c xfce4-keyboard-shortcuts -p '/commands/custom/<Super>e' -n -t string -s 'thunar'

# Lock screen
xfconf-query -c xfce4-keyboard-shortcuts -p '/commands/custom/<Super>l' -n -t string -s 'xflock4'

# Task manager
xfconf-query -c xfce4-keyboard-shortcuts -p '/commands/custom/<Control><Shift>Escape' -n -t string -s 'xfce4-taskmanager'
EOF

chmod +x ~/.config/xfce4/set-keybindings.sh

# Create startup script
cat > ~/.config/xfce4/startup.sh << 'EOF'
#!/bin/bash

# Apply keybindings
~/.config/xfce4/set-keybindings.sh

# Set wallpaper
nitrogen --set-zoom-fill ~/Pictures/Wallpapers/wallpaper1.jpg

# Apply GTK theme
xfconf-query -c xsettings -p /Net/ThemeName -s "Catppuccin-Mocha-Standard-Mauve-Dark"
xfconf-query -c xsettings -p /Net/IconThemeName -s "Papirus-Dark"
xfconf-query -c xsettings -p /Gtk/CursorThemeName -s "Bibata-Modern-Classic"

# Apply WM theme
xfconf-query -c xfwm4 -p /general/theme -s "Catppuccin-Mocha-Standard-Mauve-Dark"
EOF

chmod +x ~/.config/xfce4/startup.sh

# Create autostart entry for startup script
cat > ~/.config/autostart/xfce-custom-startup.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=XFCE Custom Startup
Comment=Apply custom XFCE settings
Exec=/bin/bash ~/.config/xfce4/startup.sh
Terminal=false
Hidden=false
EOF

# Configure LightDM greeter
print_step "Configuring LightDM greeter..."
sudo tee /etc/lightdm/lightdm-gtk-greeter.conf > /dev/null << 'EOF'
[greeter]
theme-name = Catppuccin-Mocha-Standard-Mauve-Dark
icon-theme-name = Papirus-Dark
font-name = Noto Sans 11
cursor-theme-name = Bibata-Modern-Classic
background = /usr/share/backgrounds/xfce/xfce-blue.jpg
position = 50%,center 50%,center
EOF

# Create application menu favorites
print_step "Setting up application menu..."
mkdir -p ~/.config/menus
cat > ~/.config/menus/xfce-applications.menu << 'EOF'
<!DOCTYPE Menu PUBLIC "-//freedesktop//DTD Menu 1.0//EN"
  "http://www.freedesktop.org/standards/menu-spec/1.0/menu.dtd">
<Menu>
    <Name>Xfce</Name>
    <DefaultAppDirs/>
    <DefaultDirectoryDirs/>
    <DefaultMergeDirs/>
    <Include>
        <Category>X-Xfce</Category>
        <Category>X-Xfce-Toplevel</Category>
    </Include>
    <MergeFile type="parent">/etc/xdg/menus/xfce-applications.menu</MergeFile>
</Menu>
EOF

# Install additional modern applications
print_step "Installing additional modern applications..."
read -p "Do you want to install additional modern applications? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo apt install -y \
        flatpak \
        gnome-software-plugin-flatpak \
        code \
        gimp \
        inkscape \
        vlc \
        transmission-gtk \
        timeshift
    
    # Add Flathub repository
    sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    
    print_success "Additional applications installed!"
fi

# Create info script
print_step "Creating system info script..."
cat > ~/xfce-info.sh << 'EOF'
#!/bin/bash

echo "========================================="
echo "Modern XFCE Desktop - System Information"
echo "========================================="
echo ""
echo "Desktop Environment: XFCE $(xfce4-about --version | grep xfce4 | awk '{print $2}')"
echo "Theme: Catppuccin Mocha"
echo "Icons: Papirus Dark"
echo "Cursor: Bibata Modern Classic"
echo "Compositor: Picom"
echo ""
echo "Installed Components:"
echo "  ✓ XFCE Desktop with Goodies"
echo "  ✓ Catppuccin Mocha GTK Theme"
echo "  ✓ Papirus Icon Theme"
echo "  ✓ Bibata Cursor Theme"
echo "  ✓ Picom Compositor (blur, shadows, animations)"
echo "  ✓ Plank Dock"
echo "  ✓ Rofi Launcher"
echo "  ✓ LightDM with themed greeter"
echo ""
echo "Keybindings:"
echo "  Super + Space       - Rofi App Launcher"
echo "  Super + R           - Rofi Run"
echo "  Super + Return      - Terminal"
echo "  Super + E           - File Manager"
echo "  Super + L           - Lock Screen"
echo "  Print               - Screenshot (area)"
echo "  Shift + Print       - Screenshot (window)"
echo "  Ctrl + Shift + Esc  - Task Manager"
echo ""
echo "Configuration files:"
echo "  ~/.config/xfce4/"
echo "  ~/.config/picom/picom.conf"
echo "  ~/.config/rofi/"
echo "  ~/.config/plank/"
echo ""
echo "========================================="
EOF

chmod +x ~/xfce-info.sh

# Clean up
print_step "Cleaning up..."
sudo apt autoremove -y
sudo apt autoclean

print_msg ""
print_success "============================================="
print_success "  Modern XFCE Desktop Setup Complete!       "
print_success "============================================="
print_msg ""
print_msg "Installed components:"
print_msg "  ✓ XFCE Desktop Environment"
print_msg "  ✓ Catppuccin Mocha Theme (GTK + WM)"
print_msg "  ✓ Papirus Dark Icon Theme"
print_msg "  ✓ Bibata Modern Cursor Theme"
print_msg "  ✓ Picom Compositor (blur, shadows, rounded corners)"
print_msg "  ✓ Plank Dock"
print_msg "  ✓ Rofi Application Launcher"
print_msg "  ✓ Modern terminal configuration"
print_msg "  ✓ LightDM with themed greeter"
print_msg ""
print_msg "Features:"
print_msg "  • Transparent windows with blur"
print_msg "  • Rounded corners on windows"
print_msg "  • Beautiful shadows and effects"
print_msg "  • Modern color scheme (Catppuccin Mocha)"
print_msg "  • Optimized panel layout"
print_msg "  • Custom keybindings"
print_msg ""
print_msg "Keybindings:"
print_msg "  Super + Space       - App Launcher (Rofi)"
print_msg "  Super + Return      - Terminal"
print_msg "  Super + E           - File Manager"
print_msg "  Super + L           - Lock Screen"
print_msg ""
print_msg "View full info:"
print_msg "  ~/xfce-info.sh"
print_msg ""
print_warning "Please log out and log back in for all changes to take effect."
print_warning "Select 'Xfce Session' from the login screen."
echo ""

read -p "Do you want to reboot now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_msg "Rebooting in 5 seconds..."
    sleep 5
    sudo reboot
else
    print_msg "Please remember to log out and log back in to use the new desktop!"
fi