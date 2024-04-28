ASM	= nasm
QEMUDBG = -d cpu -D qemu-debug.log
#QEMUDBG = ""
SDIR	= src
BDIR	= build
RDIR	= release
SUBDIRS	= $(BDIR) $(RDIR)
DEPS	= Makefile src/ttyout.asm src/registers.asm

THIS 	= $(shell basename $@ .rom)
MKDIR   = $(shell test -d $@ || mkdir -p $@)

.PHONY: bios clean subdirs

boot : $(RDIR)/boot.rom $(DEPS)
	qemu-system-i386 $(QEMUDBG) -serial stdio -drive file=$<,index=0,if=floppy,format=raw

bios : $(RDIR)/bios.rom $(DEPS)
	qemu-system-i386 $(QEMUDBG) -serial stdio -bios $<
clean :
	rm -fr $(SUBDIRS)

$(BDIR): ; $(MKDIR)
$(RDIR): ; $(MKDIR)

$(RDIR)/%.rom: $(SDIR)/%.asm $(DEPS) $(SUBDIRS)
	$(ASM) -i $(SDIR) -l $(BDIR)/$(THIS).lst -f bin -o $(RDIR)/$(THIS).rom $<
