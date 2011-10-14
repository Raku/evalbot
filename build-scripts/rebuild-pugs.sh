#!/bin/sh
cd
set -e
echo -e "\nNew pugs build"
GHCDIR="$HOME/ghc-7.2.1"
PATH="$GHCDIR/bin":$PATH
date
cd ~/Pugs.hs/
git pull
cd Pugs
make
make INSTALLBIN="$GHCDIR/bin"/ install
git log -1 --pretty="format:%h" >  $GHCDIR/pugs_version
echo
