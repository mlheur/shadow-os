#ifndef __RUN_INIT_COM1_S__
#define __RUN_INIT_COM1_S__
init_COM1:  pusha
            movw    $0x0003,    %ax /* 19200-8-None-1 */
            xorw    %dx,        %dx /* port 0 */
            int     $0x14       /* latch that in */
            popa
#endif /*  __RUN_INIT_COM1_S__ */