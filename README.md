echo '%sudo  ALL=(ALL) NOPASSWD: ALL' | sudo tee -a /etc/sudoers

sudo apt install git && git clone https://github.com/jacobm3/gbin.git && echo ". ~/gbin/jacobrc" >> ~/.bashrc && echo ". ~/gbin/jacobrc" >> ~/.bash_profile && ln -s gbin/jacobrc .jacobrc

sudo apt install curl && curl -fsSL https://raw.githubusercontent.com/jacobm3/gbin/main/ubuntu-setup.sh | bash 


## desktop env
sudo snap install bitwarden


echo 'setxkbmap -option caps:swapescape' >> ~/.jacobrc.local

gsettings set org.gnome.desktop.wm.preferences mouse-button-modifier '<Alt>'

  
  
Eric Reeves, 
#!/bin/bash
/usr/bin/setxkbmap -option 'caps:ctrl_modifier'
/usr/bin/xcape -e 'Caps_Lock=Escape' -t 100
Tap Caps Lock, it's Escape.  Hold it, it's Control.
Best of both words.
Just "yay -S xcape" and that little 2 liner will enable it.

  

## local rsync backups
  rsync -v -a \
    --exclude='Documents/g/h' \
    --exclude='**.exe' \
    --exclude='**.terraform**' \
    --exclude='**.git**' \
    /mnt/c/Users/jacob/Documents /mnt/g/backup-optiplex/daily/`date +%Y.%m.%d`
  
  
  
https://unsplash.com/

## linux crystaldiskmark
wget https://github.com/JonMagon/KDiskMark/releases/download/3.1.3/kdiskmark_3.1.3-ubuntu_amd64.deb 
sudo dpkg -i kdiskmark_3.1.3-ubuntu_amd64.deb
sudo apt-get -f install
  
## fix flatpak kde/qt font size under mx linux
```
flatpak --user override --reset org.openshot.OpenShot
flatpak override --user --env=GDK_SCALE=2 org.openshot.OpenShot
flatpak override --user --env=GDK_DPI_SCALE=0.5 org.openshot.OpenShot
flatpak override --user --filesystem=~/.config org.openshot.OpenShot
flatpak override --user --filesystem=~/.Xresources org.openshot.OpenShot
flatpak override --user --env=QT_AUTO_SCREEN_SCALE_FACTOR=1 org.openshot.OpenShot
flatpak override --user --env=QT_SCALE_FACTOR=1.5 org.openshot.OpenShot

```
