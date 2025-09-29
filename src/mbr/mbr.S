/*******************************************************************************
 * BIOS hands over to MBR:
 * The only things that are (nearly) certain are that
 *  - the bootsector code is loaded and running at physical address 0x7c00,
 *  - the CPU is in 16-bit Real Mode,
 *  - the CPU register called dl contains the "drive number",
 *  - and that only 512 bytes of the bootsector have been loaded.
 * -- https://wiki.osdev.org/System_Initialization_(x86)
 ******************************************************************************/

/******************************************************************************/
/* Missing in the above, taken from : https://wiki.osdev.org/Memory_Map_(x86) */
/* 0000:0000 until 0000:03FF IVT Used by the BIOS, don't write here */
/* 0040:0000 until 0040:00FF BDA Used by the BIOS, don't write here */
/* [0040:0100 is 0050:0000] until 7000:FFFF Conventional Memory */
#define MBR_SEGM 0x07C0 /* BIOS loads us here */
#define KRN_SEGM 0x1000 /* 0x10000 - 0x1FFFF */
/* 8000:0000 until 9000:FFFF EBDA */
/* A000:0000 until B000:FFFF VRAM */
/* C000:0000 until C000:7FFF BIOS Expansion */
/* C000:8000 until E000:FFFF VGA BIOS */
/* F000:0000 until F000:FFFF Motherboard BIOS */
/******************************************************************************/


/*******************************************************************************
 * TODO:
 1: set the readlen as a variable instead of hardcoding KRN_SEGM+0x1000; to make
    chs_read a general purposee OS function.
 2: prevent overreading when nearing the end.  When ES is advanced far enough
    that ES + (512 * READLEN) it will exceed 64KiB, then reduce READLEN by some
    amount.
 3: refactor print_word to use cx as the shift counter with another loop.
 ******************************************************************************/


/******************************************************************************/
#define prints(s)       movw $s, %si; call strout /* clobbers ax and si */
#define printb(b)       movw b, %ax; call print_byte /* clobbers ah */
#define printw(w)       movw w, %ax; call print_word /* clobbers ah */
/******************************************************************************/


/******************************************************************************/
/* #define DEBUG
/******************************************************************************/


/*******************************************************************************
 * BIOS Entry Point into MBR
 ******************************************************************************/
    .text
    .code16
    .globl  _start
    . = 0
_start:         pusha
                ljmp    $MBR_SEGM,          $MBR /* Run the MBR, load bootdev */
_kernel:        pushw   $KRN_SEGM           /* Do the kernel a favour ... */
                popw    %ds                 /* ... set the data segment */
                lcall    $KRN_SEGM,          $KRN /* Run the kernel */
_kernel_return: popa
                lret /* return to the BIOS, it will try the next boot device */
/******************************************************************************/


/******************************************************************************/
return:         ret     /* used for indirect "Jcc return" */
/*******************************************************************************
 * Static Data
 ******************************************************************************/
osname:                 .ascii "[s]" /* include the subsequent crlf */
crlf:                   .asciz "\r\n"
msg_halting:            .asciz "fin"
msg_chs_failed:         .asciz "CHS:AX="
msg_chs_overflow:       .asciz "OF"
/*******************************************************************************
 * Local Data
 ******************************************************************************/
bootdev:                .byte 0
chs_cmd:
chs_cmd.cylsec:         .word 1 /* seek sector 1 */
chs_cmd.head:           .byte 0
chs_cmd.readlen:        .byte 0x80 /* in & out, must be non-zero inbound */
chs_cmd_sz = . - chs_cmd
drvdata:
drvdata.cylsec:         .word 0
drvdata.head:           .byte 0
drvdata_sz = . - drvdata
/******************************************************************************/


/*******************************************************************************
 * When bootdev is copied from disk to ram at krn_segm, the following routines
 * can be available as kernel calls with cs:=KRN_SEGM
 ******************************************************************************/


/*******************************************************************************
 * Function: debug_regs
 * Purpose: print the registers during the int 0x13 ah=0x02 */
