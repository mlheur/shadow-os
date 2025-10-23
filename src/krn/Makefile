MODULE 		:= krn
COMPONENTS  := krn

INCDIR 		:= ../include
BINDIR      := ../../bin
INCLUDES  	 = $(wildcard $(INCDIR)/.h)
SOURCES 	:= $(foreach comp,$(COMPONENTS),$(comp).S)
OBJECTS    	 = $(foreach src,$(SOURCES),$(src:.S=.o))
OUTPUT    	:= $(BINDIR)/$(MODULE)
LDSCRIPT 	:= ./ld.script

AS       	:= gcc
ASFLAGS  	:= -I$(INCDIR) -g -Wa,--32 -c
LD       	:= ld
LDFLAGS  	:= -static -s -dT $(LDSCRIPT)

$(OUTPUT) : $(OBJECTS) $(INCLUDES)
	$(LD) $(LDFLAGS) -o $(OUTPUT)

%.o : %.S
	$(AS) $(ASFLAGS) $< -o $@

.PHONY : clean
clean : 
	rm -f $(OUTPUT) $(OBJECTS)