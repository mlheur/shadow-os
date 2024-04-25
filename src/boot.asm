org 0x00007c00
jmp mbr

%define DELAYLEN      0xFC000000

;https://wiki.gentoo.org/wiki/BIOS
;BIOS Memory Map
;Once the BIOS has been initialized, RAM below 1MiB looks like this:
;Start	Stop	Size	Description
;0x00000000	0x000003ff	1KiB	Interrupt Vector Table (IVT) in Protected Mode.
;0x00000400	0x000004ff	256B	BIOS Data Area (BDA).
;0x00000500	0x00007bff	29.75KiB	Conventional memory available to programs.
;0x00007c00	0x00007dff	512B	Reserved for Boot Sector.
;0x00007e00	0x0007ffff	480.5KiB	Conventional memory available to programs.
;0x00080000	0x0009ffff	128KiB	Extended BIOS Data Area (EBDA).
;0x000a0000	0x000bffff	128KiB	Video memory.
;0x000c0000	0x000c7fff	32KiB	Video card BIOS.
;0x000c8000	0x000effff	160KiB	BIOS Extensions.
;0x000f0000	0x000fffff	64KiB	Motherboard BIOS

release: db 'shadow-boot',0 ; identify ourselves
label_eax: db 'eax:',0
label_ebx: db 'ebx:',0
label_ecx: db 'ecx:',0
label_edx: db 'edx:',0
label_esp: db 'esp:',0
label_ebp: db 'ebp:',0
label_esi: db 'esi:',0
label_edi: db 'edi:',0

%include 'ttyout.asm'

regsout:
  pushad
  mov eax,label_eax
  call sztty
  mov eax,[esp+28]
  call eaxtty
  call space
  mov eax,label_ebx
  call sztty
  mov eax,[esp+16]
  call eaxtty
  call space
  mov eax,label_ecx
  call sztty
  mov eax,[esp+24]
  call eaxtty
  call space
  mov eax,label_edx
  call sztty
  mov eax,[esp+20]
  call eaxtty
  call crlf
  mov eax,label_esp
  call sztty
  mov eax,[esp+12]
  call eaxtty
  call space
  mov eax,label_ebp
  call sztty
  mov eax,[esp+8]
  call eaxtty
  call space
  mov eax,label_esi
  call sztty
  mov eax,[esp+4]
  call eaxtty
  call space
  mov eax,label_edi
  call sztty
  mov eax,[esp+0]
  call eaxtty
  call crlf
  popad
  ret

mbr:
  call regsout
  mov eax,release
  call sztty
  call crlf
  mov eax,0xfadecab1
  call eaxtty
  call crlf
  mov ecx,DELAYLEN
delay:
  add ecx,1
  jecxz poweroff
  jmp delay
poweroff:
  mov eax,0x5307
  mov ebx,0x0001
  mov ecx,0x0003
  mov edx,0x0000
  int 0x15
mbrpads: times 510-($-$$) hlt ; pad with halt to end of mbr
mbrsign: dw 0xaa55
