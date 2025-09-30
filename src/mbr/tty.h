/******************************************************************************/
#define prints(s)       movw $s, %si; call strout /* clobbers ax and si */
#define printb(b)       movw b, %ax; call print_byte /* clobbers ah */
#define printw(w)       movw w, %ax; call print_word /* clobbers ah */
/******************************************************************************/