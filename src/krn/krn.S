#ifndef __KRN_S__
#define __KRN_S__

    .code32

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
SHADOW_OS:      /* prints      (osname) */
                movl        $osname, %esi
                call        strout
                prints      (crlf)
                call        DumpIVT
FIN:            popa /* MBR saved this from the BIOS, we got here via jumps */
RETURN_TO_BIOS: lret /* qemu seems to like lret to return to the BIOS after it (l)calls MBR */

osname: .asciz "(SHADOW)"

print_long:     pushl       %ecx
                movl        $28,        %ecx
                jmp         savedx

msg_address:    .asciz "address:0x"
msg_vector:     .asciz " vector:0x"
DumpIVT:        xorl        %eax,       %eax
                movl        %eax,       %esi
                movl        $0400,      %ecx /* read from 0x0400 down to 0x0000, stepping by four */
                subl        $4,         %ecx
                pushf
                prints      (msg_address)
                movl        %ecx,       %eax
                call        print_long
                prints      (msg_vector)
                movl        (%ecx),     %eax
                call        print_long
                prints(crlf)
                popf
                jz          return

#endif /* __KRN_S__ */