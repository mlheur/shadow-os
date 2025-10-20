#ifndef __IVT_S__
#define __IVT_S__

msg_interrupt:  .asciz "int:0x"
msg_vec_seg:    .asciz " segment:0x"
msg_vec_off:    .asciz " offset:0x"
DumpIVT:        pushaw
                xorl        %ebx,           %ebx /* start at int 0x00 */
                movl        %ebx,           %ecx /* use cx as copy of ds register during IVT reads */
                movw        %ds,            %dx  /* use dx as copy of ds register during prints reads */

1:              prints      ($msg_interrupt)
                movw        %bx,            %ax
                call        print_byte

                prints      ($msg_vec_seg)
                movw        %cx,            %ds
                movw        2(,%ebx,4), %ax
                movw        %dx,            %ds
                call        print_word

                prints      ($msg_vec_off)
                movw        %cx,            %ds
                movw        (,%ebx,4),  %ax
                movw        %dx,            %ds
                call        print_word

                prints      ($_str_crlf)

                addb        $1,             %bl /* the last interrupt is 0xFF */
                jnc         1b                  /* loop until the carry flag gets set rolling past 0xFF */
                popaw
                ret

#endif /* __IVT_S__ */