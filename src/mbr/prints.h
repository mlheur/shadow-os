/******************************************************************************/
#ifndef prints
#define prints(s)       movw $s, %si; call strout /* clobbers ax and si */
#endif

#ifndef printb
#define printb(b)       movw b, %ax; call print_byte /* clobbers ah */
#endif

#ifndef print2
#define printw(w)       movw w, %ax; call print_word /* clobbers ah */
#endif
/******************************************************************************/

#ifndef MBR_S
    .extern strout
    .extern print_byte
    .extern print_word
#endif