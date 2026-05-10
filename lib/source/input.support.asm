; ------------------------------------------------------------------------------
; Keyboard/Mouse functions
;
                            copy lib/source/debug.definitions.asm
                            copy 13/Ainclude/E16.Event
                            copy 13/Ainclude/E16.Memory
                            copy 13/Ainclude/E16.ADB
                            copy lib/source/system.ids.asm
                            copy lib/source/input.constants.asm

                            mcopy generated/input.support.macros

;use_adb_input               gequ 1

; -----------------------------------------------------------------------------
inputlib_data               data seg_slib

;input_event~record          anop
;input_event~what            ds    2
;input_event~message         ds    4
;input_event~when            ds    4
;input_event~where           ds    4
;input_event~modifiers       ds    2

                            aif C:use_adb_input=0,.skip
input~adb_keyboard_address  dc i2'0'
input~adb_mouse_address     dc i2'0'
input~adb_keyboard_waiting_for_callback dc i2'0'
input~adb_keyboard_data_ready dc i2'0'
input~adb_keyboard_data_length dc i2'0'
input~adb_keyboard_data     dc i2'0,0'            ; currently padded, so we can do some overwriting.

; Keydown states, for the ADB keys.  The index is the ADB keycode, 0 = up, $80 = down
input~adb_keystates         ds 128
.skip

; This is the last key down event, along with the state of the modifiers, for the last key
; These are both in 'soft-switch' format
; A note about values, and state tracking.  The lib attempts to track the up/down state of keys, as it is very
; handy to be able to use a key as a 'button', rather than a momentary switch. However, we can only
; track one, non-modifier key at a time, at least with what have easily available.
; Pressing two or more non-modifier keys, will just return the last key pressed.
; The last_key_pressed, also has to be the one that is released, to set the 'released' flag.
; Overall, one you press another key, previous keys, might as well be released, as there is no way to track their state.
input~last_key_down             dc i2'0'
input~last_key_down_modifiers   dc i2'0'
; The last non-modifier key released.  This is NOT reset, when a key is pressed.
input~last_key_up               dc i2'0'
; Context for the last_key_down.
; If 0, the key has not been released
; If 1, the key was released the last time get_key_press was called and input~last_key_up will hold its value.
; If $8001, the key was released at least 2 passes ago.
input~key_released              dc i2'0'

; This is updated every pass through get_key_press
input~last_key_modifiers        dc i2'0'

; Analog Joystick
input~analog_joystick_enabled   dc i2'0'
; The last read joystick axis state.  The X-axis is in the high-byte, the Y-axis is in the low-byte
; A value of $ffff means no joystick was detected.
input~last_analog_joystick_axis_state dc i2'$ffff'
; Add calibration values for the analog stick?

; Bit layout for the pseudo-buttons for the analog joystick axis and its digital buttons
input~joy_right             equ $0001
input~joy_left              equ $0002
input~joy_down              equ $0004
input~joy_up                equ $0008
input~joy_a                 equ $8000   ; in the same position as ssw~key_down_apple, but in the high-byte
input~joy_b                 equ $4000   ; in the same position as ssw~key_down_option, but in the high-byte

input~analog_joystick_buttons dc i2'0'

; Gamepad support (SNES MAX)
; The button state for the two controllers
input~gamepad_buttons           anop
input~gamepad1_buttons          dc i2'0'
input~gamepad2_buttons          dc i2'0'

; Buffered buttons, to help with de-bounce / phantom presses.
; What I'm seeing, is every so often, a random button appears pressed for one read cycle.
; I don't see properly pressed buttons, appear un-pressed, nor do I see the connected state flickering.
; I've tried adjusting the read timing between the latch / clock, to no avail.  Adjusting the accelerator also has no effect.
; Maybe just crap knockoff SNES controllers?
input~buffer1_gamepad1_buttons  dc i2'0'
input~buffer2_gamepad1_buttons  dc i2'0'
input~buffer1_gamepad2_buttons  dc i2'0'
input~buffer2_gamepad2_buttons  dc i2'0'

input~gamepad_connected         anop
input~gamepad1_connected        dc i2'0'
input~gamepad2_connected        dc i2'0'

input~gamepad_slot              dc i2'$0000'            ; 0 == not-in-use
input~gamepad_slot_address      dc i2'$0000'            ; This will be filled in with the slot i/o address

