#ifndef __FUN_PRINTS_S__
#define __FUN_PRINTS_S__


_str_crlf:      .asciz "\r\n"


/*******************************************************************************
 * Function: _prints
 * Purpose: write a null-terminated string through outb_com1
 * Parameters: ds:si the address of the first character
 * Outputs: None. */
_prints:        lodsb                       /* copy the character to al, increment si */
                testb   %al,                %al /* test if it is the null terminator */
                jz      _ret
                call    outb_com1
                jmp     _prints
/******************************************************************************/


/*******************************************************************************
 * Function: nibble_ascii
 * Purpose: convert four bits to one of the characters 0-9,A-F; send it out */
nibble_ascii:   andb    $0x0F,              %al
                cmpb    $0x0A,              %al
                sbbb    $0x69,              %al
                das /* carry on to outb_com1 */
/*******************************************************************************
 * Function: outb_com1
 * Purpose: send a byte out the serial port, wait for completion */
outb_com1:      pushw   %dx
                movw    COM1_BASE,          %dx
                outb    %al,                %dx
                movw    COM1_LINE_STAT,     %dx /* watch the status register for completion */
1:              inb     %dx,                %al
                testb   $0x20,              %al
                jz      1b
                popw    %dx
                ret
/******************************************************************************/


/*******************************************************************************
 * Function: print_word; this one is called more often, goes first with fewest jumps
 * Function: print_byte; put this one later, to have faster jump backward.
 * Purpose: convert one or two bytes into to ascii, then send it out */
print_word:     pushw   %cx                         /* use cx as a loop counter for nibble shifting */
                movw    $12,                %cx     /* shift 12 bits, then 8, then 4, then zero */
_print_nibbles: pushl   %esi                        /* use esi as a backup of eax */
                movl    %eax,               %esi    /* make the backup */
1:              shrl    %cl,                %eax    /* get the nibble */
                call    nibble_ascii
                movl    %esi,               %eax    /* restore from backup */
                subw    $4,                 %cx     /* decrement the loop counter */
                jnc     1b                          /* repeat until the zeroth iteration is complete and the loop counter forced a carry */
                popl    %esi                        /* restore esi, eax is already restored */
                popw    %cx                         /* restore cx */
                ret
/******************************************************************************/
print_byte:     pushw   %cx                         /* use cx as a loop counter for nibble shifting */
                movw    $4,                 %cx     /* shift four bits, then zero bits */
                jmp     _print_nibbles /* jumping bacwkward is faster than jumping forward */
/******************************************************************************/

#endif /* __FUN_PRINTS_S__ */