#ifndef __MBR_S__
#define __MBR_S__

    .code16
    .text

#include "mbr.h"
#include "segments.h"
#include "prints.h"

/*******************************************************************************
 * BIOS hands over to MBR:
 * The only things that are (nearly) certain are that
 *  - the bootsector code is loaded and running at physical address 0x7c00,
 *  - the CPU is in 16-bit Real Mode,
 *  - the CPU register called dl contains the "drive number",
 *  - and that only 512 bytes of the bootsector have been loaded.
 * -- https://wiki.osdev.org/System_Initialization_(x86)
 ******************************************************************************/
_start:
    ljmp    $SEGM_BIOSBOOT,         $_mbr
/******************************************************************************/
mbr_next_partition:
    addw    $LEN16_PARTITION_ENTRY, %si /* increment */
    cmpw    $LEN16_MBR,             %si /* check for rollover */
    jb      mbr_is_partition_active /* not rolled over, test the partition */
/******************************************************************************/
_finish:
    lret
/******************************************************************************/

/******************************************************************************/
_mbr:
#include "run_relocate_mbr.S"       /* destroys cx,ds,es */
#include "run_lba_inquiry.S"        /* destroys ax,cx,bx */

mbr_movw_cs_ds:
    pushw   %cs
    popw    %ds

mbr_set_esi_first_partition:
    movw    $PTR16_PARTITION_TABLE, %si

mbr_is_partition_active:
    cmpb    $0x80,                  %cs:(%esi)
    jne     mbr_next_partition

mbr_use_partition_entry_as_lbacmd_packet:
    xorl    %eax,                   %eax        /* get a zero */
    movb    $0x10,                  %ds:(%esi)  /* save packet size */
    movb    %al,                    %ds:1(%esi) /* save magic: 0x00 */
    movw    $1,                     %ds:2(%esi) /* save readlen */
    movw    %ax,                    %ds:4(%esi) /* save offset: 0x0000 */
    movw    $SEGM_BIOSBOOT,         %ds:6(%esi) /* save segment */
    movl    %eax,                   %ds:12(%esi)/* lba high: 0x00000000 */

mbr_load_active_pbr:
    movw    $0x4200,                %ax         /* lba "read" */
    int     $0x13
    jc      _finish

mbr_check_is_bootable:
    cmpw    $MBR_MAGIC,             (LEN16_MBR+mbr_signature)
    jne     _finish
    
mbr_run_active_pbr:
    ljmp    $0,                     $(_start+(SEGM_BIOSBOOT<<4))
/******************************************************************************/

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