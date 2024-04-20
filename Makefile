ASM	= nasm
SDIR	= src
BDIR	= build
RDIR	= release
SUBDIRS	= $(BDIR) $(RDIR)
DEPS	= Makefile

THIS 	= $(shell basename $@ .rom)
MKDIR   = $(shell test -d $@ || mkdir -p $@)

.PHONY: bios clean subdirs

bios : $(RDIR)/bios.rom $(DEPS)
	qemu-system-i386 -nographic -m 1M -bios $<

clean :
	rm -fr $(SUBDIRS)

$(BDIR): ; $(MKDIR)
$(RDIR): ; $(MKDIR)

$(RDIR)/%.rom: $(SDIR)/%.asm $(DEPS) $(SUBDIRS)
	$(ASM) -l $(BDIR)/$(THIS).lst -f bin -o $(RDIR)/$(THIS).rom $<