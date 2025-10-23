#ifndef __IVT_S__
#define __IVT_S__

#include "prints.h"

msg_interrupt:  .asciz "int:0x"
msg_vec_seg:    .asciz " segment:0x"
msg_vec_off:    .asciz " offset:0x"
DumpIVT:        pushaw
                xorl        %ebx, %ebx /* start at int 0x00 */
1:              prints      ($msg_interrupt)
                printb      (%bl)
                prints      ($msg_vec_seg)
                printw      (%es:2(,%ebx,4))
                prints      ($msg_vec_off)
                printw      (%es:(,%ebx,4))
                prints      ($_str_crlf)
                addb        $1, %bl /* the last interrupt is 0xFF */
                jnc         1b /* loop until the carry flag gets set rolling past 0xFF */
                popaw
                ret

#endif /* __IVT_S__ */