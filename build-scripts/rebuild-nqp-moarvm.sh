#!/bin/sh
cd
set -e
echo -e "\n\nNew nqp-moarvm build"
date
cd MoarVM
git pull
perl Configure.pl --optimize --prefix=../nqp-moarvm/install && make CGOTO=1 install
cd ../nqp-moarvm/nqp
perl ConfigureMoar.pl --prefix=../install && make install
