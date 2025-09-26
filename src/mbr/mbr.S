/*******************************************************************************
 * BIOS hands over to MBR:
 * The only things that are (nearly) certain are that
 *  - the bootsector code is loaded and running at physical address 0x7c00,
 *  - the CPU is in 16-bit Real Mode,
 *  - the CPU register called dl contains the "drive number",
 *  - and that only 512 bytes of the bootsector have been loaded.
 * -- https://wiki.osdev.org/System_Initialization_(x86)
 * Missing in the above, taken from : https://wiki.osdev.org/Memory_Map_(x86)
 * 0000:0000 until 0000:03FF IVT
 * 0040:0000 until 0040:00FF BDA
 * 0040:0100 == 0050:0000
 * 0050:0000 until 7000:FFFF Conventional Memory
 ******************************************************************************/
#define MBR_SEGM 0x07C0 /* BIOS loads us here */
#define KRN_SEGM 0x1000 /* 0x10000 - 0x1FFFF */
#define STK_SEGM 0x7000 /* 7000:FFFF == 0x7FFFF stack at top of low RAM */
/*******************************************************************************
 * 8000:0000 until 9000:FFFF EBDA
 * A000:0000 until B000:FFFF VRAM
 * C000:0000 until C000:7FFF BIOS Expansion
 * C000:8000 until E000:FFFF VGA BIOS
 * F000:0000 until F000:FFFF Motherboard BIOS
 ******************************************************************************/


#define prints(s)   movw $(s), %si; call strout /* clobbers ax and si */
#define swapb(a,b)  xorb %a,%b; xorb %b,%a; xorb %a,%b


/*******************************************************************************
 * MBR */
	.text
	.code16
    .globl  _start
_start:         lcall  $MBR_SEGM,           $init_segments /* set cs register */
return:         ret                         /* used for indirect "Jcc return" */
init_segments:  movw    %cs,                %ax /* copy the code segment addr */
                movw    %ax,                %ds /* to the data segment */
save_bootdev:   movb    %dl,                bootdev /* needed throughout mbr */
init_COM1:      movw	$0xE3,              %ax /* 9600-8-None-1 */
	            xorw    %dx,                %dx /* port 0 */
	            int     $0x14               /* apply port settings */
/******************************************************************************/


/*******************************************************************************
 * Most HDD MBRs relocate themselves to nearby, maybe cs:=0x07A0 and then load a
 * PBR from the active partition.
 * shadow-os will do something completely different, there's no attempt at
 * portability since this is an educational OS built to run in 486 VM.
 * Strategy:
 * - read the whole boot device to RAM 1000:0000
 * - blind jump to 1000:0200
 * Assumptions:
 * - boot device size will be limited to 64KiB, will be exactly that size.
 * - we can terminate the read when the chs_cmd.offset wraps back to zero? */

/* Structures are addressed in unitialized RAM, memset(0) for all before use */
mzset_structs:  xorw    %ax,                %ax /* STOS: zero the source register */
                movw    $chs_cmd,           %di /* STOS: start at the chs_cmd struct */
                movw    $chs_cmd_sz,        %cx /* REP: the whole chs_cmd struct */
                addw    $drvdata_sz,        %cx /* REP: plus the drvdata struct */
                rep     stosw               /* write zeros to the memory */

/* Inquire from the BIOS what's the limit of the boot device, needed in the CHS incrementer */
inquire_geom:   movb    $0x08,              %ah /* "CHS inquire" command */
                movb    bootdev,            %dl /* inquire for the boot device */
                int     $0x13               /* submit the inquiry */
unmung_cylsec:  swapb(ch,cl)
                rolb    $2,                 %ch
save_geom:      movw    %cx,                drvdata /* save the results */
                movb    %dh,                drvdata.max_head /* ditto */

/* Prepare for CHS Reading, set the one-time and first-time values in chs_cmd */
target_krn:     movw    $KRN_SEGM,          %ax
                movw    %ax,                %es
read_bootdev:   movb    bootdev,            %al
                movb    %al,                chs_cmd.device
seek_sector1:   movw    $0x0400,            chs_cmd.cylsec

/* Start reading the boot device, assume all registers are garbage, load from struct */
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
 ******************************************************************************/
