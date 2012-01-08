#!/bin/sh
cd
set -e
echo -e "\n\nNew nqplua build"
date
cd nqplua/6model
echo |git pull
cd lua/compiler
make
