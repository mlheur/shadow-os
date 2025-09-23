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
 * - copy the whole boot device to RAM 0050:0000
 * - blind jump to 0050:0200, the kernel starts on the bootdev block.
 * Assumptions:
 * - boot device size will be limited to 64KiB (Thanks Bill!)
 * - LBA fails, AH=1: invalid function; use CHS
 * - I don't know how end of device will be signaled, read error? */
load_all:
/* CHS Read: https://fd.lod.bz/rbil/interrup/bios/1302.html#642
INT 13 - DISK - READ SECTOR(S) INTO MEMORY     
	AH = 02h
	AL = number of sectors to read (must be nonzero)
	CH = low eight bits of cylinder number
	CL = sector number 1-63 (bits 0-5)
	     high two bits of cylinder (bits 6-7, hard disk only)
	DH = head number
	DL = drive number (bit 7 set for hard disk)
	ES:BX -> data buffer
Return: CF set on error
	    if AH = 11h (corrected ECC error), AL = burst length
	CF clear if successful
	AH = status (see #00234)
	AL = number of sectors transferred (only valid if CF set for some BIOSes)
*/
chs_read_80:
    /**** SAVE STATE ****/
    pushw   %ax
    pushw   %bx
    pushw   %cx
    pushw   %dx
    /*** PREP THE THING ****/
    movw    $KRN_SEGM,  %ax /* for setting es */
    movw    %ax,        %es /* segment 0050:0000 */
    movb    $0x00,      %dh /* head zero */
    movb    bootdev,    %dl /* whatever device we booted from */
    movb    $0x00,      %ch /* Read starting on cylinder zero */
    movb    $0x00,      %cl /* sector 0, still cylinder zero */
    movw    $0x0000,    %bx /* offset 0050:0000 */
    movb    $0x02,      %ah /* CHS Read function */
    movb    $0x80,      %al /* Read 0x80 bytes at a time */
    /*** DO THE THING ***/
    int     $0x13
    jnc     chs_read_end
chs_read_failed:
    prints(msg_chs_failed)
    call    word_to_ascii_out
    prints(crlf)
    jmp     halt
chs_read_end:
    /* Give some feedback out the console */
    movb    dot,        %al
    call    charout
    /**** LOAD STATE ****/
    popw    %ax
    popw    %bx
    popw    %cx
    popw    %dx

/*******************************************************************************
 * End MBR program */
    prints(msg_halting)
halt:
    sti
    hlt
    jmp halt
/******************************************************************************/


/*******************************************************************************
 * Function: byte_to_ascii_out */
byte_to_ascii_out:
    pushw   %dx                 /* save */
    movw    %ax,        %dx     /* save */
    jmp     _byte_to_ascii_out
/*******************************************************************************
 * Function: word_to_ascii_out
 * Purpose: convert two-byte into to ascii, then send it out */
word_to_ascii_out:
    pushw   %dx                 /* save */
    movw    %ax,        %dx     /* save */
    shrw    $12,        %ax     /* bits 0xF000 */
    call    nibble_to_ascii_out
    movw    %dx,        %ax     /* restore */
    shrw    $8,         %ax     /* bits 0x0F00 */
    call    nibble_to_ascii_out
    movw    %dx,        %ax     /* restore */
_byte_to_ascii_out:
    shr     $4,         %al     /* bits 0x00F0 */
    call    nibble_to_ascii_out
    movw    %dx,        %ax     /* bits 0x000F */
    call    nibble_to_ascii_out
    movw    %dx,        %ax     /* restore */
    popw    %dx                 /* restore */
    ret
/*******************************************************************************
 * Function: nibble_to_ascii_out */
nibble_to_ascii_out:
    andw    $0x000F,    %ax     /* filter the nibble */
    addb    $0x90,      %al     /* setup for decmial arithmatic, int2hex */
    daa                         /* crank 1, int2hex */
    adc     $0x40,      %al     /* reset for decmial arithmatic, int2hex */
    daa                         /* crank 2, int2hex */
    /* int2hex complete, fall through to charout */
/*******************************************************************************
 * Function: charout
 * Purpose: write a character to serial and/or video consoles
 * Inputs: al: the 8-bit ascii character to write
 * Outputs: None */
charout:
#ifdef VDEO
    pushw   %bx
    movb    $0x0e,  %ah
    movw    $VDEO,  %bx
    int     $0x10
    popw    %bx
#endif /* VDEO */
#ifdef COM1
    pushw   %dx
    movb    $0x01,  %ah
    movw    $COM1,  %dx
    int     $0x14
    popw    %dx
#endif /* COM1 */
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
    call    charout
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
msg_chs_failed:
    .asciz  "chs read failed: ax="
osname:
    .ascii  "\r\nshadow-os"
crlf:
    .asciz  "\r\n"
dot:
    .byte   '.'


bootdev:
    .byte   0xA5



/*******************************************************************************
 * the last 2 bytes in the sector 0 contain the signature */
	. = 0x1fe
signature:
	.short	0xAA55
	. = 0x200
_krn_init:
/******************************************************************************/
