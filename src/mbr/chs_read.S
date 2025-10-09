#ifndef __CHS_READ_S__
#define __CHS_READ_S__


#include "stack_offsets.h"
#define PUSHED_ES       2+PUSHED_AX

#define SAVED_READLEN   PUSHED_AL
#define SAVED_CYLSEC    PUSHED_CX
#define SAVED_HEAD      PUSHED_DH
#define SAVED_DRIVE     PUSHED_DL
#define SAVED_OFFSET    PUSHED_BX
#define SAVED_SEGMENT   PUSHED_ES
#define SAVED_READLIMIT PUSHED_DI


/*******************************************************************************
 * TODO:
 * 1: prevent overreading when nearing the end.  When es is advanced far enough
 *    that _the next_ increment will exceed initial_es+readlimit, we need to
 *    decrease readlen accordingly.  Find a way to do this branchlessly, the MBR
 *    currently has ~50 bytes free space.
 * 2: Create self-modifying code such that drvdata values are inserted in the
 *    opcodes instructions using dot-relative addresses.
 ******************************************************************************/


/*******************************************************************************
 * Private local data, to inquire limits before reading the device
 ******************************************************************************/
drvdata:
drvdata.cylsec:         .word 0
drvdata.head:           .byte 0


/******************************************************************************/
chs_failed:     subb    $0x0C,          %ah /* return code 0x0C tried to read past end of disk, this might be OK */
                jz      adv_buf_ptr     /* handle successful read of those sectors */
/******************************************************************************/
chs_return:     del_stack_frame
                popw    %es
                ret
/******************************************************************************/


/*******************************************************************************
 * Each of the three wrappers below will set the whole CHS struct appropriately,
 * and jump to the next load_registers iteration.
 ******************************************************************************/
wrap_head:      movzbw  drvdata.head,   %bx /* get the metric against which we'll test limits */
                movzbw  SAVED_HEAD,     %ax /* get the current value */
                subw    %ax,            %bx /* if the limit is reached ... */
                jz      wrap_cylinder   /* ... wrap the cylinder instead, it will reset the head and sector */
                addb    $1,             %al /* else increment the head */
                movb    %al,            SAVED_HEAD /* and save it back */
                movw    SAVED_CYLSEC,   %ax /* pull up the mangled cylsec ... */
                andw    $0xFFC0,        %ax /* ... so we can keep the cylinder bits ... */
remaining_secs: negw    %cx             /* we have to further advance the sectors by this much, figured in the subw instruction of wrap_sector */
                addb    %cl,            %al /* add that many more to the sector ID */
                movb    %al,            SAVED_CYLSEC /* finally save the sector ID back to the CHS struct */
                jmp     load_registers  /* and go read it */
/******************************************************************************/

wrap_sector:    movw    SAVED_CYLSEC,   %ax /* get the 16-bit mangled cylsec address that was just read from */
                andw    $0x003F,        %ax /* filter the 6-bit sector portion */
                movzbw  SAVED_READLEN,  %bx /* recall how many sectors were successfully read */
                addw    %bx,            %ax /* advance the sector pointer that much ... */
/* we advanced sectors by 1 **OR MORE**, check if we exceeded the sector limit */
                movw    drvdata.cylsec, %cx /* get the last sector valid sector ID */
                andw    $0x003F,        %cx /* filter just the 6-bit sector portion */
                subw    %ax,            %cx /* compare the calculated sector ID against the limit, destroys cx */
                jb      wrap_head       /* if ax is bigger than cx then the limit was exceeded, wrap to the next head */
                movw    %ax,            SAVED_CYLSEC /* else the calculated sector ID is valid, commit it */
                jmp     load_registers  /* go read the new sector(s) */
/******************************************************************************/

wrap_cylinder:  movb    $0,             SAVED_HEAD /* reset head to zero */
                movw    SAVED_CYLSEC,   %ax /* get the current mangled address */
                andw    $0xFFC0,        %ax /* filter out sectors to zero */
                movw    drvdata.cylsec, %bx /* get the metric against which we'll test the limits */
                andw    $0xFFC0,        %bx /* filter out sectors to zero */
                subw    %ax,            %bx /* check if the limit is reached */
                hlt                     /* unable to read past end of disk */
                rolb    $2,             %al /* mangled cylsec sits in ax, filtered in the cyl bits */
                xchgb   %al,            %ah /* put the cylinder portion as LSB */
                addw    $1,             %ax /* increment the cylinder */
                andw    $0x03FF,        %ax /* filter any overflow */
                xchgb   %ah,            %al /* remangle the cylsec */
                rorb    $2,             %al /* suffle zeroed sectors to lsb */
                jmp     remaining_secs  /* and we're done */
