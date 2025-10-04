#ifndef __PRINTS_H__
#define __PRINTS_H__


#ifdef __MBR_S__

    .global strout
    .global print_byte
    .global print_word

#ifndef prints
#define prints(s)       movw $s, %si; call strout
#endif

#ifndef printb
#define printb(b)       movw b, %ax; call print_byte
#endif

#ifndef printw
#define printw(w)       movw w, %ax; call print_word
#endif

#else /* __MBR_S__ */

    .extern strout
    .extern print_byte
    .extern print_word

#ifndef prints
#define prints(s)       movl $s, %esi; call strout
#endif

#ifndef printb
#define printb(b)       movl b, %eax; call print_byte
#endif

#ifndef printw
#define printw(w)       movl w, %eax; call print_word
#endif

#endif /* __MBR_S__ */


#endif /* __PRINTS_H__ */