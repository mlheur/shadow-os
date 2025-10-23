#ifndef __MBR_H__
#define __MBR_H__

#define MBR_MAGIC               0xAA55

#define sizeof_MBR              0x0200
#define sizeof_MBR_magic        0x0002
#define sizeof_partition_entry  0x0010
#define sizeof_partition_table  ((4)*(sizeof_partition_entry))

#define ptr_mbr_partition_table ((sizeof_MBR)-(sizeof_MBR_magic)-(sizeof_partition_table))
#define ptr_mbr_signature       ((sizeof_MBR)-(sizeof_MBR_magic))

#endif /* __MBR_H__ */