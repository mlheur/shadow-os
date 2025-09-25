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
 * Missing in the above, taken from : https://wiki.osdev.org/Memory_Map_(x86) */
/* 0000:0000 until 0000:03FF IVT
/* 0040:0000 until 0040:00FF BDA */
/* 0040:0100 == 0050:0000 */
/* 0050:0000 until 7000:FFFF Conventional Memory */
#define MBR_SEGM 0x07C0 /* BIOS loads us here */
#define KRN_SEGM 0x1000 /* 0x10000 - 0x1FFFF */
#define STK_SEGM 0x7000 /* 7000:FFFF == 0x7FFFF stack at top of low RAM */
/* 8000:0000 until 9000:FFFF EBDA */
/* A000:0000 until B000:FFFF VRAM */
/* C000:0000 until C000:7FFF BIOS Expansion */
/* C000:8000 until E000:FFFF VGA BIOS */
/* F000:0000 until F000:FFFF Motherboard BIOS */
/******************************************************************************/

#define COM1 0x00
#define VDEO 0x01

#define prints(s)   pushw %si; movw $(s), %si; call strout; popw %si

/*******************************************************************************
 * MBR */
	.text
	.code16
    .globl  _start
_start:         ljmp    $MBR_SEGM,      $init_segments /* set cs register */
init_segments:  cli     /* Not strictly necessary, seems like good hygiene */
                movw    %cs,            %ax /* copy the code segment ... */
                movw    %ax,            %ds /* ... to the data segment */
                movw    %ax,            %es /* and to the extra segment */
                movw    %ax,            %fs /* and to the F segment */
                movw    %ax,            %gs /* and to the G segment */
                movw    $STK_SEGM,      %ax /* and the stack segment */
                movw    %ax,            %ss /* and the stack segment */
                xorw    %ax,            %ax /* get a zero */
                movw    %ax,            %sp /* set the stack pointer to zero */
                movw    %ax,            %bp /* set the base pointer to zero */
                sti     /* off to the races */
/******************************************************************************/


/*******************************************************************************
 * We'll need this a few times during bootloading */
save_bootdev:   movb    %dl,            bootdev
/******************************************************************************/


/*******************************************************************************
 * Initialize the com port */
#ifdef COM1
init_COM1:      movw	$0xE3,          %ax
	            movw	$COM1,          %dx
	            int     $0x14
#endif /* COM1 */
/******************************************************************************/


print_osname:   prints(osname)


/*******************************************************************************
 * Initialize the boot device geometry */
inquire_geom:   movb    $0x08,          %ah
                movb    bootdev,        %dl
                int     $0x13
save_geom:      movb    %ch,            disk_data.max_cylinder_lo
                movb    %cl,            disk_data.max_sector_cylhi
                movb    %dh,            disk_data.max_head
/******************************************************************************/


/*******************************************************************************
 * Most HDD MBRs relocate themselves to nearby, maybe cs:=0x7A0.
 * shadow-os will do something completely different, there's no attempt at
 * portability since this is an educational OS built to run in 486 VM.
 * Strategy:
 * - copy the whole boot device to RAM 1000:0000
 * - blind jump to 1000:0200, the kernel starts on the bootdev block.
 * Assumptions:
 * - boot device size will be limited to 64KiB (Thanks Bill!)
 * - I don't know how end of device will be signaled, read error? */
load_bootdev_to_krn_segm:
    movb    bootdev,                    %al
    movb    %al,                        chs_cmd.device
load_next_sector:
    movb    chs_cmd.sector_cylhi,       %al
check_sector_overflow:
    andw    $0x3F,                      %ax
    xorw    $0x3F,                      %ax
    jz      load_next_cyl /* will reset the sector for us */
really_load_next_sector:
    movb    chs_cmd.sector_cylhi,       %al /* read the current sector ... */
    addb    $1,                         %al /* ... to increment it ... */
    movb    %al,                        chs_cmd.sector_cylhi /* ... and save it in the structure */
read_sector:
    movb    $1,                         chs_cmd.readlen /* set the desired read amount */
    call    chs_read                    /* read the sector */
    movb    chs_cmd.return,             %ah /* save the return code */
    movb    chs_cmd.readlen,            %al /* save the amount read */
    testb   %ah,%ah                     /* the interrupt returned error ... */
    jnz     load_failed                 /* ah != 0: ... bail */
    testb   %al,%al                     /* check how much was read ... */
    jz      load_failed                 /* al == 0: ... nothing was read, bail */
    /* successful read, al still contains the qty of sectors successfully read */
    movw    chs_cmd.offset,             %bx
increment_buffer_pointer:
    addw    $512,                       %bx /* each sector is 512 bytes, advance the pointer ... */
    subb    $1,                         %al /* decrement the sectors_read counter */
    testb   %al,%al                     /* check if we counted all of them ... */
    jnz     increment_buffer_pointer    /* ... otherwise go back and move the pointer more */
    movw    %bx,                        chs_cmd.offset
    /* buffer pointer is advanced, go read more data */
    jmp     load_next_sector