; Bit layout in the gamepad buttons word.  Assuming a SNES MAX board and a standard SNES controller.
input~gamepad_dpad_right    equ $0001
input~gamepad_dpad_left     equ $0002
input~gamepad_dpad_down     equ $0004
input~gamepad_dpad_up       equ $0008
input~gamepad_start         equ $0010
input~gamepad_select        equ $0020
input~gamepad_y             equ $0040
input~gamepad_b             equ $0080
input~gamepad_unused1       equ $0100
input~gamepad_unused2       equ $0200
input~gamepad_unused3       equ $0400
input~gamepad_unused4       equ $0800
input~gamepad_right_shoulder equ $1000
input~gamepad_left_shoulder equ $2000
input~gamepad_x             equ $4000
input~gamepad_a             equ $8000

                            end

; -----------------------------------------------------------------------------
input_lib_initialize        start seg_slib
                            using inputlib_data

                            debugtag 'input_lib_initialize'

                            setlocaldatabank

                            aif C:use_adb_input=0,.skip
                            stz input~adb_keyboard_waiting_for_callback
                            stz input~adb_keyboard_data_ready
                            stz input~adb_keyboard_data

; If reading the ADB keyboard directly, get some information
                            _ADBStartup

                            pushsword #3
                            pushdword #buffer
                            pushsword #readConfig
                            _ReadKeyMicroData

                            lda adb_address
                            shiftright 4
                            sta input~adb_mouse_address
                            lda adb_address
                            and #$0f
                            sta input~adb_keyboard_address

; Clear the key states
                            ldx #128-2
clear_loop                  stz input~adb_keystates,x
                            dex
                            dex
                            bpl clear_loop
.skip

                            restoredatabank

                            rtl

buffer                      anop
adb_address                 ds 1                ; Keyboard address in low nybble, mouse in the high nybble.
abd_layout_lang             ds 1                ; Keyboard layout low nybble, display language, high nybble
adb_repeat_delay_rate       ds 1                ; Keyboard repeat rate low nybble, delay, high nybble
                            end

; -----------------------------------------------------------------------------
input_lib_uninitialize      start seg_slib

                            aif C:use_adb_input=0,.skip
                            _ADBShutDown
.skip
                            rtl
                            end

; -----------------------------------------------------------------------------
; Convert a key to upper.  Yes, this is a tiny bit of code, but it is often handy
; to just have something to convert it, so as to not increase code size, so
; you don't have to use long branches
; Returns: the input key, converted to upper case
key_to_upper                start seg_slib

                            cmp #'a'
                            blt not_lower
                            cmp #'z'+1
                            bge not_lower
                            sec
                            sbc #'a'-'A'
not_lower                   rtl

                            end
; -----------------------------------------------------------------------------
; Get a key press.  This just checks if a keydown is available.
; Returns: the key or 0.  Key modifiers will be in x.
get_key_press               start seg_slib
                            using inputlib_data
                            using softswitch_definitions

                            debugtag 'get_key_press'

                            setlocaldatabank

                            ldx #0
                            shortm
                            lda >ssw~key_modifiers                  ; always get the modifiers
                            sta input~last_key_modifiers
                            tax                                     ; will only change lower 8-bits

                            lda >ssw~kbd_data
                            bpl no_key
                            sta >ssw~kbd_strobe                     ; clear the key
                            and #ssw~kbd_data~ascii_mask            ; clear the high-bit
                            sta input~last_key_down                 ; store it
                            cmp input~last_key_up
                            bne not_same
                            stz input~last_key_up                   ; clear the input~last_key_up, if the same as the down
not_same                    stz input~key_released                  ; clear our 'released' tracker
                            stz input~key_released+1                ; we are in 8-bit mode, so we have to do both bytes separately
                            stx input~last_key_down_modifiers       ; store the modifiers with they key
                            longm
                            restoredatabank
                            and #$00FF                              ; caller is expecting A to have ascii and Z flag correct.
                            rtl

; No key is 'ready' from the controller.
no_key                      longm
                            txa                                     ; get the modifiers
                            bit #ssw~modifer_key_latch
                            beq key_still_down
; Key has been released
                            lda input~key_released
                            beq first_time                          ; Set the released value yet? 0 == no
                            bmi exit                                ; Third or greater pass through?

; The second time, we set the high-bit
second_time                 lda #$8001
                            sta input~key_released
                            bra exit

