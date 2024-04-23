;%define TTY_VGA               0
%define TTY_COM1               1

%ifndef COM1
  %define COM1 0x3F8
%endif

%macro hex2ascii 1
  and %1,0x0F
  add %1,0x90
  daa
  adc %1,0x40
  daa
%endmacro

%ifdef TTY_VGA
  %macro altty 0
    mov ah,0x0e
    int 0x10
  %endmacro
  %macro space 0
    mov eax,0x00000e20
    int 0x10
  %endmacro
  %macro crlf 0
    mov eax,0x00000e0d
    int 0x10
    mov eax,0x00000e0a
    int 0x10
  %endmacro
%endif

%ifdef TTY_COM1
  %macro altty 0
    out dx,al
  %endmacro
  %macro space 0
    mov al,0x20
    altty
  %endmacro
  %macro crlf 0
    mov al,0x0D
    altty
    mov al,0x0A
    altty
  %endmacro
%endif

%macro iCOM1 0
  %ifdef TTY_COM1
    mov edx,COM1
  %endif
%endmacro
%macro sCOM1 0
  %ifdef TTY_COM1
    push edx
    iCOM1
  %endif
%endmacro
%macro eCOM1 0
  %ifdef TTY_COM1
    pop edx
  %endif
%endmacro

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
  hex2ascii al
  altty
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
  altty
  add esi,1
  cmp al,0
  jz endsztty
  jmp nextsztty
endsztty:
  popad
  ret
