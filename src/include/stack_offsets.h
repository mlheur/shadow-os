#ifndef __STACK_OFFSET_H__
#define __STACK_OFFSET_H__


/* https://www.felixcloutier.com/x86/pusha:pushad */
/* ax(16), cx(14), dx(12), bx(10), sp(8), bp(6), si(4), di(2) */
#define new_stack_frame pusha; pushw %bp; movw %sp, %bp
#define del_stack_frame movw %bp, %sp; popw %bp; popa


#define PUSHED_DI   2(%bp)
#define PUSHED_SI   2+PUSHED_DI
#define PUSHED_BP   2+PUSHED_SI
#define PUSHED_SP   2+PUSHED_BP
#define PUSHED_BX   2+PUSHED_SP
#define PUSHED_DX   2+PUSHED_BX
#define PUSHED_CX   2+PUSHED_DX
#define PUSHED_AX   2+PUSHED_CX


#define PUSHED_AH   1+PUSHED_AX
#define PUSHED_AL     PUSHED_AX
#define PUSHED_CH   1+PUSHED_CX
#define PUSHED_CL     PUSHED_CX
#define PUSHED_DH   1+PUSHED_DX
#define PUSHED_DL     PUSHED_DX
#define PUSHED_BH   1+PUSHED_BX
#define PUSHED_BL     PUSHED_BX


#endif /* __STACK_OFFSET_H__ */