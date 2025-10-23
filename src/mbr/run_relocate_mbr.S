#ifndef __RUN_RELOCATE_MBR_S__
#define __RUN_RELOCATE_MBR_S__

#include "mbr.h"
#include "segments.h"

relocmbr_set_segments:
    movw    %cs,                                %cx
    movw    %cx,                                %ds
    subw    $(sizeof_MBR>>4),                   %cx
    movw    %cx,                                %es

relocmbr_copy_mbr:
    xorw    %cx,                                %cx
    movw    %cx,                                %si
    movw    %cx,                                %di
    movw    $(sizeof_MBR/4),                    %cx
    rep     movsl

relocmbr_verify:
    cmpw    $MBR_MAGIC,                         %es:(mbr_signature)
    jne     _finish

relocmbr_align_partition_table:
    pushw   $relocated_partition_table
    popw    %di
    pushw   $mbr_partition_table
    popw    %si
    movw    $sizeof_partition_table/4,          %cx
    rep     movsl

relocmbr_ljmp_relocated:
    ljmp    $(SEGM_BIOSBOOT-(sizeof_MBR>>4)),   $1f
1:

#endif /* __RUN_RELOCATE_MBR_S__ */