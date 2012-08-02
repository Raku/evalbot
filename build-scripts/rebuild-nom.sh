#!/bin/sh
cd ~/nom
git pull
make install || perl Configure.pl --gen-parrot --prefix=$HOME/nom-inst && make install && git rev-parse HEAD | cut -d '' -b 1-6 > $HOME/nom-inst/rakudo-revision
