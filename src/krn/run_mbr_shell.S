#ifndef __RUN_MBR_SHELL_S__
#define __RUN_MBR_SHELL_S__

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
                    jae     mbr_shell_fn_ENT        /* buffer is about to overflow, just boot the device the BIOS gave us */

check_for_enter:    inb     %dx,                    %al /* reread the byte from the uart after outb clobbered ax */
                    cmpb    $0x0d,                  %al
                    jne     wait_com1_input

accept_input:       movb    $0x0a,                  %al
                    call    outb_com1

lookup_user_cmd:    xorw    %cx,                    %cx /* Start at the first LUT entry */
                    movw    $mbr_shell_lut_start,   %bx /* Address the head of the LUT */
                    movw    %cx,                    %di /* reset the user input buffer pointer to the start. maybe I should be checking the last two, then I can avoid handling multiple backspace; single backspace would still need handling. */
                    movw    %es:(%di),              %dx /* load the user's first two bytes as one comparator */
1:                  movw    (%ebx,%ecx,4),          %ax /* retrieve the next LUT key as the other comparator */
                    cmpw    %ax,                    %dx /* compare them */
                    je      jmp_shell_lut           /* skips over the mbr_shell_data */
                    testw   %ax,                    %ax
invalid_user_cmd:   jz      _hlt                    /* invalid user input, halt the system */
                    addw    $1,                     %cx
                    jmp     1b
/* Pack data in the code, this is a good hiding spot */
mbr_shell_lut_start:
mbr_shell_lut_ENT:  .word   0x000d                  /* user hit enter and nothing else */
mbr_shell_ptr_ENT:  .word   mbr_shell_fn_ENT
mbr_shell_lut_02:   .word   0x0d32                  /* Menu Item 2: boot part 2 */
mbr_shell_ptr_02:   .word   mbr_shell_fn_BootPart2  /* Menu Item 2: boot part 2 */
mbr_shell_lut_03:   .word   0x0d33                  /* Menu Item 3: boot part 3 */
mbr_shell_ptr_03:   .word   mbr_shell_fn_BootPart3  /* Menu Item 3: boot part 3 */
mbr_shell_lut_end:  .word   0
end_shell_data:
/* end packing */
jmp_shell_lut:      jmp     *2(%ebx,%ecx,4)


mbr_shell_fn_BootPart3:
                    movl    $PARTITION3,    %esi
                    jmp     mbr_target_mbr
mbr_shell_fn_BootPart2:
                    movl    $PARTITION2,    %esi
                    /* see, thing is, we've pushed a bunch of stuff onto the stack.
                     * What we have to do is copy PBR of Part 2 to 0x7C00 and jump there,
                     * but doubly-clean up our stack before jumping there.
                     * Not only that, reading PBR of Part 2 means dissecting Part 2, pushing that for call _chs_read ...
                     */
mbr_target_mbr:     pushw   $MBR_SEGM
                    popw    %es
                    popw    %dx /* from the bootdev device */
                    movb    %es:1(%esi),    %dh
                    movb    %es:2(%esi),    %cl
                    movb    %es:3(%esi),    %ch
                    movb    $1,             %al
                    xorl    %ebx,           %ebx
                    movzbl  %al,            %edi
                    call    _chs_read
rejumping_mbr:      ljmp    $0,             $MBR_SEGM<<4

mbr_shell_fn_ENT:   popw    %dx /* get back the bootdevice the BIOS passed to MBR */
post_mbr_prompt:    /* ret not required, fall through to MBR since we're included inline there, not called */

#endif /* __MBR_SHELL_S__ */