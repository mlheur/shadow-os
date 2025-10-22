#ifndef __FUN_OUTX_S__
#define __FUN_OUTX_S__

/*******************************************************************************
 * Inputs:
 *  al: The nibble or byte to send out the port; destroyed on completion.
 *  dx: The com port address, e.g. 0x3F8; saved on completion.
 ******************************************************************************/

/*******************************************************************************
 * convert low nibble of al from binary to ascii */
outXa:
    andb    $0x0F,  %al
    cmpb    $0x0A,  %al
    sbbb    $0x69,  %al
    das     /* carry on to outXb */
/*******************************************************************************
 * send a byte out the given serial port */
outXb:
#ifdef USE_TELETYPE
    movb    $0x0E,  %ah
    int     $0x10
#endif /* USE_TELETYPE */
#ifdef USE_SERIALIO
    outb    %al,    %dx
    addw    $5,     %dx /* watch the line status register for completion */
1:  inb     %dx,    %al /* grab the latest line status register value */
    testb   $0x20,  %al /* when bit 0x20 is set, the write is complete */
    jz      1b
    subw    $5,     %dx /* revert to the buffer register */
#endif /* USE_SERIALIO */
    ret
/******************************************************************************/

#endif /* __FUN_OUTX_S__ */