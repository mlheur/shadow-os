%define BIOSSEGMENT 0xffff0000
%define COM1 0x3F8

bits 16
org BIOSSEGMENT

section .biosmain
  db  'shadow-bios'
init:
  mov eax,0xFEDC
  mov ebx,0xBA09
  mov ecx,0x8765
  mov edx,0x4321
  call testcom1
  jmp poweroff

testcom1:
  push eax
  mov eax,0xFADE
  call eaxout
  pop eax
  ret

eaxout:
  push edx
  mov edx,COM1

  ; use bx to hold ax for reuse
  push ebx
  mov ebx,eax

  ; print upper 4 bits
  shr eax,12
  call hexal4out

  ; print next 4 bits
  mov eax,ebx
  shr ax,8
  call hexal4out

  ; print next 4 bits
  mov eax,ebx
  shr eax,4
  call hexal4out

  ; print last 4 bits
  mov eax,ebx
  and eax,0x000F
  call hexal4out

  ; restore ax
  mov eax,ebx
  ; restore bx
  pop ebx
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