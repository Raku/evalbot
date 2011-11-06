#!/bin/sh
cd
set -e
echo -e "\n\nNew nqplua build"
date
cd nqplua/6model
git pull
cd lua/compiler
make
