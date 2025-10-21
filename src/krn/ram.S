#ifndef __RAM_S__
#define __RAM_S__

msg_value:      .asciz " value:0x"
DumpRAM:        pushaw
                movw        $0xF000,        %bx
2:              movw        %bx,            %es /* segment 0xF000 */
                movw        $0xFFFC,        %bx /* offsets 0xFFFC-0xFFFF */
1:              prints      ($msg_vec_seg)
                printw      (%es)
                prints      ($msg_vec_off)
                printw      (%bx)
                prints      ($msg_value)
                printl      (%es:(%ebx))
                prints      ($_str_crlf)
                subw        $4, %bx
                jnc         1b /* loop until the carry flag gets set rolling below offset 0x0000 */
                movw        %es,            %bx
                subw        $0x1000,        %bx
                jnc         2b
                popaw
                ret

#endif /* __RAM_S__ */