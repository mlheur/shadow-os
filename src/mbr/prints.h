#ifndef __PRINTS_H__
#define __PRINTS_H__

#ifndef prints
#define prints(s)       movw $s, %si; call strout
#endif

#ifndef printb
#define printb(b)       movw b, %ax; call print_byte
#endif

#ifndef printw
#define printw(w)       movw w, %ax; call print_word
#endif

#endif /* __PRINTS_H__ */