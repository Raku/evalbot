#!/bin/sh
set -e
cd
rm -rf nom nom-inst nom-inst1 nom-inst2
mkdir nom-inst1 nom-inst2
git clone git://github.com/rakudo/rakudo.git nom
cd nom
git checkout nom
perl Configure.pl --gen-parrot --prefix=$HOME/nom-inst1/
make -j3 install

cd
ln -s nom-inst1 nom-inst
