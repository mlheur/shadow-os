#ifndef __KRN_S__
#define __KRN_S__

#include "prints.h"

    .text
    .code16
SHADOW_OS:      prints      (osname)
                prints      (crlf)
FIN:            popa /* MBR saved this from the BIOS, we got here via jumps */
RETURN_TO_BIOS: lret /* qemu seems to like lret to return to the BIOS after it (l)calls MBR */

#endif /* KRN_S */