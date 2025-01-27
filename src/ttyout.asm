;%define TTY_VGA               0
%define TTY_COM1               1

%ifndef COM1
  %define COM1 0x3F8
%endif

altty:
%ifdef TTY_COM1
  push edx
  mov edx,COM1
  out dx,al
  pop edx
%endif
%ifdef TTY_VGA
  mov ah,0x0e
  int 0x10
%endif
  ret

space:
  push eax
  mov al,' '
  call altty
  pop eax
  ret

crlf:
  push eax
  mov eax,_crlf
  call sztty
  pop eax
  ret
_crlf:
  db 0x0d,0x0a,0

eaxtty:
%ifdef TTY_COM1
  push edx
  mov edx,COM1
%endif
  push ecx
  push eax
  mov ecx,32
nexteaxtty:
  mov eax,[esp]
  jecxz endeaxtty
  sub ecx,4
  shr eax,cl
  and al,0x0F
  add al,0x90
  daa
  adc al,0x40
  daa
  call altty
  jmp nexteaxtty
endeaxtty:
  pop eax
  pop ecx
%ifdef TTY_COM1
  pop edx
%endif
  ret

sztty:
  pushad
  mov esi,eax
%ifdef TTY_COM1
  mov edx,COM1
%endif
nextsztty:
  mov eax,[esi]
  call altty
  inc esi
  cmp al,0
  jz endsztty
  jmp nextsztty
endsztty:
  popad
  ret
