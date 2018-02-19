#!/bin/bash
if [ ! -f ./dtmxsdb ]; then
    make dtmxsdb
fi
# Function test
#./dtmxsdb +p3333 +loadmem=../../install/riscv-tests/rv32ui-p-simple
# +verbose (enable log)
./dtmxsdb +verbose +p3333 +loadmem=../../install/riscv-tests/rv32ui-p-simple
#./dtmxsdb +verbose +p3333 +loadmem=../../install/riscv-bmarks/rsort.riscv