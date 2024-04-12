[org 0x7c00] ; MBR start address

section .text
	bootloader:
		call printram
		jmp  halt
	
	printram:
		pusha          ; push the stack on call
		mov si,   0x00 ; start counting at address zero
		
	printnext:
		mov ah,   0x0E ; BIOS command to move our cursor forward
		
		; How to convert hex to ascii in 8086 assembly
		; https://www.wdj-consulting.com/blog/hex2ascii-daa/
		
		; print the high order nibble
		mov al,[si]
		shr al,0x4
		add al,0x90
		daa
		adc al,0x40
		daa
		int 0x10
		
		; print the low order nibble
		mov al,[si]
		and al,0x0f
		add al,0x90
		daa
		adc al,0x40
		daa
		int 0x10
		
		; newline
		mov al,0x0D
		int 0x10
		mov al,0x0A
		int 0x10
		
		; increment the counter
		add si,0x01
		
		; test for completion
		cmp si,0x0400 ; stop after 1k
		jne printnext ; if not, print next character
		popa          ; pop the stack before returning
		ret           ; else return
	
	halt:
		jmp $
	
	padding:
		times 510-($-$$) db 0 ; byte padding
	magicnum:
		dw 0xAA55             ; magic MBR number
