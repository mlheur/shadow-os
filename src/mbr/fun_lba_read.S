#ifndef __FUN_LBA_READ_S__
#define __FUN_LBA_READ_S__

#define LEN16_LBA_PACKET 0x10

/*******************************************************************************
 * eax: segment:offset to write to      => Packet+6, Packet+4
 * ecx: lower lba                       => Packet+8
 * (edx|0xFFFF0000)>>16: readlen        => Packet+2
 *  dl: drive to read from              => dl
 * ebx: higher lba                      => Packet+12
 ******************************************************************************/
    _lba_read = lbaread_set_pointer_to_packet
    lba_packet = LEN16_MBR - LEN16_LBA_PACKET /* we're done with the partition table, right? */

/******************************************************************************/
lbaread_set_pointer_to_packet:
    pushw   %cs
    popw    %ds
    movl    $(lba_packet),      %esi

lbaread_transfer_args_to_packet:
    movb    $LEN16_LBA_PACKET,  %ds:(%esi) /* save packet size */
    movb    $0,                 %ds:1(%esi) /* save magic */
    pushw   %dx                 /* guard */
    shrl    $16,                %edx /* get the readlen from the upper word */
    movw    %dx,                %ds:2(%esi) /* save readlen */
    popw    %dx                 /* restore */
    movw    %ax,                %ds:4(%esi) /* save offset */
    shrl    $16,                %eax /* get the semgent */
    movw    %ax,                %ds:6(%esi) /* save segment */
    movl    %ecx,               %ds:8(%esi)
    movl    %ebx,               %ds:12(%esi)

lbaread_set_function_id:
    movw    $0x4200,            %ax

lbaread_read:
    int     $0x13
    ret /* let the caller deal with carry flag checking, failure handling */
/******************************************************************************/

#endif /* __FUN_LBA_READ_S__ */