; First time, we copy the down to the up, and set a flag that the key was released this pass.
first_time                  lda input~last_key_down
                            sta input~last_key_up
                            lda #1
                            sta input~key_released

exit                        anop
key_still_down              anop
                            restoredatabank
                            lda #0
                            rtl
                            end

; From the Firmware Reference Manual

; The flags for the setModes, clearModes command
adb_modes_flag_reset_sans_command   gequ %10000000              ; Very odd wording.  Seems to imply that turning this on, allows for 'reset' to happen without the command key held
adb_modes_flag_invert_shift         gequ %01000000              ; If caps-lock is down, shift will give lower case results
adb_modes_reserved                  gequ %00100000              ;
adb_modes_buffer_keyboard           gequ %00010000              ;
adb_4x_arrow_repeat_speed           gequ %00001000              ; 4x repeat speed for arrows, when control key is pressed
adb_4x_space_delete_repeat_speed    gequ %00000100              ; 4x repeat speed for space and delete, when control key is pressed
adb_disable_mouse_polling           gequ %00000010              ; disable mouse polling
adb_disable_keyboard_polling        gequ %00000001              ; disable keyboard polling

; -----------------------------------------------------------------------------
; Disable keyboard polling from the adb firmware.
; This allows us to directly read the adb keyboard without interference.
disable_adb_keyboard_polling start seg_slib
                            using inputlib_data

                            debugtag 'disable_adb_keyboard_polling'

                            setlocaldatabank

                            pushsword #1                    ; 1 byte of data
                            pushptr #command_data
                            pushsword #setModes             ;
                            _SendInfo

                            restoredatabank
                            rtl

command_data                dc i'adb_disable_keyboard_polling'
                            end

; -----------------------------------------------------------------------------
; Re-enable keyboard polling
enable_adb_keyboard_polling start seg_slib
                            using inputlib_data

                            debugtag 'disable_adb_keyboard_polling'

                            setlocaldatabank

                            pushsword #1                    ; 1 byte of data
                            pushptr #command_data
                            pushsword #clearModes           ;
                            _SendInfo

                            restoredatabank
                            rtl

command_data                dc i'adb_disable_keyboard_polling'
                            end
; -----------------------------------------------------------------------------
; This is work-in-progress.
; This gets 'register 0' data from the ADB keyboard, using the
; _AsyncADBReceive toolbox call.
; An alternate method is to use the _SRQPoll callback function.
; Both methods seem similar, the _AsyncADBReceive seems a bit more low-level
; but requires a new call to it, after getting the ADB data, the _SQRPoll
; method seems to stay active.
;
; An important note is that this requires that the firmware's own polling
; of the ADB keyboard is disabled, else this will be fighting with the firmware
; for the keystrokes. Something that the Toolbox Reference doesn't mention.
;
; See disable_adb_keyboard_polling and enable_adb_keyboard_polling
; While the firmware keyboard polling is disabled, the standard keyboard softswitch
; will not see any keys.  However, keys from this polling function can be forwarded
; back to the firmware if desired.
;
; The code is gleaned from the ADB section in the Toolbox Manual, as well as some
; helpful guidance from Sheppy's Wolf 3D slides from Kansasfest?, 2004
get_adb_key_press           start seg_slib
                            using inputlib_data
                            using softswitch_definitions

                            debugtag 'get_adb_key_press'

; If disabled, just exit
                            aif C:use_adb_input<>0,.skip
                            rtl
.skip

                            aif C:use_adb_input=0,.skip

                            setlocaldatabank

; Is data ready for us?
                            lda input~adb_keyboard_data_ready
                            beq do_request

; Yes, clear that we are waiting for a callback
                            stz input~adb_keyboard_waiting_for_callback
; Clear that data is ready
                            stz input~adb_keyboard_data_ready

                            cmp #2                                      ; Do we have something?  A 2 means yes, a 1 means we got data back, but it was empty.
                            bne do_request                              ; No, then do another request

; Handle the data
                            jsr _handle_adb_data

; See if we need to do another request.
do_request                  lda input~adb_keyboard_waiting_for_callback
                            bne already_waiting                         ; One already queued?

; No, add one
                            inc a
                            sta input~adb_keyboard_waiting_for_callback

                            lda #4
                            sta tries

