#!/bin/sh
set -e
echo -e "\n\nNew nqp-rx build"
date
cd nqp-rx
git pull
perl Configure.pl --gen-parrot
make
