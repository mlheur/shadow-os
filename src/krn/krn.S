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
                movw        $28,            %cx
                jmp         savedx

msg_vec_seg:    .asciz " segment:0x"
msg_vec_off:    .asciz " offset:0x"
msg_interrupt:  .asciz "int:0x"
DumpIVT:        pusha
                xorl        %ebx,           %ebx /* start at int 0x00 */
                movl        %ebx,           %ecx /* use cx as copy of ds register during IVT reads */
                movw        %ds,            %dx  /* use dx as copy of ds register during prints reads */

1:              prints      (msg_interrupt)
                movw        %bx,            %ax
                call        print_byte

                prints      (msg_vec_seg)
                movw        %cx,            %ds
                movw        2(,%ebx,4), %ax
                movw        %dx,            %ds
                call        print_word

                prints      (msg_vec_off)
                movw        %cx,            %ds
                movw        (,%ebx,4),  %ax
                movw        %dx,            %ds
                call        print_word

                prints      (_str_crlf)

                addb        $1,             %bl /* the last interrupt is 0xFF */
                jnc         1b                  /* loop until the carry flag gets set rolling past 0xFF */
                popa
                ret

#endif /* __KRN_S__ */