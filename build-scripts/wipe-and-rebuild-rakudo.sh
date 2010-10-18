#!/bin/sh
set -e
cd
rm -rf p p1 p2 rakudo
mkdir p1 p2
git clone git://github.com/rakudo/rakudo.git
cd rakudo
perl Configure.pl --gen-parrot --gen-parrot-prefix=$HOME/p1/
make -j3 install

cd
ln -s p1 p
