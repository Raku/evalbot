#!/bin/sh
cd
set -e
echo -e "\nNew pugs build"
date
cd ~/Pugs.hs/
git pull
cd Pugs
make
make INSTALLBIN=$HOME/ghc-7.2.1/bin/ install
git log -1 --pretty="format:%h" >  $HOME/ghc-7.2.1/pugs_version
echo
