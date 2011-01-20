#!/bin/sh
PATH=$PATH:/usr/local/bin
PATH=/home/p6eval/sprixel/clr/bin:/usr/local/bin:/usr/bin:/bin:/usr/games
echo "updating niecza"
cd ~/niecza/
git pull
make
