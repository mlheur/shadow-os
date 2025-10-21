#ifndef __RUN_LBA_INQUIRY_S__
#define __RUN_LBA_INQUIRY_S__

lba_inquiry_prepare:
    movb        $0x41,              %ah
    movw        $0x55AA,            %bx

lba_inquiry_inquire:
    int         $0x13

lba_inquiry_errcheck:
    jc          _finish

lba_inquiry_validate_magic:
    cmpw        $0xAA55,            %bx
    jne         _finish

lba_inquiry_validate_EXRW: 
/*******************************************************************************
 * https://wiki.osdev.org/Disk_access_using_the_BIOS_(INT_13h)
 *   For this part of the guide bit 0 should be set, which
 *   indicates support for the extended read/write services.
 ******************************************************************************/
    testb       $1,                 %cl
    jz          _finish

#endif /* __RUN_LBA_INQUIRY_S__ */