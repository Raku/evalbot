#!/bin/sh
export PATH=/usr/local/mono-2.10.1/bin:/usr/local/bin:/usr/bin:/bin
export LD_LIBRARY_PATH=/usr/local/mono-2.10.1/lib
echo "updating niecza"
cd ~/niecza/
git pull
ulimit -v 307200
make
mono run/Niecza.exe --obj-dir=obj -C Test JSYNC Threads
