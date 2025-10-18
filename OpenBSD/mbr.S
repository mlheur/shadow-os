/*	$OpenBSD: mbr.S,v 1.28 2024/11/18 02:32:22 mlarkin Exp $	*/

/*
 * Copyright (c) 1997 Michael Shalayeff and Tobias Weingartner
 * Copyright (c) 2003 Tom Cosgrove <tom.cosgrove@arches-consulting.com>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 */
/* Copyright (c) 1996 VaX#n8 (vax@linkdead.paranoia.com)
 * last edited 9 July 1996
 * many thanks to Erich Boleyn (erich@uruk.org) for putting up with
 * all my questions, and for his work on GRUB
 * You may use this code or fragments thereof in a manner consistent
 * with the other copyrights as long as you retain my pseudonym and
 * this copyright notice in the file.
 */

#define SERIAL 0
#define COM1    0x3F8

/*
 * Memory layout:
 *
 * 0x07C00 -> 0x07DFF	BIOS loads us here	(at  31k)
 * 0x07E00 -> 0x17BFC	our stack		(to  95k)
 *
 * 0x07A00 -> 0x07BFF	we relocate to here	(at  30k5)
 *
 * 0x07C00 -> 0x07DFF	we load PBR here	(at  31k)
 *
 * The BIOS loads us at physical address 0x07C00.  We use a long jmp to
 * normalise our address to seg:offset 07C0:0000.  We then relocate to
 * 0x07A00, seg:offset 07A0:0000.
 *
 * We use a long jmp to normalise our address to seg:offset 07A0:0000
 * We set the stack to start at 07C0:FFFC (grows down on i386)
 * The partition boot record (PBR) loads /boot at seg:offset 4000:0000
 */

/* DOS partition table -- located at start of some disks. */
#define	DOS_LABELSECTOR 1
#define	DOSBBSECTOR	0		/* DOS boot block relative sector # */
#define	DOSPARTOFF	446
#define	DOSDISKOFF	444
#define	NDOSPART	4
#define	DOSACTIVE	0x80		/* active partition */

#define	DOSMBR_SIGNATURE	(0xaa55)
#define	DOSMBR_SIGNATURE_OFF	(0x1fe)

#define BOOTSEG         0x7c0	/* segment where we are loaded */
#define BOOTRELOCSEG	0x7a0	/* segment where we relocate to */
#define BOOTSTACKOFF	0xfffc	/* stack starts here, grows down */
#define PARTSZ		    16	/* each partition table entry is 16 bytes */

#define CHAR_LBA_READ	'.'
#define CHAR_CHS_READ	';'

#ifdef DEBUG
#define CHAR_S		'S'	/* started */
#define CHAR_R		'R'	/* relocated */
#define CHAR_L		'L'	/* looking for bootable partition */
#define CHAR_B		'B'	/* loading boot */
#define CHAR_G		'G'	/* jumping to boot */

#define DBGMSG(c)	movb	$c, %al;	call	Lchr
#else /* !DEBUG */
#define DBGMSG(c)
#endif /* !DEBUG */

/* Clobbers %al - maybe more */
#define	putc(c)		movb	$c, %al;	call	Lchr

/* Clobbers %esi - maybe more */
#define	puts(s)		movw	$s, %si;	call	Lmessage


	.text
	.code16

	.globl	_start
_start:
	/* Adjust %cs to be right */
	ljmp 	$BOOTSEG, $1f
1:
	/* Set up stack */
	movw	%cs, %ax

	/*
	 * We don't need to disable and re-enable interrupts around the
	 * load of ss and sp.
	 *
	 * From 80386 Programmer's Reference Manual:
	 * "A MOV into SS inhibits all interrupts until after the execution
	 * of the next instruction (which is presumably a MOV into eSP)"
	 *
	 * According to Hamarsoft's 86BUGS list (which is distributed with
	 * Ralph Brown's Interrupt List), some early 8086/88 processors
	 * failed to disable interrupts following a load into a segment
	 * register, but this was fixed with later steppings.
	 *
	 * Accordingly, this code will fail on very early 8086/88s, but
	 * nick@ will just have to live with it.  Others will note that
	 * we require at least a Pentium compatible processor anyway.
	 */
	/* cli */
	movw	%ax, %ss
	movw	$BOOTSTACKOFF, %sp
	/* sti */			/* XXX not necessary; see above */

	/* Set up data segment */
	movw	%ax, %ds
	DBGMSG(CHAR_S)

	/*
	 * On the PC architecture, the boot record (originally on a floppy
	 * disk) is loaded at 0000:7C00 (hex) and execution starts at the
	 * beginning.
	 *
	 * When hard disk support was added, a scheme to partition disks into
	 * four separate partitions was used, to allow multiple operating
	 * systems to be installed on the one disk.  The boot sectors of the
	 * operating systems on each partition would of course expect to be
	 * loaded at 0000:7C00.
	 *
	 * The first sector of the hard disk is the master boot record (MBR).
	 * It is this which defines the partitions and says which one is
	 * bootable.  Of course, the BIOS loads the MBR at 0000:7C00, the
	 * same location where the MBR needs to load the partition boot
	 * record (PBR, called biosboot in OpenBSD).
	 *
	 * Therefore, the MBR needs to relocate itself before loading the PBR.
	 *
	 * Make it so.
	 */
	movw	$BOOTRELOCSEG, %ax
	movw	%ax, %es
	xorw	%si, %si
	xorw	%di, %di
	movw	$0x200, %cx		/* Bytes in MBR, relocate it all */
	cld
	rep
	movsb

	/* Jump to relocated self */
	ljmp $BOOTRELOCSEG, $reloc
