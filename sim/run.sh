#!/bin/bash
# Savestate test of the N64 core in GHDL (mcode backend): a hand made state with a small MIPS program
# (timer interrupt, cached and uncached stores) is loaded, saved twice and loaded again; the program's
# loop and interrupt counters must continue without gaps and its cached data must survive.
# Takes about 15 minutes.
set -e
cd "$(dirname "$0")"
SIM=$PWD; RTL=$SIM/../rtl; W=$SIM/work
OPT="--std=08 -frelaxed -fsynopsys"
rm -rf $W; mkdir -p $W
python3 mk_sim_files.py $RTL $W/patched
python3 tb/mkimage.py $W/image.txt
pick() { for d in $SIM/models $W/patched; do [ -f $d/$1 ] && { echo $d/$1; return; }; done; echo $RTL/$1; }
ALL="$(for f in $(grep -o '[A-Za-z0-9_]*\.vhd' $RTL/mem.qip $RTL/N64.qip | cut -d: -f2); do pick $f; done)"
cd $W
ghdl -i $OPT --work=mem $ALL
ghdl -i $OPT --work=work $ALL $SIM/tb/tb_savestate.vhd
ghdl -m $OPT --work=work -P. -Wno-hide -Wno-shared -Wno-binding -Wno-others tb_savestate > make.log 2>&1 || { grep error make.log; exit 1; }
ghdl -r $OPT --workdir=. -P. tb_savestate --ieee-asserts=disable > sim.log 2>&1 || true
grep -E "report (note|error)\): [^t]|failure" sim.log | sed 's/.*(report \(note\|error\|failure\)): //'
grep -q "DONE errors=0" sim.log
