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
/* #define swapb(a,b)  xorb %a,%b; xorb %b,%a; xorb %a,%b */
#define swapb(a,b)  xchgb %a,%b

/*******************************************************************************
 * MBR */
	.text
	.code16
    .globl  _start
_start:         lcall   $MBR_SEGM,          $init_bootdev /* set cs register */
_handover:      lcall   $KRN_SEGM,          $init_kernel
return:         ret                         /* also used for indirect "Jcc return" */
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
/******************************************************************************/


/*******************************************************************************
 * Function: init_bootdev
 * Inputs: 
 * - dl, the bootdev the bios read the MBR off of
 * - best to get here via far jump so we can use the local segment offset for all addressing */
init_bootdev:   movw    %cs,                %ax /* copy the code segment address ... */
                movw    %ax,                %ds /* ...  to data segment register for easy access to locals, such as the next line */


save_bootdev:   movb    %dl,                bootdev /* save the boot device for reuse throughout MBR */


init_COM1:      movw	$0xE3,              %ax /* 9600-8-None-1 */
	            xorw    %dx,                %dx /* port 0 */
	            int     $0x14               /* apply port settings */


/* Structures are addressed in unitialized RAM, memset(0) for all before use.
 * MBR depends on some of those zeros for initial CHS addressing values */
mzset_structs:  xorw    %ax,                %ax /* STOS: zero the source register */
                movw    $chs_cmd,           %di /* STOS: start at the chs_cmd struct */
                movw    $chs_cmd_sz,        %cx /* REP: the whole chs_cmd struct */
                addw    $drvdata_sz,        %cx /* REP: plus the drvdata struct */
                rep     stosb               /* repeatedly write zeros to the memory */


/* Inquire from the BIOS: what are the CHS limits of the boot device,
 * those are needed throughout the CHS incrementer */
inquire_geom:   xorw    %ax,                %ax /* get a zero */
                movw    %ax,                %es /* to guard against BIOS bugs */
                movw    %ax,                %di /* to guard against BIOS bugs */
                movb    $0x08,              %ah /* "CHS inquire" command */
                movb    bootdev,            %dl /* inquire for the boot device */
                int     $0x13               /* submit the inquiry */
/* https://fd.lod.bz/rbil/interrup/bios/1308.html
	    AH = 00h
	    AL = 00h on at least some BIOSes
	    BL = drive type (AT/PS2 floppies only) (see #00242)
	    CH = low eight bits of maximum cylinder number
	    CL = maximum sector number (bits 5-0)
		 high two bits of maximum cylinder number (bits 7-6)
	    DH = maximum head number
	    DL = number of drives
	    ES:DI -> drive parameter table (floppies only)
*/
save_heads:     movb    %dh,                drvdata.max_head /* save heads */
unmung_cylsec:  swapb(ch,cl)                /* the sector address is stored between mangled bits of the cylinder address ... */
                rolb    $2,                 %ch /* ... these two lines unmangles those to a 16-bit linear address */
                rolw    $6,                 %cx /* finally put sectors LSB of cylinders */
save_cylsec:    movw    %cx,                drvdata.cylsec /* save the results */


/* Prepare for CHS Reading, set the one-time and first-time values in chs_cmd */
target_krn:     movw    $KRN_SEGM,          %ax
                movw    %ax,                %es
read_bootdev:   movb    bootdev,            %al
                movb    %al,                chs_cmd.device
seek_sector1:   movw    $1,                 chs_cmd.cylsec /* head zero */


/* ToDo: Refactor the below to use cylsec in mangled form all the time.
 * Pretty simple to do: the filter on bx and ax can be shifted, the add $1 can be add $000X0000b whatever; and wrap_cylinder might be more complicated ... */


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
chs_read:       xorw    %bx,                %bx /* es was managed so bx can always be zero */
                movb    chs_cmd.device,     %dl /* whatever device we booted from */
                movb    chs_cmd.head,       %dh /* address the proper head */
                movw    chs_cmd.cylsec,     %cx /* linear cylsec value into cx */
                rorw    $6,                 %cx /* put sectors MSB of cylinders */
                rorb    $2,                 %ch /* and sectors are LSB in cl */
                swapb(ch,cl)                /* mangle it so cylinder is in ch */
