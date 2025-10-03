    .file "mbr.S"
#ifndef __MBR_S__
#define __MBR_S__

#define DEBUG
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


/******************************************************************************/
/* Missing in the above, taken from : https://wiki.osdev.org/Memory_Map_(x86) */
/* 0000:0000 until 0000:03FF IVT Used by the BIOS, don't write here */
/* 0040:0000 until 0040:00FF BDA Used by the BIOS, don't write here */
/* [0040:0100 is 0050:0000] until 7000:FFFF Conventional Memory */
#define MBR_SEGM 0x07C0 /* BIOS loads us here */
#define KRN_SEGM 0x1000 /* 0x10000 - 0x1FFFF */
/* 8000:0000 until 9000:FFFF EBDA */
/* A000:0000 until B000:FFFF VRAM */
/* C000:0000 until C000:7FFF BIOS Expansion */
/* C000:8000 until E000:FFFF VGA BIOS */
/* F000:0000 until F000:FFFF Motherboard BIOS */
/******************************************************************************/



/*******************************************************************************
 * BIOS Entry Point into MBR, testing in qemu shows we get here via lcall.
 ******************************************************************************/
    .global  _start
    .text
    .code16
    . = 0
_start:         pusha /* preserve BIOS registers, KRN will restore pre-lret */
                ljmp    $MBR_SEGM,          $MBR /* Run the MBR into KRN */
/******************************************************************************/


/*******************************************************************************
 * Static Data
 ******************************************************************************/
    .global osname
osname:                 .ascii              "[s]" /* include the crlf */
    .global crlf
crlf:                   .asciz              "\r\n"
msg_halting:            .asciz              "fin"
/******************************************************************************/


/*******************************************************************************
 * Import functions for console output and disk input.
 * These will stay resident under KRN_SEGM:offset
 ******************************************************************************/
.include "prints.S"
.include "chs_read.S"


/******************************************************************************/
halting:        prints  (msg_halting)
halt:           sti
                hlt
                jmp     halt
/******************************************************************************/
return:         ret /* used only for indirect "Jcc return" */
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
init_COM1:      movw    $0xE3,              %ax /* 9600-8-None-1 */
                xorw    %dx,                %dx /* port 0 */
                int     $0x14               /* latch that into the serial controller's settings */
target_krn:     movw    $KRN_SEGM,          %ax /* pass the KRN_SEGM ... */
                movw    %ax,                %es /* ... to chs_read via es */
read_bootdev:   call    chs_read            /* copy the bootdev to RAM */
_kernel:        movw    $KRN_SEGM,          %ax /* Do the kernel a favour ... */
                movw    %ax,                %ds /* ... set the ds we chose for it */
pass_bootdev:   movzbw  chs_cmd.device,     %dx /* pass bootdev on to the kernel via dl */
                ljmp    $KRN_SEGM,          $KRN /* Run the kernel */
/*******************************************************************************
 * End MBR function
 ******************************************************************************/


/*******************************************************************************
 * the last 2 bytes in the sector 0 must contain the signature */
    . = 0x1fe
signature:      .short 0xAA55
    . = 0x200
    .global KRN
KRN:            prints      (osname)
FIN:            popa /* MBR saved this from the BIOS, we got here via jumps */
RETURN_TO_BIOS: lret /* qemu seems to like lret to return to the BIOS after it (l)calls MBR */
/******************************************************************************/

#endif /* __MBR_S__ */