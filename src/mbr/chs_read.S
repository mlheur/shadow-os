    .file "chrs_read.S"
#ifndef __CHS_READ_S__
#define __CHS_READ_S__

/*******************************************************************************
 * TODO:
 1: prevent overreading when nearing the end.  When es is advanced far enough
    that _the next_ increment will exceed initial_es+readlimit, we need to
    decrease readlen accordingly.  Find a way to do this branchlessly, the MBR
    currently has ~50 bytes free space.
 2: Turn chs_read into a proper function with stack pushing of parameters.
    es needs to be added as input paremeter, with bootdev.
 ******************************************************************************/


/*******************************************************************************
 * Input Data from caller
 ******************************************************************************/
chs_cmd:
chs_cmd.device:         .byte 0 /* will be filled in by MBR caller, passed from BIOS */
chs_cmd.cylsec:         .word 1 /* seek sector 1 */
chs_cmd.head:           .byte 0 /* seek head 0 */
chs_cmd.readlen:        .byte 0x40 /* in & out, must be non-zero inbound */
chs_cmd.readlimit:      .word 0x1000 /* boot device is 64 KiB */
chs_cmd_sz = . - chs_cmd
/*******************************************************************************
 * Private local data, to inquire limits before reading the device
 ******************************************************************************/
drvdata:
drvdata.cylsec:         .word 0
drvdata.head:           .byte 0
drvdata_sz = . - drvdata
/*******************************************************************************
 * String resources
 ******************************************************************************/
msg_chs_failed:         .asciz              "CHS:AX="
msg_chs_overflow:       .asciz              "OF"
/******************************************************************************/


/*******************************************************************************
 * inputs:
 *  es: the place in memory to save the data
 *  chs_cmd.device: the device to read from
 *  chs_cmd.cylsec: the starting sector and cylinder in mangled form
 *  chs_cmd.head: the start head to read from
 *  chs_cmd.readlen: the number of sectors to read per IOP
 *  chs_cmd.readlimit: the segment limit es can grow to.
 ******************************************************************************/
chs_read:       pusha
                movw    %es,                %bx /* hold onto this for now */
/* Inquire from the BIOS: what are the CHS limits of the boot device,
 * those are needed throughout the CHS incrementer */
inquire_geom:   xorw    %ax,                %ax /* get a zero */
                movw    %ax,                %es /* to guard against BIOS bugs */
                movw    %ax,                %di /* to guard against BIOS bugs */
                movb    $0x08,              %ah /* "CHS inquire" command */
                movb    chs_cmd.device,     %dl /* inquire for the boot device */
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
    ES:DI -> drive parameter table (floppies only) */
save_heads:     movb    %dh,                drvdata.head
save_cylsec:    movw    %cx,                drvdata.cylsec
                movw    %bx,                %es /* get it back */
set_readlimit:  addw    %bx,                chs_cmd.readlimit /* KRN_SEGM:0000 until (KRN_SEGM+readlimit):0000 */


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
run_interrupt:  movb    chs_cmd.device,     %dl /* whatever device we booted from */
                movb    chs_cmd.head,       %dh /* address the proper head */
                movw    chs_cmd.cylsec,     %cx /* mangled cylsec value into cx */
                xorw    %bx,                %bx /* es was managed so bx can always be zero */
                movb    chs_cmd.readlen,    %al /* how many sectors we'd like to read */
                movb    $0x02,              %ah /* CHS "read" command */
#ifdef DEBUG
                call    debug_regs
#endif /* DEBUG */
                int     $0x13               /* perform the read */
#ifdef DEBUG
                pushf
                call    debug_regs
                popf
#endif /* DEBUG */
errchecking:    jc      chs_failed          /* handle any errors */


/* ah=0, al=sectors_read, the read was successful, advance the buffer pointer */
adv_buf_ptr:    movw    %ax,                %bx /* get a copy of ax to work on */
                subb    chs_cmd.readlen,    %bl /* check if the sectors requested equals the sectors read */
                jnz     read_complete       /* break out if the read was truncated */
                movw    %es,                %bx /* we need to do arithmatic on es, copy to bx */
                movw    $0x20,              %ax /* get a 512-byte segment muliplicand */
                mulb    chs_cmd.readlen     /* use the sectors-read counter as the other multiplicand */
                addw    %ax,                %bx /* advance bx by the results */
                movw    %bx,                %es /* and save it back to es; bx still contains the new es value */


check_complete: subw    chs_cmd.readlimit,  %bx /* check if the buffer pointer has totally advanced by 64k */
                jb      wrap_sector             /* when the readlimit is reached, the loader is finished */
read_complete:  popa
                ret
/* this is the only legitimate exit point for MBR, all other exits are due to failure and should jump to halt(ing) */


/* advance the CHS structure similarily to advancing the buffer pointer */
/* Each of the three wrappers below will set the whole CHS struct appropriately, and jump to the next run_interrupt iteration */
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
                jmp     run_interrupt       /* go read the new sector(s) */


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
                jmp     run_interrupt       /* and go read it */


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


/*******************************************************************************
 * Error handling for chs_read function
 ******************************************************************************/
chs_overflow:   prints  (msg_chs_overflow)
                jmp     halt
/******************************************************************************/
chs_failed:     movw    %ax,                %bx /* make a backup of ax */
                subb    $0x0C,              %ah /* return code 0x0C seems to mean we tried to read a CHS address that doesn't exist.  After this subtraction, al holds the number of sectors that were read before 0x0C was triggered */
                jz      adv_buf_ptr         /* handle successful read of those sectors */
                prints  (msg_chs_failed)    /* else fall through to the uncorrectable error handling routine */
                movw    %bx,                %ax /* restore from backup */
                call    print_word          /* give some feedback */
                jmp     halt                /* unhandled error */
/*******************************************************************************
 * End chs_read function
 ******************************************************************************/

#endif /* __CHS_READ_S__ */