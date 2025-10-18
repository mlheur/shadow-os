#ifndef __MBR_S__
#define __MBR_S__

    .code16

/* #define DEBUG */
#include "globals.h"
#include "mbr.h"
#include "segments.h"
#include "prints.h"
#include "com1.h"

/* This is the benchmark for MBR size before turning chs_read into a proper
   System V ABI https://wiki.osdev.org/System_V_ABI

$ hexdump -C bin/objcopy-mbr                                                                                                        
00000000  60 ea 09 00 c0 07 c3 fb  f4 0e 1f 88 16 5e 00 b8  |`............^..|
00000010  03 00 31 d2 cd 14 68 00  10 07 e8 ba 00 ea 00 02  |..1...h.........|
00000020  00 10 0d 0a 00 ac 84 c0  74 dc e8 2a 00 eb f6 51  |........t..*...Q|
00000030  b9 0c 00 66 56 66 89 c6  66 d3 e8 e8 12 00 66 89  |...fVf..f.....f.|
00000040  f0 83 e9 04 73 f2 66 5e  59 c3 51 b9 04 00 eb e3  |....s.f^Y.Q.....|
00000050  24 0f 3c 0a 1c 69 2f 52  ba f8 03 ee 5a c3 00 01  |$.<..i/R....Z...|
00000060  00 00 80 00 10 00 00 00  80 fc 0c 0f 84 a0 00 61  |...............a|
00000070  c3 0f b6 1e 67 00 0f b6  06 61 00 29 c3 74 31 04  |....g....a.).t1.|
00000080  01 a2 61 00 a1 5f 00 83  e0 c0 f7 d9 00 c8 a2 5f  |..a.._........._|
00000090  00 eb 63 a1 5f 00 83 e0  3f 0f b6 1e 62 00 01 d8  |..c._...?...b...|
000000a0  8b 0e 65 00 83 e1 3f 29  c1 72 c6 a3 5f 00 eb 46  |..e...?).r.._..F|
000000b0  c6 06 61 00 00 a1 5f 00  83 e0 c0 8b 1e 65 00 83  |..a..._......e..|
000000c0  e3 c0 29 c3 f4 c0 c0 02  86 c4 83 c0 01 25 ff 03  |..)..........%..|
000000d0  86 e0 c0 c8 02 eb b3 60  8c c3 31 c0 8e c0 89 c7  |.......`..1.....|
000000e0  b4 08 8a 16 5e 00 cd 13  88 36 67 00 89 0e 65 00  |....^....6g...e.|
000000f0  8e c3 01 1e 63 00 8a 16  5e 00 8a 36 61 00 8b 0e  |....c...^..6a...|
00000100  5f 00 31 db a0 62 00 b4  02 cd 13 0f 82 59 ff 8c  |_.1..b.......Y..|
00000110  c3 b8 20 00 f6 26 62 00  01 c3 8e c3 84 06 62 00  |.. ..&b.......b.|
00000120  75 08 2b 1e 63 00 0f 82  69 ff 61 c3 00 00 00 00  |u.+.c...i.a.....|
00000130  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
*
000001b0  00 00 00 00 00 00 00 00  00 00 00 00 00 00 80 00  |................|
000001c0  02 00 da 02 01 00 01 00  00 00 7f 00 00 00 00 02  |................|
000001d0  02 00 01 22 22 00 80 00  00 00 00 08 00 00 00 00  |...""...........|
000001e0  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
000001f0  00 00 00 00 00 00 00 00  00 00 00 00 00 00 55 aa  |..............U.|
00000200

##### After using the stack instead of data-in-code, same size binary!

$ hexdump -C bin/objcopy-mbr
00000000  60 ea 09 00 c0 07 c3 fb  f4 0e 1f 52 b8 03 00 31  |`..........R...1|
00000010  d2 cd 14 5a 30 f6 68 00  10 07 bf 00 10 b9 01 00  |...Z0.h.........|
00000020  31 db b0 80 e8 b4 00 ea  00 02 00 10 0d 0a 00 ac  |1...............|
00000030  84 c0 74 d2 e8 2a 00 eb  f6 51 b9 0c 00 66 56 66  |..t..*...Q...fVf|
00000040  89 c6 66 d3 e8 e8 12 00  66 89 f0 83 e9 04 73 f2  |..f.....f.....s.|
00000050  66 5e 59 c3 51 b9 04 00  eb e3 24 0f 3c 0a 1c 69  |f^Y.Q.....$.<..i|
00000060  2f 52 ba f8 03 ee 5a c3  00 00 00 80 ec 0c 0f 84  |/R....Z.........|
00000070  9f 00 89 ec 5d 61 07 c3  0f b6 1e 6a 00 0f b6 46  |....]a.....j...F|
00000080  0d 29 c3 74 30 04 01 88  46 0d 8b 46 0e 83 e0 c0  |.).t0...F..F....|
00000090  f7 d9 00 c8 88 46 0e eb  64 8b 46 0e 83 e0 3f 0f  |.....F..d.F...?.|
000000a0  b6 5e 10 01 d8 8b 0e 68  00 83 e1 3f 29 c1 72 c8  |.^.....h...?).r.|
000000b0  89 46 0e eb 48 c6 46 0d  00 8b 46 0e 83 e0 c0 8b  |.F..H.F...F.....|
000000c0  1e 68 00 83 e3 c0 29 c3  f4 c0 c0 02 86 c4 83 c0  |.h....).........|
000000d0  01 25 ff 03 86 e0 c0 c8  02 eb b5 06 60 55 89 e5  |.%..........`U..|
000000e0  31 c0 8e c0 89 c7 b4 08  cd 13 88 36 6a 00 89 0e  |1..........6j...|
000000f0  68 00 8e 46 12 8c c3 01  5e 02 8a 56 0c 8a 76 0d  |h..F....^..V..v.|
00000100  8b 4e 0e 8b 5e 0a 8a 46  10 b4 02 cd 13 0f 82 5a  |.N..^..F.......Z|
00000110  ff c1 e0 05 8c c3 01 c3  8e c3 c1 e8 05 38 46 10  |.............8F.|
00000120  75 07 2b 5e 02 0f 82 70  ff e9 46 ff 00 00 00 00  |u.+^...p..F.....|
00000130  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
*
000001b0  00 00 00 00 00 00 00 00  00 00 00 00 00 00 80 00  |................|
000001c0  02 00 da 02 01 00 01 00  00 00 7f 00 00 00 00 02  |................|
000001d0  02 00 01 22 22 00 80 00  00 00 00 08 00 00 00 00  |...""...........|
000001e0  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
000001f0  00 00 00 00 00 00 00 00  00 00 00 00 00 00 55 aa  |..............U.|
00000200

######## Even smaller after using self-modifying code for drvdata entries

$ hexdump -C bin/objcopy-mbr 
00000000  60 ea 09 00 c0 07 c3 fb  f4 0e 1f 52 b8 03 00 31  |`..........R...1|
00000010  d2 cd 14 5a 30 f6 68 00  10 07 bf 00 10 b9 01 00  |...Z0.h.........|
00000020  31 db b0 80 e8 fe ff ea  00 02 00 10 0d 0a 00 ac  |1...............|
00000030  84 c0 74 d2 e8 2a 00 eb  f6 51 b9 0c 00 66 56 66  |..t..*...Q...fVf|
00000040  89 c6 66 d3 e8 e8 12 00  66 89 f0 83 e9 04 73 f2  |..f.....f.....s.|
00000050  66 5e 59 c3 51 b9 04 00  eb e3 24 0f 3c 0a 1c 69  |f^Y.Q.....$.<..i|
00000060  2f 52 ba f8 03 ee 5a c3  80 ec 0c 0f 84 9e 00 89  |/R....Z.........|
00000070  ec 5d 61 07 c3 0f b6 1e  ff 00 0f b6 46 0d 29 c3  |.]a.........F.).|
00000080  74 2f 04 01 88 46 0d 8b  46 0e 83 e0 c0 f7 d9 00  |t/...F..F.......|
00000090  c8 88 46 0e eb 63 8b 46  0e 83 e0 3f 0f b6 5e 10  |..F..c.F...?..^.|
000000a0  01 d8 b9 ff 00 83 e1 3f  29 c1 72 c9 89 46 0e eb  |.......?).r..F..|
000000b0  48 c6 46 0d 00 8b 46 0e  83 e0 c0 8b 1e 00 00 83  |H.F...F.........|
000000c0  e3 c0 29 c3 f4 c0 c0 02  86 c4 83 c0 01 25 ff 03  |..)..........%..|
000000d0  86 e0 c0 c8 02 eb b6 06  60 55 89 e5 31 c0 8e c0  |........`U..1...|
000000e0  89 c7 b4 08 cd 13 88 36  00 00 89 0e 00 00 8e 46  |.......6.......F|
000000f0  12 8c c3 01 5e 02 8a 56  0c 8a 76 0d 8b 4e 0e 8b  |....^..V..v..N..|
00000100  5e 0a 8a 46 10 b4 02 cd  13 0f 82 5b ff c1 e0 05  |^..F.......[....|
00000110  8c c3 01 c3 8e c3 c1 e8  05 38 46 10 75 07 2b 5e  |.........8F.u.+^|
00000120  02 0f 82 71 ff e9 47 ff  00 00 00 00 00 00 00 00  |...q..G.........|
00000130  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
*
000001b0  00 00 00 00 00 00 00 00  00 00 00 00 00 00 80 00  |................|
000001c0  02 00 da 02 01 00 01 00  00 00 7f 00 00 00 00 02  |................|
000001d0  02 00 01 22 22 00 80 00  00 00 00 08 00 00 00 00  |...""...........|
000001e0  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
000001f0  00 00 00 00 00 00 00 00  00 00 00 00 00 00 55 aa  |..............U.|
00000200

*/

