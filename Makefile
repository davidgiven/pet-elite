BEEBASM?=beebasm
PYTHON?=python

# A make command with no arguments will build Teletext Elite with the standard
# commander
#
# Optional arguments for the make command are:
#
#   commander=max       Start with a maxed-out commander
#
# So, for example:
#
#   make commander=max
#
# will build Teletext Elite with a maxed-out commander

ifeq ($(commander), max)
  max-commander=TRUE
else
  max-commander=FALSE
endif

remove-checksums=FALSE
match-original-binaries=FALSE

variant-number=2
folder=sth
suffix=-sth

.PHONY:all
all:
	echo _VERSION=2 > 1-source-files/main-sources/elite-build-options.asm
	echo _VARIANT=$(variant-number) >> 1-source-files/main-sources/elite-build-options.asm
	echo _REMOVE_CHECKSUMS=$(remove-checksums) >> 1-source-files/main-sources/elite-build-options.asm
	echo _MATCH_ORIGINAL_BINARIES=$(match-original-binaries) >> 1-source-files/main-sources/elite-build-options.asm
	echo _MAX_COMMANDER=$(max-commander) >> 1-source-files/main-sources/elite-build-options.asm
	$(BEEBASM) -i 1-source-files/main-sources/elite-pet-startup.asm -v > 3-assembled-output/compile.txt
	$(BEEBASM) -i 1-source-files/main-sources/elite-text-tokens.asm -v > 3-assembled-output/compile.txt
	$(BEEBASM) -i 1-source-files/main-sources/elite-missile.asm -v >> 3-assembled-output/compile.txt
	$(BEEBASM) -i 1-source-files/main-sources/elite-loader1.asm -v >> 3-assembled-output/compile.txt
	$(BEEBASM) -i 1-source-files/main-sources/elite-loader2.asm -v >> 3-assembled-output/compile.txt
	$(BEEBASM) -i 1-source-files/main-sources/elite-loader3.asm -v >> 3-assembled-output/compile.txt
	$(BEEBASM) -i 1-source-files/main-sources/elite-loader-sideways-ram.asm -v >> 3-assembled-output/compile.txt
	$(BEEBASM) -i 1-source-files/main-sources/elite-source-flight.asm -v >> 3-assembled-output/compile.txt
	$(BEEBASM) -i 1-source-files/main-sources/elite-source-docked.asm -v >> 3-assembled-output/compile.txt
	$(BEEBASM) -i 1-source-files/main-sources/elite-ships-a.asm -v >> 3-assembled-output/compile.txt
	$(BEEBASM) -i 1-source-files/main-sources/elite-ships-b.asm -v >> 3-assembled-output/compile.txt
	$(BEEBASM) -i 1-source-files/main-sources/elite-ships-c.asm -v >> 3-assembled-output/compile.txt
	$(BEEBASM) -i 1-source-files/main-sources/elite-ships-d.asm -v >> 3-assembled-output/compile.txt
	$(BEEBASM) -i 1-source-files/main-sources/elite-ships-e.asm -v >> 3-assembled-output/compile.txt
	$(BEEBASM) -i 1-source-files/main-sources/elite-ships-f.asm -v >> 3-assembled-output/compile.txt
	$(BEEBASM) -i 1-source-files/main-sources/elite-ships-g.asm -v >> 3-assembled-output/compile.txt
	$(BEEBASM) -i 1-source-files/main-sources/elite-ships-h.asm -v >> 3-assembled-output/compile.txt
	$(BEEBASM) -i 1-source-files/main-sources/elite-ships-i.asm -v >> 3-assembled-output/compile.txt
	$(BEEBASM) -i 1-source-files/main-sources/elite-ships-j.asm -v >> 3-assembled-output/compile.txt
	$(BEEBASM) -i 1-source-files/main-sources/elite-ships-k.asm -v >> 3-assembled-output/compile.txt
	$(BEEBASM) -i 1-source-files/main-sources/elite-ships-l.asm -v >> 3-assembled-output/compile.txt
	$(BEEBASM) -i 1-source-files/main-sources/elite-ships-m.asm -v >> 3-assembled-output/compile.txt
	$(BEEBASM) -i 1-source-files/main-sources/elite-ships-n.asm -v >> 3-assembled-output/compile.txt
	$(BEEBASM) -i 1-source-files/main-sources/elite-ships-o.asm -v >> 3-assembled-output/compile.txt
	$(BEEBASM) -i 1-source-files/main-sources/elite-ships-p.asm -v >> 3-assembled-output/compile.txt
	$(BEEBASM) -i 1-source-files/main-sources/elite-readme.asm -v >> 3-assembled-output/compile.txt
	#$(PYTHON) 2-build-files/elite-checksum.py
	$(BEEBASM) -i 1-source-files/main-sources/elite-disc.asm -do 5-compiled-game-discs/teletext-elite.ssd -boot ELITE2 -title "E L I T E"
