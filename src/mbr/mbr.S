/*******************************************************************************
 * BIOS hands over to MBR:
 * The only things that are (nearly) certain are that
 *  - the bootsector code is loaded and running at physical address 0x7c00,
 *  - the CPU is in 16-bit Real Mode,
 *  - the CPU register called dl contains the "drive number",
 *  - and that only 512 bytes of the bootsector have been loaded.
 * -- https://wiki.osdev.org/System_Initialization_(x86)
 ******************************************************************************/

#define COM1 0x00
#define VDEO 0x01

#define MBR_ADDR    0x7C00
#define MBR_SIZE    0x0200

#define prints(s)   pushw %si; movw $(s+MBR_ADDR), %si; call strout; popw %si

	.text
	.code16

/*******************************************************************************
 * MBR */
    .globl _start
_start:
    ljmp    $0x0000, $(MBR_ADDR+_init)    /* set code segment to 0x0000 */

osname:  .ascii  "\r\nshadow-os"
crlf:    .asciz  "\r\n"
halting: .asciz  "halting"

_init:
    cli
    movw    %cs,    %ax /* copy the code segment to all other segments ... */
    movw    %ax,    %ss /* ... to the stack segment */
    movw    %ax,    %ds /* ... to the data segment */
    movw    %ax,    %es /* ... to the extra segment */
    movw    %ax,    %si /* set a known source index */
    movw    %ax,    %di /* and known destination index */
    movw    $0,     %bp /* set the base pointer to zero */
    movw    $0,     %sp /* set the stack pointer to zero, it will decrement to 0xFFFF on first use */
/******************************************************************************/


/*******************************************************************************
 * Initialize the serial port */
#ifdef COM1
_init_COM1:
	pushw	%ax             /* save state */
    pushw   %dx
	movw	$0xE3,  %ax     /* Initialize the serial port to 9600 baud, 8N1. */
	movw	$COM1,  %dx
	int     $0x14
    popw    %dx             /* restore state */
	popw	%ax
#endif /* COM1 */
/******************************************************************************/


/*******************************************************************************
 * Write dx to the consoles */
 print_dx:
    pushw   %ax
    movb    %dl,    %al
    shr     $4,     %al
    call itoa_charout
    movb    %dl,    %al
    call itoa_charout
    popw    %ax
/******************************************************************************/


/*******************************************************************************
 * Write the OS name to the consoles */
 print_osname:
    prints(osname)
/******************************************************************************/


/*******************************************************************************
 * End MBR program */
    prints(halting)
halt:
    sti
    hlt
    jmp halt
/******************************************************************************/


/*******************************************************************************
 * Function: itoa_charout
 * Purpose: convert int to ascii before falling through to charout */
itoa_charout:
    andw    $0x0F,  %ax
    addw    $'0',   %ax
/*******************************************************************************
 * Function: charout
 * Purpose: write a character to serial and/or video consoles
 * Inputs: al: the 8-bit ascii character to write
 * Outputs: None */
charout:
#ifdef COM1
    pushw   %dx             /* save state of dx */
    movb    $0x01,  %ah     /* for int14h */
    movb    $COM1,  %dl     /* for int14h */
    int     $0x14
    popw    %dx             /* restore state of DX */
#endif /* COM1 */
#ifdef VDEO
    pushw   %bx
    movb    $0x0e,  %ah
    movw    $VDEO,  %bx
    int     $0x10
    popw    %bx
#endif /* VDEO */
    ret
/******************************************************************************/

/*******************************************************************************
 * Function: strout
 * Purpose: write a null-terminated string through charout
 * Parameters: si: the address of the first character
 * Outputs: None. */
strout:
    pushw   %ax             /* save state */
    jmp     strout_2
strout_1:
    call    charout         /* print the character */
strout_2:
    lodsb                   /* copy the character to al, increment si */
    testb   %al,    %al     /* test if it is the null terminator */
    jnz     strout_1        /* else move to the next character */
strout_fin:
    popw    %ax             /* restore state */
    ret
/******************************************************************************/


/*******************************************************************************
 * the last 2 bytes in the sector 0 contain the signature */
	. = 0x1fe
signature:
	.short	0xAA55
	. = 0x200
/******************************************************************************/
