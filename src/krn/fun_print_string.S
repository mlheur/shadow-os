#ifndef __FUN_PRINT_STRING_S__
#define __FUN_PRINT_STRING_S__

/*******************************************************************************
 * Inputs:
 *  ds:si the address of the first character; si desroyed on completion.
 ******************************************************************************/

/******************************************************************************/
print_string:
#ifdef USE_SERIALIO
    movw    $SERIALOUT, %dx
    movw    %fs:(%edx), %dx
#endif /* USE_SERIALIO */
print_string_next_byte:
1:  lodsb               /* copy the character to al, increment si */
    testb   %al,        %al /* test if it is the null terminator */
    jz      1f
    call    outXb   
    jmp     1b
/* good place to hide this */
_str_crlf:  .asciz "\r\n"
/******************************************************************************/
print_string_return:
1:  ret
/******************************************************************************/

#endif /* __FUN_PRINT_STRING_S__ */