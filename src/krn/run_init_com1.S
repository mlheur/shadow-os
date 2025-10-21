#ifndef __RUN_INIT_COM1_S__
#define __RUN_INIT_COM1_S__
    SERIALOUT = 0x0400 /* Ralf Brown says MEM 0040h:0000h - BASE I/O ADDRESS OF FIRST SERIAL I/O PORT */
init_COM1:
    pusha
    movw    $0x0003,    %ax /* 19200-8-None-1 */
    xorw    %dx,        %dx /* port 0 */
    int     $0x14       /* latch that in */
    popa
#endif /*  __RUN_INIT_COM1_S__ */