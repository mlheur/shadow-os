#ifndef __COM1_H__
#define __COM1_H__


#define COM1_BASE   $0x3F8

#define COM1_BUFFER     COM1_BASE+0
#define COM1_IRQ_STAT   COM1_BASE+1
#define COM1_DIV_LO     COM1_BASE+0
#define COM1_DIV_HI     COM1_BASE+1
#define COM1_RD_IRQID   COM1_BASE+2
#define COM1_FIFO_CTL   COM1_BASE+2
#define COM1_LINE_CTL   COM1_BASE+3
#define COM1_MODM_CTL   COM1_BASE+4
#define COM1_LINE_STAT  COM1_BASE+5
#define COM1_MODM_STAT  COM1_BASE+6
#define COM1_SCRATCH    COM1_BASE+7



#endif /* __COM1_H__ */