/*******************************************************************************
 * BIOS hands over to MBR:
 * The only things that are (nearly) certain are that
 *  - the bootsector code is loaded and running at physical address 0x7c00,
 *  - the CPU is in 16-bit Real Mode,
 *  - the CPU register called dl contains the "drive number",
 *  - and that only 512 bytes of the bootsector have been loaded.
 * -- https://wiki.osdev.org/System_Initialization_(x86)
 ******************************************************************************/

/*******************************************************************************
 * BIOS Entry Point into MBR, testing in qemu shows we get here via lcall.
 ******************************************************************************/
    .text
_start:
#include "run_relocate_mbr.S"
longjump_mbr:       ljmp    $RELOC_SEGM,$MBR
MBR:                pushw   %dx         /* preserve this for chs_read */
#include "run_init_com1.S"              /* enable output to the serial console */
prep_segments_rd:   pushw   %cs         /* copy cs to ds via stack, it's slower than ... */
prep_segments_wr:   popw    %ds         /* ... using a register, but makes for smaller assembly. */
preread_segm1:      pushw   $MBR_SEGM   /* pass the MBR_SEGM ... */
preread_segm2:      popw    %es         /* ... to chs_read via es */
check_first_part:   movl    $PARTITION1,%ebx
check_active_part:  cmpb    $0x80,      (%ebx)
rotate_partition:   jne     next_partition
assign_device:      popw    %dx         /* saved at MBR symbol */
assign_head:        movb    1(%ebx),    %dh /* head of start of selected parition */
assign_cylsec_lo:   movb    2(%ebx),    %cl /* cylsec lo of start of selected partition */
assign_cylsec_hi:   movb    3(%ebx),    %ch /* cylsec hi of start of selected partition */
preread_readlen:    movb    $0x01,      %al /* ah=XX unused, al=0x80 read 128 sectors at a time */
preread_readamt:    movw    $0x0020,    %di /* Stop reading when es is advanced this much */
preread_offset:     xorw    %bx,        %bx /* write starting at offset 0 */
preared_read:       call    _chs_read   /* copy the bootdev to RAM */
run_PBR:            ljmp    $MBR_SEGM,  $0 /* Run partition boot record */
/******************************************************************************/


