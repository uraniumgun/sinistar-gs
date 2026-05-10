# Makefile for building the game
# This assumes some development tools are in the path
# iix - The GoldenGate IIgs VM for running the ORCA tools
# The ORCA tools must be installed and configured with GoldenGate.
# cp2 - CiderPress2 command line, used to copy files to the disk image
# ffmpeg - Converts the source audio samples to 8-bit pcm.
# Powershell Core - to run some external scripts

# App sources to assemble, just the base filenames
app_sources = app.main.asm app.globals.asm app.debug.support.asm gameplay.ui.asm gameplay.manager.asm gameplay.debug.asm gameplay.difficulty.debug.asm gameplay.playfield.asm gameplay.level.asm \
 gameplay.player.asm gameplay.rock.asm gameplay.worker.asm gameplay.sinistar.asm gameplay.warrior.asm gameplay.crystal.asm gameplay.bomb.asm gameplay.caller.asm \
 gameplay.sound.asm gameplay.entity.asm gameplay.explosion.asm asset.control.asm ui.entity.asm \
 startup.splash.asm frontend.state.asm turn.start.state.asm tutorial.state.asm config.state.asm high.score.state.asm enter.score.state.asm \
 input.overview.state.asm copyright.state.asm credits.state.asm\
 playfield.asm playfield.entity.asm playfield.entity.manager.asm player.entity.asm rock.entity.manager.asm rock.entity.asm worker.entity.manager.asm worker.entity.asm \
 warrior.entity.manager.asm warrior.entity.asm sinistar.entity.manager.asm sinistar.entity.asm \
 shot.entity.manager.asm shot.entity.asm explosion.entity.manager.asm explosion.entity.asm crystal.entity.manager.asm crystal.entity.asm bomb.entity.manager.asm bomb.entity.asm \
 stars.manager.asm collision.support.asm playfield.scanner.asm \
 task.list.asm task.manager.asm \
 system.debug.asm memory.debug.asm

lib_sources = unit.tests.asm \
 framelib.manager.asm framelib.entity.asm framelib.collection.asm framelib.set.asm framelib.list.asm framelib.animation.asm framelib.frame.asm \
 datalib.manager.asm datalib.library.asm datalib.type.entry.asm datalib.data.entry.asm datalib.descriptor.asm \
 datalib.translator.default.asm datalib.translator.tile.asm datalib.translator.ctil.asm datalib.translator.palt.asm datalib.translator.frmc.asm datalib.translator.font.asm \
 datalib.translator.wave.asm \
 grlib.support.asm grlib.update.rects.asm grlib.sprite.asm grlib.sprite.manager.asm grlib.prle.shape.asm grlib.prle.shape.clipped.asm \
 grlib.blockmove.asm grlib.blockfill.asm grlib.blockfill.back.asm grlib.blockfill.screen.asm \
 grlib.blockshape.asm grlib.block.shape.blit.1.asm grlib.block.shape.blit.2.asm grlib.block.shape.blit.4.asm grlib.block.font.asm \
 grlib.compiledshape.asm grlib.globals.asm \
 grlib.entity.asm grlib.entity.manager.asm grlib.entity.sort.entry.asm grlib.entity.sort.list.asm \
 grlib.debug.rect.asm palette.support.asm grlib.ylookup.asm \
 sndlib.manager.asm sndlib.riff.asm value.transform.asm math.support.asm \
 file.manager.asm container.vector.asm container.ptr.vector.asm container.dword.vector.asm object.support.asm memory.support.asm string.support.asm fixed.buffer.pool.asm \
 input.support.asm string.manager.asm tokenizer.asm textlib.support.asm applib.support.asm id.list.asm \
 system.error.asm sba.manager.asm std.objects.asm lz4.asm zx0.asm crc32.asm

 # audio files
audio_sources = beware-coward.wav beware-i-live.wav bounce.wav collect-crystal.wav crystal-flash.wav EEERRAAURGH.wav deliver-crystal.wav explosion-clipped.wav i-am-sinistar.wav \
i-hunger-coward.wav i-hunger.wav max-bomb-pickup.wav message.wav new-ship.wav player-explosion-1.wav player-explosion-2.wav player-shot.wav \
robotron-shot.wav run-coward.wav run-run-run.wav scratchy-static-1.wav scratchy-static-2.wav sinibomb-launch.wav tough-luck-loss.wav\
turn-start.wav warrior-explosion.wav warrior-shot.wav wavy-tone.wav worker-collect-crystal.wav

# The data sources for transferring to the image
transfer_data_sources = ui.dat data.dat player.ship.dat rocks.dat red.demon.dat crystal.dat bomb.dat sinistar.dat warrior.dat

# Objects of the source files.  Using .root, rather than .a, because not all .asm files end up creating a .a file.
app_objects = $(patsubst %.asm, %.root, $(app_sources))
lib_objects = $(patsubst %.asm, %.root, $(lib_sources))
# Objects with the relative path to where they are located.
app_objects_path = $(patsubst %, obj/%, $(app_objects))
lib_objects_path = $(patsubst %, lib/obj/%, $(lib_objects))
app_clean_objects_path = $(patsubst %, obj\\%, $(app_objects))
lib_clean_objects_path = $(patsubst %, lib\\obj\\%, $(lib_objects))
# Sources, with path
app_sources_path = $(patsubst %, source/%, $(app_sources))
app_generated_macros = $(patsubst %.asm, %.macros, $(app_sources))
# Macros, with path
app_generated_macros_path = $(patsubst %.asm, generated/%.macros, $(app_sources))
lib_generated_macros_path = $(patsubst %.asm, generated/%.macros, $(lib_sources))

