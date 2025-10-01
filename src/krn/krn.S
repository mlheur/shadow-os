#define KRN_S

#include "../mbr/prints.h"

    .extern osname

    .text
    .code16
                prints      (crlf)
FIN:            popa /* MBR saved this from the BIOS, we got here via jumps */
RETURN_TO_BIOS: lret /* qemu seems to like lret to return to the BIOS after it (l)calls MBR */
