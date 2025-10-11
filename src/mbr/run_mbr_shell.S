#ifndef __MBR_SHELL_S__
#define __MBR_SHELL_S__

pre_mbr_prompt:     pushw   $MBR_SHELL_SEGM         /* es:di will be used by stosb ... */
                    popw    %es                     /* ... when the user input buffer ... */
reset_input_ptr:    xorw    %di,                    %di /* ... is read from com1 */

.equ _prompt_string, 2+.
mbr_prompt:         movb    $'>', %al
                    call    outb_com1

wait_com1_input:    movw    COM1_LINE_STAT,         %dx
1:                  inb     %dx,                    %al
                    testb   $1,                     %al
                    jz      1b

retr_com1_input:    movw    COM1_BUFFER,            %dx
                    inb     %dx,                    %al

save_com1_input:    stosb

echo_com1_input:    call    outb_com1

check_buffer_limit: cmpw    $MBR_SHELL_LIMIT,       %si
                    jae     buffer_exceeded

check_for_enter:    inb     %dx,                    %al /* reread the byte from the uart after outb clobbered ax */
                    cmpb    $0x0d,                  %al
                    jne     wait_com1_input

accept_input:       movb    $0x0a,                  %al
                    call    outb_com1

lookup_user_cmd:    movw    $mbr_shell_lut_start,   %bx /* Address the head of the LUT */
                    xorw    %cx,                    %cx /* Start at the first LUT entry */
                    movw    %cx,                    %di /* reset the user input buffer pointer to the start */
1:                  movw    %es:(%di),              %dx
                    movw    (%ebx,%ecx,4),          %ax /* retrieve the LUT key */
                    cmpw    %ax,                    %dx /* compare with the value in the user input buffer */
                    je      1f
                    testw   %ax,                    %ax
                    jz      buffer_exceeded
                    addw    $1,                     %cx
                    jmp     1b
1:                  jmp     2(%ebx,%ecx,4)

buffer_exceeded:    popw    %dx

mbr_shell_data:     jmp     post_mbr_prompt
.equ mbr_shell_lut_start, .
mbr_shell_lut_LS:   .word   0x736C                  /* ls: list all partitions on all disks */
mbr_shell_ptr_LS:   .word   mbr_shell_fn_LS
mbr_shell_lut_GO:   .word   0x6f67                  /* go: boot the selected partition */
mbr_shell_ptr_GO:   .word   mbr_shell_fn_GO
mbr_shell_lut_end:  .word   0
mbr_shell_fn_LS:    movw    $'L',%ax
                    call    outb_com1
                    jmp     buffer_exceeded         /* todo: implement ls */
mbr_shell_fn_GO:    movw    $'G',%ax
                    call    outb_com1
                    jmp     buffer_exceeded         /* todo: implement go */

post_mbr_prompt:    /* ret not required, fall through to MBR since we're included inline there, not called */

#endif /* __MBR_SHELL_S__ */