#ifndef __KRN_S__
#define __KRN_S__

    .code16

#include "globals.h"
#include "prints.h"


/*******************************************************************************
 * The sequence of events so far:
 * BIOS code sits in ROM
 *  Power on the computer
 *   CPU sets its initial vector, somehwere in the BIOS ROM
 *    BIOS reads CMOS data, chooses a boot device, reads its first sector
 *     BIOS puts that sector in RAM at 0x7C00 and long calls the MBR
 *      MBR passes the bootdevice ID to SHADOW_OS via dl register
 *      MBR sets the cs and ds registers to 1000 before jumping to SHADOW_OS
 *      MBR loaded the bootdevice to 1000:0000, including itself, consequently
 *       SHADOW_OS was loaded at 1000:0200, MBR long jumps here and here we are.
 ******************************************************************************/
    .data
    . = 0x200
    .text
SHADOW_OS:      prints      (osname)
                prints      (_str_crlf)
                call        DumpIVT
FIN:            popa /* MBR saved this from the BIOS, we got here via jumps */
RETURN_TO_BIOS: lret /* qemu seems to like lret to return to the BIOS after it (l)calls MBR */

osname: .asciz "(SHADOW)"

print_long:     pushw       %cx
                movw        $28,        %cx
                jmp         savedx

msg_address:    .asciz "address:0x"
msg_vector:     .asciz " vector:0x"
DumpIVT:        xorw        %ax,        %ax
                movw        %ax,        %si
                movl        $0400,      %ecx /* read from 0x0400 down to 0x0000, stepping by four */
1:              subl        $4,         %ecx
                pushf
                prints      (msg_address)
                movw        %cx,        %ax
                call        print_word
                prints      (msg_vector)
                movw        (%ecx),     %ax
                call        print_word
                prints      (_str_crlf)
                popf
                jz          _ret
                jmp         1b

#endif /* __KRN_S__ */