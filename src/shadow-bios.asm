bits 16
org 0xFFFF0000
    db  'MarcBIOS'
    init:
        cli
        mov ax,cs
        mov ss,ax
        mov ds,ax
        mov es,ax
        mov fs,ax
        mov gs,ax
        hlt

    padding:
		times 0x8000-(($-$$)/2)-8 dw 0x3CC3 ; byte padding

    rvec:
        jmp word 0xFFFF:0x0000+init
		times 0x10000-(($-$$)) db 0xFF ; byte padding
