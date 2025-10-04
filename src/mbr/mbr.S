    .file "mbr.S"
#ifndef __MBR_S__
#define __MBR_S__


#define DEBUG
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
    .code16
    . = 0
_start:         pusha /* preserve BIOS registers, KRN will restore pre-lret */
jump_mbr_segm:  ljmp    $MBR_SEGM,          $MBR /* Run the MBR into KRN */
/******************************************************************************/
halting:        prints  (msg_halting)
halt:           sti
                hlt
                jmp     halt
/******************************************************************************/
return:         ret /* derefence indirect "Jcc return" */
/******************************************************************************/

/*******************************************************************************
 * Static Data
 ******************************************************************************/
osname:                 .ascii              "[s]" /* include the crlf */
crlf:                   .asciz              "\r\n"
msg_halting:            .asciz              "fin"
/******************************************************************************/

/*******************************************************************************
 * Import functions for console output and disk input.
 * These will stay resident under KRN_SEGM:offset
 ******************************************************************************/
#include "prints.S"
#include "chs_read.S"

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
init_COM1:      movw    $0xE3,              %ax /* 9600-8-None-1 */
                xorw    %dx,                %dx /* port 0 */
                int     $0x14               /* latch that into the serial controller's settings */
target_krn:     movw    $KRN_SEGM,          %ax /* pass the KRN_SEGM ... */
                movw    %ax,                %es /* ... to chs_read via es */
read_bootdev:   call    chs_read            /* copy the bootdev to RAM */
pass_bootdevid: movzbw  chs_cmd.device,     %dx /* pass bootdev id on to the kernel via dl */
_kernel:        movw    $KRN_SEGM,          %ax /* Do the kernel a favour ... */
                movw    %ax,                %ds /* ... set the ds we chose for it */
run_kernel:     ljmp    $KRN_SEGM,          $KRN /* Run the kernel in its code segment */
/*******************************************************************************
 * End MBR function
 ******************************************************************************/

/*******************************************************************************
 * the last 2 bytes in the sector 0 must contain the signature */
    . = 0x1fe
signature:      .short 0xAA55
    . = 0x200
KRN:
/******************************************************************************/

#endif /* __MBR_S__ */