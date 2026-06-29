#!/bin/bash -x
# "-x" makes bash echo each command as it runs, so you can follow progress and
# spot exactly where a failure happens.

# ============================================================================
# wsl2-ubuntu-setup.sh — provision a fresh Ubuntu WSL2 box (general dev setup)
# ============================================================================
#
# WHAT THIS DOES
#   Bootstraps a fresh Ubuntu WSL2 distro into Jacob's standard dev environment:
#     - installs common CLI/devops tools
#     - replaces any Ubuntu docker with the official Docker CE
#     - copies a couple of helper scripts (pg, ng) into /usr/local/bin
#     - writes a custom vim colorscheme + ~/.vimrc for the user AND root
#     - points root's bashrc at the shared "jacobrc" environment file
#   The HashiCorp, Astronomer, and k3s installs are present but commented out.
#
# HOW TO RUN (inside the WSL Ubuntu shell, as a normal sudo-capable user):
#   bash ~/gbin/windows/wsl/wsl2-ubuntu-setup.sh
#   Then REBOOT WSL (see the loud reminder) for the iptables-legacy switch.
#
# PREREQUISITES: fresh Ubuntu WSL2, internet access, sudo, and the gbin repo
#   checked out at ~/gbin (this script copies files out of it).
# ============================================================================

# set -e makes the script ABORT immediately if any command fails, so we don't
# blunder ahead after an error. (It's selectively turned off/on around the
# docker-remove step below, which is allowed to "fail" harmlessly.)
set -e

# Stop apt from showing interactive config dialogs during an unattended run.
export DEBIAN_FRONTEND=noninteractive

# fix broken hardware crypto acceleration in virtualbox+wsl
# (left commented out — only needed on the VirtualBox+WSL combo that had a
#  broken hardware crypto path; uncomment if you hit gcrypt errors.)
#sudo mkdir -p /etc/gcrypt
#echo all | sudo tee /etc/gcrypt/hwf.deny

# Refresh package lists, then install the everyday CLI/devops tool set.
sudo apt-get update
sudo apt-get install -y nmap bzip2 ncat net-tools git htop sysstat iotop vim-nox python3-pip jq lm-sensors btop gpg curl wget lsb-release ca-certificates

# add hashi stuff
# (OPTIONAL, disabled) Uncomment this block to add HashiCorp's APT repo and
# install terraform + vault. Left off by default for a lean base image.
# sudo rm -f /usr/share/keyrings/hashicorp-archive-keyring.gpg /etc/apt/sources.list.d/hashicorp.list
# wget -q -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
# echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
# sudo apt update
# sudo apt install terraform vault


# Install Docker CE
# Temporarily turn OFF "abort on error" so that removing Ubuntu's docker
# packages doesn't kill the script when they aren't installed in the first place.
set +e
sudo apt-get remove docker docker-engine docker.io containerd runc
# Turn "abort on error" back on for the rest of the script.
set -e

# Set up the official Docker APT repo with its signing key.
sudo mkdir -p /etc/apt/keyrings
# Remove any leftover key/repo from a previous run so we start clean.
sudo rm -f /etc/apt/keyrings/docker.gpg /etc/apt/sources.list.d/docker.list
# Download Docker's signing key and convert it to apt's binary format.
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
# Write the Docker repo definition (pinned to that key) into sources.list.d.
# $(dpkg --print-architecture)=CPU arch, $(lsb_release -cs)=Ubuntu codename.
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
# Refresh lists and install the Docker engine, CLI, containerd, compose plugin.
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
# WSL2 networking needs the older "legacy" iptables backend; point iptables and
# ip6tables at it so Docker's firewall rules work.
sudo update-alternatives --set iptables /usr/sbin/iptables-legacy
sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
# Loud reminder: the iptables switch above only applies after a WSL restart.
echo '#'
echo '#'
echo '#'
echo '# YOU MUST REBOOT FOR THE DOCKER-CE IPTABLES CHANGE TO TAKE EFFECT!!!'
echo '#'
echo '#'
echo '#'

# Add the default "ubuntu" user to the docker group so it can run docker
# without sudo (effective after next login/reboot).
sudo usermod -G docker -a ubuntu

#sudo apt-get upgrade -y

