                            copy lib/source/debug.definitions.asm
                            copy lib/source/system.ids.asm
                            copy lib/source/object.definitions.asm
                            copy lib/source/string.definitions.asm
                            copy lib/source/container.definitions.asm
                            copy lib/source/datalib.constants.asm
                            copy lib/source/input.constants.asm

                            copy source/gameplay.constants.asm
                            copy source/app.debug.definitions.asm

                            mcopy generated/frontend.state.macros

                            longa on
                            longi on
; ----------------------------------------------------------------------------
; Frontend state.  This coordinates the other front end states as well as launching the in-game states
frontend_state_data         data seg_gameplay
                            using appdata

frontend~started_game       ds 2

frontend~request_none           equ 0
frontend~request_single_player  equ 1
frontend~request_two_player     equ 2

frontend~next_request       ds 2

frontend~state_sequence     anop
                            dc i'app_state~high_scores'
                            dc i'app_state~copyright'
;                            dc i'app_state~demo'
                            dc i'app_state~tutorial'
                            dc i'app_state~input_overview'
                            dc i'0'                                 ; list terminator

frontend~request_handlers   anop
                            dc a'frontend_start_single_player'
                            dc a'frontend_start_two_player'

                            end
; ----------------------------------------------------------------------------
frontend_state_initialize   start seg_gameplay
                            using frontend_state_data

                            debugtag 'frontend_state_initialize'

                            setlocaldatabank

                            stz frontend~started_game
                            stz frontend~next_request

                            restoredatabank
                            rtl
                            end

; ----------------------------------------------------------------------------
frontend_state_activate     start seg_gameplay
                            using frontend_state_data

                            debugtag 'frontend_state_activate'

                            rtl

                            end

; ----------------------------------------------------------------------------
frontend_state_tick         start seg_gameplay
                            using appdata
                            using frontend_state_data

                            debugtag 'frontend_state_tick'

                            setlocaldatabank

; Have a request to do something?
                            lda frontend~next_request
                            beq no_request
                            stz frontend~next_request
                            dec a
                            asl a
                            tax
                            jsr (frontend~request_handlers,x)           ; probably overkill to have a table
                            bra exit

no_request                  anop

; Just kick off the first state in the sequence
                            lda frontend~state_sequence
                            sta >appdata~pending_state

exit                        restoredatabank
                            rtl
                            end

; ----------------------------------------------------------------------------
; Set the next state from the input state
; Parameters:
; wFromState        the current / previous
; Return:
; Carry clear, the next state, it will already be set as the pending state
; Carry set.  No state OR a request to just stay in the current state.  i.e. Repeat it.
frontend_set_next_state     start seg_gameplay
                            using appdata
                            using frontend_state_data

                            begin_locals
result                      decl word
work_area_size              end_locals

                            sub (2:wFromState),work_area_size

                            setlocaldatabank

; Do we have a request queued?
                            lda frontend~next_request
                            beq no_request
; Yes, exit back to the frontend to handle it
                            lda #app_state~frontend
                            bra different

no_request                  anop
                            ldx #0
loop                        lda frontend~state_sequence,x
                            beq not_found
                            cmp <wFromState
                            beq found
                            inx
                            inx
                            bra loop
found                       inx
                            inx
                            lda frontend~state_sequence,x
                            beq wrap
different                   sta >appdata~pending_state
                            clc
exit                        sta <result
                            restoredatabank
                            retkc 2:result

wrap                        lda frontend~state_sequence
                            cmp <wFromState
                            bne different
not_found                   lda <wFromState
                            sec
                            bra exit
                            end

; ----------------------------------------------------------------------------
; Handle input from a child state.
; Parameters:
;   wKey - key pressed, can be 0
frontend_state_handle_input start seg_gameplay
                            using appdata
                            using grlib_global_data
                            using inputlib_data
                            using frontend_state_data
                            using gameplay_manager_data

                            begin_locals
work_area_size              end_locals

                            sub (2:wKey),work_area_size

                            setlocaldatabank                    ; probably not needed

                            lda >grlib~in_text_mode
                            bmi skip_to_debug                   ; if in text mode, just send the keys to the debug panels.

                            lda <wKey
                            beq no_key
                            jsl key_to_upper
                            cmp #'1'
                            beq single_player
                            cmp #'2'
                            beq two_player
                            aif C:debug~use_profile_state=0,.skip
                            cmp #'3'
                            beq single_player_profile
.skip
                            cmp #'Q'
                            beq quit
                            cmp #'C'
                            beq show_config
                            cmp #'I'
                            beq show_information

skip_to_debug               pushsword <wKey
                            jsl handle_common_keypresses

; Pressed Start on the gamepad?
no_key                      lda >input~gamepad1_connected
                            beq not_connected1

                            lda >input~gamepad1_buttons
                            bit #input~gamepad_start
                            bne single_player
; Hmm, so how have a two player start with the gamepad?  If there is a second gamepad, check for Start on that?
; What if they want two player, but one gamepad?
not_connected1              anop
                            lda >input~gamepad2_connected
                            beq not_connected2

                            lda >input~gamepad2_buttons
                            bit #input~gamepad_start
                            bne single_player
not_connected2              anop

exit                        restoredatabank
                            ret

                            aif C:debug~use_profile_state=0,.skip
single_player_profile       lda #$8000
                            sta gameplay_manager~static_profile
.skip
single_player               lda #frontend~request_single_player
                            sta frontend~next_request
                            lda #app_state~frontend                     ; make sure we are back in the front end to handle the request
                            sta >appdata~pending_state
                            bra exit

two_player                  lda #frontend~request_two_player
                            sta frontend~next_request
                            lda #app_state~frontend                     ; make sure we are back in the front end to handle the request
                            sta >appdata~pending_state
                            bra exit

quit                        lda #$ffff
                            sta >appdata~exit_requested
                            bra exit

show_config                 lda #app_state~config
                            sta >appdata~pending_state
                            bra exit

show_information            lda #app_state~credits
                            sta >appdata~pending_state
                            bra exit
                            end

; -----------------------------------------------------------------------------
frontend_start_single_player start seg_gameplay
                            using frontend_state_data

                            pushsword #1
                            jsl gameplay_manager_start_game
                            rts

                            end

; -----------------------------------------------------------------------------
frontend_start_two_player start seg_gameplay
                            using frontend_state_data

                            pushsword #2
                            jsl gameplay_manager_start_game

                            rts
                            end

