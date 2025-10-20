#ifndef __RUN_RELOCATE_MBR_S__
#define __RUN_RELOCATE_MBR_S__

#include "mbr.h"
#include "segments.h"
#include "memcpy.h"

relocmbr_set_segments:
    movw    %cs,%ax
    movw    %ax,%ds
    subw    $(LEN16_MBR>>4),%ax
    movw    %ax,%es

relocmbr_copy_mbr:
    _unsafe_memcpy_common_index(
        0,
        LEN16_MBR
    )

relocmbr_verify:
    cmpw    $MBR_MAGIC,         %es:(mbr_signature)
    jne     _return_to_bios

relocmbr_align_partition_table:
    PTR16_PARTITION_TABLE = LEN16_MBR - LEN16_PARTITION_TABLE
    _unsafe_memcpy_unique_index(
        mbr_partition_table,
        PTR16_PARTITION_TABLE,
        LEN16_PARTITION_TABLE
    )

relocmbr_ljmp_relocated:
    ljmp    $(SEGM_BIOSBOOT-(LEN16_MBR>>4)),     $1f
1:

#endif /* __RUN_RELOCATE_MBR_S__ */