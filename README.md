## Passwordless sudo setup
echo '%sudo  ALL=(ALL) NOPASSWD: ALL' | sudo tee -a /etc/sudoers

## Install git and clone this repo - github
sudo apt install git && git clone https://github.com/jacobm3/gbin.git && echo ". ~/gbin/jacobrc" >> ~/.bashrc && echo ". ~/gbin/jacobrc" >> ~/.bash_profile && ln -s gbin/jacobrc .jacobrc

## Install git and clone this repo - gitea
sudo apt install git && git clone https://gitea.mink-neon.ts.net/jacobm3/gbin.git && echo ". ~/gbin/jacobrc" >> ~/.bashrc && echo ". ~/gbin/jacobrc" >> ~/.bash_profile && ln -s gbin/jacobrc .jacobrc



## desktop env
echo 'setxkbmap -option caps:swapescape' >> ~/.jacobrc.local
gsettings set org.gnome.desktop.wm.preferences mouse-button-modifier '<Alt>'
  
Eric Reeves:
```
#!/bin/bash
/usr/bin/setxkbmap -option 'caps:ctrl_modifier'
/usr/bin/xcape -e 'Caps_Lock=Escape' -t 100
Tap Caps Lock, it's Escape.  Hold it, it's Control.
Best of both words.
Just "yay -S xcape" and that little 2 liner will enable it.
```
  
https://unsplash.com/