load_next_cyl:
    movb    chs_cmd.cylinder_lo,        %al /* find the current cylinder */
    movb    disk_data.max_cylinder_lo,  %bl /* check if we hit the bios cylinder limit ... */
    andb    $63,                        %bl
    testb   %bl,                        %al
    jz      load_next_cylhi
    movb    chs_cmd.cylinder_lo,        %al /* find the current cylinder */
    addb    $1,                         %al /* increment it */
    jc      load_next_cylhi             /* wrap the upper bits if we carried */
    movb    %al,                        chs_cmd.cylinder_lo /* else save the new value and carry on */
    /* the high two bits are OK */
    /* the six bits of the sector are decimal 63 */
    movb    chs_cmd.sector_cylhi,       %al /* read the high two bits */
    andb    $0xC1,                      %al /* just the two bits, and force the sector to 1 */
    movb    %al,                        chs_cmd.sector_cylhi
    jmp     read_sector
load_next_cylhi:
    movb    $0,                         chs_cmd.cylinder_lo /* reset lower eight bits */
    movb    chs_cmd.sector_cylhi,       %al                 /* get the upper two bits */
    testb   disk_data.max_cylinder_lo,  %al                 /* test if we hit the limit ... */
    jz      load_next_head                                  /* ... and go to next head */
    addb    $40,                        %al                 /* increment just those two bits */
    jc      load_next_head              /* reminiscent of Towers of Hanoi */
    movb    %al,                        chs_cmd.sector_cylhi /* else save it back before invoking the interrupt */
    jmp     read_sector                 /* invoke the interrupt */
load_next_head:
    xorb    %al,%al /* get a zero */
    movb    %al,                        chs_cmd.sector_cylhi /* reset the sector, cylinder */
    movb    %al,                        chs_cmd.cylinder_lo /* reset the cylinder */
    movb    chs_cmd.head,               %al /* current head ... */
    addb    $1,                         %al /* ... ++ ... */
    jc      load_overflow               /* unable to read past the last head */
    movb    %al,                        chs_cmd.head /* ... and saved */
    jmp     read_sector
load_overflow:
    prints(msg_chs_overflow)
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
chs_read:
    /**** SAVE STATE ****/
    pushw   %ax
    pushw   %bx
    pushw   %cx
    pushw   %dx
    pushw   %si
chs_load_struct:
    /*** PREP THE THING ****/
    movw    $KRN_SEGM,                  %ax /* for setting es ... */
    movw    %ax,                        %es /* ... segment to 1000:0000 */
    movb    chs_cmd.device,             %dl /* whatever device we booted from */
    movb    chs_cmd.head,               %dh /* head zero */
    movb    chs_cmd.sector_cylhi,       %cl /* sector 0, still cylinder zero */
    movb    chs_cmd.cylinder_lo,        %ch /* Read starting on cylinder zero */
    movw    chs_cmd.offset,             %bx /* offset 1000:0000 */
    movb    chs_cmd.readlen,            %al /* Read 0x80 bytes at a time */
    movb    $0x02,                      %ah /* CHS Read function */
    /*** DO THE THING ***/
    int     $0x13
    movb    %al,                        chs_cmd.readlen
    movb    %ah,                        chs_cmd.return
    jc      chs_read_failed
chs_read_success:
    /* Give some feedback out the console */
    movb    $'.',                       %al
    call    charout
    jmp     chs_read_return
chs_read_failed:
    prints(msg_chs_failed)
    call    word_ascii_out
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
 * Function: byte_ascii_out */
byte_ascii_out:
    pushw   %dx                                 /* save */
    movw    %ax,                        %dx     /* save */
    jmp     _byte_ascii_out
/*******************************************************************************
 * Function: word_ascii_out
 * Purpose: convert two-byte into to ascii, then send it out */
word_ascii_out:
    pushw   %dx                                 /* save */
    movw    %ax,                        %dx     /* save */
    shrw    $12,                        %ax     /* bits 0xF000 */
    call    nibble_to_ascii_out
    movw    %dx,                        %ax     /* restore */
    shrw    $8,                         %ax     /* bits 0x0F00 */
    call    nibble_to_ascii_out
    movw    %dx,                        %ax     /* restore */
_byte_ascii_out:
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
    pushw   %ax                         /* save state */
    jmp     strout_2
strout_1:
    call    charout
strout_2:
    lodsb                               /* copy the character to al, increment si */
    testb   %al,                %al     /* test if it is the null terminator */
    jnz     strout_1                    /* else move to the next character */
strout_fin:
    popw    %ax                         /* restore state */
    ret
/******************************************************************************/

osname:                         .ascii  "\r\nshadow-os"
crlf:                           .asciz  "\r\n"
msg_halting:                    .asciz  "halting"
msg_chs_failed:                 .asciz  "chs read failed: ax="
msg_chs_overflow:               .asciz  "CHS read overflow"

/*******************************************************************************
 * the last 2 bytes in the sector 0 contain the signature */
	. = 0x1fe
signature:                      .short	0xAA55
	. = 0x200
_krn_init:
/******************************************************************************/


/*******************************************************************************
 * Local Data: these will be left on disk when the bios loads, just pointers. */
/******************************************************************************/
bootdev:                        .byte 0
chs_cmd:
chs_cmd.device:                 .byte 0
chs_cmd.offset:                 .word 0
chs_cmd.readlen:                .byte 0
chs_cmd.cylinder_lo:            .byte 0
chs_cmd.sector_cylhi:           .byte 0
chs_cmd.head:                   .byte 0
chs_cmd.return:                 .byte 0
chs_cmd_sz = . - chs_cmd
disk_data:
disk_data.max_cylinder_lo:      .byte 0
disk_data.max_sector_cylhi:     .byte 0
disk_data.max_head:             .byte 0
disk_data_sz = . - disk_data

	. = 0x400

