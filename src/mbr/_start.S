#ifndef __MBR_S__
#define __MBR_S__

    .bss

LBA_CMD_PACKET: /* linker will put this at 0x7000, 16 byte aligned */
lcb.sizeof:     .byte 0
lcb.magic:      .byte 0
lcb.readlen:    .word 0
lcb.writesegm:  .word 0
lcb.writeoffs:  .word 0
lcb.lba_low:    .long 0
lcb.lba_high:   .long 0
sizeof_LBA_CMD_PACKET = . - LBA_CMD_PACKET

JUMP_POINTER:
reljump_segm:   .word 0
reljump_offs:   .word 0
sizeof_JUMP_POINTER = . - JUMP_POINTER
#define LONGJUMP(O,S) movw S,reljump_segm; movw O,reljump_offs; ljmp *JUMP_POINTER
#define NEARJUMP(O,S) movw S,reljump_segm; movw O,reljump_offs;  jmp *JUMP_POINTER

    .text
    .code16

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


/*******************************************************************************
 * Phase 0: Guard DX. It's used to inquire if LBA mode is supported by the BIOS,
 *          and again when performing the LBA read on PBR.  A good MBR will
 *          pass this to PBR.  Perhaps also ds:si should point to the partition
 *          entry in the MBR table.
 ******************************************************************************/

_start:

#define BOOTSEGM %gs
#define BOOTOFFS %fs
#define RELOCSEGM %es

/*******************************************************************************
 * Phase 1: Relocate the MBR backward to make room for PBR; BPR will also expect
 *          to have been loaded by BIOS at _start since PBR could be MBR of a
 *          floppy or can be PBR of a partition.  Floppy MBRs don't do what's
 *          being done here, they just load their OS or run their application.
 ******************************************************************************/

mbr_load_bootvector:
    call    1f
1:  popw    %cx
    subw    $(1b-_start),   %cx

mbr_save_bootvector:
    movw    %cx,            BOOTOFFS

mbr_save_bootsegm:
    shrw    $4,             %cx
    movw    %cx,            BOOTSEGM

mbr_memcpy_set_source_address:
    movw    BOOTOFFS,       %cx
    movw    %cx,            %si

mbr_memcpy_set_target_address:
    subw    $(sizeof_MBR),  %cx
    movw    %cx,            %di

mbr_save_relocsegm:
    shrw    $4,             %cx
    movw    %cx,            RELOCSEGM

mbr_memcpy_relocate_mbr:
    movw    $(longof_MBR),  %cx
    rep     movsl

/******************************************************************************/

verify_mbr_memcpy_success:
    cmpw    $(MBR_MAGIC),   BOOTSEGM:(mbr_signature)
    jne     _finish

/******************************************************************************/


/*******************************************************************************
 * Phase 2: Move execution to the MBR code that was memcpy'd backward by sizeof
 *          MBR.  If the sizeof MBR was known at assembly time, this would be
 *          a simple relative jump backward by that size + few bytes of the jump
 *          instruction itself.  Since both those values are only properly known
 *          at link time, MBR is forced to use an absolute jump whose address is
 *          calculated at runtime, saved in ram, and used as a pointer. Do this.
 ******************************************************************************/

mbr_jump_to_relocated_mbr:
    movw    BOOTOFFS,       %si /* start at the BIOS boot address */
    subw    $(sizeof_MBR),  %si /* backtrack by the size of the MBR */
    addw    $(1f),          %si /* fast forward past the jump instruction */
    NEARJUMP($0,%si)
1:  

/******************************************************************************/


/*******************************************************************************
 * Phase 3: Ensure the BIOS supports LBA read, apparently that's Pentium & up.
 ******************************************************************************/

lba_inquiry_prepare:
    movb    $0x41,          %ah /* setup the function ID for BIOS Inquiry */
    movw    $(MBR_MAGIC),   %bx /* doing in two steps to minize magic numbers in code */
    rorw    $8,             %bx /* 0x55AA is needed to setup LBA inquiry */
    int     $0x13               /* inquire */
    jc      _finish             /* give up, return to BIOS on failure */

lba_inquiry_validate_magic:
    cmpw    $(MBR_MAGIC),   %bx /* We know LBA read is enabled when the magic is back to 0xAA55 */
    jne     _finish             /* or bail to BIOS if it's not enabled */

lba_inquiry_validate_EXRW: 
    testb   $1,             %cl /* finally, bit 1 must be set in the cx reply to be sure we have LBA read */
    jz      _finish             /* else we return to BIOS */

/******************************************************************************/


/*******************************************************************************
 * Phase 4: Find the active partition.
 ******************************************************************************/

mbr_set_si_first_partition:
    movw    $(aligned_partition_table), %si

mbr_is_partition_active:
    cmpb    $0x80, RELOCSEGM:(%esi)
    jne     mbr_next_partition

/******************************************************************************/


/*******************************************************************************
 * Phase 5: Use LBA read, load the active partition's PBR where BIOS loaded MBR
 ******************************************************************************/

mbr_use_partition_entry_as_lbacmd_packet:
    movl    %ds:8(%esi),    %eax
    movl    %eax,           lcb.lba_low
    xorl    %eax,           %eax  /* get a zero */
    movl    %eax,           lcb.lba_high
    movw    %ax,            lcb.writesegm
    movb    %al,            lcb.magic
    movw    BOOTSEGM,       lcb.writeoffs
    movb    $0x10,          lcb.sizeof
    movw    $1,             lcb.readlen

mbr_load_active_pbr:
    movb    $0x42,          %ah /* lba "read" function ID */
    int     $0x13               
    jc      _finish

mbr_check_is_bootable:
    cmpw    $MBR_MAGIC,     %es:(mbr_signature)
    jne     _finish

mbr_run_active_pbr:
    LONGJUMP($0,BOOTOFFS)

/******************************************************************************/

mbr_next_partition:
    addw    $(sizeof_partition_entry),  %si /* increment */
    cmpw    $sizeof_MBR,                %si /* check for rollover */
    jb      mbr_is_partition_active         /* not rolled over, test flags */

/******************************************************************************/

_finish:
    lret

/******************************************************************************/

#endif /* __MBR_S__ */