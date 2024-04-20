%define BIOSSEGMENT 0xffff0000
%define COM1 0x3F8

org BIOSSEGMENT

section .biosmain
signature:
  db  'shadow-bios',0x0
init:
  call printsignature
  call regsout
  jmp poweroff

db 'eax',0
db 'ebx',0
db 'ecx',0
db 'edx',0
regsout:
  pusha
  push eax
  mov eax,regsout-16
  call szout
  call space
  pop eax
  call eaxout
  call crlf
  mov eax,regsout-12
  call szout
  call space
  mov eax,ebx
  call eaxout
  call crlf
  mov eax,regsout-8
  call szout
  call space
  mov eax,ecx
  call eaxout
  call crlf
  mov eax,regsout-4
  call szout
  call space
  mov eax,edx
  call eaxout
  call crlf
  popa
  ret

memout:
  push eax
  push ebx
  push esi
  mov esi,0
nextmem:
  sub esi,4
  mov eax,esi
  mov ebx,[esi]
  cmp ebx,0
  jz nomemout
  call eaxout
  call space
  mov eax,ebx
  call eaxout
  call crlf
nomemout:
  cmp esi,0
  jz endmemout
  jmp nextmem
endmemout:
  pop esi
  pop ebx
  pop eax
  ret

printsignature:
  push eax
  mov eax,signature
  call szout
  call crlf
  pop eax
  ret

szout:
  push esi
  push eax
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
  ret

eaxout:
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
  ret

hexal4out:
  and al,0x0F
  add al,0x90
  daa
  adc al,0x40
  daa
  call comout
  ret

crlf:
  push eax
  mov eax,0xd
  call comout
  mov eax,0xa
  call comout
  pop eax
  ret

space:
  push eax
  mov eax,' '
  call comout
  pop eax
  ret

comout:
  ; ax has the byte to write
  push edx
  mov edx,COM1
  out dx,ax
  pop edx
  ret

poweroff:
  hlt
  times 0xfff0-($-$$) db 0

section .rvec
rvec:
  jmp word BIOSSEGMENT+init
  times 0x10-1-(($-$$)) hlt ; byte padding
  db 0x00