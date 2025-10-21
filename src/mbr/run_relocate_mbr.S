#ifndef __RUN_RELOCATE_MBR_S__
#define __RUN_RELOCATE_MBR_S__

#include "mbr.h"
#include "segments.h"

relocmbr_set_segments:
    movw    %cs,                                %cx
    movw    %cx,                                %ds
    subw    $(LEN16_MBR>>4),                    %cx
    movw    %cx,                                %es

relocmbr_copy_mbr:
    xorw    %cx,                                %cx
    movw    %cx,                                %si
    movw    %cx,                                %di
    movw    $(LEN16_MBR/4),                     %cx
    rep     movsl

relocmbr_verify:
    cmpw    $MBR_MAGIC,                         %es:(mbr_signature)
    jne     _finish

relocmbr_align_partition_table:
    PTR16_PARTITION_TABLE = LEN16_MBR - LEN16_PARTITION_TABLE
    pushw   $PTR16_PARTITION_TABLE
    popw    %di
    pushw   $mbr_partition_table
    popw    %si
    movw    $LEN16_PARTITION_TABLE/4,           %cx
    rep     movsl

relocmbr_ljmp_relocated:
    ljmp    $(SEGM_BIOSBOOT-(LEN16_MBR>>4)),    $1f
1:

#endif /* __RUN_RELOCATE_MBR_S__ */