chs_read:       xorw    %bx,                %bx /* es was managed so bx can be zero */
                movb    chs_cmd.device,     %dl /* whatever device we booted from */
                movb    chs_cmd.head,       %dh /* address the proper head */
                movw    chs_cmd.cylsec,     %cx /* linear cylsec value into cx */
                swapb(ch,cl)                /* mangle it so cylinder is in ch */
                rorb    $2,                 %cl /* and sectors are LSB if cl */
read_amount:    movw    $0x0201,            %ax /* CHS "read" function, 2 sectors */
call_int_13:    int     $0x13               /* perform the read */
/*******************************************************************************
 * Return: CF set on error
 *	    if AH = 11h (corrected ECC error), AL = burst length
 *	CF clear if successful
 *	AH = status (see #00234)
 *	AL = number of sectors transferred (only valid if CF set for some BIOSes)
 ******************************************************************************/
errchecking:    testb   %ah,                %ah /* the interrupt returned error ... */
                jnz     load_failed         /* ... when ah != 0; bail */
                testb   %al,                %al /* check how much was read ... */
                jz      load_failed         /* ... when al == 0 nothing was read; bail */
chs_success:    movb    %al,                chs_cmd.readlen /* save for reuse */
                movb    $'.',               %al
                call    altty
                movb    chs_cmd.readlen,    %al
                movw    %es,                %bx
incr_buff_ptr:  addw    $0x20,              %bx
                movw    %bx,                %es
                subb    $1,                 %al /* decrement the sectors_read counter */
                jnz     incr_buff_ptr       /* ... otherwise go back and move the pointer more */
                subw    $(KRN_SEGM+0x100),  %bx /* check if the buffer pointer has advannced 64k */
                jz      load_finished       /* finished when 64KiB have been read */
increment_chs:  movw    drvdata.cylsec,     %bx /* Get the metric against which we'll test limits */
                movw    chs_cmd.cylsec,     %ax /* get the 16-bit linear cylsec address */
                andw    $0x03FF,            %ax /* filter the 10-bit cylinder portion */
                andw    $0x03FF,            %bx /* same in the metric */
                subw    %bx,                %ax /* check if the cylinder limit is reached ... */
                jz      wrap_head           /* ... and wrap the head if it is */
                movw    chs_cmd.cylsec,     %ax /* ... else, revert the unfiltered cylsec */
                addw    $1,                 %ax /* increment it */
                movw    %ax,                chs_cmd.cylsec /* save it back */
head_wrapped:   xorb    %ah,                %ah /* prevent side effect of upcoming byte decrement */
                movb    chs_cmd.readlen,    %al /* get back the qty of sectors read */
                subb    $1,                 %al /* decrement it, when it hits zero ... */
                jz      chs_read            /* ... go read the next sector */
                movb    %al,                chs_cmd.readlen
                jmp     increment_chs       /* else advance CHS again */
/******************************************************************************/
wrap_head:      movb    drvdata.max_head,   %bl /* Get the metric against which we'll test limits */
                movb    chs_cmd.head,       %al /* get the current value */
                xorb    %bh,                %bh /* to prevent side effects of 8-bit tests */
                xorb    %ah,                %ah /* ditto */
                subb    %al,                %bl /* if the limit is reached ... */
                jz      wrap_sector         /* ... wrap the sector instead, it will reset the head and cylinder */
                addb    $1,                 %al /* else increment the head */
                movb    %al,                chs_cmd.head /* and save it back */
                movw    chs_cmd.cylsec,     %ax /* restore the saved linear cylsec */
                andw    $0xFC00,            %ax /* keep just the sector bits */
                movw    %ax,                chs_cmd.cylsec /* save just the sector */
                jmp     head_wrapped        /* and we're done */
/******************************************************************************/
wrap_sector:    movb    $0,                 chs_cmd.head /* reset head to zero */
                movw    chs_cmd.cylsec,     %ax /* get the current linear address */
                andw    $0xFC00,            %ax /* filter out to cylinder zero */
                addw    $0x0400,            %ax /* add 1 to the sector count */
                jc      chs_overflow        /* cylinder wrapped, head wrapped, sector is wrapping: nothing more to read */
                movw    %ax,                chs_cmd.cylsec /* else save back the new sector & zeroed cylinder */
                jmp     head_wrapped        /* and we're done */
