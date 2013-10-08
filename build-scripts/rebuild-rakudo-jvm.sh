#!/bin/sh
cd
set -e
echo -e "\n\nNew rakudo-jvm build"
PREFIX=$HOME/rakudo-jvm
date
cd jvm-rakudo
git fetch origin
if ! diff .git/refs/remotes/origin/nom .git/refs/heads/nom
then
    git pull
    perl ConfigureJVM.pl --gen-nqp --prefix=$PREFIX
    make install && git rev-parse HEAD | cut -b 1,2,3,4,5,6 > $PREFIX/revision
fi
cd ..
