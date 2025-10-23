MODULE 		:= mbr
COMPONENTS  := mbr partition_table mbr_signature

INCDIR 		:= ../include
BINDIR      := ../../bin
OBJDIR      := ../../objs
DUMPDIR     := ../../dumps
INCLUDES  	 = $(wildcard $(INCDIR)/.h)
SOURCES 	:= $(foreach comp,$(COMPONENTS),$(comp).S)
OBJNAMES  	 = $(foreach src,$(SOURCES),$(src:.S=.o))
OBJECTS      = $(foreach obj,$(OBJNAMES),$(OBJDIR)/$(obj))
OUTPUT    	:= $(BINDIR)/$(MODULE)
LDSCRIPT 	:= ./ld.script

AS       	:= gcc
ASFLAGS  	:= -I$(INCDIR) -g -Wa,--32 -c
LD       	:= ld
LDFLAGS  	:= -static -s -dT $(LDSCRIPT)
OBJDUMP     := objdump
OBJOPTS     := -M att -m i8086

.PHONY : $(MODULE)
$(MODULE) : $(OUTPUT)

$(OUTPUT) : $(OBJECTS) $(LDSCRIPT)
	$(LD) $(LDFLAGS) -o $(OUTPUT) && \
	$(OBJDUMP) $(OBJOPTS) -d $(OBJECTS) > $(DUMPDIR)/$(MODULE).dump

$(OBJDIR)/%.o : %.S $(INCLUDES) $(SOURCES)
	$(AS) $(ASFLAGS) $< -o $@

.PHONY : clean
clean : 
	@rm -f $(OUTPUT) $(OBJECTS) $(DUMPDIR)/$(MODULE).dump