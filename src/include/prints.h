#ifndef __PRINTS_H__
#define __PRINTS_H__

.global print_string
.global _str_crlf
.global print_word
.global print_byte
.global print_long

#ifndef prints
#define prints(s) \
    movl    s, %esi; \
    call    print_string
#endif /* prints */

#ifndef printl
#define printl(l) \
    movl    l, %eax; \
    call    print_long
#endif /* printl */

#ifndef printw
#define printw(w) \
    movzwl  w, %eax; \
    call    print_word
#endif /* printw */

#ifndef printb
#define printb(b) \
    movzbl  b, %eax; \
    call    print_byte
#endif /* printb */

#endif /* __PRINTS_H__ */