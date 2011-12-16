#!/bin/sh
cd
set -e
echo -e "\n\nNew nqp build"
date
cd nqp
git pull
perl Configure.pl --gen-parrot
make
