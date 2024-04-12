[org 0x7c00] ; MBR start address

section .text
	bootloader:
		call printram
		jmp poweroff
	
	printf:
		pusha
		loadchar:
			mov al,[si]
			cmp al,0
			jne charout
		popa
		ret
		charout:
			mov ah,0x0e
			int 0x10
			add si,1
			jmp loadchar
	
	hexout:
		; How to convert hex to ascii in 8086 assembly
		; https://www.wdj-consulting.com/blog/hex2ascii-daa/
		and al,0x0f
		add al,0x90
		daa
		adc al,0x40
		daa
		mov ah,0x0e
		int 0x10
		ret
	
	printbreg:
		pusha
		nextb:
			sub cl,4
			mov eax,ebx
			shr eax,cl
			call hexout
			cmp ecx,0
			jne nextb
		popa
		ret
	
	space:
		mov ax,0x0e20
		int 0x10
		ret
	
	crlf:
		mov ax,0x0e0d
		int 0x10
	lf:
		mov ax,0x0e0a
		int 0x10
		ret
	
	printram:
		pusha
		mov edi,0
		nextaddr:
			; print the addr
			mov ebx,edi
			mov ecx,32
			call printbreg
			
			mov edx,8 ; entries per line
			nextbyte:
				call space
				; print the data
				mov ebx,[edi]
				mov ecx,32 ; bits per entry
				call printbreg
				; next four bytes
				add edi,4 ; depends on bits per entry
				sub edx,1
				cmp edx,0
				jne nextbyte
			cmp edi,0
			jne nextaddr
		popa
		ret

	poweroff:
		call space
		mov ah,0x53
		mov al,0x07
		mov bx,0x0001
		mov cx,0x03
		int 0x15
		hlt
	
	padding:
		times 510-($-$$) db 0 ; byte padding
	magicnum:
		dw 0xaa55 ; MBR CKSUM
