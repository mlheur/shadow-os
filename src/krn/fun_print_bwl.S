#ifndef __FUN_PRINT_BWL_S__
#define __FUN_PRINT_BWL_S__

#include "serial_ports.h"

/*******************************************************************************
 * Inputs:
 *  eax: The binary data to send out the port; destroyed completion.
 ******************************************************************************/

#define _print_setup(N) pushw %dx; pushw %cx; movw $COM1,%dx; movw $(-4+8*N),%cx
#define _print_done  popw %cx; popw %dx

/*******************************************************************************
 * Purpose: convert 1, 2 or 4 bytes into to ascii; and send them out COM1 */
print_word:
    _print_setup(2)
2:  pushl   %ebx                 /* use ebx as a backup of eax */
    movl    %eax,           %ebx /* make the backup */
1:  shrl    %cl,            %eax /* get the nibble */
    call    outXa
    movl    %ebx,           %eax /* restore from backup */
    subw    $4,             %cx  /* decrement the loop counter */
    jnc     1b                   /* repeat until the zeroth iteration is complete and the loop counter forced a carry */
    popl    %ebx                 /* restore ebx, eax is already restored */
    _print_done
    ret
/******************************************************************************/
print_byte:
    _print_setup(1)
    jmp     2b                   /* jumping bacwkward is faster than jumping forward */
/******************************************************************************/
print_long:
    _print_setup(4)
    jmp     2b
/******************************************************************************/


#endif /* __FUN_PRINT_BWL_S__ */