#!/bin/sh
PATH=$PATH:/usr/local/bin
PATH=/usr/local/bin:/usr/bin:/bin:/usr/games
echo "updating niecza"
cd ~/niecza/
git pull
xbuild
