%define BIOSSEGMENT 0xffff0000
%define COM1 0x3F8

bits 16
org BIOSSEGMENT

section .biosmain
  db  'shadow-bios'
init:
  mov ax,0xFEDC
  mov bx,0xBA09
  mov cx,0x8765
  mov dx,0x4321
  call testcom1
  jmp poweroff

testcom1:
  pusha
  mov ax,'M'
  mov dx,COM1
  call comout
  popa
  ret

comout:
  pusha
  ; eax has the byte to write
  ; edx has the CPU IO address
  out dx,ax
  popa
  ret

poweroff:
  times 0xfff0-($-$$) hlt

bits 16
section .rvec
rvec:
  jmp word BIOSSEGMENT+init
  times 0x10-1-(($-$$)) hlt ; byte padding
  db 0x00