ASM	= nasm
SDIR	= src
BDIR	= build
RDIR	= release
SUBDIRS	= $(BDIR) $(RDIR)
DEPS	= Makefile src/ttyout.asm

THIS 	= $(shell basename $@ .rom)
MKDIR   = $(shell test -d $@ || mkdir -p $@)

.PHONY: bios clean subdirs

boot : $(RDIR)/boot.rom $(DEPS)
	qemu-system-i386 -serial stdio -drive file=$<,index=0,if=floppy,format=raw

bios : $(RDIR)/bios.rom $(DEPS)
	qemu-system-i386 -serial stdio -bios $<
clean :
	rm -fr $(SUBDIRS)

$(BDIR): ; $(MKDIR)
$(RDIR): ; $(MKDIR)

$(RDIR)/%.rom: $(SDIR)/%.asm $(DEPS) $(SUBDIRS)
	$(ASM) -i $(SDIR) -l $(BDIR)/$(THIS).lst -f bin -o $(RDIR)/$(THIS).rom $<