[org 0x7c00] ; MBR start address

section .text
	bootloader:
		call printrom
		call crlf
		call printFirstCall
		jmp poweroff
	
	szout:
		pusha
		loadchar:
			mov al,[esi]
			cmp al,0
			jne charout
		popa
		ret
		charout:
			mov ah,0x0e
			int 0x10
			inc esi
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
		; ebx contains the thing to print
		; ecx contains the qty of bits to print
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
	
	printFirstCall:
		; ROM:FFFFFFF0  EA 5B E0 00 F0 30 36 2F  32 33 2F 39 39 00 FC 00
		pusha
		mov esi,0x000FFF80	; print start address
		mov edi,0x00100000	; print end address
		call printram
		popa
		ret

	printrom:
		pusha
		mov esi,0xFFFFFF80
		mov edi,0x00000000
		call printram
		popa
		ret

	printram:
		; esi contains the start address
		; edi contains the end address
		pusha
		nextaddr:
			; print the addr
			mov ebx,esi
			mov ecx,32
			call printbreg
			call space
			
			mov edx,0x10 ; entries per line
			nextbyte:
				call space

				; print the data
				mov ebx,[esi]
				mov ecx,0x08 ; bits per entry
				call printbreg

				; after the halfway point, print an extra space
				cmp edx,0x09
				jne doincrement
				call space

				doincrement:
					inc esi
					dec edx
					cmp edx,0
					jne nextbyte
			call crlf
			cmp esi,edi
			jne nextaddr
		popa
		ret

	poweroff:
		call space
		mov ah,0x53
		mov al,0x07
		mov bx,0x0001
		mov cx,0x0003
		int 0x15
	
	padding:
		times 510-($-$$) db 0 ; byte padding
	magicnum:
		dw 0xaa55 ; MBR CKSUM
