#!/bin/bash
#
# lubuntu-desktop-setup.sh
#
# WHAT THIS DOES:
#   Personal setup steps for a Lubuntu desktop:
#     - Links dotfiles (htop config, etc.) via the shared link-dotfiles.sh.
#     - Creates two autostart entries that run at login:
#         * swap Caps Lock and Escape keys
#         * launch ksnip (a screenshot tool)
#     - Installs ksnip and redshift (screen color-temperature / night light).
#
# HOW TO RUN:
#   ./lubuntu-desktop-setup.sh
#   Prompts for sudo password for the apt install at the end.
#
# PREREQUISITES:
#   - Lubuntu/Ubuntu-based desktop with apt and a graphical login that honors
#     ~/.config/autostart .desktop files (LXQt/most XDG desktops do).

# This commented-out line was an old way to force Chromium to disable GPU
# acceleration; kept for reference but intentionally not run.
#echo 'CHROMIUM_FLAGS="--disable-gpu"' >> ~/.chromium-browser.init

# htop config is now managed by the dotfile linker, which picks the right
# per-profile variant (laptop here) and symlinks it. See linux/link-dotfiles.sh.
# "$(dirname "$0")" is the folder this script lives in, so "../link-dotfiles.sh"
# finds the linker one directory up regardless of where you run this from.
"$(dirname "$0")/../link-dotfiles.sh"

# ASD = AutoStart Dir. This is where the desktop looks for programs to run at
# login. We create it (mkdir -p won't complain if it already exists) and cd in.
ASD=~/.config/autostart
mkdir -p $ASD && cd $ASD

# Write an autostart entry that swaps Caps Lock and Escape on login.
# "cat > file << EOF ... EOF" is a "here-document": everything between the two
# EOF markers is written verbatim into the named file.
cat > swap_caps_esc.desktop << EOF
[Desktop Entry]
Type=Application
Exec=setxkbmap -option caps:swapescape
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Swap Caps and Esc
Comment=Swaps the Caps Lock and Escape keys
EOF

# Write an autostart entry that launches the ksnip screenshot tool on login.
cat > ksnip.desktop << EOF
[Desktop Entry]
Type=Application
Exec=ksnip
Name=ksnip
EOF

# Install the screenshot tool (ksnip) and redshift (warms screen colors at
# night to reduce eye strain). Both are referenced by the autostart entries /
# expected desktop tools above.
sudo apt install ksnip redshift
