ASM	= nasm
SDIR	= src
BDIR	= build
RDIR	= release
SUBDIRS	= $(BDIR) $(RDIR)
DEPS	= Makefile

THIS 	= $(shell basename $@ .rom)
MKDIR   = $(shell test -d $@ || mkdir -p $@)

.PHONY: bios clean subdirs

boot : $(RDIR)/boot.rom $(DEPS)
	qemu-system-i386 -serial stdio -drive file=$<,index=0,if=floppy,format=raw

clean :
	rm -fr $(SUBDIRS)

$(BDIR): ; $(MKDIR)
$(RDIR): ; $(MKDIR)

$(RDIR)/%.rom: $(SDIR)/%.asm $(DEPS) $(SUBDIRS)
	$(ASM) -l $(BDIR)/$(THIS).lst -f bin -o $(RDIR)/$(THIS).rom $<