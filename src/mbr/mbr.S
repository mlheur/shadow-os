#ifndef __MBR_S__
#define __MBR_S__

#define __16BIT__
#include "system_bits.h"

/* #define DEBUG /* Enable debugging */
#include "mbr.h"
#include "segments.h"
#include "prints.h"
#include "lba_read.h"

/*******************************************************************************
 * BIOS hands over to MBR:
 * The only things that are (nearly) certain are that
 *  - the bootsector code is loaded and running at physical address 0x7c00,
 *  - the CPU is in 16-bit Real Mode,
 *  - the CPU register called dl contains the "drive number",
 *  - and that only 512 bytes of the bootsector have been loaded.
 * -- https://wiki.osdev.org/System_Initialization_(x86)
 ******************************************************************************/
    .text
_start:
    ljmp    $SEGM_BIOSBOOT, $1f
1:

#include "run_relocate_mbr.S"
#include "run_lba_inquiry.S"

/******************************************************************************/
mbr_check_first_part:
    movl    $PTR16_PARTITION_TABLE, %esi

mbr_check_active_part:
    cmpb    $0x80,                  %cs:(%esi)

mbr_rotate_partition:
    jne     mbr_next_partition

mbr_set_readamt:
    andl    $0x0000FFFF,            %edx
    orl     $0x00010000,            %edx

mbr_set_lba_lolong:
    movl    %cs:8(%esi),            %ecx

mbr_set_lba_hilong:
    xorl    %ebx,                   %ebx

mbr_set_lba_target:
    movl    $SEGM_BIOSBOOT << 16,   %eax

mbr_load_active_pbr:
    call    _lba_read
    jc      _return_to_bios

mbr_check_is_bootable:
    cmpw    $MBR_MAGIC,             (LEN16_MBR+mbr_signature)
    jne     _return_to_bios
    
mbr_run_active_pbr:
    xorw    %ax,%ax
    movw    %ax,%cx
    /* guard dx */
    movw    %ax,%bx
    movw    %ax,%si
    movw    %ax,%di
    movw    %ax,%ds
    movw    %ax,%es
    cld
    /* dx should still contain bootdev from lba_read */
    ljmp    $0,         $(_start+(SEGM_BIOSBOOT<<4))
/******************************************************************************/
mbr_next_partition:
    addw    $LEN16_PARTITION_ENTRY, %si
    cmpw    $LEN16_MBR,             %si
    jne     mbr_check_active_part
    ret
/******************************************************************************/
_return_to_bios:
    lret
/******************************************************************************/


#include "fun_lba_read.S"


/******************************************************************************/
    . = _start + 0x1BE /* assert assembler error if MBR is too big */
mbr_partition_table:
#include "partition_table.S"
    . = _start + 0x1FE  /* assert assembler error if PT is too big */
mbr_signature:
    .short MBR_MAGIC
    . = _start + 0x200 /* assert assembler error if MBR_MAGIC is too big */
    LEN16_MBR = . - _start
/******************************************************************************/


#endif /* __MBR_S__ */