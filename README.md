# Sinistar.GS
A clone / port of the classic 80's arcade game, Sinistar, to the Apple IIgs.

## System Requirements
**Sinistar.GS** requires around **1MB** of free ram, so realistically your Apple IIgs needs at least 2MB of physical ram.  Even then, if you have a lot of desk-accessories and such on your boot drive, you may need to cold-start your machine and hold-down the control and shift keys, to force GS/OS to not load Inits and Desk Accessories.  It will show you in the boot box if it is doing this by printing "No Inits/DAs".

**Sinistar.GS** will run reasonably well on a IIgs, running at the stock speed of 2.8Mhz, however an accelerator card is highly recommended.

#### A note about performance
If you are running at stock speed, it is recommended that you turn on the **FPS Limiter** option in the Configuration screen.  See the [Configuration](#configuration) section for more information on this option.

## Controls

Sinistar.GS supports input from the keyboard, analog joystick or a SNES MAX controller card.

### Keyboard
* **Turn** - I,J,K.L or the keypad
* **Thrust** - Shift or Option
* **Fire** - Open-Apple / Command
* **Sinibomb** - Space
* **Start a game** - 1 or 2
* **Quit** - Q will quit to desktop in the front end or quit the active game, if playing.
* **Pause** - P will pause and un-pause the game.
* **Configuration** - C will go to the configuration, when in the front-end.

### SNES MAX

The SNES MAX card defaults to off, set its slot number in the Configuration screen.

* **Turn/Thrust** - D-Pad
* **Fire** - Y
* **Sinibomb** - B
* **Pause** - Select.
* **Start a game** - Start

### Analog Joystick

The Analog Joystick support is off by default, turn it on in the Configuration screen.

* **Turn/Thrust** - Joystick
* **Fire** - Button 1
* **Sinibomb** - Button 2

#### A note about the Analog Joystick
Reading the analog joystick is slow because of the fixed rate of the hardware timers in all Apple II systems.  It is recommended that the Analog Joystick is only used on an accelerated GS. If you are not using the Analog Joystick, make sure it is disabled in the [Configuration](#configuration), else it will be attempting to read the joystick, even if it is not in use / plugged in and will slow the game down.

### Input Troubleshooting
* If you are having trouble using the keyboard, where the thrust and fire don't seem to work, make sure you have the Analog Joystick and SNES MAX turned off in the [Configuration](#configuration) screen.  Only one type of input is supported at a time, in-game.

# Configuration
Pressing **C** in the front-end, will go to the Configuration screen.  The configuration allows for adjusting many different aspects of the game, including setting cheat options and enabling debugging options.

* **Unlimited Ships** and **Unlimited Sinibombs** give you unlimited amounts of those things.  Note that with Unlimited Ships, the game never ends, so you will have to press **Q** to quit back to the front-end.
* **Difficulty Level**
	* This changes the five options below it to provide an **easy** game, which is the default and a **hard** game, which is more in line with the starting conditions of the original game, though the extra ship scoring is still easier than the original game.
	* The **Difficulty Adjustment** is a magic value that controls the starting conditions of the difficulty progression, and how that ramps up over time.  As the difficulty tables progress, they adjust various population values such as the Warrior count, which usually increases, and the Planetoid count, which usually decreases.  The difficulty tables also adjust the aggression level of the Warriors, mainly controlling how often they shoot.  Setting this to a lower value, starts the difficulty processing at a lower starting value.  However, the original game defaulted to 5, and it is already hard, so there is not much room to adjust this lower.
	* The **Crystal Attraction** option will cause nearby crystals to get attracted to the player.  This can be set to **off**, **low** or **high**.  If set to low, the crystal has to be within about 10 pixels from the center of the ship to get attracted, so pretty close.  On high, the distance is 20 pixels.  This can greatly help with collecting crystals.  This is an additional option that is not in the original game.
	* The **Population Difficulty** option is a tweak to the starting population of Warriors on each level, adjusting them downward, so there are fewer Warriors to start with. This also makes adjustment to slow down the timer that adds additional Warriors to the level.  This was taken (lovingly) from a YouTube video made by SynaMax, https://youtu.be/HnfcAudPPS4?si=UINAaxX3hjbroZ1I, on how to patch the original game to make it easier.  If this option is set to **easy** the adjusted tables are used, if it is set to **hard** the original tables are used.
* **Sound Disabled**, disables all sound, and **Attract Sound Disabled**, just prevents the Sinistar taunt in the front-end.
* **FPS PIP**, will show a small row of pixels in the upper right of the game play screen, showing a general frames-per-second level.  If the pip is yellow, then the game is running at 60fps, if it is blue, it is running at 30fps, and red, it is 20fps or under.
* **FPS Limiter**, will limit the FPS to 30, regardless of how fast the game can run.  This is useful when running at a stock speed of 2.8Mhz.  At that speed, the game can occasionally hit 60fps, if there isn't much on the screen, but when more objects are on screen, it will drop to 30fps or less and it can flip-flop between 30 and 60fps.  Because the movement rate is coded for 60fps, when the game is running at 30fps, the game compensates for the slowdown, by doubling the movement rate, so the effective movement rate is the same. However quickly flipping between the two, causes noticeable jitter.
* **SNES MAX Slot**, will allow you to specify which slot the SNES MAX card is in, or disable the card.
* **Analog Joystick**, will enable or disable the Analog Joystick usage.  Do not leave this on if you are not using an Analog Joystick and be aware that it is not recommended at stock speed.
* **Workers Disabled** and **Warriors Disabled**, turns off those types of enemies.  This is mainly for debugging and the state of these options is not saved to the configuration file.
* **Reset High Scores**, will reset the `high.scores` file.
* **Debug Mode**, will enable extended debugging capabilities.  See Debug Mode for more information.

#### Other Game Play Adjustments
Other than the adjustments you can make through the configuration.  I also tweaked the firing rate of the Warriors, so after each shot, their existing shot-inhibitor is reset.  In the original game, it was only reset when the Warrior transitioned on-screen.  Always resetting the inhibitor, helps prevent Warriors from sending streams of shots at you. This was especially prevalent, when there is more than one Warrior on screen, as the secondary warriors have a different logic path, which allows them to shoot more often.  The inhibition is still only about 1/2 second to a second, depending on the aggression level, so they will still shoot fairly quickly, but it feels a bit more fair than a wall of shots coming at you.

#### Difficulty
Sinistar is a notoriously difficult game, and the options in the configuration were added to make the game less frustrating to play. However, it may lean toward being too easy with the default settings.  Rather than going completely to the **hard** difficulty settings, try changing the **Population Difficulty** to **hard**, which will introduce more Warriors, at earlier levels.  Turning the **Crystal Attraction** to **low** or **off** is also a good way to increase the difficulty, without getting too frustrated.

#### A note about the configuration and high score files
* Both the configuration and high scores are written out to disk, so that they can be restored on startup of the game.  If you wish to reset these, you can simply delete the two files, `config` and `high.scores` that are in the same directory as the Sinistar.GS application.
* If the configuration or high scores don't seem to be saving across application runs.  Make sure the disk is not write protected and if you are running in an emulator, make sure the image file you are using, is not read-only on the native side.

# Emulators
Sinistar.GS works great in the IIgs emulators I have used on the PC.

**MAME**, works great and I extensively used this during development to test and debug the game.  I primarily configured it to emulate a ROM3 IIgs, with 4MB of RAM.  Setting its Machine Configuration to emulated a ZipGS at 8Mhz makes the game run super-smooth.  All input worked great, including emulating the analog joystick with a twin stick Logitech gamepad, and MAME also supports emulating a SNES MAX card, which I also mapped to a gamepad easily.

**Crossrunner**, worked well, running smoothly at 7Mhz and it gave a better sense of how the game performs at 2.8Mhz than MAME did.  However, I did have issues with Crossrunner and my PC number pad.  It doesn't seem to want to map the keys to what the IIgs number pad keys should give back.  Numlock on or off, gave differing keys, but that were not number pad keys, and this even persisted in GS/OS. Typing into a text editor, showed various alpha characters and not numbers, so it seems to not like my keyboard, maybe other users will have better luck.  Using the I,J,K,L keys to rotate the ship works well.  I also didn't get Crossrunner to work with my Logitech joystick to emulate the analog joystick.

**KEGS**, worked well.  The only issue you might have with that emulator, is if you want to use the number pad for ship rotation. If so, you will have to go into the KEGS configuration and change the **Joystick** option to **Mouse Joystick**, rather than **Keypad Joystick**.  KEGS defaults to emulating the analog joystick with the native number pad, and does not present those keys to the IIgs system if that is on. You can also leave KEGS emulating the analog joystick with the number pad and turn on Sinistar.GS's usage of the analog joystick and that works great too.  Using KEGS emulation of the analog joystick with the mouse works nicely as well.  Be sure to have KEGS emulator a faster processor speed if you are using the analog joystick option in-game.

# Debug Mode
When Debug Mode is turned on in the configuration, there are several keys you can press that will affect the game.
* **{** and **}** will lower or add an extra 'tick' delay to game, slowing down the frame rate.  Be careful, there is no visual indication that the frame rate is being adjusted, other than the game being slow.
* **Control-V** will toggle showing where the screen is updating.  The two rectangles will flash on screen for each object.  The white rectangle is the drawing rectangle, and the red rectangle is the merged draw/erase rectangle that is used to update the screen. There is a bit of a pause between the rectangle drawing, and you can slow it down further with the FPS adjustment keys.
* **Control-D** will toggle showing the collision rectangles only.  This may leave streaks, bits of rectangle on the screen, as it doesn't completely erase itself like the update rects do.
* **T** can be pressed at any time to toggle into text mode, and view various debug panels.

The first time showing the Debug Panels, a help screen will be displayed, showing the keys that activate / deactivate the panels.  Press **/ or ?** to toggle the help panel.

The Debug panels are setup so that some can be shown at the same time, such as the Player Info and the Entities list.  Pressing the activation key again, will toggle the panel off, if you end up getting too many stacked panels on the screen.
Some panels, like the Gameplay Difficulty or the Options, are exclusive and hide the other panels.

#### Top Line
The top line always shows the current FPS, the last key pressed, the current key held down, the key modifiers state, and V for VBL tracking on, and S that Shadow memory is being used.  As of this writing, I'm not actually obeying the VBL flag, and just trying to run as fast as possible, so there is some tearing.  Also, the game won't run without being able to allocate the BANK 1 screen shadow memory, so S will always be shown.

#### Gameplay Difficulty
This will show the **Difficulty Progression** that the game uses to control the population of some entities in the game, as well as the Warrior aggression.  The Target values are what is being progressed, using fixed point 8.8 numbers.  The values are the maximum number of entities allowed at any moment.  As the game goes on, some population values go up, like the Warriors, and some go down, like the Planetoid types.

#### Game Options
This allows for tweaking some values that are normally set in the Configuration.  The changes will not be saved.  You can also see the state of the SNES MAX controller, if setup as well as some stats on frame rate.

#### Memory
This will show handles allocated from the OS, as well as allocations in the internal small-block pools.

#### Misc System Values
Mainly just a place where the current palette setup is displayed.

#### Player Info
This will show the location of the player ship, its enclosing rectangle, its sprite reference, its speed and the screen speed, which is tied to the player movement.
It will also show a list of 'responders' that are getting 'called' by the player.  Responders are either Workers or Warriors, and each caller object, has a quota of responders.  The list will contain the reponder type, its id, its location and its mission.

#### Entity List
This will display a list, showing each type of entity separately, with a little bit of information about the entity.
Pressing 0 - 9, will switch between the types.
* 0 - Planetoids
* 1 - Player
* 2 - Sinistar
* 3 - Bomb
* 4 - Crystal
* 5 - Worker
* 6 - Warrior
* 7 - Player Shot
* 8 - Warrior Shot
* 9 - Explosion

#### Collision List
These are all the on-screen entities that can collide with each other.  Collisions either do not happen, or are faked, when entities are off-screen.