reloc:
	DBGMSG(CHAR_R)

	/* Set up %es and %ds */
	pushw	%ds
	popw	%es	/* next boot is at the same place as we were loaded */
	pushw	%cs
	popw	%ds	/* and %ds is at the %cs */

#ifdef SERIAL
	/* Initialize the serial port to 9600 baud, 8N1.
	 */
	pushw	%dx
	movw	$0xe3, %ax
	movw	$SERIAL, %dx
	int	$0x14
	popw	%dx
#endif
coler:

	/* BIOS passes us drive number in %dl
	 *
	 * XXX - This is not always true.  We currently check if %dl
	 * points to a HD, and if not we complain, and set it to point
	 * to the first HDD.  Note, this is not 100% correct, since
	 * there is a possibility that you boot from HD #2, and still
	 * get (%dl & 0x80) == 0x00, these type of systems will lose.
	 */
	testb	$0x80, %dl
	jnz	drive_ok

	/* MBR on floppy or old BIOS
	 * Note: MBR (this code) should never be on a floppy.  It does
	 * not belong there, so %dl should never be 0x00.
	 *
	 * Here we simply complain (should we?), and then hardcode the
	 * boot drive to 0x80.
	 */
	puts(efdmbr)

	/* If we are passed bogus data, set it to HD #1
	 */
	movb	$0x80, %dl

drive_ok:
	/* Find the first active partition.
	 * Note: this should be the only active partition.  We currently
	 * don't check for that.
	 */
	movw	$pt, %si

	movw	$NDOSPART, %cx
find_active:
	DBGMSG(CHAR_L)
	movb	(%si), %al

	cmpb	$DOSACTIVE, %al
	je	found

	addw	$PARTSZ, %si
	loop	find_active

	/* No bootable partition */
no_part:
	movw	$enoboot, %si

err_stop:
	call	Lmessage

stay_stopped:
	sti				/* Ensure Ctl-Alt-Del will work */
	hlt				/* (don't require power cycle) */
	/* Just to make sure */
	jmp	stay_stopped

