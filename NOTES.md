# Developer Notes
This file contains a bit of history of the development of Sinistar.GS

# How it Started
I'm a lifelong Apple II fan, and even did a little professional development of educational software for the Apple II, back in the late 80's.  I used a IIgs for my development platform, but never had a chance to do a full Apple IIgs application.  So to scratch that itch, I thought I'd do a port/re-creation of a game, and I settled on Sinistar.  At first, I thought I'd just re-create the game from scratch, attempting to figure out everything the game was doing, by just playing it.  However, being a fairly fast-paced game, it was going to be difficult to accurately re-create all the logic, based on just looking at the game.  This is especially difficult, because a lot of action happens off-screen.  Well, I was fortunate to quickly stumble upon the original source to the arcade game on github.  https://github.com/historicalsource/sinistar This was a great boon, and made it much easier to understand what was going on behind the scenes. Warriors, Workers, Planetoids, Crystals, and Sinistar all have off-screen logic, and having the source made it so I could get the game to play like the original, without a lot of guessing.

#### The Arcade Source Code
The original source is written in 6809 assembly, which is reasonably close to the 65816 instruction set and the source is very well annotated.  Using the source, I was able to re-create key parts of the logic systems, such as the task manager and the tasks that drive the logic for each of the object types.  The source was also handy for extracting the pixel maps for a majority of the art, as it was just included in the source as data definitions.  The fonts are in there too, though I was able to find some reasonable facsimiles on https://www.fontspace.com.

Having the original source was great for mimicking the logic, but the original arcade game had blitter hardware and a dedicated sound chip and a separate 6809 to drive the sound generation.  There was still a lot of work to do, such as file reading, drawing, sound playback, input handling, and the like.  I had made a small library of general purpose code, just prior to starting the Sinistar port, so I had something to go on.

#### Alternate Sinistar Source Code
I do have to mention, that there is an alternate version of the original Sinistar source code, that was cleaned up and re-annotated, and made to compile on a more modern 6809 assembler.  This was posted after I had found the historic source archive, and I didn't think to look back for more references.  The repo is at https://github.com/synamaxmusic/sinistar. An amazing amount of work was put into making this updated version by Synamax, including a lot of figuring out how things worked.  I wish I had seen this earlier on, in the development on my port, but even finding this later, was a tremendous help.  I highly recommend looking at this version if you want to know more of how the original Sinistar was made.

## Graphics
The original arcade game, had a hardware blitter that could DMA transfer blocks of memory, with transparency and flipping support, in mere microseconds.  On the IIgs, the CPU has to push all the pixels through a 1Mhz bus on the Mega II side.  Well, there are ways to speed things up a bit, and I am truly indebted to those in the Apple II community who have shared their knowledge.  John Brooks, Lucas Scharenbroich with the GTE Engine, Antoine Vignau, Olivier Zardini with Mr. Sprite, and many others.
In Sinistar I use a mix of techniques, mainly doing a "dirty rectangle" system to keep track of what needs to change on the screen, and I use the shadowed Video RAM in bank `$01` to do a majority of the updating, then block-copy the updated areas to the 'real' screen, in bank `$e1`.  Most of this block erasing and copying, uses the stack-remapping and stack opcode techniques, pioneered by those before me.

The drawing of the sprites is done with two types of formats. A 'compiled sprite' style format, similar to, but a bit more generic than Brutal Deluxe's Mr. Sprite.  I don't use stack remapping for my compiled sprite format, just indexed writes.  I chose this because it is simpler, and is reasonably close in speed to what a fully stack re-mapped format would do, and it doesn't require interrupt disabling.  I feel like I already turn off the interrupts way too much for the block move operations, and I don't want to have the streaming audio drop out.  I also use a traditional read-mask-merge-write style format in some situations.  This 'classic' style of drawing is slower, but can handle clipping without much of a speed penalty. At least for me, I didn't see a way to clip compiled sprites, without introducing a drastic speed hit.  A vast majority of the time, the game will be drawing with the faster, compiled sprites.  All sprites have two copies as well, one for starting on an even pixel boundary, and one for starting on an odd pixel boundary, which is needed because there are two pixels per byte, and shifting pixels on the fly, even with lookup tables is not really an option if you want to go fast.  This takes a fair amount of extra memory, but if there is one advantage the IIgs has, it is that it has a large memory space.