/******************************************************************************/
_ret:               ret /* dereference indirect "Jcc _ret" */
_lret:              lret /* dereference Jcc _lret */
_hlt:               sti
                    hlt
                    jmp _hlt
/******************************************************************************/

next_partition:     addw    $0x10,          %bx
                    cmpw    $mbr_signature, %bx
                    je      _lret
                    jmp     check_active_part




/*******************************************************************************
 * Import functions for console output and disk input.
 * These will stay resident under KRN_SEGM:offset
 ******************************************************************************/
#include "fun_prints.S"
#include "fun_chs_read.S"


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
    . = _start + 0x1BE /* Part 1 */
PARTITION1:
P1.flag:    .byte   0x00 /* active */
P1.head:    .byte   0x00 /* starts on head 0 */
P1.cysleclo:.byte   0x02 /* starts on sector 2, mbr is on 1 */
P1.cylsechi:.byte   0x00 /* cylinder zero */
P1.fsid:    .byte   0xda /* shadow-os.img format, I agree with John Hardin https://aeb.win.tue.nl/partitions/partition_types-1.html */
P1.endhead: .byte   0x02 /* up to head 2 (0x80 - 0x3f - 0x3f - 0x02 == 0) */
P1.endcslo: .byte   0x02 /* just the first two sectors on head 2 */
P1.endcshi: .byte   0x00 /* all within cylinder zero */
P1.lba_off: .long   0x00000001
P1.lba_len: .long   0x0000007F
    . = _start + 0x1CE
PARTITION2:
P2.flag:    .byte   0x80 /* active */
P2.head:    .byte   0x02 /* starts on head 2 */
P2.cysleclo:.byte   0x03 /* starts on sector 3 */
P2.cylsechi:.byte   0x00 /* cylinder zero */
P2.fsid:    .byte   0x01 /* mkfs.fat */
P2.endhead: .byte   0x22
P2.endcslo: .byte   0x22
P2.endcshi: .byte   0x00
P2.lba_off: .long   0x00000080
P2.lba_len: .long   0x00000800
    . = _start + 0x1DE
PARTITION3:
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
    . = _start + 0x1EE
PARTITION4:
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
/******************************************************************************/

/*******************************************************************************
 * the last 2 bytes in the sector 0 must contain the signature */
    . = _start + 0x1fe
mbr_signature:  .short MBR_MAGIC
    . = _start + 0x200
KRN:
/******************************************************************************/


#endif /* __MBR_S__ */