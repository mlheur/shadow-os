#ifndef __RUN_RELOCATE_MBR_S__
#define __RUN_RELOCATE_MBR_S__

#include "mbr.h"
#include "segments.h"

#define _mbr_memcpy(AMT) movl $AMT,%ecx; cld; rep movsl

memcpy_mbr_from:
pushw   $MBR_SEGM<<4
popw    %si
memcpy_mbr_to:
pushw   $RELOC_SEGM<<4
popw    %di
_mbr_memcpy(0x80)
cmpw    $MBR_MAGIC,-2(%edi)
jne     _ret


#endif /* __RUN_RELOCATE_MBR_S__ */