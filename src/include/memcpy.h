#ifndef __MEMCPY_H__
#define __MEMCPY_H__

/*******************************************************************************
 * Caller must preset: ds, es
 * Unsafe versions destroy: ecx, esi, edi
 ******************************************************************************/

#ifdef __32BIT__
#define __memcpy_Scale      4
#define __memcpy_PSH        pushl
#define __memcpy_POP        popl
#define __memcpy_MOV        movl
#define __memcpy_REP_MOVS   rep movsl
#define __memcpy_CX         %ecx
#define __memcpy_SI         %esi
#define __memcpy_DI         %edi
#endif /* __32BIT__ */

#ifdef __16BIT__
#define __memcpy_Scale      2
#define __memcpy_PSH        pushw
#define __memcpy_POP        popw
#define __memcpy_MOV        movw
#define __memcpy_REP_MOVS   rep movsw
#define __memcpy_CX         %cx
#define __memcpy_SI         %si
#define __memcpy_DI         %di
#endif /* __16BIT__ */

#define _unsafe_memcpy_common_index(Index,Amt) \
    __memcpy_MOV   $((Index) + (Amt) - (__memcpy_Scale)), __memcpy_CX; \
    __memcpy_MOV   __memcpy_CX, __memcpy_SI; \
    __memcpy_MOV   __memcpy_CX, __memcpy_DI; \
    __memcpy_MOV   $((Amt) / (__memcpy_Scale)), __memcpy_CX; \
    std; \
    __memcpy_REP_MOVS (__memcpy_SI), (__memcpy_DI)

#define _unsafe_memcpy_unique_index(SrcIndex,DstIndex,Amt) \
    __memcpy_PSH    $((SrcIndex) + (Amt) - (__memcpy_Scale));\
    __memcpy_POP    __memcpy_SI ;\
    __memcpy_PSH    $((DstIndex) + (Amt) - (__memcpy_Scale));\
    __memcpy_POP    __memcpy_DI ; \
    __memcpy_MOV    $((Amt) / (__memcpy_Scale)), __memcpy_CX; \
    std; \
    __memcpy_REP_MOVS (__memcpy_SI), (__memcpy_DI)

#endif /* __MEMCPY_H__ */