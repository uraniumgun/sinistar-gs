; ------------------------------------------------------------------------------
; Main entry point for the application
; This file must be first in the app.link, linker file.
; ------------------------------------------------------------------------------
                            copy lib/source/debug.definitions.asm
                            copy 13/Ainclude/E16.Event
                            copy 13/Ainclude/E16.Memory
                            copy lib/source/system.ids.asm
                            copy lib/source/object.definitions.asm
                            copy lib/source/string.definitions.asm
                            copy lib/source/container.definitions.asm
                            copy lib/source/fixed.buffer.pool.definitions.asm
                            copy lib/source/file.definitions.asm
                            copy lib/source/datalib.constants.asm
                            copy lib/source/datalib.definitions.asm
                            copy lib/source/shape.definitions.asm
                            copy lib/source/grlib.definitions.asm
                            copy lib/source/framelib.definitions.asm
                            copy lib/source/input.constants.asm
                            copy lib/source/grlib.entity.sort.definitions.asm

                            copy source/gameplay.constants.asm

                            mcopy generated/app.main.macros

                            longa on
                            longi on

; Note there are some references to debug~use_min_toolbox, where we want
; little to no toolbox usage.  This is enabled and probably can't be disabled
; at this point in development.  Same with the fake_screen usage.

; -----------------------------------------------------------------------------
main                        start
                            using applib_data
                            using grlib_global_data

                            aif  C:debug~use_fake_screen=0,.skip
                            mnote 'Fake Screen:Enabled'
.skip
                            longmx

; Set the banks = to each other for short addressing
; We will assume this for most of the front-end code, though in the
; library code, long addressing will be used as well as stack/zp based
; local values.

                            phk
                            plb

