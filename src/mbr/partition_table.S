#ifndef __PARTITION_TABLE_S__
#define __PARTITION_TABLE_S__

/*******************************************************************************
 * https://wiki.osdev.org/Partition_Table
 * .byte: bootable flag on bit 0x80
 * .byte: starting head
 * .byte: starting cylsec, sector portion
 * .byte: starting cylsec, cylinder portion
 * .byte: filesys ID
 * .byte: ending head
 * .byte: ending cylsec, sector part
 * .byte: ending cylsec, cyl part
 * .long: starting LBA
 * .long: quantity LBA
 ******************************************************************************/
P1.flag:    .byte   0x80 /* active */
P1.head:    .byte   0x00 /* starts on head 0 */
P1.cysleclo:.byte   0x02 /* starts on sector 2, mbr is on 1 */
P1.cylsechi:.byte   0x00 /* cylinder zero */
P1.fsid:    .byte   0xda /* shadow-os.img format, I agree with John Hardin https://aeb.win.tue.nl/partitions/partition_types-1.html */
P1.endhead: .byte   0x02 /* up to head 2 (0x80 - 0x3f - 0x3f - 0x02 == 0) */
P1.endcslo: .byte   0x02 /* just the first two sectors on head 2 */
P1.endcshi: .byte   0x00 /* all within cylinder zero */
P1.lba_off: .long   0x00000001
P1.lba_len: .long   0x0000007F

P2.flag:    .byte   0x00 /* active */
P2.head:    .byte   0x02 /* starts on head 2 */
P2.cysleclo:.byte   0x03 /* starts on sector 3 */
P2.cylsechi:.byte   0x00 /* cylinder zero */
P2.fsid:    .byte   0x01 /* mkfs.fat */
P2.endhead: .byte   0x22
P2.endcslo: .byte   0x22
P2.endcshi: .byte   0x00
P2.lba_off: .long   0x00000080
P2.lba_len: .long   0x00000800

P3.flag:    .byte   0x00 /* inactive */
P3.head:    .byte   0x22
P3.cysleclo:.byte   0x23
P3.cylsechi:.byte   0x00
P3.fsid:    .byte   0x83 /* mkfs.ext2 */
P3.endhead: .byte   0x43
P3.endcslo: .byte   0x03
P3.endcshi: .byte   0x00
P3.lba_off: .long   0x00000880
P3.lba_len: .long   0x00000800

P4.flag:    .byte   0x00 /* inactive */
P4.head:    .byte   0x43
P4.cysleclo:.byte   0x04
P4.cylsechi:.byte   0x00
P4.fsid:    .byte   0x81 /* mkfs.minix */
P4.endhead: .byte   0x63
P4.endcslo: .byte   0x23
P4.endcshi: .byte   0x00
P4.lba_off: .long   0x00001080
P4.lba_len: .long   0x00000800

#endif /* __PARTITION_TABLE_S__ */