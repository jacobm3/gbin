#!/bin/bash

# install git 
command -v git >/dev/null 2>&1 || sudo apt update && sudo apt install -y git


# install Qogir theme
mkdir -p ~/src
git clone https://github.com/vinceliuice/Qogir-theme.git
cd Qogir-theme
sudo apt-get install gtk2-engines-murrine gtk2-engines-pixbuf
./install.sh --tweaks square

# install Kora icons
cd ~/src
git clone https://github.com/bikass/kora.git
cd kora
sudo cp -r kora* /usr/share/icons
