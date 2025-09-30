#include "tty.h"


/*******************************************************************************
 * Function: print_byte
 * Function: print_word
 * Purpose: convert one or two bytes into to ascii, then send it out */
print_byte:     pushw   %cx                         /* use cx as a loop counter for nibble shifting */
                movw    $4,                 %cx     /* shift four bits, then zero bits */
                jmp     savedx
/******************************************************************************/
print_word:     pushw   %cx                         /* use cx as a loop counter for nibble shifting */
                movw    $12,                %cx     /* shift 12 bits, then 8, then 4, then zero */
savedx:         pushw   %dx                         /* use dx as a backup of ax */
                movw    %ax,                %dx     /* make the backup */
nibble_loop:    shrw    %cl,                %ax     /* get the nibble */
                call    nibble_ascii
                movw    %dx,                %ax     /* restore from backup */
                subw    $4,                 %cx     /* decrement the loop counter */
                jnc     nibble_loop                 /* repeat until the zeroth iteration is complete and the loop counter forced a carry */
                popw    %dx                         /* restore dx, ax is already restored */
                popw    %cx                         /* restore cx */
                ret
/******************************************************************************/


/*******************************************************************************
 * Function: nibble_ascii
 * Purpose: convert four bits to one of the characters 0-9,A-F; send it out */
nibble_ascii:   andb    $0x0F,              %al
                cmpb    $0x0A,              %al
                sbbb    $0x69,              %al
                das
/******************************************************************************/
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
 * Function: strout
 * Purpose: write a null-terminated string through altty
 * Parameters: ds:si the address of the first character
 * Outputs: None. */
strout:         lodsb                       /* copy the character to al, increment si */
                testb   %al,                %al /* test if it is the null terminator */
                jz      return
                call    altty
                jmp     strout
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
                prints  (crlf)
                popw    %ax
                ret
#endif
/******************************************************************************/