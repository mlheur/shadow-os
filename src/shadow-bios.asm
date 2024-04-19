bits 16
org 0xFFFF0000

section .biosmain
	db	'(C) mlheur@gmail.com'
	init:
		mov eax,0xFEDC
		mov ebx,0xBA09
		mov ecx,0x8765
		mov edx,0x4321
		hlt
	
padding:
		times 0xfff0-($-$$) hlt

bits 16
section .rvec
	rvec:
		jmp word 0xFFFF0000+init
		times 0x10-1-(($-$$)) hlt ; byte padding
		db 0x00
