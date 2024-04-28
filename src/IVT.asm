
%define GI_p_dpl_type   0b1000111000000000

struc       GATE_INTERRUPT_80386
    .offset_lo:     resb    2
    .selector:      resb    2
    .p_dpl_type:    resb    2
    .offset_hi:     resb    2
endstruc

IDT:

IDT_INT0:   