#ifdef DEBUG
dbgES:          .asciz  "ES:"
dbgDX:          .asciz  " DX:"
dbgCX:          .asciz  " CX:"
dbgBX:          .asciz  " BX:"
dbgAX:          .asciz  " AX:"
debug_regs:     pushw   %ax
                pushw   %ax
                prints  (dbgES)
                printw  (%es)
                prints  (dbgBX)
                printw  (%bx)
                prints  (dbgDX)
                printw  (%dx)
                prints  (dbgCX)
                printw  (%cx)
                prints  (dbgAX)
                popw    %ax
                call    print_word
                prints  (crlf)
                popw    %ax
                ret
#endif
/******************************************************************************/


/*******************************************************************************
 * Function: print_byte
 * Function: print_word
 * Purpose: convert one or two bytes into to ascii, then send it out */
print_byte:     pushw   %dx                         /* save */
                movw    %ax,                %dx     /* save */
                jmp     1f
/******************************************************************************/
print_word:pushw   %dx                         /* save */
                movw    %ax,                %dx     /* save */
                shrw    $12,                %ax     /* bits 0xF000 */
                call    nibble_ascii
                movw    %dx,                %ax     /* restore */
                shrw    $8,                 %ax     /* bits 0x0F00 */
                call    nibble_ascii
                movw    %dx,                %ax     /* restore */
1:              shr     $4,                 %al     /* bits 0x00F0 */
                call    nibble_ascii
                movw    %dx,                %ax     /* bits 0x000F */
                call    nibble_ascii
                movw    %dx,                %ax     /* restore */
                popw    %dx                         /* restore */
                ret
/******************************************************************************/


/*******************************************************************************
 * Function: nibble_ascii
 * Purpose: convert four bits to one of the characters 0-9,A-F; send it out */
nibble_ascii:   andb    $0x0F,              %al
                cmpb    $0x0A,              %al
                sbbb    $0x69,              %al
                das
/******************************************************************************/
altty:
outb_com1:      pushw   %dx
                xorw    %dx,                %dx /* Serial Port 0 */
                movb    $0x01,              %ah /* "send" command */
                int     $0x14
                popw    %dx
outb_tty:       pushw   %bx
                movw    $0x0001,            %bx /* bh=page,bl=fg_colour */
                movb    $0x0e,              %ah /* "tty out" VGA command */
                int     $0x10
                popw    %bx
altty_end:      ret
/******************************************************************************/


/*******************************************************************************
 * Function: strout
 * Purpose: write a null-terminated string through altty
 * Parameters: ds:si the address of the first character
 * Outputs: None. */
strout:         lodsb                      /* copy the character to al, increment si */
                testb   %al,               %al /* test if it is the null terminator */
                jz      return
                call    altty
                jmp     strout
/******************************************************************************/


/*******************************************************************************
 * Most HDD MBRs relocate themselves to nearby, maybe cs:=0x07A0 and then load a
 * PBR from the active partition.
 * shadow-os will do something completely different, there's no attempt at
 * portability since this is an educational OS built to run in qemu as a 486 VM.
 * Strategy:
 * - Building the boot image: MBR goes on sector 1, KRN goes on sector 2.
 * - read the whole boot device to RAM 1000:0000; earlier attempts wanted to
 *   aim for 0050:0000 but this BIOS uses a stack at 0600:0FFF, that strategy
 *   trampled the stack; we'll continue using the BIOS stack.
 * - hand off to the kernel that just got loaded to 1000:0200
 * Assumptions:
 * - boot device size will be limited to 64KiB, will be exactly that size.
 * - we can terminate the read when the buffer pointer is advanced by 64KiB */
/******************************************************************************/


/*******************************************************************************
 * Function: MBR
 * Inputs: 
 * - dl, the bootdev the bios read the MBR off of
 * - best to get here via long jump so we can use the local segment offsets for
 *   all addressing */
MBR:


prep_segments:  movw    %cs,                %ax /* copy the code segment address ... */
                movw    %ax,                %ds /* ...  to data segment register for easy access to locals, such as in save_bootdev */


