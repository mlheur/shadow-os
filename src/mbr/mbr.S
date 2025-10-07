    .file "mbr.S"
#ifndef __MBR_S__
#define __MBR_S__

    .code16

/* #define DEBUG */
#include "globals.h"
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

/*******************************************************************************
 * BIOS Entry Point into MBR, testing in qemu shows we get here via lcall.
 ******************************************************************************/
    .text
_start:         pusha /* preserve BIOS registers, KRN will restore pre-lret */
jump_mbr_segm:  ljmp    $MBR_SEGM,          $MBR /* Run the MBR into KRN */
/******************************************************************************/
_halting:       prints  (msg_halting)
halt:           sti
                hlt
                jmp     halt
/******************************************************************************/
_ret:           ret /* derefence indirect "Jcc return" */
/******************************************************************************/

/*******************************************************************************
 * Static Data
 ******************************************************************************/
msg_halting:            .asciz              "fin"
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
save_bootdev:   movb    %dl,                chs_cmd.device /* submit the bootdevice the chs_read function's input parameters */
#include "init_com1.S"
target_krn:     movw    $KRN_SEGM,          %ax /* pass the KRN_SEGM ... */
                movw    %ax,                %es /* ... to chs_read via es */
read_bootdev:   call    chs_read            /* copy the bootdev to RAM */
pass_bootdevid: movzbl  chs_cmd.device,     %edx /* pass bootdev id on to the kernel via dl */
pass_partition: movw    $PARTITION1,        %ax
                movzwl  %ax,                %esi
run_kernel:     ljmp    $KRN_SEGM,          $KRN /* Run the kernel in its code segment */
/*******************************************************************************
 * End MBR function
 ******************************************************************************/

/*******************************************************************************
 * Import functions for console output and disk input.
 * These will stay resident under KRN_SEGM:offset
 ******************************************************************************/
#include "prints.S"
#include "chs_read.S"

/*******************************************************************************
 * https://wiki.osdev.org/Partition_Table */
    . = 0x1BE /* Part 1 */
PARTITION1:
.byte   0x80 /* active */
.byte   0x00 /* starts on head 0 */
.byte   0x02 /* starts on sector 2, mbr is on 1 */
.byte   0x00 /* cylinder zero */
.byte   0xda /* shadow-os.img format, I agree with John Hardin https://aeb.win.tue.nl/partitions/partition_types-1.html */
.byte   0x02 /* up to head 2 (0x80 - 0x3f - 0x3f - 0x02 == 0) */
.byte   0x01 /* just the first two sectors on head 2 */
.byte   0x00 /* all within cylinder zero */
.long   0x00000001
.long   0x0000007F
PARTITION2:
    . = 0x1CE
.long   0x00000000
.long   0x00000000
.long   0x00000000
.long   0x00000000
PARTITION3:
    . = 0x1DE
.long   0x00000000
.long   0x00000000
.long   0x00000000
.long   0x00000000
PARTITION4:
    . = 0x1EE
.long   0x00000000
.long   0x00000000
.long   0x00000000
.long   0x00000000
/******************************************************************************/


/*******************************************************************************
 * the last 2 bytes in the sector 0 must contain the signature */
    . = _start + 0x1fe
signature:      .short 0xAA55
    . = _start + 0x200
KRN:
/******************************************************************************/


#endif /* __MBR_S__ */