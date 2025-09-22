/*******************************************************************************
 * BIOS hands over to MBR:
 * The only things that are (nearly) certain are that
 *  - the bootsector code is loaded and running at physical address 0x7c00,
 *  - the CPU is in 16-bit Real Mode,
 *  - the CPU register called dl contains the "drive number",
 *  - and that only 512 bytes of the bootsector have been loaded.
 * -- https://wiki.osdev.org/System_Initialization_(x86)
 ******************************************************************************/

/*******************************************************************************
 * Missing in the above: https://wiki.osdev.org/Memory_Map_(x86) */
/* 0000:0000 until 0000:03FF IVT
/* 0040:0000 until 0040:00FF BDA */
/* 0040:0100 == 0050:0000 */
/* 0050:0000 until 7000:FFFF Conventional Memory */
#define KRN_SEGM    0x0050 /* 0x00500 - 0x104FF */
#define MBR_SEGM    0x07C0 /* BIOS loads us here, 0x07C00, within KRN_SEGM */
#define STK_SEGM    0x7000 /* 7000:FFFF == 0x7FFFF stack at top of low RAM */
/* 8000:0000 until 9000:FFFF EBDA */
/* A000:0000 until B000:FFFF VRAM */
/* C000:0000 until C000:7FFF BIOS Expansion */
/* C000:8000 until E000:FFFF VGA BIOS */
/* F000:0000 until F000:FFFF Motherboard BIOS */
/******************************************************************************/

#define COM1 0x00
#define VDEO 0x01

#define prints(s)   pushw %si; movw $(s), %si; call strout; popw %si

	.text
	.code16

/*******************************************************************************
 * MBR */
    .globl _start
_start:
    ljmp    $MBR_SEGM,  $_init_registers
_init_registers:
    cli
    movw    %cs,        %ax /* copy the code segment ... */
    movw    %ax,        %ds /* ... to the data segment */
    movw    %ax,        %es /* and to the extra segment */
    movw    %ax,        %fs /* and to the F segment */
    movw    %ax,        %gs /* and to the G segment */
    movw    $STK_SEGM,  %ax /* and the stack segment */
    movw    %ax,  %ss /* and the stack segment */
    movw    $0,         %sp /* set the stack pointer to zero */
    movw    $0,         %bp /* set the base pointer to zero */
    sti
save_bootdev:
    movb    %dl,        bootdev
/*******************************************************************************
 * Initialize the serial port to 9600 8N1 */
#ifdef COM1
_init_COM1:
	movw	$0xE3,      %ax
	movw	$COM1,      %dx
	int     $0x14
#endif /* COM1 */
/*******************************************************************************
 * Write bootdev to the consoles */
 print_bootdev:
    movb    bootdev,    %al
    call    byte_to_ascii_out
/*******************************************************************************
 * Write the OS name to the consoles */
 print_osname:
    prints(osname)
/*******************************************************************************
 * Most HDD MBRs relocate themselves to nearby, maybe cs:=0x7A0.
 * shadow-os will do something completely different, there's no attempt at
 * portability since this is an educational OS built to run in 486 VM.
 * Strategy:
 * - copy the whole boot device to RAM 0040:0000
 * - blind jump to 0040:0200
 * Assumptions:
 * - boot device size will be limited to 64KiB (Thanks Bill!)
 * - LBA addressing is avaialble
 * - I don't know how end of device will be signaled, read error? */
load_all:
	/*
	 * BIOS call "INT 0x13 Extensions Extended Read"
	 *	Call with	%ah = 0x42
	 *			%dl = drive (0x80 for 1st hd, 0x81 for 2nd, etc)
	 *			%ds:%si = segment:offset of command packet
	 *	Return:
	 *			carry set: failure
	 *				%ah = error code (0x01, invalid func)
	 *				command packet's sector count field set
	 *				to the number of sectors successfully
	 *				transferred
	 *			carry clear: success
	 *				%ah = 0 (success)
	 *	Command Packet:
	 *			0x0000	BYTE	packet size (0x10 or 0x18)
	 *			0x0001	BYTE	reserved (should be 0)
	 *			0x0002	WORD	sectors to transfer (max 127)
	 *			0x0004	DWORD	seg:offset of transfer buffer
	 *			0x0008	QWORD	starting sector number
	 */
	movb	$0x42,              %ah
    movb    bootdev,            %dl
	movw	lba_cmd_packet,     %si
	int     $0x13
    jnc     lba_read_success
lba_read_failed:
    pushw   %ax                 /* save ah, it has return code */
    prints(msg_readfailed)