try_again                   anop
                            pushdword #callback
                            lda input~adb_keyboard_address      ; Get the address in the lower bits, 0 in the register bits
                            ora #talk                           ; talk command
                            pha
                            _AsyncADBReceive
                            bcc ok
                            cmp #adbBusy
                            bne error
                            dec tries
                            bne try_again

ok                          anop
already_waiting             anop
                            restoredatabank

                            rtl
error                       anop
                            stz input~adb_keyboard_waiting_for_callback
                            bra ok

tries                       ds 2

;;;

; Handle the incoming data.  We are only expecting data from the keyboard
; The data will be in input~adb_keyboard_data_length, which will be 1 or 2
; and input~adb_keyboard_data, which will contain the keyboard data.
; The data will be two bytes, with each byte containing a key state from
; the controller.  Bits 0-6 will be the ADB keycode (not ASCII!)
; and bit 7 will be 0 if the key was pressed, and 1 if it was released.
; The byte will be 0 for NO KEY.
_handle_adb_data            anop

                            lda input~adb_keyboard_data_length
                            cmp #2
                            beq two_keys

one_key                     anop
                            shortmx
                            lda input~adb_keyboard_data
                            cmp #$80                        ; will make carry set if high bit set.
                            and #$7f
                            tax
                            lda #$00
                            ror a
                            sta input~adb_keystates,x       ; 0 = key up, $80 = key down.
                            longmx

                            lda input~adb_keyboard_data
                            and #$00ff
                            jsr send_key_to_adb

                            rts

two_keys                    anop
                            shortmx
                            lda input~adb_keyboard_data
                            cmp #$80                        ; will make carry set if high bit set.
                            and #$7f
                            tax
                            lda #$00
                            ror a
                            sta input~adb_keystates,x       ; 0 = key up, $80 = key down.

                            lda input~adb_keyboard_data+1
                            cmp #$80                        ; will make carry set if high bit set.
                            and #$7f
                            tax
                            lda #$00
                            ror a
                            sta input~adb_keystates,x       ; 0 = key up, $80 = key down.
                            longmx

                            lda input~adb_keyboard_data
                            and #$00ff
                            jsr send_key_to_adb

                            lda input~adb_keyboard_data+1
                            and #$00ff
                            jsr send_key_to_adb

                            rts

;; Send the keycode in A to the ADB controller.
send_key_to_adb             anop
                            sta key_send_command_data
                            pushsword #1                    ; 1 byte of data
                            pushptr #key_send_command_data
                            pushsword #keyCode
                            _SendInfo
                            rts

key_send_command_data       ds 2

;;
; The ADB receive callback
; Note this is called with a and i off.
; This will always get called, even if there is no available data.
; I am assuming that this is just getting called after a PollDevice
; and the Firmware Manual says that will timeout after 10ms.
; This means that we have to check for both bytes being $FFFF
                            longa off
                            longi off

callback                    anop
; At this point, there is the a pointer to a buffer at 4,s
                            tsc
                            phd
                            tcd
                            lda [4]                                 ; Note, I don't seem to every have this be anything other than 1.
                            bne has_data

                            lda #1                                  ; 1 means there was nothing
                            sta >input~adb_keyboard_data_ready
                            pld
                            clc
                            rtl

has_data                    anop
; It's a bit easier to do this in 16-bit more
                            longmx
; and it will be easier if the databank is set local
                            setlocaldatabank

; We are going to assume that there is always two bytes of data, which is ADB Register 0 for the Keyboard
; The data is also formatted so that if the byte is $FF, the key is 'invalid', and if there is just a single
; key press/release, the valid data is in the high byte.
; The fact that the byte ordering seems to be high to low, might be explained by a comment in the Firmware
; Reference Manual, for the PollDevice command, "The microcontroller then returns the data bytes to the
; system in the opposite order that they were received from the ADB."
; Also, there is a special key press of $7f7f, that is the Reset key.
;
; Note that it is possible that both bytes will be $FFFF.  Because of this, I don't see a way
; to detect the 'release' of the reset key.  Perhaps the SRQ callback handles this better?

                            ldy #1
                            lda [4],y
                            tay
                            cmp #$7f7f
                            beq handle_reset
; I did not see any of these possibilities
;                            cmp #$ff7f
;                            beq handle_reset
;                            cmp #$7fff
;                            beq handle_reset

                            ldx #0
                            and #$00FF
                            cmp #$00FF
                            beq no_key0

                            sta input~adb_keyboard_data,x
                            inx

