#!/bin/bash
#
# install-qogir-kora.sh
#
# WHAT THIS DOES:
#   Installs the "Qogir" GTK desktop theme and the "Kora" icon set on a Linux
#   desktop. These are cosmetic: Qogir restyles window/app widgets, Kora swaps
#   the application icons. After running, you still have to pick them in your
#   desktop's appearance settings (Settings > Appearance / tweaks tool).
#
# HOW TO RUN:
#   ./install-qogir-kora.sh
#   You will be prompted for your sudo password (it installs system packages
#   and copies icons into a system directory).
#
# PREREQUISITES:
#   - A Debian/Ubuntu-based system (uses apt) with internet access.
#   - git (installed automatically below if missing).

# install git
# "command -v git" prints the path to git if it exists, and is silent + returns
# non-zero if it does not. We send its output to /dev/null (we only care about
# success/failure, not the path). The "||" means: only if git is NOT found, run
# the right-hand side to update apt's package lists and install git.
command -v git >/dev/null 2>&1 || sudo apt update && sudo apt install -y git


# install Qogir theme
# Create a ~/src folder to hold downloaded source code. "-p" means "don't error
# if it already exists, and create parent folders as needed."
mkdir -p ~/src
# Download (clone) the Qogir theme's source code from GitHub into ./Qogir-theme.
git clone https://github.com/vinceliuice/Qogir-theme.git
# Move into the freshly cloned theme folder so the installer runs in the right place.
cd Qogir-theme
# These two GTK2 rendering engines are required for the theme to draw correctly.
# (murrine = the gradient/widget engine, pixbuf = image-based widget rendering.)
sudo apt-get install gtk2-engines-murrine gtk2-engines-pixbuf
# Run the theme's own installer. "--tweaks square" picks the square-cornered
# variant instead of the default rounded corners.
./install.sh --tweaks square

# install Kora icons
# Go back to ~/src so we clone the icons next to the theme.
cd ~/src
# Download the Kora icon set source from GitHub.
git clone https://github.com/bikass/kora.git
# Enter the icon folder.
cd kora
# Copy every folder starting with "kora" (kora, kora-light, etc.) into the
# system-wide icon directory so all users/desktops can select them. "-r" copies
# directories recursively; sudo is needed because /usr/share is root-owned.
sudo cp -r kora* /usr/share/icons