read_amount:    movw    $0x0201,            %ax /* CHS "read" function, 1 sector at a time (for now) */
call_int_13:    int     $0x13               /* perform the read */
errchecking:    jc      load_failed         /* handle any errors */
chs_success:    movb    %al,                chs_cmd.readlen /* save sectors_read counter for reuse */
printdot:       movb    $'.',               %al
                call    altty               /* for some kind of feedback */
                movb    chs_cmd.readlen,    %al /* restore sectors_read counter after printdot destroyed it */
                xorb    %ah,                %ah /* wipe the leftovers of altty */
                movw    %es,                %bx /* Advancing the buffer pointer by 512 bytes is done more easily via segment increment */
incr_buff_ptr:  addw    $0x20,              %bx /* increment the segment pointer ... */
                movw    %bx,                %es /* and store it in the segment register */
                subb    $1,                 %al /* decrement the sectors_read counter */
                jnz     incr_buff_ptr       /* non-zero counter means we have to move the buffer pointer some more */
                subw    $(KRN_SEGM+0x100),  %bx /* check if the buffer pointer has totally advanced by 64k */
                jz      return              /* init_bootdev is finished when 64KiB have been read */
increment_shc:  movw    drvdata.cylsec,     %bx /* get the metric against which we'll test limits */
                andw    $0x003F,            %bx /* filter the 6-bit sector portion */
                movw    chs_cmd.cylsec,     %ax /* get the 16-bit linear cylsec address that was just read from */
                andw    $0x003F,            %ax /* filter the 6-bit sector portion */
                testw   %ax,                %bx /* check if the sector limit is reached ... */
                je      wrap_head           /* ... and wrap the head if it is ... */
                movw    chs_cmd.cylsec,     %ax /* ... else, revert the unfiltered cylsec */
                addw    $1,                 %ax /* advance the sector for real this time ... */
                movw    %ax,                chs_cmd.cylsec /* ... and save it back */
head_wrapped:   xorb    %ah,                %ah /* prevent side effect of upcoming byte decrement */
                movb    chs_cmd.readlen,    %al /* get back the qty of sectors read */
                subb    $1,                 %al /* decrement it, when it hits zero ... */
                jz      chs_read            /* ... go read the next sector */
                movb    %al,                chs_cmd.readlen
                jmp     increment_shc       /* else advance CHS again */
/******************************************************************************/
wrap_head:      movb    drvdata.max_head,   %bl /* get the metric against which we'll test limits */
                movb    chs_cmd.head,       %al /* get the current value */
                xorb    %bh,                %bh /* to prevent side effects of 8-bit tests */
                xorb    %ah,                %ah /* ditto */
                subb    %al,                %bl /* if the limit is reached ... */
                jz      wrap_cylinder       /* ... wrap the cylinder instead, it will reset the head and sector */
                addb    $1,                 %al /* else increment the head */
                movb    %al,                chs_cmd.head /* and save it back */
                movw    chs_cmd.cylsec,     %ax /* restore the saved linear cylsec */
                andw    $0xFFC0,            %ax /* keep just the cylinder bits */
                movw    %ax,                chs_cmd.cylsec /* save just the cylinder */
                jmp     head_wrapped        /* and we're done */
/******************************************************************************/
wrap_cylinder:  movb    $0,                 chs_cmd.head /* reset head to zero */
                movw    chs_cmd.cylsec,     %ax /* get the current linear address */
                andw    $0xFFC0,            %ax /* filter out to sectors zero */
                movw    drvdata.cylsec,     %bx /* get the metric against which we'll test the limits */
                andw    $0xFFC0,            %ax /* filter out to sectors zero */
                testw   %bx,                %ax /* check if the limit is reached */
                je      chs_overflow        /* unable to read past end of disk */
                addw    $0x0041,            %ax /* add one to each of the cylinder and sector */
                movw    %ax,                chs_cmd.cylsec /* set cylsec for the next read */
                jmp     head_wrapped        /* and we're done */
/******************************************************************************/
load_failed:    movb    %ah,                %bl /* save ah for later by altty */
                prints(msg_chs_failed)
                movb    %bl,                %al
                call    byte_ascii_out
                prints(crlf)                
/*******************************************************************************
 * End MBR program */
halting:        prints(msg_halting)
halt:           sti
                hlt
                jmp     halt
/******************************************************************************/
chs_overflow:   prints(msg_chs_overflow)
                jmp     halt
/******************************************************************************/





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
init_kernel:
    prints(osname)
    jmp halting
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