no_key0                     tya
                            xba
                            and #$00FF
                            cmp #$00FF
                            beq no_key1

                            sta input~adb_keyboard_data,x       ; this will go off the edge!  Make sure input~adb_keyboard_data is more than 2 bytes!
                            inx

no_key1                     lda #1                              ; assume no keys
                            cpx #0
                            beq was_empty

                            stx input~adb_keyboard_data_length
                            lda [4]
                            and #$00ff
                            xba
                            ora input~adb_keyboard_data_length
                            sta input~adb_keyboard_data_length
                            lda #1

                            inc a                              ; signal there was something

was_empty                   sta input~adb_keyboard_data_ready
                            restoredatabank
                            shortmx                             ; required?

                            pld
                            clc
                            rtl

                            longa on
                            longi on

; This needs to actually handle the reset key by seeing if it is a 'release'
; with the command and control down
handle_reset                sta input~adb_keyboard_data

                            lda [4]
                            and #$00ff
                            sta input~adb_keyboard_data_length
                            lda #2
                            sta input~adb_keyboard_data_ready
                            restoredatabank
                            shortmx                         ; required?

                            pld
                            clc
                            rtl

                            longa on
                            longi on
.skip
                            end

; -----------------------------------------------------------------------------
; Read all the buttons from a SNES MAX board.
; The SNES Max board reads the buttons one-by-one, though it reads the same button on each controller
; at the same time.
; The method is to reset the latch, then read a button, then pulse the clock, which will setup the
; next button to read.
;
; Note this reads 16 buttons per controller, but the SNES controller only supports 12
; Could exit earlier, but there is a final 'plugged in' status byte we want to read.
snes_max_read_controller    start seg_slib
                            using inputlib_data

                            begin_locals
wController1                decl word
wController2                decl word
wControllerState            decl word
work_area_size              end_locals

                            sub ,work_area_size

; SNES Max controller I/O
; Slot based, add slot * 16 to the values or use indexing
snes_max~latch              equ $c080               ; Write any value to sets the latch pulse.  Read to get the current button state.  Bit 7 = controller 1, Bit 6 = Controller 2
snes_max~clock              equ $c081               ; sets the clock pulse, to move to the next button.  Write any value.

; Reference implementation, from the sample code.  Note timings are from the source, and don't include the +1 overhead from unaligned DP access
                            ago .skip

                            phb
                            shortm
                            lda #0
                            pha
                            plb

                            sta |snes_max~latch      ; 4: Set Latch pulse for 1 cycle

                            ldx #0                  ; 2
loop1                       ldy #8                  ; 2 <---.   (((29x8)-1+9)x2)-1+19 = 498 cycles
loop2                       lda |snes_max~latch     ; 4: Read a button.  bit 7, Controller 1, bit 6, controller 2
                            rol a                   ; 2: controller 1 button state to carry
                            rol <wController1,x     ; 6: move bit into result
                            rol a                   ; 2
                            rol <wController1,x     ; 6
                            sta |snes_max~clock     ; 4; Next button
                            dey                     ; 2
                            bne loop2               ; 3/2
                            inx                     ; 2
                            cpx #2                  ; 2
                            bne loop1               ; 3/2
; After reading the buttons, the next byte is the plugged in status
                            lda |snes_max~latch      ; 4: Read status.  bit 7, Controller 1, bit 6, controller 2
                            sta <wControllerStatus
.skip

; Unrolled loop
; Note, I originally was going to use sta address,y and lda address,y access so that I didn't
; have to use self-modifying code, but I changed, because of remembering the issue with 'false reads'
; with indexed modes, that can cause issues with latch-style i/o, especially ones where access 'advances' something.
; See the Apple IIgs Hardware Reference manual, where it mentions this when accessing Sound DOC registers and the 1-bit sound toggle.
; Admittedly, the example code in the Hardware Reference manual, about I/O Addressing, uses indexed reads.
; However the sample code for the SNES Max uses patched code, to read the address without indexed addressing.

                            lda >input~gamepad_slot_address
                            jeq exit

                            phb
                            shortm
; Set the data bank to 0
                            lda #0
                            pha
                            plb

