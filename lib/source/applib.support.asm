                            copy lib/source/debug.definitions.asm
                            copy lib/source/system.ids.asm
                            copy lib/source/object.definitions.asm

                            copy 13/Ainclude/E16.MiscTool

                            mcopy generated/applib.support.macros

; -----------------------------------------------------------------------------
; Some simple 'app' support functions.
; Mainly installing and managing the tick count
; There was support for the standard OS tick handler, but this
; changed to favor just using our own tick handler.

; -----------------------------------------------------------------------------
applib_data                 data seg_slib
; Set by the application at startup.  The ZP base given by GS/OS (bottom of the stack)
applib~dp_base              ds 2
; This is a shared DP for the libraries.
; See applib.definitions.asm, for ranges assigned to libraries
applib~shared_dp            ds 2

; Memory Manager ID for the application
applib~MM_ID                ds 2

applib~heartbeat_installed  dc i'0'                         ; Is the heartbeat callback installed?
applib~heartbeat_tick       dc i4'0'                        ; If we are using our own heartbeat task, this is what we increment.
applib~system_tick          dc i4'0'                        ; The last 'real' tick count of the system
applib~current_tick         dc i4'0'                        ; An idealized tick count.

applib~tick_mark            dc i4'0'

applib~fps_tick_start       dc i4'0'
applib~fps_current          dc i2'0'
applib~fps_frame_number     dc i2'0'

                            end

; -----------------------------------------------------------------------------
; Install / Uninstall the Heartbeat Task.
applib_install_heartbeat    start seg_slib
                            using applib_data

                            setlocaldatabank

                            lda applib~heartbeat_installed
                            bne already_installed

                            stz applib~heartbeat_tick
                            stz applib~heartbeat_tick+2

                            sei
                            pushdword #task_header
                            _SetHeartBeat
                            cli

                            inc applib~heartbeat_installed

                            pushsword #0
                            _GetIRQEnable
                            pla
                            and #vbInt                  ; vbl already on?
                            bne vbl_on
; Turn on VBL
                            pushsword #vblEnable
                            _IntSource
vbl_on                      anop
already_installed           restoredatabank
                            rtl

applib_uninstall_heartbeat  entry

                            lda >applib~heartbeat_installed
                            beq not_installed
                            sei
                            pushdword #task_header
                            _DelHeartBeat
                            cli
                            lda #0
                            sta >applib~heartbeat_installed
; Should I turn off VBLs if they were not on?
not_installed               rtl

; A tick task
task_interval               equ 1               ; Setting to 0, since we are only installing this, so GetTick works

task_header                 anop
                            dc a4'0'            ; Space for a pointer
task_counter                dc i2'task_interval' ; The task interval, in ticks.  This will be counted down.
                            dc i2'$A55A'         ; Signature

task_entry                  anop
                            longm

                            lda #task_interval
                            sta >task_counter

                            lda >applib~heartbeat_tick
                            inc a
                            sta >applib~heartbeat_tick
                            bne no_rollover
                            lda >applib~heartbeat_tick+2
                            inc a
                            sta >applib~heartbeat_tick+2
no_rollover                 anop

                            shortm
                            rtl

                            end

                            longa on

; -----------------------------------------------------------------------------
; Reset the idealized tick counter
applib_reset_tick_count     start seg_slib
                            using applib_data

                            debugtag 'reset_tick_count'

                            setlocaldatabank

                            ago .no_sys_tick
; Get the system ticks
                            pushdword #0
                            _GetTick                            ; deprecated
; Store the ticks away in x/y, then find the delta from the last time we called this function.
                            pla
                            sta applib~system_tick
                            pla
                            sta applib~system_tick+2
.no_sys_tick

; These are updated in our heartbeat task, so pause interrupts
                            sei
                            lda applib~heartbeat_tick+2
                            sta applib~system_tick+2
                            lda applib~heartbeat_tick
                            sta applib~system_tick
                            cli

                            stz applib~current_tick
                            stz applib~current_tick+2

                            restoredatabank
                            rtl

                            end

; -----------------------------------------------------------------------------
applib_update_tick_count    start seg_slib
                            using applib_data

                            debugtag 'update_tick_count'

                            setlocaldatabank

; If the system tick delta is more than this, cap the advance to this.
; This helps is when debugging, so that the frame processing doesn't have huge amounts between each of them
limited_advance_amount      equ 6

; Get the system ticks
                            ago .no_sys_tick
                            pushdword #0
                            _GetTick                            ; deprecated
; Store the ticks away in x/y, then find the delta from the last time we called this function.
                            pla
                            tax
                            sec
                            sbc applib~system_tick
                            sta delta_ticks
                            pla
                            tay
.no_sys_tick
; Get our heartbeat ticks. Should probably disable/enable interrupts here while we get the two parts.
                            lda applib~heartbeat_tick
                            tax
                            sec
                            sbc applib~system_tick
                            sta delta_ticks
                            lda applib~heartbeat_tick+2
                            tay

                            sbc applib~system_tick+2
                            bne limit_advance
                            lda delta_ticks
                            cmp #limited_advance_amount
                            bge limit_advance

; Ticks were within our cap, just adjust by that delta
                            lda applib~current_tick
                            clc
                            adc delta_ticks
                            sta applib~current_tick
                            bcc no_overflow
                            inc applib~current_tick+2
no_overflow                 anop

; Store the system ticks for reference
                            stx applib~system_tick
                            sty applib~system_tick+2

                            restoredatabank
                            rtl