; GS/OS gives us 4k of bank 0, for use as our ZP and stack, which should be plenty
; The DP register will be pointing to the bottom, the stack pointer will be pointing to
; the top.  We have to make sure that the stack never collides with what we are using
; as fixed ZP locations.  There is no hardware check for collisions. :(

                            tdc
                            sta >applib~dp_base
                            sta >applib~shared_dp
; Give a page to the grlib, it uses a lot.
                            clc
                            adc #$100
                            sta >grlib~dp

                            jsl startup
                            bcs stopit

                            jsl execute

stopit                      jsl shutdown

                            _QuitGS quit_params

quit_params                 dc    i2'$0002'
                            dc    i4'0'
                            dc    i2'0'

                            end
; -------------------------------------------------------------------
; Startup any tools needed, as well as initializing any libs.
; This will try and get $012000 as our off-screen buffer, so we can
; use memory-shadowing functions to do quicker copies.
; However, we are supporting some debug equates to allow us to run
; where we assume that we will be running without
; drawing to the screen.
; -------------------------------------------------------------------
startup                     start seg_app
                            using appdata
                            using applib_data
                            using grlib_global_data

pTemp                       equ 0

; Startup some things early, to handle errors
                            jsl textlib_initilize
                            jsl system_error_initialize
; Set a string to show when OoM.  Note, this string is not copied, it has to stay around
                            pushptr #str_required_memory
                            jsl system_error_set_required_memory_string

                            setlocaldatabank

                            _TLStartup            ; Tool Locator needs to be first

; and the Memory Manager

                            pushsword #0
                            _MMStartup
                            tay                 ; Save any error
                            pla
                            sta >applib~MM_ID
                            ldx #0
                            jsr check_for_error
                            jcs error_exit

; And to Misc. Tools too

                            _MTStartup

; Compact memory.
; We will try and allocate a giant block, we know will fail.
; This will trigger compaction internally.
                            pushdword #0                                        ; result
                            pushdword #$8fffff                                  ; 8mb
                            pushsword >applib~MM_ID
                            pushsword #attrLocked+attrFixed                     ;locked, fixed
                            pushdword #0                                        ; no fixed address
                            _NewHandle
                            _DisposeHandle
; Then do an explicit compaction
                            _CompactMem

                            jsl math~initialize
; Initialize this early, as it can be used when debugging (scrambling memory)
                            lda #$9d83
                            jsl math~rnd_initialize

                            jsl input_lib_initialize
; Initialize the library.  This does not initialize graphics/buffers
                            jsl grlib_initialize

; Skip if debug~use_fake_screen
                            aif  C:debug~use_fake_screen<>0,.skip

; Because I'm worried that I won't get the specific memory, try and allocate the 'shadow' screen memory right away.
                            pushdword #0
                            pushdword #$8000
                            pushsword >applib~MM_ID
                            pushsword #attrLocked+attrFixed+attrAddr+attrBank       ;locked, fixed, fixed address
                            pushdword #$00012000
                            _NewHandle
                            pla
                            sta >appdata~altscr_handle
                            pla
                            sta >appdata~altscr_handle+2
                            bcc got_shadowed_memory

                            jsr failed_to_get_shadowed_memory
                            brl error_exit
.skip

got_shadowed_memory         anop
                            aif C:debug~os_memory_tracking=0,.no_tracking
                            tax
                            lda >appdata~altscr_handle
                            jsl track_os_allocation
.no_tracking

                            aif  C:debug~use_min_toolbox<>0,.skip

; Get some zp for Quickdraw and the Event Manager

                            pushdword #0
                            pushdword #$400                                         ; $300 for QD, $100 for EM
                            pushsword >applib~MM_ID
                            pushsword #attrLocked+attrFixed+attrBank+attrPage       ;locked, fixed, fixed bank, aligned
                            pushdword #0
                            _NewHandle
                            tay                 ; Save any error
                            pla
                            sta >appdata~tool_zp_handle
                            sta <pTemp            ;hold for a sec
                            pla
                            sta >appdata~tool_zp_handle+2
                            sta <pTemp+2
                            ldx #2
                            jsr check_for_error
                            jcs error_exit

                            aif C:debug~os_memory_tracking=0,.no_tracking
                            lda >appdata~tool_zp_handle+2
                            tax
                            lda >appdata~tool_zp_handle
                            jsl track_os_allocation
.no_tracking

                            lda   [<pTemp]          ;get the dereferenced pointer, just need the low word.
                            sta   >appdata~tool_zp
.skip

; Install the heartbeat task, so we can get timing
                            jsl applib_install_heartbeat

; Start QuickDraw.  Not Enabled in min_toolbox mode
                            aif  C:debug~use_min_toolbox<>0,.skip
                            pha                     ;give it's zp address
                            pushsword #0            ;320 mode, pallete 0
                            pushsword #160          ;scan line 160 bytes across
                            pushsword >applib~MM_ID
                            _QDStartup
                            tay                 ; Save any error
                            ldx #3
                            jsr check_for_error
                            jcs error_exit
.skip

; If not min_toolbox
                            aif  C:debug~use_min_toolbox=0,.skip
; Set the graphics mode, directly
                            jsl grlib_set_shr_mode                  ; Set the graphics mode
; Set all the sbcs
                            pushsword #grlib~shr_scb_320
                            pushsword #0
                            pushsword #200
                            jsl grlib_set_scb_range
.skip

                            aif  C:debug~use_min_toolbox<>0,.skip
; Load in the RAM based tools off the disk

                            pushdword #loadtools_table
                            _LoadTools
                            tay                 ; Save any error
                            ldx #5
                            jsr check_for_error
                            jcs error_exit
.skip

; We need some blocks of 32k for the screen buffers

; See if we already snagged it above
                            testptr >appdata~altscr_handle
                            bne already_allocated_altscr_handle
; Nope, we have to get some plain memory.  We won't be able to use shadowing to update the real screen
                            pushdword #0
                            pushdword #$8000                                             ;32k
                            pushsword >applib~MM_ID
                            pushsword #attrLocked+attrNoCross+attrNoSpec+attrPage        ;locked, fixed, no special, aligned, no bank crossing
                            pushdword #0
                            _NewHandle
                            tay                 ; Save any error
                            pla
                            sta >appdata~altscr_handle
                            pla
                            sta >appdata~altscr_handle+2
                            ldx #6
                            jsr check_for_error
                            jcs error_exit

                            aif C:debug~os_memory_tracking=0,.no_tracking
                            lda >appdata~altscr_handle+2
                            tax
                            lda >appdata~altscr_handle
                            jsl track_os_allocation
.no_tracking

already_allocated_altscr_handle anop

; Get the alt-screen pointer and give it to the grlib
                            getptr >appdata~altscr_handle,<pTemp
                            pushptr [<pTemp],#0
                            jsl grlib_set_alt_screen_buffer

; Now get the background buffer

                            pushdword #0
                            pushdword #$8000                                             ;32k
                            pushsword >applib~MM_ID
                            pushsword #attrLocked+attrNoCross+attrNoSpec+attrPage        ;locked, fixed, no special, aligned, no bank crossing
                            pushdword #0
                            _NewHandle
                            tay                 ; Save any error

                            pla
                            sta >appdata~back_handle
                            sta <pTemp
                            pla
                            sta >appdata~back_handle+2
                            sta <pTemp+2

                            ldx #7
                            jsr check_for_error
                            jcs error_exit

                            aif C:debug~os_memory_tracking=0,.no_tracking
                            lda >appdata~back_handle+2
                            tax
                            lda >appdata~back_handle
                            jsl track_os_allocation
.no_tracking

                            pushptr [<pTemp],#0
                            jsl grlib_set_back_buffer

; If debug~debug~use_fake_screen, then we will allocate a fake screen
                            aif  C:debug~use_fake_screen<>0,.noskip
                            ago .skip
.noskip
                            mnote 'Using fake screen target'

; Get a 'target' buffer, if we are not drawing to the real screen

                            pushdword #0
                            pushdword #$8000       ;32k
                            pushsword >applib~MM_ID
                            pushsword #attrLocked+attrNoCross+attrNoSpec+attrPage       ;locked, fixed, no special, aligned, no bank crossing
                            pushdword #0
                            _NewHandle
                            tay                 ; Save any error

                            pla
                            sta >appdata~targetscr_handle
                            sta <pTemp
                            pla
                            sta >appdata~targetscr_handle+2
                            sta <pTemp+2

                            ldx #7
                            jsr check_for_error
                            jcs error_exit

                            aif C:debug~os_memory_tracking=0,.no_tracking
                            lda >appdata~targetscr_handle+2
                            tax
                            lda >appdata~targetscr_handle
                            jsl track_os_allocation
.no_tracking

                            pushptr [<pTemp],#0
                            jsl grlib_set_target_screen_buffer
.skip

; If NOT debug~use_fake_screen, then we are using the 'real' screen as the target
                            aif  C:debug~use_fake_screen<>0,.skip
                            mnote 'Using real screen'
                            pushdword #grlib~shr_screen
                            jsl grlib_set_target_screen_buffer
.skip
                            jsl grlib_initialize_patching

; Initialize the global SBA manager.
                            jsl sba_manager_initialize
; Graphics sub-systems
                            jsl grlib_update_rects_initialize
                            jsl sprite_manager_initialize
                            jsl grlib_entity_manager_initialize

; Initialize the global string manager
                            jsl string_manager_initialize
; Initialize the file manager
                            jsl file_manager_initialize
; Initialize our library stuff
                            jsl datalib_manager_initialize
; Initialize the datalib translators we will use
                            jsl datalib_translator_tile_initialize
                            jsl datalib_translator_ctil_initialize
                            jsl datalib_translator_palt_initialize
                            jsl datalib_translator_frmc_initialize
                            jsl datalib_translator_font_initialize
                            jsl datalib_translator_wave_initialize

; Sound library
; TODO: I'd like to have whether or not we initialize the sound, come from the config, which will mean moving the config_read call to before here, or move this downward.
                            lda appdata~use_sndlib
                            beq skip_sndlib
                            jsl sndlib_initialize
skip_sndlib                 anop

exit                        restoredatabank
                            rtl

error_exit                  anop
                            sec
                            bra exit

; -----------------------------------------------------------
failed_to_get_shadowed_memory anop
                            jsl system_error_reset_strings

; Add the Error string
                            pushptr #failed_to_get_shadowed_memory_msg
                            jsl system_error_set_string
                            jsl system_error_show_error_msg
                            rts

failed_to_get_shadowed_memory_msg anop
                            cstring 'Startup: failed to allocate shadowed SHR memory'
str_required_memory         cstring 'The game requires approximately 850k of free memory when launching.'
loadtools_table             dc    i'2'                      ; 2 tools
                            dc    i'4,$0100'                ; Quickdraw, version 1
                            dc    i'6,$0100'                ; Event Manager, version1

                            end
; ----------------------------------------------------------
; Display an error in the startup sequence, if carry is set.
; Parameters:
; x-reg     - holds a sequence breadcrumb
; y-reg     - toolbox error code
; Returns, carry flag unchanged
; -----------------------------------------------------------
check_for_error             private seg_app
                            using system_error_data

                            bcs exit
                            rts

exit                        anop
; Setup some extended information
                            tya
                            sta >system_error~last_toolbox_code
                            txa
                            sta >system_error~last_system_breadcrumb
                            lda #system_id_startup+1
                            jsl system_error_handle_error

                            sec
                            rts

                            end
; -------------------------------------------------------------
; Startup the graphics and do the test
; -------------------------------------------------------------
execute                     start seg_app

                            setlocaldatabank

                            aif  C:debug~use_min_toolbox<>0,.skip
                            _GrafOn
                            _InitCursor
.skip
                            jsr do_game

                            aif  C:debug~use_min_toolbox<>0,.skip
                            _HideCursor
.skip
                            restoredatabank

                            rtl
                            end
; ---------------------------------------------------------------
; Shut down the tools and deallocate buffers
; ---------------------------------------------------------------
shutdown                    start seg_app
                            using appdata
                            using applib_data

                            setlocaldatabank
; App specific
                            jsl stars_manager_uninitialize
                            jsl bomb_entity_manager_uninitialize
                            jsl crystal_entity_manager_uninitialize
                            jsl explosion_entity_manager_uninitialize
                            jsl shot_entity_manager_uninitialize
                            jsl warrior_entity_manager_uninitialize
                            jsl worker_entity_manager_uninitialize
                            jsl rock_entity_manager_uninitialize
                            jsl sinistar_entity_manager_uninitialize
                            jsl playfield_entity_manager_uninitialize
; Library
                            jsl sndlib_uninitialize
                            jsl grlib_entity_manager_uninitialize
                            jsl sprite_manager_uninitialize
;                            jsl datalib_translator_tile_uninitialize
;                            jsl datalib_translator_ctil_uninitialize
;                            jsl datalib_translator_palt_uninitialize
                            jsl datalib_manager_uninitialize
                            jsl file_manager_uninitialize
                            jsl string_manager_uninitialize
                            jsl sba_manager_uninitialize
                            jsl input_lib_uninitialize
                            jsl system_error_uninitialize
                            jsl textlib_uninitilize

                            aif  C:debug~use_min_toolbox<>0,.skip
                            _QDShutDown
.skip

; Remove the heartbeat task
                            jsl applib_uninstall_heartbeat

                            _MTShutDown

; Get rid of the zp I got for the tools
                            lda >appdata~tool_zp_handle+2
                            tax
                            lda >appdata~tool_zp_handle
                            jsl deallocate_fixed_handle

; And the  screen buffers too
                            lda >appdata~back_handle+2
                            tax
                            lda >appdata~back_handle
                            jsl deallocate_fixed_handle

                            lda >appdata~altscr_handle+2
                            tax
                            lda >appdata~altscr_handle+2
                            jsl deallocate_fixed_handle

                            lda >appdata~targetscr_handle+2
                            tax
                            lda >appdata~targetscr_handle
                            jsl deallocate_fixed_handle

                            pushsword >applib~MM_ID
                            _MMShutDown
                            _TLShutDown

                            restoredatabank

                            rtl
                            end

; =============================================================================
; The main entry point to running the game
do_game                     private seg_app

; Using both of these random generators.  Each as its strengths and weaknesses.
                            lda #$6743
                            jsl math~rnd_initialize
                            jsl math~rnd3_initialize

; Set the clip coords to full screen

                            pushsword #0                 ; left
                            pushsword #0                 ; top
                            pushsword #320               ; right
                            pushsword #200               ; bottom
                            jsl grlib_set_clip_rect

; Run some of the smaller unit tests that exercise some of the systems
                            jsl run_unit_tests
                            cmp #0
                            beq exit

                            lda #$0000
                            jsl grlib_fill_back_buffer
                            lda #$0000
                            jsl grlib_fill_alt_screen
                            jsl grlib_alt_screen_to_screen

                            setlocaldatabank
; Initialize/Load game data
                            jsr do_game_startup
                            bcs exit
; Do the game loop
                            jsr do_game_loop

; Shutdown/release all game data
                            jsr do_game_shutdown

                            restoredatabank

exit                        anop
                            rts
                            end

; -----------------------------------------------------------------------------
do_game_startup             private seg_app
                            using appdata

                            debugtag 'do_game_startup'
; Load some assets
                            jsl open_datalibs
                            bcs error
                            jsl load_fonts
                            bcs error

                            jsl config_read                             ; do this after the splash?  I don't think any config is needed before that

                            jsl do_startup_splash                       ; This currently requires the datalibs to be loaded

                            jsl playfield_entity_manager_initialize
                            jsl sinistar_entity_manager_initialize
                            jsl rock_entity_manager_initialize
                            jsl worker_entity_manager_initialize
                            jsl warrior_entity_manager_initialize
                            jsl shot_entity_manager_initialize
                            jsl explosion_entity_manager_initialize
                            jsl crystal_entity_manager_initialize
                            jsl bomb_entity_manager_initialize
                            jsl system_debug_initialize
                            jsl memory_debug_initialize

                            jsl task_manager_initialize
                            jsl gameplay_sound_initialize
                            jsl gameplay_manager_initialize

                            jsl run_app_unit_tests

; Initialize the states.  This doesn't set them, just gives them some setup time to pre-load things.
                            jsl high_score_state_initialize
                            jsl tutorial_state_initialize
                            jsl frontend_state_initialize
                            jsl turn_start_state_initialize

; Start with the frontend_state
                            lda #app_state~frontend
                            sta >appdata~pending_state

                            clc

error                       rts
                            end

; -----------------------------------------------------------------------------
do_game_shutdown            private seg_app
                            using appdata

                            debugtag 'do_game_shutdown'

; The various states that have global data
                            jsl gameplay_manager_state_uninitialize
                            jsl turn_start_state_uninitialize
                            jsl gameplay_ui_uninitialize
                            jsl gameplay_sound_uninitialize
                            jsl close_datalibs

                            rts
                            end

; -----------------------------------------------------------------------------
do_game_loop                private seg_app
                            using applib_data
                            using appdata
                            using inputlib_data
                            using gameplay_level_data

                            debugtag 'do_game_loop'

; We can assume the databank is set to seg_app at this time
                            stz appdata~last_paused_tick
                            stz appdata~last_paused_tick+2

                            jsl applib_reset_tick_count
                            jsl applib_reset_tick_timer
                            jsl applib_reset_fps
                            jsl sndlib_manager_sync_ticks

; This just checks if a state change is needed and calls the appropriate state functions
loop                        anop
; Are we paused?
                            lda appdata~paused
                            bne is_paused

; Do we have a pending state change?
                            lda appdata~pending_state
                            cmp appdata~current_state
                            beq do_tick
; Yes, store off the current state into a previous state value, so the new state can see where it came from
                            pha
                            lda appdata~current_state
                            sta appdata~previous_state
                            pla
                            sta appdata~current_state
                            shiftleft 2
                            tax
; Patch in the state 'activate' and 'tick' functions
                            lda appdata~state_activate_table,x
                            sta patch_state_activate+1
                            lda appdata~state_activate_table+1,x
                            sta patch_state_activate+2

                            lda appdata~state_tick_table,x
                            sta patch_state_tick+1
                            lda appdata~state_tick_table+1,x
                            sta patch_state_tick+2

; Call a function to kick off the start of the state
patch_state_activate        jsl $ffffff
; Handle the activate wanting to swap states
                            lda appdata~pending_state
                            cmp appdata~current_state
                            bne check_end                           ; if a swap was detected, skip the tick, but wait for a loop around to actually change the state.
; Do the state tick
do_tick                     anop
patch_state_tick            jsl $ffffff

check_end                   anop
; Do we want to exit the app?
                            lda appdata~exit_requested
                            beq loop

                            rts

;; In a paused state
is_paused                   anop
                            jsr do_paused_tick
                            bra check_end
                            end

; -----------------------------------------------------------------------------
; Handle updates while the game is paused
do_paused_tick              private seg_app
                            using applib_data
                            using appdata

; We still want to track if ticks have passed, as some things don't like to be called too fast.
                            lda >applib~heartbeat_tick
                            sec
                            sbc appdata~last_paused_tick
                            tax
                            lda >applib~heartbeat_tick+2
                            sbc appdata~last_paused_tick+2
                            bne big_paused_ticks
                            txa
                            bne some_paused_ticks
; No ticks have passed
                            bra no_paused_tick

big_paused_ticks            anop
                            lda #2
some_paused_ticks           anop
                            sta appdata~last_paused_tick_delta

                            lda >applib~heartbeat_tick
                            sta appdata~last_paused_tick
                            lda >applib~heartbeat_tick+2
                            sta appdata~last_paused_tick+2

                            jsl snes_max_read_controller            ; read the button state for the controller, if enabled.

no_paused_tick              anop
                            jsl get_key_press
                            beq paused_update
                            cmp #$0011                              ; ctrl-q
                            beq exit_done
                            pha
                            jsl handle_common_keypresses
paused_update               jsl appdebug_update_text_screen
; give the gameplay state some time.  Maybe add in a paused tick function for all states?
                            lda appdata~last_paused_tick_delta
                            jsl gameplay_do_paused_tick
                            rts

exit_done                   lda #$ffff
                            sta appdata~exit_requested
                            rts

                            end

; -----------------------------------------------------------------------------
app_toggle_paused           start seg_app
                            using applib_data
                            using appdata

                            lda >appdata~paused
                            eor #$8000
                            sta >appdata~paused
                            beq unpause

; Save the tick we paused on.
                            lda >applib~heartbeat_tick
                            sta >appdata~last_paused_tick
                            lda >applib~heartbeat_tick+2
                            sta >appdata~last_paused_tick+2

; Apply the 'paused' palettes
                            jsl gameplay_ui_apply_paused_palettes
                            rtl

unpause                     jsl gameplay_ui_remove_paused_palettes
                            rtl
                            end

; -----------------------------------------------------------------------------
; Handle an abort from an error handler.
; This will shutdown systems that need to cleanup, even in the event
; of an abort.  Usually if they have possibly setup a callback vector.
app_handle_abort            start

                            jsl sndlib_uninitialize
                            jsl applib_uninstall_heartbeat
                            rtl

                            end
