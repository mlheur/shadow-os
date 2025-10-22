#ifndef __KRN_S__
#define __KRN_S__

    .code16
    .text

#include "mbr.h"
#include "segments.h"
#include "prints.h"

/* #define USE_TELETYPE /**/
#define USE_SERIALIO /**/

/*******************************************************************************
 * The sequence of events so far:
 * BIOS code sits in ROM
 *  Power on the computer
 *   CPU sets its initial vector, somehwere in the BIOS ROM
 *    BIOS reads CMOS data, chooses a boot device, reads its first sector
 *     QEMU uses a stack limit 0000:6FFFF and below
 *     BIOS puts that sector in RAM at 0x7C00 and long calls the MBR
 *      MBR loaded the PBR to 0000:7C00, size 512 Bytes
 *      MBR passes the bootdevice ID to SHADOW_OS via dl register
 *       SHADOW_OS was loaded at 0000:7C00, MBR long jumps here and here we are.
 ******************************************************************************/
_start:
0:  ljmp    $SEGM_BIOSBOOT,$1f
1:  pushw   %cs
    popw    %ds
    jmp     SHADOW_OS
/******************************************************************************/
osname: .asciz "(SHADOW)"
/******************************************************************************/

/*******************************************************************************
 * Import functions for console output and disk input. These will stay resident.
 ******************************************************************************/
#include "fun_outX.S"
#include "fun_print_string.S"
#include "fun_print_bwl.S"

#include "ivt.S"
#include "ram.S"

/******************************************************************************/
SHADOW_OS:
#include "run_init_com1.S"
    prints  ($osname)
    prints  ($_str_crlf)
    call    DumpIVT /**/
    call    DumpRAM /**/
    lret    /* return to BIOS */
/******************************************************************************/

/******************************************************************************/
    . = _start + 0x1FE /* Proper MBRs won't boot us without this */
.word   MBR_MAGIC

#endif /* __KRN_S__ */