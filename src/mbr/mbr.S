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
/* 1000:0000 until 7000:FFFF Conventional Memory */
#define KRN_SEGM    0x1000 /* 0x10000 - 0x1FFFF */
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
    ljmp    $MBR_SEGM,                  $_init_registers
_init_registers:
    cli
    movw    %cs,                        %ax /* copy the code segment ... */
    movw    %ax,                        %ds /* ... to the data segment */
    movw    %ax,                        %es /* and to the extra segment */
    movw    %ax,                        %fs /* and to the F segment */
    movw    %ax,                        %gs /* and to the G segment */
    movw    $STK_SEGM,                  %ax /* and the stack segment */
    movw    %ax,                        %ss /* and the stack segment */
    movw    $0,                         %sp /* set the stack pointer to zero */
    movw    $0,                         %bp /* set the base pointer to zero */
    sti
save_bootdev:
    movb    %dl,                        bootdev
/*******************************************************************************
 * Initialize the serial port to 9600 8N1 */
#ifdef COM1
_init_COM1:
	movw	$0xE3,                      %ax
	movw	$COM1,                      %dx
	int     $0x14
#endif /* COM1 */
/*******************************************************************************
 * Write bootdev to the consoles */
 print_bootdev:
    movb    bootdev,                    %al
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
 * - copy the whole boot device to RAM 1000:0000
 * - blind jump to 1000:0200, the kernel starts on the bootdev block.
 * Assumptions:
 * - boot device size will be limited to 64KiB (Thanks Bill!)
 * - LBA fails, AH=1: invalid function; use CHS
 * - I don't know how end of device will be signaled, read error? */
load_all:
    movb    bootdev,                    %al
    movb    %al,                        chs_cmd.device
load_next:
check_sector_overflow:
    movb    chs_cmd.sector_cylhi,       %al
    andb    $0x3F,                      %al
    testb   63,                         %al
    je      load_next_cyl
load_next_sector:
    movb    chs_cmd.sector_cylhi,       %al
    addb    $1,                         %al
    movb    %al,                        chs_cmd.sector_cylhi
load_do_read:
    movb    $1,                         chs_cmd.readlen
    call    chs_read
    movb    chs_cmd.return,             %ah
    movb    chs_cmd.readlen,            %al
    testb   %ah,%ah
    jnz     load_failed /* ah != 0: non-zer return code */
    testb   %al,%al
    jz      load_failed /* al == 0: nothing was read */
    /* successful read */
    movb    chs_cmd.readlen,            %al
load_buffer_mover_start:
    addw    512,                        %bx
    subb    $1,                         %al
    testb   %al,%al
    jnz     load_buffer_mover_start
    jnz     load_next                   /* otherwise go back and load the next batch */
    jmp     load_finished
load_next_cyl:
    movb    chs_cmd.cylinder_lo,        %al
    addb    $1,                         %al
    jc      load_next_cylhi
    movb    %al,                        chs_cmd.cylinder_lo
    jmp     load_next
load_next_cylhi:
    movb    $0,                         chs_cmd.cylinder_lo /* reset lower 8 bits */
    movb    chs_cmd.sector_cylhi,       %al                 /* get the upper 2 bits */
    addb    $40,                        %al                 /* increment */
    jc      load_overflow
    movb    %al,                        chs_cmd.sector_cylhi
    jmp     load_next
load_overflow_msg:
    .asciz  "CHS read overflow"
load_overflow:
    prints(load_overflow_msg)
load_failed:
/*******************************************************************************
 * End MBR program */
    prints(msg_halting)
halt:
    sti
    hlt
    jmp halt
/******************************************************************************/

load_finished:
    jmp halt

/*******************************************************************************
 * CHS Read: https://fd.lod.bz/rbil/interrup/bios/1302.html#642
 * INT 13 - DISK - READ SECTOR(S) INTO MEMORY     
 *	AH = 02h
 *	AL = number of sectors to read (must be nonzero)
 *	CH = low eight bits of cylinder number
 *	CL = sector number 1-63 (bits 0-5)
 *	     high two bits of cylinder (bits 6-7, hard disk only)
 *	DH = head number
 *	DL = drive number (bit 7 set for hard disk)
 *	ES:BX -> data buffer
 * Return: CF set on error
 *	    if AH = 11h (corrected ECC error), AL = burst length
 *	CF clear if successful
 *	AH = status (see #00234)
 *	AL = number of sectors transferred (only valid if CF set for some BIOSes)
 */
chs_msg:
    .asciz  "CHS struct: "
