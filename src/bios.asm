%define BIOSSEGMENT    0xffff0000
%define RELOCSEGMENT   0x000f0000

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
; 0xFEDFFFFF - 0xFED00150  free
; https://revers.engineering/evading-trivial-acpi-checks/
; 0xFED00000 - ACPI hwid, 8086A201
; 0xFECFFFFF - 0x00100000  free
; 0x000FFFFF - 0x000F0000  relocated BIOS
; 0x000EFFFF - 0x00010000  free
; 0x0000FFFF - 0x00000000  first stack

signature: db 'shadow-bios',0x0

%include 'ttyout.asm'
%include 'register.asm'

%define DEBUG 1

printsignature:
  push eax
  mov eax,signature
  call sztty
  call crlf
  pop eax
  ret

init:
  call printsignature
poweroff:
  hlt
  times 0xfff0-($-$$) db 0

section .rvec
rvec:
  jmp word BIOSSEGMENT+init
  times 0x10-1-(($-$$)) hlt ; byte padding
  db 0x00