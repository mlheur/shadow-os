#ifndef __FUN_LBA_READ_S__
#define __FUN_LBA_READ_S__

#define sizeof_LBA_CMD 0x10

/* we're done with the partition table, right? */
    LBA_CMD = _start + sizeof_MBR - sizeof_LBA_CMD

/*******************************************************************************
 * eax: segment:offset to write to      => Packet+6, Packet+4
 * ecx: lower lba                       => Packet+8
 * (edx|0xFFFF0000)>>16: readlen        => Packet+2
 *  dl: drive to read from              => dl
 * ebx: higher lba                      => Packet+12
 ******************************************************************************/
    _lba_read = lbaread_set_pointer_to_packet

/******************************************************************************/
lbaread_set_pointer_to_packet:
    pushw   %cs
    popw    %ds
    movl    $(LBA_CMD),         %esi

lbaread_transfer_args_to_packet:
    movb    $sizeof_LBA_CMD,    %ds:(%esi)  /* save packet size */
    movb    $0,                 %ds:1(%esi) /* save magic */
    pushw   %dx                             /* guard */
    shrl    $16,                %edx        /* get the readlen from the upper word */
    movw    %dx,                %ds:2(%esi) /* save readlen */
    popw    %dx                             /* restore */
    movw    %ax,                %ds:4(%esi) /* save offset */
    shrl    $16,                %eax        /* get the semgent */
    movw    %ax,                %ds:6(%esi) /* save segment */
    movl    %ecx,               %ds:8(%esi) /* lba low */
    movl    %ebx,               %ds:12(%esi)/* lba high */

lbaread_set_function_id:
    movw    $0x4200,            %ax         /* lba "read" */

lbaread_read:
    int     $0x13
    ret /* let the caller deal with carry flag checking, failure handling */
/******************************************************************************/

#endif /* __FUN_LBA_READ_S__ */