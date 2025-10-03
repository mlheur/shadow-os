#ifndef __KRN_S__
#define __KRN_S__

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
    .text
    .code16
SHADOW_OS:      prints      (osname)
                prints      (crlf)
FIN:            popa /* MBR saved this from the BIOS, we got here via jumps */
RETURN_TO_BIOS: lret /* qemu seems to like lret to return to the BIOS after it (l)calls MBR */


#endif /* __KRN_S__ */