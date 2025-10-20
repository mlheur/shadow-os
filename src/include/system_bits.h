/*
 * This one is reimportable and will flip-flop appropriately because
 * the gnu C Pre Processor runs entirely before any assembly and is
 * therefore woefully ignorant whether the code is in 16bit or 32bit
 * address and data modes.  The memcpy macros *depend* on knowing
 * which mode we're in.  This habit of defining bits as a macro and
 * using system_bits.h recurringly, I'm hoping will use the appropriate
 * inline memcpy accordingly.
 */


#ifdef __16BIT__
.code16
#endif /* __16BIT__ */

#ifdef __32BIT__
.code32
#endif /* __32_BIT__ */