save_bootdev:   movb    %dl,                bootdev /* save the boot device for reuse throughout MBR */


init_COM1:      movw	$0xE3,              %ax /* 9600-8-None-1 */
                xorw    %dx,                %dx /* port 0 */
                int     $0x14               /* latch that into the serial controller's settings */
CONTINUE_INT14_init_COM1:


/* Inquire from the BIOS: what are the CHS limits of the boot device,
 * those are needed throughout the CHS incrementer */
inquire_geom:   xorw    %ax,                %ax /* get a zero */
                movw    %ax,                %es /* to guard against BIOS bugs */
                movw    %ax,                %di /* to guard against BIOS bugs */
                movb    $0x08,              %ah /* "CHS inquire" command */
                movb    bootdev,            %dl /* inquire for the boot device */
                int     $0x13               /* submit the inquiry */
CONTINUE_INT13_inquire_geom:
/* https://fd.lod.bz/rbil/interrup/bios/1308.html
         AH = 00h
         AL = 00h on at least some BIOSes
         BL = drive type (AT/PS2 floppies only) (see #00242)
         CH = low eight bits of maximum cylinder number
         CL = maximum sector number (bits 5-0)
           high two bits of maximum cylinder number (bits 7-6)
         DH = maximum head number
         DL = number of drives
         ES:DI -> drive parameter table (floppies only) */
save_heads:     movb    %dh,                drvdata.head
save_cylsec:    movw    %cx,                drvdata.cylsec


/* Prepare for CHS Reading, set the one-time and first-time values in chs_cmd */
target_krn:     movw    $KRN_SEGM,          %ax
                movw    %ax,                %es /* we have to guard es for the duration of MBR */


/* Start reading the boot device, assume all+ registers are garbage, load from struct
 *   +[guard es, was set above and is managed throughout] */
/*******************************************************************************
 * CHS Read: https://fd.lod.bz/rbil/interrup/bios/1302.html
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
chs_read:       movb    bootdev,            %dl /* whatever device we booted from */
                movb    chs_cmd.head,       %dh /* address the proper head */
                movw    chs_cmd.cylsec,     %cx /* mangled cylsec value into cx */
                xorw    %bx,                %bx /* es was managed so bx can always be zero */
                movb    chs_cmd.readlen,    %al /* how many sectors we'd like to read */
                movb    $0x02,              %ah /* CHS "read" command */
#ifdef DEBUG
                call    debug_regs
#endif
                int     $0x13               /* perform the read */
CONTINUE_INT13_chs_read:
#ifdef DEBUG
                pushf
                call    debug_regs
                popf
#endif
errchecking:    jc      chs_failed          /* handle any errors */


/* ah=0, al=sectors_read, the read was successful, advance the buffer pointer */
adv_buf_ptr:    movb    %al,                chs_cmd.readlen /* save sectors_read counter for reuse */
                movw    %es,                %bx /* we need to do arithmatic on es, copy to bx */
                movw    $0x20,              %ax /* get a 512-byte segment muliplicand */
                mulb    chs_cmd.readlen     /* use the sectors-read counter as the other multiplicand */
                addw    %ax,                %bx /* advance bx by the results */
                movw    %bx,                %es /* and save it back to es; bx still contains the new es value */
check_complete: subw    $(KRN_SEGM+0x1000), %bx /* check if the buffer pointer has totally advanced by 64k */
                jae     _kernel             /* when 64KiB have been read, the loader is finished */
/* this is the only legitimate exit point for MBR, all other exits are due to failure and should jump to halt(ing) */


/* advance the CHS structure similarily to advancing the buffer pointer */
/* Each of the three wrappers below will set the whole CHS struct appropriately, and jump to the next chs_read iteration */
wrap_sector:    movw    chs_cmd.cylsec,     %ax /* get the 16-bit mangled cylsec address that was just read from */
                andw    $0x003F,            %ax /* filter the 6-bit sector portion */
                movzbw  chs_cmd.readlen,    %bx /* recall how many sectors were successfully read */
                addw    %bx,                %ax /* advance the sector pointer that much ... */