# GS/OS File attributes for a 'data' file.  Using the generic "Load File" type
# See https://github.com/a2infinitum/apple2-filetypes for a handy list of GS/OS file types
datafileattribs = BC0000

# Linked application name
progname = Sinistar.GS
# image directory
imagedir = image
# image file
imagefile = sinistargs
# image volume name
imagevol = Sinistar.GS
# audio assets directory
audioassetsdir = assets/audio

# Extra options, for use when compiling / linking to debug with Crossrunner
#asm_options = +L +S
#asm_redirect = >debug/$*.asm
link_options = +L
link_redirect = >debug/app.map
asm_options =
asm_redirect =
#link_options =
#link_redirect =

# CiderPress2 options for adding a file
cp2_add_options = add --overwrite --strip-paths

# Do all
all: $(app_objects_path) $(lib_objects_path) image/$(progname)
# Rule for the objects to get generated from the sources.  This seems oddly formatted if you ask me, but it works.
# $^ is the right-side / dependent file, $* is the left-side / target file, though stripped of its extension and directory
$(app_objects_path): obj/%.root: source/%.asm
	iix assemble $(asm_options) +P $^ keep=obj/$* $(asm_redirect)
#
$(lib_objects_path): lib/obj/%.root: lib/source/%.asm
	iix assemble $(asm_options) +P $^ keep=lib/obj/$* $(asm_redirect)
# Do the link  The pattern substitution is there to remove the .root extension. cd .\obj & $(patsubst %.asm,%,$(sources))
image/$(progname): $(app_objects_path) $(lib_objects_path) source/app.link
	iix chtyp -l linker source/app.link
	iix -DKeepType=S16 compile source/app.link $(link_options) keep=image/$(progname) $(link_redirect)
	cp image/$(progname) image/$(progname)#B30000

# No prereqs, I want to do this every time
%.wav:
	ffmpeg -hide_banner -y -i $(audioassetsdir)/exports/$(@F) -codec:a pcm_u8 -ar 11025 $(audioassetsdir)/conversions/$(@F)
# Convert audio samples
convert_audio: $(audioassetsdir)/conversions/$(audio_sources)

# Copy the data files to temporary files with ProDOS file attributes and the extension removed
# Then copy to the image, then delete the temporary file
$(transfer_data_sources):
	mkdir -p temp
	cp -f image/$@ temp/$(patsubst %.dat,%#$(datafileattribs),$@)
	cp2.exe $(cp2_add_options) $(imagedir)/$(imagefile).2mg temp/$(patsubst %.dat,%#$(datafileattribs),$@)
	rm -f temp/$(patsubst %.dat,%#$(datafileattribs),$@)

# Create the target disk image if it doesn't exist.
# The rename is to change the default NEWDISK volume name to Sinistar.GS
$(imagedir)/$(imagefile).2mg:
	cp2.exe cdi $(imagedir)/$(imagefile).2mg 800KiB ProDOS
	cp2.exe rename $(imagedir)/$(imagefile).2mg : $(imagevol)

# Copy just the data to the image
transfer_data: image/$(progname) $(imagedir)/$(imagefile).2mg $(transfer_data_sources)
	cp2.exe $(cp2_add_options) $(imagedir)/$(imagefile).2mg $(imagedir)/manifest

# Copy the app to the image
transfer_app: image/$(progname) $(imagedir)/$(imagefile).2mg
	cp2.exe $(cp2_add_options) $(imagedir)/$(imagefile).2mg $(imagedir)/$(progname)#B30000

# Copy the data and app to the image
transfer: transfer_app transfer_data

# Remove any user data (the config and high.scores) from the image
remove_user_data:
	cp2.exe delete $(imagedir)/$(imagefile).2mg config
	cp2.exe delete $(imagedir)/$(imagefile).2mg high.scores

# $@ is the full target
# $^ is every source (prerequisite), $? would give me ones newer than $@
$(app_generated_macros_path): generated/%.macros: source/%.asm
	iix macgen +C -P $? $@ macros/= lib/macros/= 13/ORCAInclude/m= 13/AInclude/m= 13/AppleUtil/m=
#
$(lib_generated_macros_path): generated/%.macros: lib/source/%.asm
	iix macgen +C -P $? $@ lib/macros/= 13/ORCAInclude/m= 13/AInclude/m= 13/AppleUtil/m=

build_macros: $(app_generated_macros_path) $(lib_generated_macros_path)

clean:
	rm -f obj/*.*
	rm -f lib/obj/*.*
	rm -f generated/*.*

clean_code:
	rm -f obj/*.*
	rm -f lib/obj/*.*

clean_macros:
	rm -f generated/*.*

clean_disk_image:
	rm -f $(imagedir)/$(imagefile).2mg

run:
	./runit.ps1

convert_symbols:
	./orca-to-merlin-symbols.ps1 -map ./debug/app.map -dest ./debug/sinistar.gs_symbols.txt