patch1                      sta |snes_max~latch        ; Set Latch pulse for 1 cycle
; Delay a bit.  This is here because the SNESMAX emulation in MAME needs
; at least 7 nops of delay if the CPU is set to 16Mhz, else the first button will
; appear as stuck on.  8Mhz required fewer nops, but I decided to up the total nops to 8,
; just in case.
; On-real-hardware, with an 8Mhz ZIP, I didn't need these nops, though at the end
; I did need a nop before the last read of the latch for the connected-state bits.
; I could make this delay adjustable, but really, the controller only needs to be
; read once a frame, so this isn't too bad.
                            nop
                            nop
                            nop
                            nop
                            nop
                            nop
                            nop
                            nop
; Read the first 8 buttons
patch2                      snes_read_controller_button 8,<wController1,<wController2
; Then the next 8
                            snes_read_controller_button 8,<wController1+1,<wController2+1

; Delay a bit since we just strobed the clock
                            nop

patch3                      lda |snes_max~latch
                            longm

; Set the data bank to local.
                            phk
                            plb

                            tay                             ; save this
                            and #$0080                      ; controller 1 plugged in state
                            eor #$0080                      ; on means unplugged, but I'd rather have it the other way
                            sta input~gamepad1_connected
                            tya
                            and #$0040                      ; controller 2 plugged in state
                            eor #$0040                      ; on means unplugged, but I'd rather have it the other way
                            sta input~gamepad2_connected

; Swap the last buffer button states.  This is part of the de-bounce / phantom press mitigation.  See variable declaration above.
                            lda input~buffer2_gamepad1_buttons
                            sta input~buffer1_gamepad1_buttons
                            lda input~buffer2_gamepad2_buttons
                            sta input~buffer1_gamepad2_buttons

; Put the buttons into their final location.
                            lda <wController1
                            eor #$ffff                      ; on means up, but I'd rather have it the other way
; Put in the second buffer, and then 'and' with the previous one.  This is part of the de-bounce / phantom press mitigation.
                            sta input~buffer2_gamepad1_buttons
                            and input~buffer1_gamepad1_buttons
; The result will be that the button will only appear on, if it was on for two consecutive reads.
                            sta input~gamepad1_buttons

                            lda <wController2
                            eor #$ffff                      ; on means up, but I'd rather have it the other way
                            sta input~buffer2_gamepad2_buttons
                            and input~buffer1_gamepad2_buttons
                            sta input~gamepad2_buttons

                            restoredatabank

exit                        ret

; Patch the read function with the slot address

snes_max_patch_slot         entry
                            setlocaldatabank

                            sta input~gamepad_slot
                            cmp #1
                            blt disabled
                            cmp #8
                            bge disabled

                            shiftleft 4

; I hope the user knows where it is, because there is no way to verify!
                            clc
                            adc #snes_max~latch
                            sta input~gamepad_slot_address

                            sta patch1+1
                            sta patch3+1

; This is the size of the read entry, as long as we are using ZP values for temporary storage!
button_read_entry_nops      equ 1
button_read_entry_size      equ 12+button_read_entry_nops

                            ldx #0
patch_loop                  lda input~gamepad_slot_address
                            sta patch2+1+button_read_entry_nops,x
                            inc a                           ; the clock advance address
                            sta patch2+10+button_read_entry_nops,x
                            txa
                            clc
                            adc #button_read_entry_size    ; bytes in each button read entry
                            tax
                            cpx #button_read_entry_size*16
                            bne patch_loop

                            restoredatabank
                            rtl
disabled                    stz input~gamepad_slot_address
                            restoredatabank
                            rtl
                            end

; -----------------------------------------------------------------------------
; Read the analog joysick
; This is a bit on the slow side, on purpose, as it will read the stick
; at 1Mhz, so the timing will be consistent.  Even trying to read it at whatever
; accelerated speed the user might be running at, doesn't really help, as
; that does not affect the 555 timer speed.
;
; The inner loop, with the trick incrementing is based on code
; from Brutal Deluxe.
; Returns:
; a-reg: y-axis in low-byte, x-axis in high-byte
; If both are $FF, then the joystick loop timed out, and there is most likely,
; no joystick attached
joy_1_read                  start seg_slib
                            using inputlib_data
                            using softswitch_definitions

                            phd
                            pushsword #0                ; some temp space
; Set DP to the SSW bank, for faster reading, though we are really more concerned about
; consistent timing, than speed
                            lda #ssw~bank
                            tcd

                            sei                         ; shut off interrupts, so we don't get disturbed.  We want to have this off for the least amount of time possible
