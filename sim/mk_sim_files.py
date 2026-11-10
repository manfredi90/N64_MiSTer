#!/usr/bin/env python3
# GHDL is stricter than Quartus with integer port ranges: patched copies of the two affected files
import sys, os
rtl, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)

s = open(os.path.join(rtl, 'VI_videoout.vhd')).read()
s = s.replace("to_integer(overlay_xpos),", "overlay_xpos_i,").replace("to_integer(overlay_ypos),", "overlay_ypos_i,")
a = "   signal overlay_ypos        : unsigned(8 downto 0);"
assert a in s
s = s.replace(a, a + "\n   signal overlay_xpos_i      : integer range 0 to 2047;\n   signal overlay_ypos_i      : integer range 0 to 1023;", 1)
i = s.index("begin", s.index("signal overlay_ypos_i"))
s = s[:i] + "begin\n   overlay_xpos_i <= to_integer(overlay_xpos);\n   overlay_ypos_i <= to_integer(overlay_ypos);\n" + s[i + 5:]
open(os.path.join(out, 'VI_videoout.vhd'), 'w').write(s)

s = open(os.path.join(rtl, 'statemanager.vhd')).read()
a = "      savestate_number    : in    integer;"
assert a in s
open(os.path.join(out, 'statemanager.vhd'), 'w').write(s.replace(a, "      savestate_number    : in    integer range 0 to 3;"))

# SyncRamDualByteEnable without the altsyncram branch
import re
out_lines, skip = [], False
for l in open(os.path.join(rtl, 'SyncRamDualByteEnable.vhd')).read().split('\n'):
    if 'gsynth_cyclone5 : if' in l: skip = True
    if not skip and 'altera_mf' not in l: out_lines.append(l)
    if skip and re.match(r'\s*end generate;', l): skip = False
open(os.path.join(out, 'SyncRamDualByteEnable.vhd'), 'w').write('\n'.join(out_lines))