/******************************************************************************/
load_failed:    movb    %ah,                %al
                subb    $0x0C,              %ah
                jz      wrap_sector
                prints(msg_chs_failed)
                call    byte_ascii_out
                prints(crlf)                
/*******************************************************************************
 * End MBR program */
                prints(msg_halting)
halt:           sti
                hlt
                jmp     halt
/******************************************************************************/
chs_overflow:   prints(msg_chs_overflow)
                jmp     halt
/******************************************************************************/
load_finished:  prints(osname)
                jmp     halt /* TODO: jmp to KRN_SEGM:_krn_init */





/*******************************************************************************
 * When data is copied from disk to ram at krn_segm, the following tty-output
 * routines can be available as kernel calls with cs:=KRN_SEGM
 ******************************************************************************/


/*******************************************************************************
 * Function: byte_ascii_out */
byte_ascii_out:
    pushw   %dx                                     /* save */
    movw    %ax,                            %dx     /* save */
    jmp     _byte_ascii_out
/*******************************************************************************
 * Function: word_ascii_out
 * Purpose: convert two-byte into to ascii, then send it out */
word_ascii_out:
    pushw   %dx                                     /* save */
    movw    %ax,                            %dx     /* save */
    shrw    $12,                            %ax     /* bits 0xF000 */
    call    nibble_to_ascii_out
    movw    %dx,                            %ax     /* restore */
    shrw    $8,                             %ax     /* bits 0x0F00 */
    call    nibble_to_ascii_out
    movw    %dx,                            %ax     /* restore */
_byte_ascii_out:
    shr     $4,                             %al     /* bits 0x00F0 */
    call    nibble_to_ascii_out
    movw    %dx,                            %ax     /* bits 0x000F */
    call    nibble_to_ascii_out
    movw    %dx,                            %ax     /* restore */
    popw    %dx                                     /* restore */
    ret
/*******************************************************************************
 * Function: nibble_to_ascii_out */
nibble_to_ascii_out:
    andw    $0x000F,                        %ax     /* filter the nibble */
    addb    $0x90,                          %al     /* setup for decmial arithmatic, int2hex */
    daa                                             /* crank 1, int2hex */
    adc     $0x40,                          %al     /* reset for decmial arithmatic, int2hex */
    daa                                             /* crank 2, int2hex */
    /* int2hex complete, fall through to altty */
/*******************************************************************************
 * Function:
 *  altty
 * Inputs:
 *  al: the byte to send */
altty:
outb_com1:  pushw   %dx
            xorw    %dx,                    %dx /* Serial Port 0 */
            movb    $0x01,                  %ah /* "send" command */
            int     $0x14
            popw    %dx
outb_tty:   pushw   %bx
            movw    $0x0001,                %bx /* bh=page,bl=fg_colour */
            movb    $0x0e,                  %ah /* "tty out" VGA command */
            int     $0x10
            popw    %bx
altty_end:  ret
/******************************************************************************/


/*******************************************************************************
 * Function: strout
 * Purpose: write a null-terminated string through altty
 * Parameters: ds:si the address of the first character
 * Outputs: None. */
strout:     lodsb                           /* copy the character to al, increment si */
            testb   %al,                    %al /* test if it is the null terminator */
            jz      return
            call    altty
            jmp     strout
/******************************************************************************/


/*******************************************************************************
 * Static Data */
/******************************************************************************/
osname:             .ascii "shadow-os"
crlf:               .asciz "\r\n"
msg_halting:        .asciz "halting"
msg_chs_failed:     .asciz "CHS read failed: %ah=0x"
msg_chs_overflow:   .asciz "CHS read overflow"


/*******************************************************************************
 * the last 2 bytes in the sector 0 contain the signature */
	. = 0x1fe
signature:          .short 0xAA55
	. = 0x200
_krn_init:
/******************************************************************************/


/*******************************************************************************
 * Local Data: these will be left on disk when the bios loads, just pointers. */
/******************************************************************************/
bootdev:            .byte 0
chs_cmd:
chs_cmd.cylsec:     .word 0 /* saved here in linear value */
chs_cmd.head:       .byte 0
chs_cmd.device:     .byte 0
chs_cmd.readlen:    .byte 0
chs_cmd_sz = . - chs_cmd
drvdata:
drvdata.cylsec:     .word 0 /* saved here in linear value */
drvdata.max_head:   .byte 0
drvdata_sz = . - drvdata

	. = 0x400
