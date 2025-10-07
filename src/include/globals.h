#ifndef __GLOBALS_H__
#define __GLOBALS_H__


.global _str_crlf
.global _ret
.global _halting


#define COM1_BASE   $0x3F8
#define OUTB(a,d)   movb a,%al; movw d,%dx; outb %al,%dx


#endif /* __GLOBALS_H__ */