# Run MAME to play the game
# Expects a -mame [path to mame], defaults to \bin\mame
# Expects -bootdrive [path to boot drive image], defaults to apple2_imgs\devboot.2mg
# -gameio joy
# -sl2 snesmax
# Can change to -flop3 to use image as a floppy, to test the speed of reading from that device.

param (
	[Alias("mame")]
	[string] $MamePath = "\bin\mame",
	[Alias("bootdrive")]
	[string] $BootDrivePath = "apple2_imgs\devboot.2mg"
)

$cwd = pwd
& pushd $MamePath
& .\mame -w -skip_gameinfo -screen0 \\.\DISPLAY2 apple2gs -gameio joy -ramsize 4M -sl7 cffa2 -hard1 "$BootDrivePath" -hard2 "$cwd\image\sinistargs.2mg"
& popd