/* we advanced sectors by 1 **OR MORE**, check if we exceeded the sector limit */
                movw    drvdata.cylsec,     %cx /* get the last sector valid sector ID */
                andw    $0x003F,            %cx /* filter just the 6-bit sector portion */
                subw    %ax,                %cx /* compare the calculated sector ID against the limit, destroys cx */
                jb      wrap_head           /* if ax is bigger than cx then the limit was exceeded, wrap to the next head */
                movw    %ax,                chs_cmd.cylsec /* else the calculated sector ID is valid, commit it */
                jmp     chs_read            /* go read the new sector(s) */


/******************************************************************************/
wrap_head:      movzbw  drvdata.head,       %bx /* get the metric against which we'll test limits */
                movzbw  chs_cmd.head,       %ax /* get the current value */
                subw    %ax,                %bx /* if the limit is reached ... */
                jz      wrap_cylinder       /* ... wrap the cylinder instead, it will reset the head and sector */
                addb    $1,                 %al /* else increment the head */
                movb    %al,                chs_cmd.head /* and save it back */
                movw    chs_cmd.cylsec,     %ax /* pull up the mangled cylsec ... */
                andw    $0xFFC0,            %ax /* ... so we can keep the cylinder bits ... */
/* this assumes we previously read _the last_ sector on the prior head, that's a bad assumption */
/*
 * Let's say we're reading 5 sectors at a time for no good reason.  It's likeley
 * the last sector is 63.  When we advance to sector 61 and read 5 sectors, the BIOS may or may not
 * read 2 sectors off the next head.  We'll know if the BIOS read 3 or 5 sectors based on the
 * chs_cmd.readlen result.
 *
 * After advancing the head and seeking sector 1, we need to seek further by either 0 or 2 sectors.
 *
 * We know how many sectors were attempted to be read, that's hard-coded in the ax assignment of chs_read before the interrupt invokation.
 */
remaining_secs: negw    %cx                 /* we have to further advance the sectors by this much, figured in the subw instruction of wrap_sector */
                addb    %cl,                %al /* add that many more to the sector ID */
                movb    %al,                chs_cmd.cylsec /* finally save the sector ID back to the CHS struct */
                jmp     chs_read            /* and go read it */


/******************************************************************************/
wrap_cylinder:  movb    $0,                 chs_cmd.head /* reset head to zero */
                movw    chs_cmd.cylsec,     %ax /* get the current mangled address */
                andw    $0xFFC0,            %ax /* filter out sectors to zero */
                movw    drvdata.cylsec,     %bx /* get the metric against which we'll test the limits */
                andw    $0xFFC0,            %bx /* filter out sectors to zero */
                subw    %ax,                %bx /* check if the limit is reached */
                jz      chs_overflow        /* unable to read past end of disk */
                rolb    $2,                 %al /* mangled cylsec sits in ax, filtered in the cyl bits */
                xchgb   %al,                %ah /* put the cylinder portion as LSB */
                addw    $1,                 %ax /* increment the cylinder */
                andw    $0x03FF,            %ax /* filter any overflow */
                xchgb   %ah,                %al /* remangle the cylsec */
                rorb    $2,                 %al /* suffle zeroed sectors to lsb */
                jmp     remaining_secs      /* and we're done */


/******************************************************************************/
chs_overflow:   prints  (msg_chs_overflow)
                jmp     halt
/******************************************************************************/
chs_failed:     movw    %ax,                %bx
                subb    $0x0C,              %ah
                jz      adv_buf_ptr
                prints  (msg_chs_failed)
                movw    %bx,                %ax
                call    print_word
                prints  (crlf)
/******************************************************************************/
halting:        prints  (msg_halting)
halt:           sti
                hlt
                jmp     halt
/******************************************************************************/
/* End MBR function */
/******************************************************************************/


/*******************************************************************************
 * the last 2 bytes in the sector 0 must contain the signature */
    . = 0x1fe
signature:      .short 0xAA55
    . = 0x200
KRN:            prints      (osname)
FIN:            lret
/******************************************************************************/