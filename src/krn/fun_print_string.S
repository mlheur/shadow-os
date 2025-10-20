#ifndef __FUN_PRINT_STRING_S__
#define __FUN_PRINT_STRING_S__

#include "serial_ports.h"

/*******************************************************************************
 * Inputs:
 *  ds:si the address of the first character; si desroyed on completion.
 ******************************************************************************/

/******************************************************************************/
print_string:
    pushw   %ax     /* guard ax */
    pushw   %dx     /* guard dx */
    movw    $COM1,  %dx
    cld
print_string_next_byte:
1:  lodsb           /* copy the character to al, increment si */
    testb   %al,    %al /* test if it is the null terminator */
    jz      1f
    call    outXb   
    jmp     1b
/* good place to hide this */
_str_crlf:  .asciz "\r\n"
/******************************************************************************/
print_string_return:
1:  popw    %dx     /* restore dx */
    popw    %ax     /* restore ax */
    ret
/******************************************************************************/


#endif /* __FUN_PRINT_STRING_S__ */