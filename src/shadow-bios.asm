%define BIOSSEGMENT 0xffff0000
%define COM1 0x3F8

bits 16
org BIOSSEGMENT

section .biosmain
  db  'shadow-bios'
init:
  call testcom1
  jmp poweroff

testcom1:
  push eax
  mov eax,0xCAB1FADE
  call eaxout
  pop eax
  ret

eaxout:
  push edx
  mov edx,COM1
  push ecx
  mov ecx,32
  push eax
nibbleout:
  mov eax,[SS:ESP]
  jecxz eaxisout
  sub ecx,4
  shr eax,cl
  call hexal4out
  jmp nibbleout
eaxisout:
  pop eax
  pop ecx
  pop edx
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
  ; ax has the byte to write
  ; dx has the CPU IO address
  out dx,ax
  ret

poweroff:
  times 0xfff0-($-$$) hlt

bits 16
section .rvec
rvec:
  jmp word BIOSSEGMENT+init
  times 0x10-1-(($-$$)) hlt ; byte padding
  db 0x00