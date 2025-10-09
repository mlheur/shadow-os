#ifndef __RAM_S__
#define __RAM_S__

msg_value:      .asciz " value:0x"
DumpRAM:        pusha
                xorl        %ebx,           %ebx /* start at offset 0x0000 */
                subw        $4,             %bx
                movl        $0xF000,        %ecx /* use cx as copy of ds register during IVT reads */
                movw        %ds,            %dx  /* use dx as copy of ds register during prints reads */

1:              prints      (msg_vec_seg)
                movw        %cx,            %ax
                call        print_word

                prints      (msg_vec_off)
                movw        %bx,            %ax
                call        print_word

                prints      (msg_value)
                movw        %cx,            %ds
                movl        (%ebx),         %eax
                movw        %dx,            %ds
                call        print_long

                prints      (_str_crlf)

                subw        $4,             %bx /* the last offset is 0xFFFF */
                jnc         1b                  /* loop until the carry flag gets set rolling past 0xFFFF */

                subw        $0x1000,        %cx /* same like above */
                jnc         1b

                popa
                ret

#endif /* __RAM_S__ */