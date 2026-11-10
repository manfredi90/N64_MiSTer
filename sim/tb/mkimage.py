#!/usr/bin/env python3
# builds the initial savestate image (slot 0) with a small MIPS test program, as "wordindex hexvalue" lines
import struct, sys
R={'zero':0,'at':1,'v0':2,'v1':3,'a0':4,'t0':8,'t1':9,'t2':10,'t3':11,'t4':12,'s0':16,'s1':17,'s2':18,'s3':19,'k0':26,'k1':27}
def r(x): return R[x]
def I(op,rs,rt,imm): return (op<<26)|(r(rs)<<21)|(r(rt)<<16)|(imm&0xFFFF)
def Rt(fn,rs,rt,rd,sh=0): return (r(rs)<<21)|(r(rt)<<16)|(r(rd)<<11)|(sh<<6)|fn
def addiu(rt,rs,i): return I(9,rs,rt,i)
def andi(rt,rs,i): return I(12,rs,rt,i)
def lui(rt,i): return I(15,'zero',rt,i)
def sw(rt,off,rs): return I(43,rs,rt,off)
def lw(rt,off,rs): return I(35,rs,rt,off)
def sll(rd,rt,sh): return Rt(0,'zero',rt,rd,sh)
def addu(rd,rs,rt): return Rt(0x21,rs,rt,rd)
def beq(rs,rt,off): return I(4,rs,rt,off)
def j(addr): return (2<<26)|((addr>>2)&0x3FFFFFF)
def mfc0(rt,rd): return (0x10<<26)|(0<<21)|(r(rt)<<16)|(rd<<11)
def mtc0(rt,rd): return (0x10<<26)|(4<<21)|(r(rt)<<16)|(rd<<11)
ERET=0x42000018; NOP=0

mem={}
def put(addr,words):
    for i,w in enumerate(words): mem[addr+4*i]=w

# interrupt handler at 0x180: next timer interrupt, count interrupts uncached at 0x508
put(0x180,[mfc0('k0',9), addiu('k0','k0',1500), mtc0('k0',11), NOP,
           lui('k1',0xA000), lw('k0',0x508,'k1'), NOP, addiu('k0','k0',1), sw('k0',0x508,'k1'), NOP, ERET, NOP])
# main at 0x800
MAIN=0x800
prog=[lui('s1',0xA000), lui('s2',0x8000),
 # loop:
 addiu('s0','s0',1), andi('t0','s0',0x3F), sll('t0','t0',2), addu('t1','s2','t0'), sw('s0',0x400,'t1'),
 addiu('t2','s0',-1), andi('t3','t2',0x3F), sll('t3','t3',2), addu('t3','s2','t3'), lw('t4',0x400,'t3'), NOP,
 beq('t4','t2',2), NOP, sw('s0',0x600,'s1'),
 # ok:
 sw('s0',0x500,'s1'), j(0x80000000+MAIN+8), NOP]
put(MAIN,prog)

SLOT=0xC000000//8
img={}
def w64(idx,val): img[SLOT+idx]=val&0xFFFFFFFFFFFFFFFF
w64(0,(4194302<<32)|0)                     # header
w64(2048,0x00FFFC0000000000)               # AI default
w64(6144,1<<52)                            # RDP cbuf_ready
CPU=16384
import os
PCSTART=int(os.environ.get('PCSTART','0x800'),16)
w64(CPU+0,0xFFFFFFFF80000000+PCSTART)      # PC
if os.environ.get('PENDING'): w64(CPU+64+13,0x8000)
if os.environ.get('S0'): w64(CPU+32+16,int(os.environ['S0'])); w64(CPU+32+17,0xFFFFFFFFA0000000); w64(CPU+32+18,0xFFFFFFFF80000000)
w64(CPU+64+12,0x30008001)                  # SR: IE, IM7, CU0, CU1, BEV=0
w64(CPU+64+11,1000)                        # COMPARE
w64(CPU+64+16,0x7006E463)                  # CONFIG, kseg0 cached
# RAM, first 512 words (FASTSIM), N64 byte order in DDR3 byte lanes
RAM=1048576
for a,wv in mem.items():
    k=SLOT+RAM+a//8
    b=struct.pack('>I',wv)
    v=img.get(k,0)
    for i in range(4):
        lane=(a%8)+i
        v&=~(0xFF<<(8*lane)); v|=b[i]<<(8*lane)
    img[k]=v
with open(sys.argv[1],'w') as f:
    for k in sorted(img): f.write("%d %016X\n"%(k,img[k]))
print(len(img),"words")
