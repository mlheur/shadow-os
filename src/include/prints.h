#ifndef __PRINTS_H__
#define __PRINTS_H__

.global print_string
.global _str_crlf
.global print_word
.global print_byte
.global print_long

#ifndef prints
#define prints(s) \
    pushl   %esi; \
    movl    s, %esi; \
    call    print_string; \
    popl    %esi;
#endif /* prints */

#ifndef printl
#define printl(l) \
    pushl   %eax; \
    movl    l, %eax; \
    call    print_long; \
    popl    %eax
#endif /* printl */

#ifndef printw
#define printw(w) \
    pushl   %eax; \
    movzwl  w, %eax; \
    call    print_word; \
    popl    %eax
#endif /* printw */

#ifndef printb
#define printb(b) \
    pushl   %eax; \
    movzbl  b, %eax; \
    call    print_byte; \
    popl    %eax
#endif /* printb */

#endif /* __PRINTS_H__ */