    .file "prints.S"
#ifndef __PRINTS_S__
#define __PRINTS_S__


_str_crlf:      .asciz "\r\n"


/*******************************************************************************
 * Function: _prints
 * Purpose: write a null-terminated string through altty
 * Parameters: ds:si the address of the first character
 * Outputs: None. */
_prints:        lodsb                       /* copy the character to al, increment si */
                testb   %al,                %al /* test if it is the null terminator */
                jz      _ret
                call    altty
                jmp     _prints
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
print_long:     pushw   %cx
                movw    $28,                %cx
                jmp     _print_nibbles
/******************************************************************************/


/*******************************************************************************
 * Function: nibble_ascii
 * Purpose: convert four bits to one of the characters 0-9,A-F; send it out */
nibble_ascii:   andb    $0x0F,              %al
                cmpb    $0x0A,              %al
                sbbb    $0x69,              %al
                das /* carry on to altty */
/*******************************************************************************
 * Function: altty
 * Purpose: send a byte out the serial port and teletype */
altty:
outb_com1:      pushw   %dx
                xorw    %dx,                %dx /* Serial Port 0 */
                movb    $0x01,              %ah /* "send" command */
                int     $0x14
                popw    %dx
outb_tty:       pushw   %bx
                movw    $0x0001,            %bx /* bh=page,bl=fg_colour */
                movb    $0x0e,              %ah /* "tty out" VGA command */
                int     $0x10
                popw    %bx
altty_end:      ret
/******************************************************************************/


/*******************************************************************************
 * Function: debug_regs
 * Purpose: print the registers during the int 0x13 ah=0x02 */
#ifdef DEBUG
dbgES:          .asciz  "ES:"
dbgDX:          .asciz  " DX:"
dbgCX:          .asciz  " CX:"
dbgBX:          .asciz  " BX:"
dbgAX:          .asciz  " AX:"
debug_regs:     pushw   %ax
                pushw   %ax
                prints  (dbgES)
                printw  (%es)
                prints  (dbgBX)
                printw  (%bx)
                prints  (dbgDX)
                printw  (%dx)
                prints  (dbgCX)
                printw  (%cx)
                prints  (dbgAX)
                popw    %ax
                call    print_word
                prints  (_str_crlf)
                popw    %ax
                ret
#endif /* DEBUG */
/******************************************************************************/

#endif /* __PRINTS_S__ */