### Where did the art for the game come from?
The pixels maps used by the game are all original, no re-touching was done.  The original source has all of the pixels maps encoded as source in `sam/image.asm` and is 4-bits per pixel, just like the IIgs. I wrote a Powershell script to scrape the images out of that file and write them to FLC image files.  I processed the resulting FLC files into the format I needed for my port of the game.

## Audio
Audio in the original is done with a custom sound generation chip as well as a dedicated 6809 processor to control the sound generation.  Most of the sound effects in the original are frequency-modulation style effect, with Sinistar's vocalizations done with an early compressed PCM style format.  Re-creating all the sound effects, essentially from scratch by trying to generate the FM style effects from small waveforms and CPU control code to mimic what the original sounded like, was, well, not within scope.  So I cheated, and had MAME dump out recordings of the original effects, edited them up, re-sampled and exported them as 11Khz clips.  I was able to stuff most of the frequently used ones into Sound RAM, leaving some, like the Sinistar speech, to be 'streamed'.  The latter requires interrupt handling to keep the buffers up-to-date, and is the reason I try to not shut off interrupts too much with drawing trickery.  Playing single shot sound effects that are in Sound RAM is a fairly straight-forward process, though triggering a sound takes a surprising amount of DOC register fiddling, which isn't fast.  The sounds are triggered on two oscillators, so the audio is 'stereo', though the feed is mono.

## So is this just a port of Sinistar?
In a nutshell, yes, this is faithful port of Sinistar, in that no attempt to diverge from the original game was made, and having the game play as closely as the original, was the goal.  Having the original source for the game made it straight-forward, as to how to mimic the game play.  There are some bits of code that are a very close re-coding of what was in the original.  The task manager assignment and dispatch loop, which controls how logic is processed, is very close to the original.  Also, most of the tasks that drive the 'thinking' of the Workers, Warriors, etc, are pretty close interpretation to the original.  The time-based difficulty scaling system, which controls how aggressive the Warriors are and the population of Workers / Warriors / Planetoids is also a close approximation of the original function, using the original tables.

Where the code diverges from the original is with all the support code that is needed for loading assets, creating, destroying, tracking, invalidating, drawing, erasing and collision testing of objects.  Starting up, shutting down levels, drawing and managing the front-end as well as in-game UI, playing sounds, managing the input, and user configuration.  Overall, all the systems code that supports the game play.

## Coding Style
A big draw to coding a IIgs application, at least for me, is the 16-bit registers, but also the larger memory space, larger stack, and the ability to have a 'stack frame'.  This makes for passing values between functions more like what more modern processors do, as well as allowing for a clean way to have local variables to the function, that allow for recursion.  This functionality nicely wrapped up with ORCA's `sub` and `ret` macros and I used it extensively, including some variations of my own.  In the beginning, I maybe used it too extensively, because while very nice and clean looking, and not requiring magic globals, it does have overhead of setting up and tearing down the stack frame.  Not much, but it adds up, and for functions that are called at a very high-frequency, I switched back to passing through registers as much as possible.

I do also use a lot of macros, like a lot.  Even for what seems like mundane things like loading and storing the accumulator.  These macros like `getword` and `putword` are mainly there to wrap different addressing styles into, what I think, is a bit more readable format, especially indexed long indirect, where you need to set the Y register.  This gets wrapped up into one macro line, which makes it clearer (in my mind) to read.

# How it's Going
Overall, I'm reasonably happy with the way the port turned out.  I think it plays fairly close to the original, with a few adjustments for making it less difficult.  I do wish I could have gotten it to run a bit faster and smoother at the stock speed of 2.8Mhz.  At that speed, the frame rate can vary widely, and the game can chug if there is a lot on the screen.  I feel like there is still excessive overhead with tracking all the objects, including tracking the update rectangles for what is on screen.  This is above and beyond the actual erasing/drawing/updating that needs to be done.

There are also some missing features, most notably, the demo mode in the front end is not there.  Some text overlays when destroying Sinistar and warping to the next level are also missing.  My font drawing is nowhere near performant enough to do that, it would have to be custom compiled shapes or something similar.

The game balance is also, uneven.  The original game is notorious for its difficulty.  Options like the extra lives, easier scoring for extra lives, crystal attraction and population table adjustments, were added to mitigate the frustration, but there are more possibilities.  A frustration for me is that if Sinistar comes alive, and you don't have enough Sinibombs, you are pretty much dead, no matter how many lives you have.  He can easily chase you down, and attempting to mine anything more than one or two crystals while he is alive, is extremely difficult.  This is worse after the first zone, as the Workers can heal Sinistar, making it practically impossible to get enough crystals.  Maybe an option to disable Sinistar healing might help?  Maybe a longer stun time for Sinistar, after getting hit by a Sinibomb?

