#ifndef __PRINTS_H__
#define __PRINTS_H__


    .global _prints
    .global print_byte
    .global print_word
    .global print_long
    .global _print_nibbles
    .global _str_crlf


#ifdef __MBR_S__

#ifndef prints
#define prints(s)       movw $s, %si; call _prints
#endif

#else /* __MBR_S__ */

#ifndef prints
#define prints(s)       movl $s, %esi; call _prints
#endif

#ifndef printl
#define printl(l)       movl l, %eax; call print_long
#endif

#endif /* __MBR_S__ */

#ifndef printw
#define printw(w)       movw w, %ax; call print_word
#endif

#ifndef printb
#define printb(b)       movb b, %al; call print_byte
#endif


#endif /* __PRINTS_H__ */