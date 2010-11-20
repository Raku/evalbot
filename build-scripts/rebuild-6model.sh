#!/bin/sh
cd
set -e
echo -e "\n\nNew 6model build"
date
cd 6model
git pull
make -f Makefile.linux