; System tick delta is above the cap, limit the applib~current_tick advance
limit_advance               anop
                            lda applib~current_tick
                            clc
                            adc #limited_advance_amount
                            sta applib~current_tick
                            bcc no_overflow2
                            inc applib~current_tick+2
no_overflow2                anop

                            stx applib~system_tick
                            sty applib~system_tick+2
                            restoredatabank
                            rtl

delta_ticks                 ds 2

                            end

; -----------------------------------------------------------------------------
applib_reset_tick_timer     start seg_slib
                            using applib_data

                            debugtag 'reset_tick_timer'

                            AIF  C:debug~golden_gate<>0,.skip
                            setlocaldatabank

                            ago .no_sys_tick
                            pushdword #0
                            _GetTick                            ; deprecated
                            pla
                            sta applib~tick_mark
                            pla
                            sta applib~tick_mark+2
.no_sys_tick
; Get our hearbeat ticks
                            lda applib~heartbeat_tick
                            sta applib~tick_mark
                            lda applib~heartbeat_tick+2
                            sta applib~tick_mark+2

                            restoredatabank
.skip
                            rtl
                            end

; -----------------------------------------------------------------------------
applib_wait_ticks           start seg_slib
                            using applib_data

                            debugtag 'wait_ticks'

                            AIF  C:debug~golden_gate<>0,.skip
                            setlocaldatabank

                            sta waitfor
                            cmp #0
                            beq zero_wait

loop                        anop
                            ago .no_sys_tick
                            pushdword #0
                            _GetTick                            ; deprecated
                            pla
                            sec
                            sta tick_current
                            sbc applib~tick_mark
                            sta tick_delta
                            pla
                            sta tick_current+2
.no_sys_tick
                            lda applib~heartbeat_tick
                            sec
                            sta tick_current
                            sbc applib~tick_mark
                            sta tick_delta
                            lda applib~heartbeat_tick+2
                            sta tick_current+2

                            sbc applib~tick_mark+2
                            sta tick_delta+2
                            bne past
                            lda tick_delta
                            cmp waitfor
                            blt loop

past                        lda tick_current
                            sta applib~tick_mark
                            lda tick_current+2
                            sta applib~tick_mark+2
                            restoredatabank
                            rtl
; Just update the tick_mark value and exit
zero_wait                   anop
                            ago .no_sys_tick2
                            pushdword #0
                            _GetTick                            ; deprecated
                            pla
                            sta applib~tick_mark
                            pla
                            sta applib~tick_mark+2
.no_sys_tick2
                            lda applib~heartbeat_tick
                            sta applib~tick_mark
                            lda applib~heartbeat_tick+2
                            sta applib~tick_mark+2

                            restoredatabank
                            rtl

tick_current                ds 4
tick_delta                  ds 4
waitfor                     ds 2
.skip
                            AIF  C:debug~golden_gate=0,.skip
                            rtl
.skip
                            end

; -----------------------------------------------------------------------------
; Reset the FPS counter
applib_reset_fps            start seg_slib
                            using applib_data

                            debugtag 'reset_fps'

                            AIF  C:debug~golden_gate<>0,.skip
                            setlocaldatabank

                            ago .no_sys_tick
                            pushdword #0
                            _GetTick                            ; deprecated
                            pla
                            sta applib~fps_tick_start
                            pla
                            sta applib~fps_tick_start+2
.no_sys_tick
                            lda applib~heartbeat_tick
                            sta applib~fps_tick_start
                            lda applib~heartbeat_tick+2
                            sta applib~fps_tick_start+2

                            stz applib~fps_frame_number
                            restoredatabank
.skip
                            rtl
                            end

; -----------------------------------------------------------------------------
; Update the fps value.  For ease of dividing, it is expected that the time was
; over a fixed amount of frames
applib_update_fps           start seg_slib
                            using applib_data
                            using grlib_global_data

                            debugtag 'update_fps'

                            AIF  C:debug~golden_gate<>0,.skip
                            setlocaldatabank

sampled_frame_count         equ 60
ticks_per_second            equ 60

                            inc applib~fps_frame_number
                            lda applib~fps_frame_number
                            cmp #sampled_frame_count
                            bge update
exit                        restoredatabank
                            rtl

update                      anop

                            ago .no_sys_tick
                            pushdword #0
                            _GetTick                            ; deprecated
                            pla
                            sec
                            sta tick_current
                            sbc applib~fps_tick_start
                            sta tick_delta
                            pla
.no_sys_tick
                            lda applib~heartbeat_tick
                            sec
                            sta tick_current
                            sbc applib~fps_tick_start
                            sta tick_delta
                            lda applib~heartbeat_tick+2
                            sta tick_current+2
                            sbc applib~fps_tick_start+2
                            sta tick_delta+2
                            bne large

                            lda #(sampled_frame_count*32)       ; Number of elapsed frames * 100
                            ldx tick_delta                      ; div by the number of ticks
                            beq too_fast
                            jsl ~div2                           ; This will give us the number of ticks, per frame * 100
                            ldx #ticks_per_second               ; times ticks in a second
                            jsl math~umul2r2
                            shiftright 5
limited                     sta applib~fps_current

done                        lda tick_current
                            sta applib~fps_tick_start
                            lda tick_current+2
                            sta applib~fps_tick_start+2
                            stz applib~fps_frame_number
                            restoredatabank
                            rtl
large                       stz applib~fps_current
                            bra done

too_fast                    lda #$7fff
                            bra limited

tick_current                ds 4
tick_delta                  ds 4
.skip
                            AIF  C:debug~golden_gate=0,.skip
                            rtl
.skip
                            end
