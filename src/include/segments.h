#ifndef __SEGMENTS_H__
#define __SEGMENTS_H__

/******************************************************************************/
/* 0000:0000 until 0000:03FF IVT Used by the BIOS, don't write here */
/* 0040:0000 until 0040:00FF BDA Used by the BIOS, don't write here */
/* [0040:0100 is 0050:0000] until 7000:FFFF Conventional Memory */
#define SEGM_BIOSBOOT 0x07C0 /* BIOS loads us here */
/* 8000:0000 until 9000:FFFF EBDA */
/* A000:0000 until B000:FFFF VRAM */
/* C000:0000 until C000:7FFF BIOS Expansion */
/* C000:8000 until E000:FFFF VGA BIOS */
/* F000:0000 until F000:FFFF Motherboard BIOS */
/******************************************************************************/

/*******************************************************************************
 * Thoughts:
 * - 0x0nnnn reserved for BIOS and MBR; if the OS is going to lret back
 *   to the BIOS then we have to protect the stack that was used before it
 *   lcalled MBR.
 *   I might consider using some available sections for numerous kernel flags,
 *   and/or transient data; similar to Vic-20 zero page variables.
 * - 0x1nnnn: 
 * - 0x2nnnn: 
 * - 0x3nnnn: 
 * - 0x4nnnn: 
 * - 0x5nnnn: 
 * - 0x6nnnn: 
 * - 0x7nnnn: 
 * Above this, EBDA, VRAM, BIOS-Exp, VGA-BIOS and MOBO-BIOS.
 * It is also reasonable to wish to reclaim the memory from 0xA0000 to 0xFFFFF
 * and make your RAM contiguous. Again the answer is disappointing: Forget about
 * it.
 ******************************************************************************/

#endif /* __SEGMENTS_H__ */