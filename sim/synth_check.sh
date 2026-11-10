#!/bin/bash
# GHDL elaboration of n64top with the synthesis translate_off regions removed, as Quartus sees the sources
cd "$(dirname "$0")"
SIM=$PWD; RTL=$SIM/../rtl; W=$SIM/work_synth
rm -rf $W; mkdir -p $W/src
python3 mk_sim_files.py $RTL $W/patched
pick() { for d in $SIM/models $W/patched; do [ -f $d/$1 ] && { echo $d/$1; return; }; done; echo $RTL/$1; }
ALL=""
for f in $(grep -o '[A-Za-z0-9_]*\.vhd' $RTL/mem.qip $RTL/N64.qip | cut -d: -f2); do
  python3 - "$(pick $f)" "$W/src/$f" <<'PY'
import sys,re
out=[];skip=False
for l in open(sys.argv[1]).read().split('\n'):
    if re.search(r'--\s*synthesis\s+translate_off',l,re.I): skip=True; continue
    if re.search(r'--\s*synthesis\s+translate_on',l,re.I): skip=False; continue
    if not skip: out.append(l)
open(sys.argv[2],'w').write('\n'.join(out))
PY
  ALL="$ALL $W/src/$f"
done
cd $W
OPT="--std=08 -frelaxed -fsynopsys"
ghdl -i $OPT --work=mem $ALL && ghdl -i $OPT --work=work $ALL && ghdl -m $OPT --work=work -P. -Wno-hide -Wno-shared -Wno-binding -Wno-others n64top > make.log 2>&1
RC=$?; grep -E "error" make.log | head -20; echo "SYNTH_VIEW_RC=$RC"; exit $RC
