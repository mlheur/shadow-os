%define BIOSSEGMENT   0xffff0000
%define RELOCSEGMENT  0x000f0000
org BIOSSEGMENT
section .biosmain

%define DEBUG   1

; MEMORY LAYOUT
; 0xFFFFFFFF - 0xFFFF0000  this BIOS
; 0xFEFFFFFF - 0xFEEFF400  free
; 0xFEEFF3FF - 0xFEEFF000  QEMU: is this the IVT?
; 0xFEEFFFFF - 0xFEEFE400  free
; 0xFEEFE3FF - 0xFEEFF000  more of the same?
; 0xFEExxFFF - 0xFEExx400  repeats in every segment
; 0xFEExx3FF - 0xFEExx000  repeats in every segment
; 0xFEDFFFFF - 0xFED00150  free 8086 compat
; 0xFED0014F - 0xFED00000  8086 compat IVT
; 0xFECFFFFF - 0x00100000  free
; 0x000FFFFF - 0x000F0000  relocated BIOS
; 0x000EFFFF - 0x00010000  free
; 0x0000FFFF - 0x00000000  first stack

signature: db 'shadow-bios',0x0
label_eax: db 'eax:',0
label_ebx: db 'ebx:',0
label_ecx: db 'ecx:',0
label_edx: db 'edx:',0
label_esp: db 'esp:',0
label_ebp: db 'ebp:',0
label_esi: db 'esi:',0
label_edi: db 'edi:',0
label_eip: db 'eip:',0
label_cs: db '_cs:',0
label_ss: db '_ss:',0
label_ds: db '_ds:',0
label_es: db '_es:',0
label_fs: db '_fs:',0
label_gs: db '_gs:',0
label_cr0: db 'cr0:',0

%include 'ttyout.asm'

init:
  call printsignature
  call regsout
 ; call printIVT
  jmp poweroff

testregs:
  pushad
  mov eax,0xfedcba09
  mov ebx,0x90abcdef
  mov ecx,0x87654321
  mov edx,0x12345678
  mov esi,0xffeeddcc
  mov edi,0xbbaa0099
  call regsout
  popad
  ret

regsout:
  pushad
  iCOM1
  mov eax,label_eax
  call sztty
  mov eax,[esp+28]
  call eaxtty
  space
  mov eax,label_ebx
  call sztty
  mov eax,[esp+16]
  call eaxtty
  space
  mov eax,label_ecx
  call sztty
  mov eax,[esp+24]
  call eaxtty
  space
  mov eax,label_edx
  call sztty
  mov eax,[esp+20]
  call eaxtty
  crlf
  mov eax,label_esp
  call sztty
  mov eax,[esp+12]
  call eaxtty
  space
  mov eax,label_ebp
  call sztty
  mov eax,[esp+8]
  call eaxtty
  space
  mov eax,label_esi
  call sztty
  mov eax,[esp+4]
  call eaxtty
  space
  mov eax,label_edi
  call sztty
  mov eax,[esp+0]
  call eaxtty
  crlf
  ;
  mov eax,label_eip
  call sztty
  ; https://stackoverflow.com/questions/4062403/how-to-check-the-eip-value-with-assembly-language
  call $+4
  pop eax
  call eaxtty
  space
  ;
  mov eax,label_cs
  call sztty
  mov eax,cs
  call eaxtty
  space
  ;
  mov eax,label_ss
  call sztty
  mov eax,ss
  call eaxtty
  space
  ;
  mov eax,label_ds
  call sztty
  mov eax,ds
  call eaxtty
  crlf
  ;
  mov eax,label_es
  call sztty
  mov eax,es
  call eaxtty
  space
  ;
  mov eax,label_fs
  call sztty
  mov eax,fs
  call eaxtty
  space
  ;
  mov eax,label_gs
  call sztty
  mov eax,gs
  call eaxtty
  space
  ;
  mov eax,label_cr0
  call sztty
  mov eax,cr0
  call eaxtty
  crlf
  ;
  popad
  ret

printIVT:
  pushad
  iCOM1
  mov esi,0x00000400
  mov edi,0
  jmp nextmemout
memout:
  pushad
  iCOM1
  mov esi,0
  mov edi,0
nextmemout:
  sub esi,4
  mov eax,esi
%ifndef DEBUG
  mov ebx,[esi]
  cmp ebx,edi
  jz nomemout
%endif
  call eaxtty
  space
  mov eax,ebx
  call eaxtty
  crlf
nomemout:
  cmp esi,edi
  jz endmemout
  jmp nextmemout
endmemout:
  popad
  ret

printsignature:
  push eax
  sCOM1
  mov eax,signature
  call sztty
  crlf
  eCOM1
  pop eax
  ret

poweroff:
  hlt
  times 0xfff0-($-$$) db 0

section .rvec
rvec:
  jmp word BIOSSEGMENT+init
  times 0x10-1-(($-$$)) hlt ; byte padding
  db 0x00