found:
	/*
	 * Found bootable partition
	 */

	DBGMSG(CHAR_B)

	/* Store the drive number (from %dl) in decimal */
	movb	%dl, %al
	andb	$0x0F, %al
	addb	$'0', %al
	movb	%al, drive_num

	/*
	 * Store the partition number, in decimal.
	 *
	 * We started with cx = 4; if found we want part '0'
	 *                 cx = 3;                  part '1'
	 *                 cx = 2;                  part '2'
	 *                 cx = 1;                  part '3'
	 *
	 * We'll come into this with no other values for cl.
	 */
	movb	$'0'+4, %al
	subb	%cl, %al
	movb	%al, part_num

	/*
	 * Tell operator what partition we're trying to boot.
	 *
	 * Using drive X, partition Y
	 * - this used to be printed out after successfully loading the
	 *   partition boot record; we now print it out before
	 */
	pushw	%si
	movw	$info, %si
	call	Lmessage
	popw	%si

	/*
	 * Partition table entry format:
	 *
	 * 0x00	BYTE boot indicator (0x80 = active, 0x00 = inactive)
	 * 0x01	BYTE start head
	 * 0x02	WORD start cylinder, sector
	 * 0x04	BYTE system type (0xA6 = OpenBSD)
	 * 0x05 BYTE end head
	 * 0x06	WORD end cylinder, sector
	 * 0x08	LONG start LBA sector
	 * 0x0C	LONG number of sectors in partition
	 *
	 * In the case of a partition that extends beyond the 8GB boundary,
	 * the LBA values will be correct, the CHS values will have their
	 * maximums (typically (C,H,S) = (1023,255,63)).
	 *
	 * %ds:%si points to the active partition table entry.
	 */

	/* We will load the partition boot sector (biosboot) where we
	 * were originally loaded.  We'll check to make sure something
	 * valid comes in.  So that we don't find ourselves, zero out
	 * the signature at the end.
	 */
	movw	$0, %es:signature(,1)

	/*
	 * We will use the LBA sector number if we have LBA support,
	 * so find out.
	 */

	/*
	 * BIOS call "INT 0x13 Extensions Installation Check"
	 *	Call with	%ah = 0x41
	 *			%bx = 0x55AA
	 *			%dl = drive (0x80 for 1st hd, 0x81 for 2nd, etc)
	 *	Return:
	 *			carry set: failure
	 *				%ah = error code (0x01, invalid func)
	 *			carry clear: success
	 *				%bx = 0xAA55 (must verify)
	 *				%ah = major version of extensions
	 *				%al   (internal use)
	 *				%cx = capabilities bitmap
	 *					0x0001 - extnd disk access funcs
	 *					0x0002 - rem. drive ctrl funcs
	 *					0x0004 - EDD functions with EBP
	 *				%dx   (extension version?)
	 */

	movb	%dl, (%si)		/* Store drive here temporarily */
					/* (This call trashes %dl) */
					/*
					 * XXX This is actually the correct
					 *     place to store this.  The 0x80
					 *     value used to indicate the
					 *     active partition is by intention
					 *     the same as the BIOS drive value
					 *     for the first hard disk (0x80).
					 *     At one point, 0x81 would go here
					 *     for the second hard disk; the
					 *     0x80 value is often used as a
					 *     bit flag for testing, rather
					 *     than an exact byte value.
					 */
	movw	$0x55AA, %bx
	movb	$0x41, %ah
	int	$0x13

	movb	(%si), %dl		/* Get back drive number */


	/*
	 * BIOS call "INT 0x13 Function 0x2" to read sectors from disk into
	 * memory
	 *       Call with       %ah = 0x2
	 *                       %al = number of sectors
	 *                       %ch = cylinder & 0xFF
	 *                       %cl = sector (0-63) | rest of cylinder bits
	 *                       %dh = head
	 *                       %dl = drive (0x80 for hard disk)
	 *                       %es:%bx = segment:offset of buffer
	 *       Return:
	 *                       carry set: failure
	 *                           %ah = err code
	 *                           %al = number of sectors transferred
	 *                       carry clear: success
	 *                           %al = 0x0 OR number of sectors transferred
	 *                                 (depends on BIOS!)
	 *                                 (according to Ralph Brown Int List)
	 */
do_chs:
    movb	$CHAR_CHS_READ, %al
	call	Lchr

	/* Load values from active partition table entry */
	movb	1(%si), %dh		/* head */
	movw	2(%si), %cx		/* sect, cyl */
	movw	$0x201, %ax		/* function and number of blocks */
	xorw	%bx, %bx		/* put it at %es:0 */
	int	$0x13
done_chs:
    jnc	booting_os

read_error:
	movw	$eread, %si
	jmp	err_stop

booting_os:
	puts(crlf)
	DBGMSG(CHAR_G)

	/*
	 * Make sure the pbr we loaded has a valid signature at the end.
	 * This also ensures that something did load where we were expecting
	 * it, as there's still a copy of our code there...
	 */
	cmpw	$DOSMBR_SIGNATURE, %es:signature(,1)
	jne	missing_os

	/* jump to the new code (%ds:%si is at the right point) */
	ljmp	$0, $BOOTSEG << 4
	/* not reached */

missing_os:
	movw	$enoos, %si
	jmp	err_stop

/*
 * Display string
 */
Lmessage:
	pushw	%ax
	cld
1:
	lodsb			/* %al = *%si++ */
	testb	%al, %al
	jz	1f
	call    Lchr
	jmp	1b

/*
 *	Lchr: write the error message in %ds:%si to console
 */
Lchr:
	pushw	%ax

#ifdef SERIAL
	pushw	%dx
	movb	$0x01, %ah
	movw	$COM1, %dx
	outb    %al,   %dx
	popw	%dx
#else
	pushw	%bx
	movb	$0x0e, %ah
	movw	$1, %bx
	int	$0x10
	popw	%bx
#endif
1:	popw	%ax
	ret

/* command packet for LBA read of boot sector */
lba_command:
	.byte	0x10			/* size of command packet */
	.byte	0x00			/* reserved */
	.word	0x0001			/* sectors to transfer, just 1 */
	.word	0			/* target buffer, offset */
	.word	BOOTSEG			/* target buffer, segment */
lba_sector:
	.long	0, 0			/* sector number */

/* Info messages */
info:	.ascii		"Using drive "
drive_num:
	.byte		'X'
	.ascii		", partition "
part_num:
	.asciz		"Y"

/* Error messages */
efdmbr:	.asciz		"MBR on floppy or old BIOS\r\n"
eread:	.asciz		"\r\nRead error\r\n"
enoos:	.asciz		"No O/S\r\n"
enoboot: .ascii		"No active partition"	/* runs into crlf... */
crlf:	.asciz		"\r\n"

endofcode:
	nop

/* partition table */
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
pt:
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

/* the last 2 bytes in the sector 0 contain the signature */
	. = 0x1fe
signature:
	.short	DOSMBR_SIGNATURE
	. = 0x200