# Install Astronomer CLI
# (OPTIONAL, disabled) Uncomment to install the "astro" Airflow CLI.
# curl -sSL install.astronomer.io | sudo bash -s

# Install k3s
# (OPTIONAL, disabled) Uncomment to install k3s, a lightweight Kubernetes.
#curl -sfL https://get.k3s.io | sh -



# add environment
# Copy two helper scripts (pg, ng) from the gbin repo into /usr/local/bin so
# they're on PATH for every user.
cd /home/$USER/gbin && sudo cp pg ng /usr/local/bin

# Create the user's vim colors folder, then write a custom colorscheme into it.
cd /home/$USER && mkdir -p .vim/colors 
# "cat > file <<EOF ... EOF" is a heredoc: everything up to the matching EOF is
# written verbatim into the file. This block is the "jacobm3" vim colorscheme;
# each "hi <Group> ..." line sets the colors for one syntax-highlight category
# (Normal text, Comments, Strings, errors, etc). You normally don't hand-edit
# these — they're just color preferences.
cat > .vim/colors/jacobm3.vim <<EOF
set background=dark
hi clear
if exists("syntax_on")
  syntax reset
endif
let colors_name = "jacobm3"
hi Normal ctermbg=Black ctermfg=LightGrey
hi ErrorMsg             term=standout   ctermbg=DarkRed ctermfg=White
hi IncSearch            term=reverse            cterm=bold
hi ModeMsg                      term=bold                       cterm=bold
hi StatusLine   term=bold                       cterm=bold
hi StatusLineNC term=bold                       cterm=bold
hi VertSplit            term=bold                       cterm=bold
hi Visual                       term=bold                       cterm=reverse
hi VisualNOS            term=underline,bold cterm=underline,bold
hi DiffText             term=reverse cterm=bold ctermbg=grey
hi Directory            term=bold ctermfg=cyan
hi LineNr                       term=underline ctermfg=darkgrey
hi MoreMsg                      term=bold ctermfg=LightGreen
hi NonText                      term=bold ctermfg=darkgrey
hi Question             term=standout ctermfg=LightGreen
hi Search                       term=reverse ctermbg=Yellow ctermfg=Black
hi SpecialKey   term=bold ctermfg=grey
hi Title                                term=bold ctermfg=darkGreen
hi WarningMsg   term=standout ctermfg=grey
hi WildMenu                     term=standout ctermbg=Yellow ctermfg=Black
hi Folded                       term=standout ctermbg=LightGrey ctermfg=grey
hi FoldColumn   term=standout ctermbg=LightGrey ctermfg=grey
hi DiffAdd                      term=bold ctermbg=grey
hi DiffChange   term=bold ctermbg=cyan
hi DiffDelete   term=bold ctermfg=grey ctermbg=cyan
hi Comment                      ctermfg=darkgrey
hi String                               ctermfg=grey
hi Statement            ctermfg=blue
hi Keyword              ctermfg=blue
hi PreCondit            ctermfg=blue
hi Function             ctermfg=grey
hi Constant             term=underline ctermfg=grey
hi Special                      term=bold ctermfg=grey
if &t_Co > 8
  hi Statement  term=bold cterm=bold ctermfg=grey
endif
hi Ignore                       ctermfg=LightGrey
EOF

# Write the user's vim config (~/.vimrc). Settings: show line numbers, indent
# with 4 spaces (expandtab turns tabs into spaces), auto-indent new lines, use
# the colorscheme we just installed, and enable syntax highlighting.
cat > /home/$USER/.vimrc <<EOF
set number
set ts=4
set autoindent
set expandtab
set tabstop=4
set sw=4
colorscheme jacobm3
syntax on
EOF

# Give the root user the same vim setup by copying the colorscheme and .vimrc
# into root's home.
sudo mkdir -p /root/.vim/colors 
sudo cp /home/$USER/.vim/colors/jacobm3.vim /root/.vim/colors
sudo cp /home/$USER/.vimrc /root
# Make root's shell source the shared "jacobrc" environment file on login.
# Note: "tee" (not "tee -a") OVERWRITES /root/.bashrc with just this one line.
echo ". /home/$USER/gbin/jacobrc" | sudo tee /root/.bashrc