chs_cmd.funcid:
    .byte   0x02
chs_cmd.device:
    .byte   0xA5
chs_cmd.segm:
    .word   KRN_SEGM
chs_cmd.offset:
    .word   0x0000
chs_cmd.readlen:
    .byte   0x00
chs_cmd.cylinder_lo:
    .byte   0x00
chs_cmd.sector_cylhi:
    .byte   0x00
chs_cmd.head:
    .byte   0x00
chs_cmd.return:
    .byte   0x00
/*  02
    80
    0010
    0000
    01
    00
    01
    00
    00 */
/*  02
    80
    0010
    0000
    01
    02
    01
    00
    00 */
chs_read:
    /**** SAVE STATE ****/
    pushw   %ax
    pushw   %bx
    pushw   %cx
    pushw   %dx
    pushw   %si
    prints(chs_msg)
    movw    $chs_cmd.funcid,            %si
    movw    $(chs_read-chs_cmd.funcid), %cx
chs_print_next:
    lodsb
    call    byte_to_ascii_out
    subw    $1,                         %cx
    testw   %cx,                        %cx
    jnz     chs_print_next
    /*** PREP THE THING ****/
    movw    chs_cmd.segm,               %ax /* for setting es ... */
    movw    %ax,                        %es /* ... segment to 1000:0000 */
    movb    chs_cmd.device,             %dl /* whatever device we booted from */
    movb    chs_cmd.head,               %dh /* head zero */
    movb    chs_cmd.sector_cylhi,       %cl /* sector 0, still cylinder zero */
    movb    chs_cmd.cylinder_lo,        %ch /* Read starting on cylinder zero */
    movw    chs_cmd.offset,             %bx /* offset 1000:0000 */
    movb    chs_cmd.readlen,            %al /* Read 0x80 bytes at a time */
    movb    chs_cmd.funcid,             %ah /* CHS Read function */
    /*** DO THE THING ***/
    int     $0x13
    movb    %al,                        chs_cmd.readlen
    movb    %ah,                        chs_cmd.return
    jc      chs_read_failed
chs_read_success:
    /* Give some feedback out the console */
    movb    dot,                        %al
    call    charout
    jmp     chs_read_return
chs_read_failed:
    prints(msg_chs_failed)
    call    word_to_ascii_out
    prints(crlf)
chs_read_return:
    /**** LOAD STATE ****/
    popw    %si
    popw    %dx
    popw    %cx
    popw    %bx
    popw    %ax
    ret


/*******************************************************************************
 * When data is copied from disk to ram at krn_segm, the following tty-output
 * routines can be available as kernel calls with cs:=KRN_SEGM
 ******************************************************************************/



/*******************************************************************************
 * Function: byte_to_ascii_out */
byte_to_ascii_out:
    pushw   %dx                                 /* save */
    movw    %ax,                        %dx     /* save */
    jmp     _byte_to_ascii_out
/*******************************************************************************
 * Function: word_to_ascii_out
 * Purpose: convert two-byte into to ascii, then send it out */
word_to_ascii_out:
    pushw   %dx                                 /* save */
    movw    %ax,                        %dx     /* save */
    shrw    $12,                        %ax     /* bits 0xF000 */
    call    nibble_to_ascii_out
    movw    %dx,                        %ax     /* restore */
    shrw    $8,                         %ax     /* bits 0x0F00 */
    call    nibble_to_ascii_out
    movw    %dx,                        %ax     /* restore */
_byte_to_ascii_out:
    shr     $4,                         %al     /* bits 0x00F0 */
    call    nibble_to_ascii_out
    movw    %dx,                        %ax     /* bits 0x000F */
    call    nibble_to_ascii_out
    movw    %dx,                        %ax     /* restore */
    popw    %dx                                 /* restore */
    ret
/*******************************************************************************
 * Function: nibble_to_ascii_out */
nibble_to_ascii_out:
    andw    $0x000F,                    %ax     /* filter the nibble */
    addb    $0x90,                      %al     /* setup for decmial arithmatic, int2hex */
    daa                                         /* crank 1, int2hex */
    adc     $0x40,                      %al     /* reset for decmial arithmatic, int2hex */
    daa                                         /* crank 2, int2hex */
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
dash:
    .byte   '-'


bootdev:
    .byte   0xA5

var8:
    .byte   0x00
var16:
    .word   0x0000

/*******************************************************************************
 * the last 2 bytes in the sector 0 contain the signature */
	. = 0x1fe
signature:
	.short	0xAA55
	. = 0x200
_krn_init:
/******************************************************************************/
