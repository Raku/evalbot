#!/bin/sh
cd
set -e
echo -e "\n\nNew std build"
date
cd std-rx
git pull
make snap || ( git clean -xdf; make snap )
