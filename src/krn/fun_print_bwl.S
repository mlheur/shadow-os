#ifndef __FUN_PRINT_BWL_S__
#define __FUN_PRINT_BWL_S__

/*******************************************************************************
 * Inputs:
 *  eax: The binary data to send out the port; destroyed completion.
 ******************************************************************************/

#define _print_setup(N) pushw %cx; movw $(-4+8*N),%cx
#define _print_done     popw %cx;

/*******************************************************************************
 * Purpose: convert 1, 2 or 4 bytes into to ascii; and send them out COM1 */
print_word:
    _print_setup(2)
#ifdef USE_SERIALIO
2:  movw    $SERIALOUT,     %dx  /* Ralf Brown says MEM 0040h:0000h - BASE I/O ADDRESS OF FIRST SERIAL I/O PORT */
    movw    %fs:(%edx),     %dx  /* serial port address is loaded */
#else
2:
#endif /* USE_SERIALIO */
    pushl   %ebx                 /* use ebx as a backup of eax */
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