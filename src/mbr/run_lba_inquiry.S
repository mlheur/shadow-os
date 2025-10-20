#ifndef __RUN_LBA_INQUIRY_S__
#define __RUN_LBA_INQUIRY_S__


#include "prints.h"


lba_inquiry_prepare:
    movb        $0x41,              %ah
    movw        $0x55AA,            %bx

lba_inquiry_inquire:
    int         $0x13

lba_inquiry_errcheck:
    jc          _return_to_bios

lba_inquiry_validate_magic:
    cmpw        $0xAA55,            %bx
    jne         _return_to_bios

lba_inquiry_validate_EXRW: 
/*******************************************************************************
 * https://wiki.osdev.org/Disk_access_using_the_BIOS_(INT_13h)
 *   For this part of the guide bit 0 should be set, which
 *   indicates support for the extended read/write services.
 ******************************************************************************/
    testb       $1,                 %cl
    jz          _return_to_bios

lba_inquiry_success:
#ifdef DEBUG
    shrw        $8,                 %ax
    movw        %ax,                %di
    prints      (lba_return_msgA)
    movw        %di,                %ax
    call        print_byte
    prints      (lba_return_msgD)
    printb      (%dh)
    prints      (lba_return_msgB)
    printw      (%bx)
    prints      (lba_return_msgC)
    printw      (%cx)
    prints      (_str_crlf)
    jmp         1f
lba_return_msgA:
    .asciz      "AH:"
lba_return_msgD:
    .asciz      " DH:"
lba_return_msgB:
    .asciz      " BX:"
lba_return_msgC:
    .asciz      " CX:"
1:
#endif /* DEBUG */


#endif /* __RUN_LBA_INQUIRY_S__ */
