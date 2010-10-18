#!/bin/sh
cd
PATH=/usr/local/bin:/usr/bin:/bin:/usr/games
echo
echo "updating partcl-nqp"
date
cd ~/partcl-nqp/
git pull
perl Configure.pl --gen-parrot
make -j3 
