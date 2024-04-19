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
  mov dx,COM1
  mov ax,0xFADE
  call axout
  popa
  ret

axout:
  ; use bx to hold ax for reuse
  push bx
  mov bx,ax

  ; print upper 4 bits
  and ax,0xF000
  shr ax,12
  call hexal4out

  ; print next 4 bits
  mov ax,bx
  and ax,0x0F00
  shr ax,8
  call hexal4out

  ; print next 4 bits
  mov ax,bx
  and ax,0x00F0
  shr ax,4
  call hexal4out

  ; print last 4 bits
  mov ax,bx
  and ax,0x000F
  call hexal4out

  ; restore ax
  mov ax,bx
  ; restore bx
  pop bx

  ret

hexal4out:
  and al,0x0F
  add al,0x90
  daa
  adc al,0x40
  daa
  call comout
  ret

comout:
  pusha
  ; ax has the byte to write
  ; dx has the CPU IO address
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