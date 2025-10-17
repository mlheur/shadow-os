#ifndef __RUN_INIT_COM1_S__
#define __RUN_INIT_COM1_S__

#ifndef AVOID_INTERRUPTS

init_COM1:  movw        $0x0003,    %ax /* 19200-8-None-1 */
            xorw        %dx,        %dx /* port 0 */
            int         $0x14       /* latch that into the serial controller's settings */

#else /* AVOID_INTERRUPTS */

/* plagarized from https://wiki.osdev.org/Serial_Ports, but I typed it myself */

init_COM1:
OUTB    ($0x00, COM1_IRQ_STAT)  /* inhibit interrupts */
OUTB    ($0x80, COM1_LINE_CTL)  /* DLAB ON */
OUTB    ($0x01, COM1_DIV_LO)    /* Max baud */
OUTB    ($0x00, COM1_DIV_HI)    /* Max baud */
OUTB    ($0x03, COM1_LINE_CTL)  /* 8N1 */
OUTB    ($0xc7, COM1_FIFO_CTL)  /* Enable FIFO, clear Tx/Rx Qs, all 14 bits worth */
OUTB    ($0x0b, COM1_MODM_CTL)  /* assert RTS, assert DTS, enable interrupts */
OUTB    ($0x1E, COM1_MODM_CTL)  /* enter loopback mode */
OUTB    ($0xAE, COM1_BUFFER)    /* send some data */
inb     %dx,    %al             /* receive the btye, dx still still set from OUTB */
cmpb    $0xAE,  %al             /* check if it was the one we sent */
jne     _hlt                    /* or bail */
OUTB    ($0x0F, COM1_MODM_CTL)  /* disable loopback mode, assert both Out pins */

#endif /* AVOID_INTERRUPTS */


#endif /*  __RUN_INIT_COM1_S__ */