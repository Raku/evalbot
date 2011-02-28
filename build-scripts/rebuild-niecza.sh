#!/bin/sh
PATH=$PATH:/usr/local/mono-2.10.1/bin
#PATH=/home/p6eval/sprixel/clr/bin:/usr/local/bin:/usr/bin:/bin:/usr/games
echo "updating niecza"
cd ~/niecza/
git pull
make
