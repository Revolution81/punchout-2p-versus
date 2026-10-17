#!/usr/bin/env python3
"""Build the 2-player Punch-Out hack: assemble p2.s and patch it into the ROM."""
import subprocess, os, sys, json
HERE=os.path.dirname(os.path.abspath(__file__))
CC65=os.environ.get('CC65BIN','/tmp/claude-0/-home-claude/a583e203-54e1-595a-9dcc-b8c16ad2bd56/scratchpad/cc65/bin')
from moves import MOVES, SEQ, TUNING

def prg_off(addr):  # fixed bank $A000-$FFFF -> file offset
    return 16 + 0x1A000 + (addr - 0xA000)

def build(src_rom, out_rom, tuning=None):
    t=dict(TUNING); t.update(tuning or {})
    with open(os.path.join(HERE,'tuning.inc'),'w') as f:
        for k,v in t.items(): f.write(f'{k} = {v}\n')
    with open(os.path.join(HERE,'moves.inc'),'w') as f:
        f.write('MoveTbl:\n')
        for n in range(14): f.write('  .byte '+','.join('$%02X'%a for a in (MOVES[n]+[0]*8)[:8])+'\n')
        seq=[0]; idx={}
        for n in range(14):
            for slot,anims in SEQ.get(n,{}).items():
                idx[(n,slot)]=len(seq); seq+=list(anims[1:])+[0]
        f.write('NextTbl:\n')
        for n in range(14): f.write('  .byte '+','.join('$%02X'%idx.get((n,k),0) for k in range(8))+'\n')
        f.write('SeqData:\n  .byte '+','.join('$%02X'%a for a in seq)+'\n')
        for (n,slot),i in idx.items(): assert MOVES[n][slot]==SEQ[n][slot][0]
        assert len(seq)<256
    obj=os.path.join(HERE,'p2.o'); binf=os.path.join(HERE,'p2.bin'); lst=os.path.join(HERE,'p2.lst')
    subprocess.check_call([f'{CC65}/ca65','-o',obj,'-l',lst,os.path.join(HERE,'p2.s')],cwd=HERE)
    subprocess.check_call([f'{CC65}/ld65','-C',os.path.join(HERE,'p2.cfg'),'-o',binf,'-Ln',os.path.join(HERE,'p2.lbl'),obj],cwd=HERE)
    code=open(binf,'rb').read()
    labels={}
    for line in open(os.path.join(HERE,'p2.lbl')):
        p=line.split(); labels[p[2].lstrip('.')]=int(p[1],16)
    rom=bytearray(open(src_rom,'rb').read())
    o=prg_off(0xF900)
    assert all(b==0 for b in rom[o:o+len(code)]), 'target area not free'
    assert len(code)<=0x600
    rom[o:o+len(code)]=code
    def patch_jsr(at, old, new):
        p=prg_off(at)
        assert rom[p]==0x20 and rom[p+1]|rom[p+2]<<8==old, hex(at)
        rom[p+1]=new&0xFF; rom[p+2]=new>>8
    patch_jsr(0xA69F,0xC291,labels['DefHook'])
    patch_jsr(0xA6A2,0xB196,labels['AtkHook'])
    open(out_rom,'wb').write(rom)
    return labels, len(code)

if __name__=='__main__':
    labels,n=build(sys.argv[1],sys.argv[2])
    print('code bytes',n,{k:hex(v) for k,v in labels.items() if k in('DefHook','AtkHook','MoveTbl','NextTbl')})
