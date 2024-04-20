%define BIOSSEGMENT 0xffff0000
%define COM1 0x3F8

bits 16
org BIOSSEGMENT

section .biosmain
signature:
  db  'shadow-bios',0x0d,0x0a,0x00
init:
  call testcom1
  jmp poweroff

testcom1:
  push eax
  mov eax,signature
  call szout
  pop eax
  ret

szout:
  push edx
  push esi
  push eax
  mov edx,COM1
  mov esi,eax
nextchar:
  mov al,[esi]
  cmp al,0x00
  jz szisout
  call comout
  add esi,1
  jmp nextchar
szisout:
  pop eax
  pop esi
  pop edx
  ret

eaxout:
  push edx
  mov edx,COM1
  push ecx
  mov ecx,32
  push eax
nibbleout:
  mov eax,[ss:esp]
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