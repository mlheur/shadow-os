%define BIOSSEGMENT 0xffff0000
%define COM1 0x3F8

org BIOSSEGMENT

section .biosmain
signature:
  db  'shadow-bios',0x0
regstrings:
  db 'eax',0
  db 'ebx',0
  db 'ecx',0
  db 'edx',0
  db 'esp',0
  db 'ebp',0
  db 'esi',0
  db 'edi',0

init:
  cli
  call printsignature
  call testregs
  jmp poweroff

testregs:
  push eax
  push ebx
  push ecx
  push edx
  push esi
  push edi
  mov eax,0xfedcba09
  mov ebx,0x90abcdef
  mov ecx,0x87654321
  mov edx,0x12345678
  mov esi,0xffeeddcc
  mov edi,0xbbaa0099
  call regsout
  pop edi
  pop esi
  pop edx
  pop ecx
  pop ebx
  pop eax
  ret

regsout:
  pushad
  mov eax,regstrings
  call szout
  call space
  mov eax,[esp+28]
  call eaxout
  call space
  mov eax,regstrings+4
  call szout
  call space
  mov eax,[esp+16]
  call eaxout
  call space
  mov eax,regstrings+8
  call szout
  call space
  mov eax,[esp+24]
  call eaxout
  call space
  mov eax,regstrings+12
  call szout
  call space
  mov eax,[esp+20]
  call eaxout
  call crlf
  mov eax,regstrings+16
  call szout
  call space
  mov eax,[esp+12]
  call eaxout
  call space
  mov eax,regstrings+20
  call szout
  call space
  mov eax,[esp+8]
  call eaxout
  call space
  mov eax,regstrings+24
  call szout
  call space
  mov eax,[esp+4]
  call eaxout
  call space
  mov eax,regstrings+28
  call szout
  call space
  mov eax,[esp+0]
  call eaxout
  call crlf
  popad
  ret

memout:
  push eax
  push ebx
  push esi
  mov esi,0
nextmemout:
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
  jmp nextmemout
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
nextszout:
  mov al,[esi]
  cmp al,0x00
  jz endszout
  call comout
  add esi,1
  jmp nextszout
endszout:
  pop eax
  pop esi
  ret

eaxout:
  push ecx
  mov ecx,32
  push eax
nexteaxout:
  mov eax,[ss:esp]
  jecxz endeaxout
  sub ecx,4
  shr eax,cl
  call hex2asciiout
  jmp nexteaxout
endeaxout:
  pop eax
  pop ecx
  ret

hex2asciiout:
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