# Building the Game

### Required Tools
If you wish to build the game yourself, you will need a few things installed.

* **Visual Studio Code** - While not strictly necessary, it is the IDE I used to make the game.  You can probably just run make commands from the CLI.
* **GoldenGate** - This is a specialized virtual machine that allows for running IIgs applications.  It only supports a limited set of Toolbox calls, and it is primarily used to run **ORCA** shell commands.  Namely, the **ORCA/M** assembler, linker and other support programs.  This wonderful bit of kit was made by Kelvin Sherlock and is available from the **Juiced.GS Store**, https://juiced.gs/store/category/software/
* **ORCA/M** - This is the assembler / linker suite of tools, used to make the application.  I've always loved this toolchain, and have used it since the 80's.  It is also available at the **Juiced.GS Store**.  Please make sure you have the latest version, which fixes some linker bugs.
* **CiderPress2** - The build process uses the command-line version of this application to create the destination disk image.  `cp2.exe` must be in your path.
* **make** - A makefile parser that does the build steps.  I use **GNU Make 4.4.1** from the **MSYS2** installation.  Other make executables will probably work too.
* **Powershell 7** - There are some extra scripts that use this, though it is not needed for building.

### Making the build
With everything installed, you can open the root of the source directory in Visual Studio Code or just open a Command or Powershell prompt at the root of the source.

The first thing to do, with a fresh installation is to build the macros for the project.  The ORCA assembler works best if it is setup to have all the macros used for each file, pre-parsed into a single file, using the **macgen** tool.

* If using Visual Studio Code, select the "build macros" task from **Run Tasks...** in the **Terminal** menu.
* If using make from the command line, type `make build_macros`

This will run `macgen` over all the source files.  This only needs to be done once, unless new macros are used in a source file.  I probably could have including this in the normal build process, but macros don't need to be generated every time a source file changes, and I didn't want to slow down the build process.

The second step is to build the game

* If using Visual Studio Code, select **Run Build Task...** in the **Terminal** menu.
* If using make from the command line, type `make all`

This will run the assembler over all the source files and then run the linker.
The final output will be put into the `image` subfolder.

>Note:
>The ORCA Linker requires that the file `source/app.link` is writable.  The GoldenGate VM has to change metadata values for the file, so that the ORCA linker knows what type of GS/OS file it is.  If you are having linker errors, please check to see that this file is not read-only.

Once the game is built, you can transfer the updated application to a disk image.

* If using Visual Studio Code, select the "transfer" task from **Run Tasks...** int the **Terminal** menu.
* If using make from the command line, type `make transfer`

This will transfer the application, as well as the data files to the disk image.

### Cyrene

Cyrene is a profiler application, made by the wonderful people at Brutal Deluxe.  This is a Windows application, that attaches to a modified version of KEGS, and allows for getting profile snapshots from a running application.  I used this extensively, when attempting to speed up the game.
Cyrene is expecting the application to be built with Merlin32, but I was able to write a Powershell script, that will take the ORCA symbol file and write it out as a hacked up Merlin32 format, that is good enough for Cyrene to use.  The Powershell script is `orca-to-merlin-symbols.ps1` and can be run through the `convert symbols` VSCode task.  It will convert the ORCA symbol file for the game, `./debug/app.map` and will output `./debug/sinistar.gs_symbols.txt`.  Loading this into Cyrene before attaching to the modified KEGS emulator, running the game, will give enough context to the capture.

# Special Thanks

I have to give a hearty thank you to the Apple II and retro programming community and the very special people in it.

* Byte Works, Mike Westerfield and all the maintainers of the ORCA/M environment.
* Kelvin Sherlock, for the amazing Golden Gate Virtual Machine, that made it possible for me to develop with ORCA/M, just like the old days.
* Antoine Vignau, Olivier Zardini and Brutal Deluxe for all of the games, tools, documentation and code over these many years.
* SynaMax for the original Sinistar source code clean up, annotation and insights into the gameplay.
* Einar Saukas for the ZX0 compression algorithm https://github.com/einar-saukas/ZX0
* Emmanuel Marty for the Salvador ZX0 Decompressor https://github.com/emmanuel-marty/salvador
