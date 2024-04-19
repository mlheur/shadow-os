%define BIOSSEGMENT 0xffff0000

bits 16
org BIOSSEGMENT

section .biosmain
  db  'shadow-bios'
init:
  mov ax,0xFEDC
  mov bx,0xBA09
  mov cx,0x8765
  mov dx,0x4321
  jmp poweroff

poweroff:
  times 0xfff0-($-$$) hlt

bits 16
section .rvec
rvec:
  jmp word BIOSSEGMENT+init
  times 0x10-1-(($-$$)) hlt ; byte padding
  db 0x00