/******************************************************************************/


/*******************************************************************************
 * inputs:
 *  es: segment register for write operation
 *  di: stop reading when es advanced this much
 *  dh: the first head to read from
 *  dl: the disk/drive device to read from
 *  cx: the starting sector and cylinder in mangled form
 *  bx: the offset from es for the write opeartion
 *  ah: the start head to read from
 *  al: the number of sectors to read per IOP
 ******************************************************************************/
chs_read:       pushw   %es
                new_stack_frame
/* Inquire from the BIOS: what are the CHS limits of the boot device,
 * those are needed throughout the CHS incrementer */
inquire_geom:   xorw    %ax,            %ax /* get a zero */
                movw    %ax,            %es /* to guard against BIOS bugs */
                movw    %ax,            %di /* to guard against BIOS bugs */
                movb    $0x08,          %ah /* "CHS inquire" command */
                int     $0x13           /* submit the inquiry */
/* https://fd.lod.bz/rbil/interrup/bios/1308.html
 *  AH = 00h
 *  AL = 00h on at least some BIOSes
 *  BL = drive type (AT/PS2 floppies only) (see #00242)
 *  CH = low eight bits of maximum cylinder number
 *  CL = maximum sector number (bits 5-0)
 *    high two bits of maximum cylinder number (bits 7-6)
 *  DH = maximum head number
 *  DL = number of drives
 *  ES:DI -> drive parameter table (floppies only) */
save_heads:     movb    %dh,            drvdata.head
save_cylsec:    movw    %cx,            drvdata.cylsec
                movw    SAVED_SEGMENT,  %es
                movw    %es,            %bx
                addw    %bx,            SAVED_READLIMIT
                movb    SAVED_DRIVE,    %dl /* this was clobbered within inquire_geom */
load_registers: movb    SAVED_HEAD,     %dh /* address the latest head */
                movw    SAVED_CYLSEC,   %cx /* mangled cylsec value into cx */
                movw    SAVED_OFFSET,   %bx /* es was managed so bx can remain constant, but it's been used willy-nilly in the wrap functions */
                movb    SAVED_READLEN,  %al /* how many sectors we'd like to read, ax register has been destroyed in supporting functions */
                movb    $0x02,          %ah /* force CHS "read" command */

#ifdef DEBUG
                call    debug_regs
#endif
/*******************************************************************************
 * CHS Read: https://fd.lod.bz/rbil/interrup/bios/1302.html
 * INT 13 - DISK - READ SECTOR(S) INTO MEMORY     
 *  AH = 02h
 *  AL = number of sectors to read (must be nonzero)
 *  CH = low eight bits of cylinder number
 *  CL = sector number 1-63 (bits 0-5)
 *    high two bits of cylinder (bits 6-7, hard disk only)
 *  DH = head number
 *  DL = drive number (bit 7 set for hard disk)
 *  ES:BX -> data buffer
 ******************************************************************************/
                int     $0x13           /* perform the read */
#ifdef DEBUG
                pushf
                call    debug_regs
                popf
#endif /* DEBUG */
errchecking:    jc      chs_failed      /* handle any errors */
/* ah=0, al=sectors_read, the read was successful, advance the buffer pointer */
adv_buf_ptr:    shlw    $5,             %ax /* within ax, convert 'sectors read' scalar value into 'segment offset read' scalar value */
                movw    %es,            %bx
                addw    %ax,            %bx /* increment the segment pointer accordingly */
                movw    %bx,            %es /* and save it back (ALU cant write to segment registers) */
check_partial:  shrw    $5,             %ax /* convert back to 'sectors read' */
                cmpb    %al,            SAVED_READLEN /* when the amount read differs from amount requested ... */
                jne     was_partial     /* ... then we have nothing more to read */
check_complete: subw    SAVED_READLIMIT,%bx /* check if the buffer pointer has totally advanced by 64k */
                jb      wrap_sector     /* when 64KiB have been read, the loader is finished */
was_partial:    jmp     chs_return
/*******************************************************************************
 * End chs_read function
 ******************************************************************************/

#endif /* __CHS_READ_S__ */
