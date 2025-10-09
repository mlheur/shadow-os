#ifndef __MBR_SHELL_S__
#define __MBR_SHELL_S__

pre_mbr_prompt:     pushw   $MBR_SHELL_SEGM
                    popw    %es
reset_input_ptr:    xorw    %ax,                %ax
                    movw    %ax,                %di

mbr_prompt:         movb    $'>', %al
                    call    outb_com1

wait_com1_input:    movw    COM1_LINE_STAT,     %dx
1:                  inb     %dx,                %al
                    testb   $1,                 %al
                    jz      1b

retr_com1_input:    movw    COM1_BUFFER,        %dx
                    inb     %dx,                %al

save_com1_input:    stosb

echo_com1_input:    call    outb_com1

check_buffer_limit: cmpw    $MBR_SHELL_LIMIT,   %si
                    jae     buffer_exceeded

check_for_enter:    inb     %dx,                %al /* reread the byte from the uart after outb clobberd ax */
                    cmpb    $0x0d,              %al
                    jne     wait_com1_input
                    movb    $0x0a,              %al
                    call    outb_com1

buffer_exceeded:    popw    %dx

post_mbr_prompt:    /* ret not required, fall through to MBR since we're included inline there, not called */

#endif /* __MBR_SHELL_S__ */