lba_read_failed1:
    popw    %ax                 /* restore ah */
    shrw    $8,%ax              /* print ah, the return code */
    call    byte_to_ascii_out
    prints(msg_sectorcount)
    movw    lba_cmd_sector_count,   %ax
    call    word_to_ascii_out
    prints(msg_sectorstart)
    movw    lba_cmd_sector_start,   %ax
    call    word_to_ascii_out
    prints(crlf)
    jmp     halt
lba_false_read_success:
    pushw   %ax
    prints(msg_falsreadfailed)
    jmp     lba_read_failed1
lba_read_success:
    prints(msg_readsuccess)
    testb   %ah,%ah
    jnz     lba_false_read_success
/*******************************************************************************
 * End MBR program */
    prints(msg_halting)
halt:
    sti
    hlt
    jmp halt
/******************************************************************************/


/*******************************************************************************
 * Function: word_to_ascii_out
 * Purpose: convert int to ascii before falling through to charout */
word_to_ascii_out:
    pushw   %ax
    shrw    $8,%ax              /* hight byte */
    call    byte_to_ascii_out
    popw    %ax                 /* low byte */
    call    byte_to_ascii_out
    ret
/*******************************************************************************
 * Function: byte_to_ascii_out */
byte_to_ascii_out:
    pushw   %ax
    shr     $4,         %al     /* handle high nibble */
    call    nibble_ascii_out
    popw    %ax                 /* handle low nibble */
    call    nibble_ascii_out
    ret
nibble_ascii_out:
    andw    $0xF,       %ax     /* filter the nibble */
    addb    $0x90,      %al     /* setup for decmial arithmatic, int2hex */
    daa                         /* crank 1, int2hex */
    adc     $0x40,      %al     /* reset for decmial arithmatic, int2hex */
    daa                         /* crank 2, int2hex */
    call    charout             /* int2hex complete */
    ret
/******************************************************************************/


/*******************************************************************************
 * Function: charout
 * Purpose: write a character to serial and/or video consoles
 * Inputs: al: the 8-bit ascii character to write
 * Outputs: None */
charout:
    pushw   %ax
#ifdef COM1
    pushw   %dx             /* save state of dx */
    movb    $0x01,  %ah     /* for int14h */
    movb    $COM1,  %dl     /* for int14h */
    int     $0x14
    popw    %dx             /* restore state of DX */
#endif /* COM1 */
#ifdef VDEO
    pushw   %bx
    movb    $0x0e,  %ah
    movw    $VDEO,  %bx
    int     $0x10
    popw    %bx
#endif /* VDEO */
    popw    %ax
    ret
/******************************************************************************/


/*******************************************************************************
 * Function: strout
 * Purpose: write a null-terminated string through charout
 * Parameters: si: the address of the first character
 * Outputs: None. */
strout:
    pushw   %ax             /* save state */
    jmp     strout_2
strout_1:
    call    charout         /* print the character */
strout_2:
    lodsb                   /* copy the character to al, increment si */
    testb   %al,    %al     /* test if it is the null terminator */
    jnz     strout_1        /* else move to the next character */
strout_fin:
    popw    %ax             /* restore state */
    ret
/******************************************************************************/


msg_halting:
    .asciz  "halting"
msg_readfailed:
    .asciz  "lba read failed: ah="
msg_falsreadfailed:
    .asciz  "lba false read: ah="
msg_readsuccess:
    .asciz  "lba read success"
msg_sectorcount:
    .asciz  " sector count="
msg_sectorstart:
    .asciz  " sector start="
osname:
    .ascii  "\r\nshadow-os"
crlf:
    .asciz  "\r\n"
dot:
    .byte   '.'


bootdev:
    .byte   0xA5


lba_cmd_packet:
	.byte 0x10          /* 0x0000 BYTE  packet size (0x10 or 0x18) */
	.byte 0x00          /* 0x0001 BYTE  reserved (should be 0) */
lba_cmd_sector_count:
	.word 1             /* 0x0002 WORD  sectors to transfer (max 127) */
    .word KRN_SEGM      /* 0x0004 WORD  seg: of transfer buffer */
	.word 0x0000        /* 0x0006 WORD  :offset of transfer buffer */
lba_cmd_sector_start:
    .long 0x00000000    /* 0x0008 QWORD starting sector number */
end_of_code:
    nop


/*******************************************************************************
 * the last 2 bytes in the sector 0 contain the signature */
	. = 0x1fe
signature:
	.short	0xAA55
	. = 0x200
_krn_init:
/******************************************************************************/