ifneq ($(verify), no)
	@$(PYTHON) 2-build-files/crc32.py 4-reference-binaries/$(folder) 3-assembled-output
endif
	salvador -classic -c 3-assembled-output/ELITE4.unprot.bin 3-assembled-output/ELITE4.unprot.bin.zx0
	salvador -classic -c 3-assembled-output/T.CODE.unprot.bin 3-assembled-output/T.CODE.unprot.bin.zx0
	salvador -classic -c 3-assembled-output/D.CODE.unprot.bin 3-assembled-output/D.CODE.unprot.bin.zx0
	salvador -classic -c 3-assembled-output/D.MOA.bin 3-assembled-output/D.MOA.bin.zx0
	salvador -classic -c 3-assembled-output/D.MOB.bin 3-assembled-output/D.MOB.bin.zx0
	salvador -classic -c 3-assembled-output/D.MOC.bin 3-assembled-output/D.MOC.bin.zx0
	salvador -classic -c 3-assembled-output/D.MOD.bin 3-assembled-output/D.MOD.bin.zx0
	salvador -classic -c 3-assembled-output/D.MOE.bin 3-assembled-output/D.MOE.bin.zx0
	salvador -classic -c 3-assembled-output/D.MOF.bin 3-assembled-output/D.MOF.bin.zx0
	salvador -classic -c 3-assembled-output/D.MOG.bin 3-assembled-output/D.MOG.bin.zx0
	salvador -classic -c 3-assembled-output/D.MOH.bin 3-assembled-output/D.MOH.bin.zx0
	salvador -classic -c 3-assembled-output/D.MOI.bin 3-assembled-output/D.MOI.bin.zx0
	salvador -classic -c 3-assembled-output/D.MOJ.bin 3-assembled-output/D.MOJ.bin.zx0
	salvador -classic -c 3-assembled-output/D.MOK.bin 3-assembled-output/D.MOK.bin.zx0
	salvador -classic -c 3-assembled-output/D.MOL.bin 3-assembled-output/D.MOL.bin.zx0
	salvador -classic -c 3-assembled-output/D.MOM.bin 3-assembled-output/D.MOM.bin.zx0
	salvador -classic -c 3-assembled-output/D.MON.bin 3-assembled-output/D.MON.bin.zx0
	salvador -classic -c 3-assembled-output/D.MOO.bin 3-assembled-output/D.MOO.bin.zx0
	salvador -classic -c 3-assembled-output/D.MOP.bin 3-assembled-output/D.MOP.bin.zx0
	exomizer sfx sys -t 4032 -q -o 3-assembled-output/elite.prg.crunched 3-assembled-output/elite.prg
	rm -f 5-compiled-game-discs/pet-elite.d64
	c1541 -format 'elite', d64 5-compiled-game-discs/pet-elite.d64 \
		-write 3-assembled-output/elite.prg.crunched elite \
		-write 3-assembled-output/ELITE4.unprot.bin.zx0 elite4,s \
		-write 3-assembled-output/T.CODE.unprot.bin.zx0 t.code,s \
		-write 3-assembled-output/D.CODE.unprot.bin.zx0 d.code,s \
		-write 3-assembled-output/D.MOA.bin.zx0 d.moa,s \
		-write 3-assembled-output/D.MOB.bin.zx0 d.mob,s \
		-write 3-assembled-output/D.MOC.bin.zx0 d.moc,s \
		-write 3-assembled-output/D.MOD.bin.zx0 d.mod,s \
		-write 3-assembled-output/D.MOE.bin.zx0 d.moe,s \
		-write 3-assembled-output/D.MOF.bin.zx0 d.mof,s \
		-write 3-assembled-output/D.MOG.bin.zx0 d.mog,s \
		-write 3-assembled-output/D.MOH.bin.zx0 d.moh,s \
		-write 3-assembled-output/D.MOI.bin.zx0 d.moi,s \
		-write 3-assembled-output/D.MOJ.bin.zx0 d.moj,s \
		-write 3-assembled-output/D.MOK.bin.zx0 d.mok,s \
		-write 3-assembled-output/D.MOL.bin.zx0 d.mol,s \
		-write 3-assembled-output/D.MOM.bin.zx0 d.mom,s \
		-write 3-assembled-output/D.MON.bin.zx0 d.mon,s \
		-write 3-assembled-output/D.MOO.bin.zx0 d.moo,s \
		-write 3-assembled-output/D.MOP.bin.zx0 d.mop,s \
		-write 1-source-files/other-files/E.MAX.bin e.max \
		-write 1-source-files/other-files/E.FIGHT.bin e.fight \
		-write 1-source-files/other-files/E.MISS1.bin e.miss1 \
		-write 1-source-files/other-files/E.MISS2.bin e.miss2

.PHONY:b2
b2:
	curl -G "http://localhost:48075/reset/b2"
	curl -H "Content-Type:application/binary" --upload-file "5-compiled-game-discs/teletext-elite.ssd" "http://localhost:48075/run/b2?name=teletext-elite.ssd"
