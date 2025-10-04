#ifndef __GLOBALS_H__
#define __GLOBALS_H__


#ifdef __MBR_S__
    .global _start
    .global osname
    .global crlf
    .global return
    .global savedx
#else /* __MBR_S__ */
    .extern osname
    .extern crlf
    .extern return
    .extern savedx
#endif /* __MBR_S__ */


#endif /* __GLOBALS_H__ */