; Set to 1mhz.  There are other SSW values on either side of this byte, so I'm doing it in short-mode to be 'safe'.
                            shortm
                            lda #ssw~speed_reg~fast
                            trb <ssw~speed_reg
                            longm

                            lda <ssw~paddle_trigger     ; note, will read c071 too!  Should be harmless, this is in the interrupt ROM address area.
; Set the maximum loop count.  Doing this after the paddle trigger, just to give the HW some time to have the data ready.
; Cycles are are in the comments, however, everytime we read the paddle, the FPI is going to have to sync to the Mega II.
; Might not have an effect, since the entire system is in slow-mode while reading.
default_joy_loop_count      equ 144
                            ldx #default_joy_loop_count ; (3)

; One pass through (except the last) is 26 cycles
; The HW manual says that the timer will expire in 'about 3 milliseconds'
; 3072 cycles at 1.024Mhz., is 3ms.
; The max loop count is purposely more than is needed (144 * 26) = 3744, so that if a joystick is not connected
; we will be sure to get a 'bad' value.  However, it will be best to warn the user that no joystick is connected,
; as this will be wasting lots of time polling.

read_loop                   lda <ssw~paddle_0           ; (4) this will read paddle 0 in the low-byte, and paddle 1 in the high-byte
                            and #$8080                  ; (3) mask relevant bits
                            beq read_done               ; (2-3)
; Do a trick with the adding, where we shift out paddle 1's bit, into the carry, and paddle 0's bit, into the low-bit, of paddle 1.
; We can then just do an adc, and we will increment the low and high byte by one, according to the high-bits.
; This does mean that paddle 0's count is in the high-byte and paddle 1 is in the low byte.
                            asl a                       ; (2)
                            adc 1,s                     ; (5)
                            sta 1,s                     ; (5)
                            dex                         ; (2)
                            bne read_loop               ; (2-3)
; If we get here, then we probably don't have a joystick hooked up, or it is calibrated incorrectly
                            lda #$ffff
                            sta 1,s

read_done                   anop
                            shortm
                            lda #ssw~speed_reg~fast
                            tsb <ssw~speed_reg
                            longm

                            cli
                            pla                         ; get the result into A
                            sta >input~last_analog_joystick_axis_state
                            pld
                            rtl
                            end

; -----------------------------------------------------------------------------
; This will convert the last-read joystick state into pseudo-buttons
; for the stick, as well as button state for the two digital buttons.
; This uses the last joystick axis read state.
; This will also use the last key modifier state, for the digital buttons
; i.e. open-apple (switch 0) and option (switch 1).  Be sure to read the keyboard
; before calling this function.
; Returns:
; a-reg     - joystick button state.  See button bit values in data section above
convert_joy_state_to_buttons start seg_slib
                            using inputlib_data
                            using softswitch_definitions

                            setlocaldatabank

analog_joystick~range_low   equ 38
analog_joystick~range_high  equ 80

                            ldx #input~joy_left
                            lda input~last_analog_joystick_axis_state
                            xba
                            and #$00ff
                            cmp #analog_joystick~range_low
                            blt found_x
                            ldx #0
                            cmp #analog_joystick~range_high
                            blt found_x
                            ldx #input~joy_right
found_x                     stx input~analog_joystick_buttons

                            ldx #input~joy_up
                            lda input~last_analog_joystick_axis_state
                            and #$00ff
                            cmp #analog_joystick~range_low
                            blt found_y
                            ldx #0
                            cmp #analog_joystick~range_high
                            blt found_y
                            ldx #input~joy_down
found_y                     txa
                            tsb input~analog_joystick_buttons

; Using the last key modifiers as our button state.
                            lda input~last_key_modifiers
                            xba
                            and #input~joy_a+input~joy_b
                            ora input~analog_joystick_buttons
                            sta input~analog_joystick_buttons           ; save, but leave button values in a-reg on exit

; If directly reading the button state is desired, enable this code
                            ago .skip
; This code assumes input~joy_a is the high-bit in the word
                            lda >ssw~button_0
                            and #$8080
                            xba                                         ; Get switch 0 in the correct position
                            bit #$0080
                            beq switch_1_off
                            and #$8000
                            ora #input~joy_b
switch_1_off                ora input~analog_joystick_buttons
                            sta input~analog_joystick_buttons
.skip

                            restoredatabank
                            rtl
                            end
