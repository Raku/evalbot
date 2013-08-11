#!/bin/sh
export PATH=/home/p6eval/nqp-jvm/nqp/install/bin:/home/p6eval/nqp-jvm/jdk1.7.0/bin:/home/p6eval/nqp-jvm/jdk1.7.0/jre/bin:/usr/local/bin:/usr/bin:/bin:/usr/bin/X11:/usr/games
cd
set -e
echo -e "\n\nNew nqp-jvm build"
date
cd nqp-jvm/nqp
git fetch origin
if ! diff .git/refs/remotes/origin/master .git/refs/heads/master
then
git pull
perl Configure.pl --gen-parrot
make install
fi
cd ..
git fetch origin
if ! diff .git/refs/remotes/origin/master .git/refs/heads/master
then
git pull
make clean
make
fi

