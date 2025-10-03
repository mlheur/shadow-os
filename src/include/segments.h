#ifndef __SEGMENTS_H__
#define __SEGMENTS_H__

/******************************************************************************/
/* 0000:0000 until 0000:03FF IVT Used by the BIOS, don't write here */
/* 0040:0000 until 0040:00FF BDA Used by the BIOS, don't write here */
/* [0040:0100 is 0050:0000] until 7000:FFFF Conventional Memory */
#define MBR_SEGM 0x07C0 /* BIOS loads us here */
#define KRN_SEGM 0x1000 /* 0x10000 - 0x1FFFF */
/* 8000:0000 until 9000:FFFF EBDA */
/* A000:0000 until B000:FFFF VRAM */
/* C000:0000 until C000:7FFF BIOS Expansion */
/* C000:8000 until E000:FFFF VGA BIOS */
/* F000:0000 until F000:FFFF Motherboard BIOS */
/******************************************************************************/

#endif /* __SEGMENTS_H__ */