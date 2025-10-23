#ifndef __MBR_S__
#define __MBR_S__
    .code16
    .text
#include "mbr.h"
#include "segments.h"
/*******************************************************************************
 * BIOS hands over to MBR:
 * The only things that are (nearly) certain are that
 *  - the bootsector code is loaded and running at physical address 0x7c00,
 *  - the CPU is in 16-bit Real Mode,
 *  - the CPU register called dl contains the "drive number",
 *  - and that only 512 bytes of the bootsector have been loaded.
 * -- https://wiki.osdev.org/System_Initialization_(x86)
 ******************************************************************************/
mbr_start:
/******************************************************************************/
relocmbr_set_segments:
    movw    $(SEGM_BIOSBOOT),               %cx
    movw    %cx,                            %ds
    shlw    $4,                             %cx /* three lines ... */
    subw    $(sizeof_MBR),                  %cx /* to do subw $(sizeof_mbr>>4), ... */
    shrw    $4,                             %cx /* because assembly happens before linking. */
    movw    %cx,                            %es
relocmbr_copy_mbr:
    xorw    %cx,                            %cx
    movw    %cx,                            %si
    movw    %cx,                            %di
    movw    $(sizeof_MBR),                  %cx /* two lines to do movw $(sizeof_MBR/4) ... */
    shrw    $2,                             %cx /* because assembly happens before linking. */
    rep     movsl
relocmbr_verify:
    cmpw    $(MBR_MAGIC),    %es:(mbr_signature)
    jne     _finish
relocmbr_align_partition_table:
    movw    $(aligned_partition_table),     %di
    movw    $(mbr_partition_table),         %si
    movw    $(sizeof_partition_entry),      %cx /* happy coincidence that 4 bytes per long matches 4 partitions per drive */
    rep     movsl
relocmbr_run_relocated_mbr:
    movw    $(1f),                          %si
    subw    $(sizeof_MBR),                  %si
    addw    $(SEGM_BIOSBOOT<<4),            %si
    pushw   %es
    pushw   %si
    jmp     *(%esp)
1:  popw    %si
    popw    %es
/******************************************************************************/
lba_inquiry_prepare:
    movb    $0x41,                          %ah
    movw    $(MBR_MAGIC),                   %bx
    rorw    $8,                             %bx
lba_inquiry_inquire:
    int     $0x13
lba_inquiry_errcheck:
    jc      _finish
lba_inquiry_validate_magic:
    cmpw    $(MBR_MAGIC),                   %bx
    jne     _finish
lba_inquiry_validate_EXRW: 
    testb   $1,                             %cl
    jz      _finish
/******************************************************************************/
mbr_set_esi_first_partition:
    movw    $aligned_partition_table,       %si
mbr_is_partition_active:
    cmpb    $0x80,                    %es:(%esi)
    jne     mbr_next_partition
relocmbr_swap_es_ds:
    pushw   %ds /* 0x7c00 */
    pushw   %es /* 0x7a00 */
    popw    %ds /* 0x7a00 */
    popw    %es /* 0x7c00 */
mbr_use_partition_entry_as_lbacmd_packet:
    xorl    %eax,                          %eax  /* get a zero */
    movb    $0x10,                        (%esi) /* save packet size */
    movb    %al,                         1(%esi) /* save magic: 0x00 */
    movw    $1,                          2(%esi) /* save readlen */
    movw    %ax,                         4(%esi) /* save offset: 0x0000 */
    movw    $SEGM_BIOSBOOT,              6(%esi) /* save segment */
    movl    %eax,                       12(%esi) /* lba high: 0x00000000 */
mbr_load_active_pbr:
    movb    $0x42,                          %ah  /* lba "read" */
    int     $0x13
    jc      _finish
mbr_check_is_bootable:
    cmpw    $MBR_MAGIC,      %es:(mbr_signature)
    jne     _finish
mbr_run_active_pbr:
    ljmp    $0,              $(SEGM_BIOSBOOT<<4)
/******************************************************************************/
mbr_next_partition:
    addw    $(sizeof_partition_entry),      %si /* increment */
    cmpw    $sizeof_MBR,                    %si /* check for rollover */
    jb      mbr_is_partition_active         /* not rolled over, test the partition */
/******************************************************************************/
_finish:
    lret
/******************************************************************************/

#endif /* __MBR_S__ */