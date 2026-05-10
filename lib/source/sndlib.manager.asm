                        copy 13/Ainclude/E16.Memory
                        copy lib/source/debug.definitions.asm
                        copy lib/source/system.ids.asm
                        copy lib/source/object.definitions.asm
                        copy lib/source/sndlib.riff.definitions.asm
                        copy lib/source/sndlib.definitions.asm
                        copy lib/source/datalib.constants.asm

                        mcopy generated/sndlib.manager.macros

                        longa on
                        longi on

; -----------------------------------------------------------------------------
; Sound functions and data

sndlib_data             data seg_sndlib

sndlib_error_none               equ 0
sndlib_error_null_pointer       equ system_id_sound+1
sndlib_error_allocation         equ system_id_sound+2

ctrl_panel_volume                       equ $e100ca                ; Known location where the control panel stores the system volume.  Can get this with _GetAddr #irqVolume ($06)
irq_oscillator                          equ $e100cc                ; Known location where firmware will put what oscillator generated the interrupt.  Can get this with _GetAddr #irqSndData ($08)

; Registers in main-ram
doc_reg~sound_control                   equ $c03c

doc_sound_control~volume_mask           equ $000f
doc_sound_control~auto_increment        equ $0020
doc_sound_control~access_doc            equ $0000
doc_sound_control~access_ram            equ $0040

doc_reg~data                            equ $c03d
doc_reg~address                         equ $c03e

; Registers internal to the DOC
doc_reg~oscillator_interrupt            equ $e0
doc_reg~oscillator_enable               equ $e1
doc_reg~oscillator_control              equ $a0                 ; the control register for the first oscillator.

doc_oscillator_control~halt             equ %00000001
doc_oscillator_control~free_run         equ %00000000
doc_oscillator_control~one_shot         equ %00000010
doc_oscillator_control~sync             equ %00000100
doc_oscillator_control~swap             equ %00000110
doc_oscillator_control~interrupt_enable equ %00001000
doc_oscillator_control~channel_mask     equ %11110000
doc_oscillator_control~channel_right    equ %00000000
doc_oscillator_control~channel_left     equ %00010000

doc_reg~frequency_control_low           equ $00                 ; the control register, for the first oscillator's frequency, low byte.
doc_reg~frequency_control_high          equ $20                 ; the control register, for the first oscillator's frequency, high byte.

doc_reg~oscillator_volume               equ $40                 ; the volume register, for the first oscillator
doc_oscillator_volume~min               equ $00
doc_oscillator_volume~max               equ $ff

doc_reg~oscillator_wave_table_addr      equ $80                 ; the bank address register, for the first oscillator
doc_reg~oscillator_wave_table_size      equ $c0                 ; the wave table size register, for the first oscillator

doc_oscillator_wave_table_size~resolution_mask equ %00000111
doc_oscillator_wave_table_size~size_mask equ %00111000
doc_oscillator_wave_table_size~256      equ %00000000
doc_oscillator_wave_table_size~512      equ %00001000
doc_oscillator_wave_table_size~1024     equ %00010000
doc_oscillator_wave_table_size~2048     equ %00011000
doc_oscillator_wave_table_size~4096     equ %00100000
doc_oscillator_wave_table_size~8192     equ %00101000
doc_oscillator_wave_table_size~16384    equ %00110000
doc_oscillator_wave_table_size~32768    equ %00111000

; The default values for the bus resolution for each table size.
; This is essentially a mirror of the size bits, in the lower 3 bits.
; This value keeps the 'advance' resolution to 9 bits, for all the sizes,
; which allows the same frequency value to be used for any buffer size.
doc_oscillator_wave_table_resolution~256 equ %00000000
doc_oscillator_wave_table_resolution~512 equ %00000001
doc_oscillator_wave_table_resolution~1024 equ %00000010
doc_oscillator_wave_table_resolution~2048 equ %00000011
doc_oscillator_wave_table_resolution~4096 equ %00000100
doc_oscillator_wave_table_resolution~8192 equ %00000101
doc_oscillator_wave_table_resolution~16384 equ %00000110
doc_oscillator_wave_table_resolution~32768 equ %00000111

max_usable_oscillators                  equ 30                  ; the last two are reserved by the system

sndlib_initialized                      dc i'0'
sndlib_enabled                          dc i'0'
sndlib_sound_tools_handle               dc a4'0'
sndlib_last_update_tick                 dc i4'0'

sndlib_irq_backup                       ds 4
; Convenience values that are used a lot

; Enable the DOC to read/write its registers

; This will be filled with
; lda >ctrl_panel_volume
; and #$0f
; ora #doc_sound_control~access_doc
sndlib_doc_control_rw_registers         ds 2

; Enable the DOC to access ram and auto-advance
; This will be filled with
; lda >ctrl_panel_volume
; and #$0f
; ora #doc_sound_control~auto_increment+doc_sound_control~access_ram
sndlib_doc_control_write_ram            ds 2

doc_table_size_to_bytes     dc i'256,512,1024,2048,4096,8192,16384,32768'

doc_table_size_to_doc_size  dc i'doc_oscillator_wave_table_size~256+doc_oscillator_wave_table_resolution~256'
                            dc i'doc_oscillator_wave_table_size~512+doc_oscillator_wave_table_resolution~512'
                            dc i'doc_oscillator_wave_table_size~1024+doc_oscillator_wave_table_resolution~1024'
                            dc i'doc_oscillator_wave_table_size~2048+doc_oscillator_wave_table_resolution~2048'
                            dc i'doc_oscillator_wave_table_size~4096+doc_oscillator_wave_table_resolution~4096'
                            dc i'doc_oscillator_wave_table_size~8192+doc_oscillator_wave_table_resolution~8192'
                            dc i'doc_oscillator_wave_table_size~16384+doc_oscillator_wave_table_resolution~16384'
                            dc i'doc_oscillator_wave_table_size~32768+doc_oscillator_wave_table_resolution~32768'

; Oscillator bindings. See the oscillator_binding definition
max_oscillator_bindings                 equ max_usable_oscillators
sizeof~oscillator_bindings              equ sizeof~oscillator_binding*max_oscillator_bindings
oscillator_bindings                     ds sizeof~oscillator_bindings

sizeof~sound_interrupt_entries          equ sizeof~sound_interrupt_entry*max_oscillator_bindings
sound_interrupt_entries                 ds sizeof~sound_interrupt_entries


; Sound data entries.  These are all the loaded wave entries, some of which are resident in the DOC
max_sound_data_entries                  equ 64
sizeof~sound_data_entries               equ sizeof~sound_data_entry*max_sound_data_entries
sound_data_entries                      ds sizeof~sound_data_entries


; A queued callback
callback_queue~ptr                      equ 0
callback_queue~oscillator_instance      equ callback_queue~ptr+4
callback_queue~used_by                  equ callback_queue~oscillator_instance+2
sizeof~callback_queue                   equ callback_queue~used_by+2

; Offset into the queued callbacks
queued_oscillator_callback_offset       dc i'0'
; An array of queued callbacks.  This is set, as the oscillators are updated and once
; that is complete, the callbacks will be done.
; This allows the callbacks to queue up another sound, i.e. we are not in the middle of the update loop.
queued_oscillator_callbacks             ds max_usable_oscillators*sizeof~callback_queue

                        end

; -----------------------------------------------------------------------------
; Initialize the sound library
sndlib_initialize       start seg_sndlib
                        using sndlib_data
                        using applib_data

                        begin_locals
pTemp                   decl long
work_area_size          end_locals

                        sub ,work_area_size

                        setlocaldatabank

; Get some zp for the sound manager.  Maybe just use what the app was given?  I don't think we have used it all.

                        pushdword #0
                        pushdword #$100                                         ; Only wants one page
                        pushsword >applib~MM_ID
                        pushsword #attrLocked+attrFixed+attrBank+attrPage+attrNoPurge  ;locked, fixed, fixed bank, aligned
                        pushdword #0
                        _NewHandle
                        tay                 ; save toolbox error
                        pla
                        sta sndlib_sound_tools_handle
                        sta <pTemp            ;hold for a sec
                        pla
                        sta sndlib_sound_tools_handle+2
                        sta <pTemp+2
                        jcs memory_error

                        aif C:debug~os_memory_tracking=0,.no_tracking
                        tax
                        lda <pTemp
                        jsl track_os_allocation
.no_tracking

                        lda [<pTemp]          ;get the dereferenced pointer, just need the low word.
                        pha

; Starting up the sound tools, though we will not use it much, if at all.  Kinda signals to the system that we are using
; the sound hardware though.
                        _SoundStartUp                   ; Start Sound Tool Set
                        jcs tool_error

; Completely replace the sound interrupt handler, so we have the least amount of overhead.
; Could use the Sound Tools, SetSoundMIRQV too?  Does that do the exact same thing, or is there still an intermediate handler?
; We could be really bad and just backup and overwrite the vector in memory.  It is located at $e1002c
                        pushdword #0
                        pushsword #11                   ; the sound interrupt handler, sndIntHnd from E16.MiscTool
                        _GetVector
                        pulldword sndlib_irq_backup
                        pushsword #11
                        pushdword #sndlib_irq_handler
                        _SetVector

                        lda #1
                        sta sndlib_initialized
                        sta sndlib_enabled

; Clear the oscillator bindings
                        pushdword #oscillator_bindings
                        pushsword #sizeof~oscillator_bindings
                        pushsword #0
                        jsl fill_memory_2

; Clear the sound interrupt entries
                        pushdword #sound_interrupt_entries
                        pushsword #sizeof~sound_interrupt_entries
                        pushsword #0
                        jsl fill_memory_2

; Clear the sound data entries
                        pushdword #sound_data_entries
                        pushsword #sizeof~sound_data_entries
                        pushsword #0
                        jsl fill_memory_2

                        jsl sndlib_update_values

                        sei
                        shortm

; Set the DOC to read / write the registers
; Just snagging this from the known location.  Yes, we are supposed to query for it with the GetVector, but its not going anywhere.
                        lda sndlib_doc_control_rw_registers
                        sta >doc_reg~sound_control

; Make sure all the oscillators are on.  Do we have to do this?  I would assume the _SoundStartUp would do this.
                        lda #doc_reg~oscillator_enable
                        sta <doc_reg~address
                        lda #(31*2)
                        sta >doc_reg~data

                        longm
                        cli

                        pushsword #$8080
                        pushsword #$200
                        pushsword #$0000
                        jsl sndlib_fill_doc
                        clc
exit                    restoredatabank
                        retkc

memory_error            anop
                        lda #sndlib_error_allocation
                        jsl system_error_handle_toolbox_error
                        bra exit

tool_error              anop
                        ldx sndlib_sound_tools_handle+2
                        lda sndlib_sound_tools_handle
                        jsl deallocate_fixed_handle
                        sec
                        bra exit
                        end

; -----------------------------------------------------------------------------
; Uninitialize the sound library
sndlib_uninitialize     start seg_sndlib
                        using sndlib_data

                        setlocaldatabank

                        lda sndlib_initialized
                        beq not_initialized

                        pushsword #11
                        pushdword sndlib_irq_backup
                        _SetVector

                        _SoundShutDown

                        stz sndlib_initialized
                        stz sndlib_enabled

                        ldx sndlib_sound_tools_handle+2
                        lda sndlib_sound_tools_handle
                        jsl deallocate_fixed_handle

not_initialized         anop
                        restoredatabank

                        rtl
                        end

; -----------------------------------------------------------------------------
; Set whether or not the sound is enabled.
; This will test to see if the sound lib is initialized.
; Parameters:
; a-reg   - 0 off, any other value, on.
sndlib_set_enabled      start seg_sndlib
                        using sndlib_data

                        cmp #0
                        beq off
                        lda >sndlib_initialized
                        beq off

                        lda #$ffff
off                     sta >sndlib_enabled
                        rtl
                        end

; -----------------------------------------------------------------------------
; Setup the convenience sndlib values.
; This should be updated every once in a while, so that if the control-panel
; volume changes, the calculated value will update.
sndlib_update_values    start seg_sndlib
                        using sndlib_data

                        lda >ctrl_panel_volume
                        and #$0f
                        pha
                        ora #doc_sound_control~access_doc
                        sta >sndlib_doc_control_rw_registers

                        pla
                        ora #doc_sound_control~auto_increment+doc_sound_control~access_ram
                        sta >sndlib_doc_control_write_ram
                        rtl

                        end

; -----------------------------------------------------------------------------
; Set a single oscillator binding entry
; Parameters:
; wIndex            - index in the oscillator binding table
; wOscillatorIndex  - the index of the first oscillator
; wOscillatorCount  - the number of oscillators to bind
; wGroup            - the group to assign the oscillators to
; wDOCBinding       - the optional DOC page (high byte) / DOC Size (low-byte)
;                   - this associates the binding with a specific are in DOC RAM, used for streaming bindings
sndlib_set_oscillator_binding start seg_sndlib
                        using sndlib_data

                        begin_locals
work_area_size          end_locals

                        sub (2:wIndex,2:wOscillatorIndex,2:wOscillatorCount,2:wGroup,2:wDOCBinding),work_area_size

                        setlocaldatabank

                        getword <wIndex
                        cmp #max_oscillator_bindings+1
                        bge too_big
                        static_assert_equal sizeof~oscillator_binding,16
                        shiftleft 4
                        tax
                        lda <wOscillatorCount                       ; range check
                        clc
                        adc <wOscillatorIndex
                        cmp #max_usable_oscillators+1
                        bge error
; store the range
                        lda <wOscillatorCount
                        sta oscillator_bindings+oscillator_binding~count,x
                        lda <wOscillatorIndex
                        sta oscillator_bindings+oscillator_binding~index,x
                        lda <wGroup
                        sta oscillator_bindings+oscillator_binding~group,x
                        lda <wDOCBinding
                        sta oscillator_bindings+oscillator_binding~doc_binding,x
; clear the rest here?  It is already cleared on manager initialization.

error                   anop
too_big                 anop
                        restoredatabank
                        ret
                        end

; -----------------------------------------------------------------------------
; Set a range of oscillator binding entries
; Parameters:
; wStartIndex       - start index in the oscillator binding table
; wCount            - number of bindings to change
; wOscillatorIndex  - the index of the first oscillator
; wOscillatorCount  - the number of oscillators to bind
; wGroup            - the group to assign the oscillators to
;
; For each binding, the wOscillatorIndex will be advanced by wOscillatorCount
sndlib_set_oscillator_binding_range start seg_sndlib
                        using sndlib_data

                        begin_locals
work_area_size          end_locals

                        sub (2:wStartIndex,2:wCount,2:wOscillatorIndex,2:wOscillatorCount,2:wGroup),work_area_size

                        setlocaldatabank

                        getword <wCount
                        beq too_big
loop                    getword <wStartIndex
                        cmp #max_oscillator_bindings+1
                        bge too_big
                        static_assert_equal sizeof~oscillator_binding,16
                        shiftleft 4
                        tax
                        lda <wOscillatorCount                       ; range check
                        clc
                        adc <wOscillatorIndex
                        cmp #max_usable_oscillators+1
                        bge done
; store the range
                        lda <wOscillatorCount
                        sta oscillator_bindings+oscillator_binding~count,x
                        lda <wOscillatorIndex
                        sta oscillator_bindings+oscillator_binding~index,x
                        lda <wGroup
                        sta oscillator_bindings+oscillator_binding~group,x
                        lda #0
                        sta oscillator_bindings+oscillator_binding~doc_binding,x
; clear the rest here?  It is already cleared on manager initialization.

                        dec <wCount                                 ; done?
                        beq done
; Next entry
                        inc <wStartIndex
                        lda <wOscillatorIndex
                        clc
                        adc <wOscillatorCount
                        sta <wOscillatorIndex
                        cmp #max_usable_oscillators                 ; might as well do a range check here, since we have the value
                        blt loop

done                    anop
too_big                 anop
                        restoredatabank
                        ret
                        end

; -----------------------------------------------------------------------------
; Start an sfx definition playing
; This is a higher level interface and shields the caller from having to
; know how the sound is played.  i.e. resident or streamed.
; Parameters:
; wSfxXID            - the id of the sfx to play.
; wFrequencyAdjust   - amount to adjust the playback frequency by.  This is in DOC format!
; pCallback          - optional callback.  Set to 0 if none.
; Returns:
; carry set if there was an error, carry clear if successful and the ACC
; will contain the oscillator binding offset.
sndlib_play_sfx_with_callback start seg_sndlib
                        using sndlib_data
                        using gameplay_sound_data                   ; access gameplay defined data.

                        begin_locals
wInstance               decl word
work_area_size          end_locals

                        debugtag 'play_sfx_with_callback'

                        sub (2:wSfxXID,2:wFrequencyAdjust,4:pCallback),work_area_size

                        setlocaldatabank

                        lda sndlib_enabled
                        jeq error

                        lda <wSfxXID
                        static_assert_equal sizeof~sfx_entry,4
                        shiftleft 2
                        tax

                        lda sfx_entries+sfx_entry~sound_data,x
                        static_assert_equal sizeof~sound_data_entry,16
                        shiftleft 4
                        tay

; Is the sound loaded?
                        getword {y},sound_data_entries+sound_data_entry~bank_entry+sound_bank_entry~page
                        beq check_streaming                                         ; If not in the DOC, try streaming

; The sound is in DOC ram

; Go through the oscillator bindings, and find a free binding
                        ldx #0

resident_loop           getword {x},oscillator_bindings+oscillator_binding~count
                        beq none_free                                                ; when we hit an entry with no oscillators, we are done

                        getword {x},oscillator_bindings+oscillator_binding~group
                        cmp #id_oscillator_group~resident
                        bne not_resident

                        getword {x},oscillator_bindings+oscillator_binding~timer
                        beq found_resident

; todo, we should keep track of possible sfx to 'kick'.  i.e. lower priority, or possibly the same sfx type, with a timer that is almost expired
not_resident            anop
                        txa
                        clc
                        adc #sizeof~oscillator_binding
                        tax
                        cmp #sizeof~oscillator_bindings
                        blt resident_loop
                        bra none

found_resident          anop

; save the index of the binding for the return value
                        txa
                        static_assert_equal sizeof~oscillator_binding,16
                        shiftright 4
                        sta <wInstance

; store what sfx ID is using it
                        lda <wSfxXID
                        putword {x},oscillator_bindings+oscillator_binding~used_by

; setup the timer
                        getword {y},sound_data_entries+sound_data_entry~timer_length
                        putword {x},oscillator_bindings+oscillator_binding~timer
; Set the callback.
                        lda <pCallback
                        putword {x},oscillator_bindings+oscillator_binding~callback
                        lda <pCallback+2
                        putword {x},oscillator_bindings+oscillator_binding~callback+2

; Push on the values and play the audio
                        pushsword {x},oscillator_bindings+oscillator_binding~index
                        pushsword {x},oscillator_bindings+oscillator_binding~count
                        getword {y},sound_data_entries+sound_data_entry~bank_entry+sound_bank_entry~default_frequency
                        clc
                        adc <wFrequencyAdjust
                        pha
                        pushsword {y},sound_data_entries+sound_data_entry~bank_entry+sound_bank_entry~page
                        pushsword {y},sound_data_entries+sound_data_entry~bank_entry+sound_bank_entry~table_size
                        jsl sndlib_play_one_shot

exit                    anop
                        restoredatabank
                        retkc 2:wInstance

none_free               anop

error                   anop
none                    stz <wInstance
                        sec
                        bra exit

; The sound is non-resident, we are going to try and stream it.
check_streaming         anop

; Go through the oscillator bindings, and find a free binding
                        ldx #0

streaming_loop          getword {x},oscillator_bindings+oscillator_binding~count
                        beq none_free                                                ; when we hit an entry with no oscillators, we are done

                        getword {x},oscillator_bindings+oscillator_binding~group
                        cmp #id_oscillator_group~streaming
                        bne not_streaming

                        getword {x},oscillator_bindings+oscillator_binding~timer
                        beq found_streaming

; todo, we should keep track of possible sfx to 'kick'.  i.e. lower priority, or possibly the same sfx type, with a timer that is almost expired
not_streaming           anop
                        txa
                        clc
                        adc #sizeof~oscillator_binding
                        tax
                        cmp #sizeof~oscillator_bindings
                        blt streaming_loop
                        bra none

found_streaming         anop

; save the index of the binding for the return value
                        txa
                        static_assert_equal sizeof~oscillator_binding,16
                        shiftright 4
                        sta <wInstance

; store what sfx ID is using it
                        lda <wSfxXID
                        putword {x},oscillator_bindings+oscillator_binding~used_by

; setup the timer
                        getword {y},sound_data_entries+sound_data_entry~timer_length
                        putword {x},oscillator_bindings+oscillator_binding~timer

                        lda <pCallback
                        putword {x},oscillator_bindings+oscillator_binding~callback
                        lda <pCallback+2
                        putword {x},oscillator_bindings+oscillator_binding~callback+2

; Push on the values and play the audio
                        pushdword {y},sound_data_entries+sound_data_entry~wavetable_ptr
                        pushdword {y},sound_data_entries+sound_data_entry~wavetable_size
                        pushsword {x},oscillator_bindings+oscillator_binding~index
                        pushsword {x},oscillator_bindings+oscillator_binding~count
                        getword {y},sound_data_entries+sound_data_entry~bank_entry+sound_bank_entry~default_frequency
                        clc
                        adc <wFrequencyAdjust
                        pha
; The DOC page/size to use, is in the oscillator binding, packed, to keep the struct size a power of 2.
                        getword {x},oscillator_bindings+oscillator_binding~doc_binding
                        and #$ff00
                        pha
                        getword {x},oscillator_bindings+oscillator_binding~doc_binding
                        and #$00ff
                        pha
                        jsl sndlib_play_streamed
                        brl exit

                        end

; -----------------------------------------------------------------------------
; Start an sfx definition playing.  No callback
; is complete.
; Parameters:
; wSfxXID            - the id of the sfx to play.
; Returns:
; carry set if there was an error, carry clear if successful and the ACC
; will contain the oscillator binding offset.
sndlib_play_sfx         start seg_sndlib
                        using sndlib_data

                        begin_locals
work_area_size          end_locals

                        debugtag 'sndlib_play_sfx'

                        sub (2:wSfxXID),work_area_size

                        pushsword <wSfxXID
                        pushsword #0
                        pushdword #0
                        jsl sndlib_play_sfx_with_callback
                        sta <wSfxXID                    ; reuse this

                        retkc 2:wSfxXID
                        end

; -----------------------------------------------------------------------------
; Start an sfx definition playing.  No callback
; is complete.
; Parameters:
; wSfxXID            - the id of the sfx to play.
; wFrequencyAdjust   - amount to adjust the playback frequency by.  This is in DOC format!
; Returns:
; carry set if there was an error, carry clear if successful and the ACC
; will contain the oscillator binding offset.
sndlib_play_sfx_with_adjustments start seg_sndlib
                        using sndlib_data

                        begin_locals
work_area_size          end_locals

                        debugtag 'sndlib_play_sfx'

                        sub (2:wSfxXID,2:wFrequencyAdjust),work_area_size

                        pushsword <wSfxXID
                        pushsword <wFrequencyAdjust
                        pushdword #0
                        jsl sndlib_play_sfx_with_callback
                        sta <wSfxXID                    ; reuse this

                        retkc 2:wSfxXID
                        end

; -----------------------------------------------------------------------------
; Stop an sfx instance.
; Parameters:
; wInstanceID           - the instance ID, returned from play_sfx (not the sfx ID!)
; wOptions              - options when stopping the sfx.
;                          sfx_stop_option~default, do the default action, which will do the callbacks
;                          sfx_stop_option~cancel_callback, do not do any callbacks.
sndlib_stop_sfx_instance start seg_sndlib
                        using sndlib_data

                        begin_locals
work_area_size          end_locals

                        debugtag 'stop_sfx_instance'

                        sub (2:wInstanceID,2:wOptions),work_area_size

                        lda >sndlib_enabled
                        beq is_disabled

                        setlocaldatabank

                        lda <wInstanceID
                        static_assert_equal sizeof~oscillator_binding,16
                        shiftleft 4
                        tax
                        getword {x},oscillator_bindings+oscillator_binding~timer
                        beq already_stopped                 ; If the timer is 0, then it is already stopped (0 == free entry)

                        putzero {x},oscillator_bindings+oscillator_binding~timer
                        phx                                 ; save our place
; Halt the oscillators
                        pushsword {x},oscillator_bindings+oscillator_binding~index
                        pushsword {x},oscillator_bindings+oscillator_binding~count
                        jsl sndlib_halt_oscillators
                        plx

; Should we do the callback?
                        lda <wOptions
                        bit #sfx_stop_option~cancel_callback
                        bne no_callback
; Do the callback
                        getword {x},oscillator_bindings+oscillator_binding~callback+1       ; yes, +1 is correct
                        beq no_callback             ; any callback?

                        sta patch_func+2
                        getword {x},oscillator_bindings+oscillator_binding~callback
                        sta patch_func+1
                        pushsword <wInstanceID
                        pushsword {x},oscillator_bindings+oscillator_binding~used_by

patch_func              jsl $bbaaaa

no_callback             anop
already_stopped         anop
                        restoredatabank
is_disabled             ret
                        end

; -----------------------------------------------------------------------------
; Stop all sfx instances.
; Parameters:
; wOptions              - options when stopping the sfx.
;                          sfx_stop_option~default, do the default action, which will do the callbacks
;                          sfx_stop_option~cancel_callback, do not do any callbacks.
sndlib_stop_all_sfx     start seg_sndlib
                        using sndlib_data

                        begin_locals
wOffset                 decl word
wIndex                  decl word
work_area_size          end_locals

                        debugtag 'stop_sfx_instance'

                        sub (2:wOptions),work_area_size

                        lda >sndlib_enabled
                        beq is_disabled

                        setlocaldatabank

                        stz <wOffset
                        stz <wIndex

loop                    ldx <wOffset
                        getword {x},oscillator_bindings+oscillator_binding~count
                        beq exit                                                ; when we hit an entry with no oscillators, we are done

                        getword {x},oscillator_bindings+oscillator_binding~timer
                        beq already_stopped                 ; If the timer is 0, then it is already stopped (0 == free entry)

                        putzero {x},oscillator_bindings+oscillator_binding~timer
; Halt the oscillators
                        pushsword {x},oscillator_bindings+oscillator_binding~index
                        pushsword {x},oscillator_bindings+oscillator_binding~count
                        jsl sndlib_halt_oscillators

; Should we do the callback?
                        lda <wOptions
                        bit #sfx_stop_option~cancel_callback
                        bne no_callback
; Do the callback
                        ldx <wOffset
                        getword {x},oscillator_bindings+oscillator_binding~callback+1       ; yes, +1 is correct
                        beq no_callback             ; any callback?

                        sta patch_func+2
                        getword {x},oscillator_bindings+oscillator_binding~callback
                        sta patch_func+1
                        pushsword <wIndex           ; the index, is the SFX instance ID
                        pushsword {x},oscillator_bindings+oscillator_binding~used_by

patch_func              jsl $bbaaaa

no_callback             anop
already_stopped         anop
; Next
                        inc <wIndex
                        lda <wOffset
                        clc
                        adc #sizeof~oscillator_binding
                        sta <wOffset
                        cmp #sizeof~oscillator_bindings
                        blt loop

exit                    restoredatabank
is_disabled             ret
                        end
; -----------------------------------------------------------------------------
; Load a sound data entry with wave data
; Parameters:
; wSoundDataIndex   - the global sound data index to fill
; dwWaveID          - the ID of the wave data to load
; wTableIndex       - the DOC RAM table index to use.  Note, this is dependent on the size of the wave data loaded.
; wTableSize        - the DOC table size index, that is expected to use.
sndlib_load_sound_data  start seg_sndlib
                        using sndlib_data

                        begin_locals
pData                   decl long
dwSampleLength          decl long
spSndDOCRAM             decl word
wSndDOCSize             decl word
wTemp                   decl word
work_area_size          end_locals

                        sub (2:wSoundDataIndex,4:dwWaveID,2:wTableIndex,2:wTableSize),work_area_size

                        setlocaldatabank

                        pushdword #datalib_type_WAVE
                        pushdword <dwWaveID
                        pushsword #datalib_load_options~reference
                        jsl datalib_manager_get_data_ptr
                        jcs failed_to_read
                        putretptr <pData

                        lda <wTableIndex
                        bne want_resident
; Data will not be resident in the DOC.
                        getword [<pData],#wavetable_definition~size+2
                        putword <dwSampleLength+2
                        getword [<pData],#wavetable_definition~size
                        putword <dwSampleLength
                        stz <spSndDOCRAM
                        stz <wSndDOCSize
                        bra non_resident

; Data will be resident in the DOC
want_resident           anop
; Get the length
                        getword [<pData],#wavetable_definition~size+2
                        putword <dwSampleLength+2
                        cmp #0
                        jne too_big
                        getword [<pData],#wavetable_definition~size
                        putword <dwSampleLength
                        cmp #1+(1024*32)
                        jge too_big

; round up to the next power of 2, if needed
                        jsl sndlib_get_table_size_from_byte_size        ; input A=byte size, output X=table size index
                        stx <wSndDOCSize                                ; store this here, it isn't quite in the register format yet
                        cpx <wTableSize
                        beq size_matches
                        assert_brk 'table size mismatch'
size_matches            anop
                        ldy <wTableIndex
                        jsl sndlib_get_table_address                    ; input X=table size index, Y=table offset index, output A=table address in DOC ram
                        putword <spSndDOCRAM                            ; save the doc ram address

; Upload to the DOC
                        pushsword [<pData],#wavetable_definition~offset+2
                        pushsword [<pData],#wavetable_definition~offset   ; this is a pointer at runtime
                        pushsword <dwSampleLength
                        pushsword <spSndDOCRAM
                        jsl sndlib_copy_to_doc

non_resident            anop
                        lda <wSoundDataIndex
                        static_assert_equal sizeof~sound_data_entry,16
                        shiftleft 4
                        tax

                        getword <spSndDOCRAM
                        putword {x},sound_data_entries+sound_data_entry~bank_entry+sound_bank_entry~page
; Make the correct doc size value, by putting the table size in the correct location
; and leaving the table size value in the lower bits, so that the bus-resolution is 9-bits
                        getword <wSndDOCSize
                        shiftleft 3
                        ora <wSndDOCSize
                        putword {x},sound_data_entries+sound_data_entry~bank_entry+sound_bank_entry~table_size
; Calculate the frequency
                        phx
                        pushsword [<pData],#wavetable_definition~sample_rate
                        pushsword #doc_default_sample_advance_delta
                        jsl sndlib_khz_to_doc_frequency
                        plx
                        putword {x},sound_data_entries+sound_data_entry~bank_entry+sound_bank_entry~default_frequency
; Wave data, for streaming.  Should we even bother saving if 'resident'?  Maybe just unload it?
                        getword [<pData],#wavetable_definition~offset
                        putword {x},sound_data_entries+sound_data_entry~wavetable_ptr
                        getword [<pData],#wavetable_definition~offset+2   ; this is a pointer at runtime
                        putword {x},sound_data_entries+sound_data_entry~wavetable_ptr+2
; Wave data length, for streaming
                        getword [<pData],#wavetable_definition~size
                        putword {x},sound_data_entries+sound_data_entry~wavetable_size
                        getword [<pData],#wavetable_definition~size+2
                        putword {x},sound_data_entries+sound_data_entry~wavetable_size+2
; Calculate the timer length.
; This is somewhat expensive to calculate, and is only correct for the sampling rate that the sample was recorded at.
; Using the DOC frequency here, would be a little more involved, but would give the same-ish value, since the default
; DOC frequency should be close to the original.  It would be best to calculate at playback time, but that would be too
; expensive.  If anything, it would be nice if the value was pre-calculate and put into the header of the WAVE data.

                        phx                                 ; save our position

; Push the sample length, times 8 as the dividend, so we have a 24.8 value
                        lda <dwSampleLength+1
                        pha
                        lda <dwSampleLength
                        xba
                        and #$ff00
                        pha
; divide by the sample rate
                        pushsword #0
                        pushsword [<pData],#wavetable_definition~sample_rate
                        jsl ~div4
                        pla                                 ; the result, which will be 24.8.  We can just use the lower-word, as that will still hold a value of up to 256 seconds.
; clean up the rest of the stack
                        plx
                        plx
                        plx
; Calculate ticks
                        ldx #60
                        jsl math~mul2r4
; shift down from the fixed point to integer
                        shiftright 8
                        sta <wTemp
                        txa
                        shiftright 8
                        ora <wTemp

                        plx
                        sta sound_data_entries+sound_data_entry~timer_length,x

                        clc
exit                    anop
                        restoredatabank
                        retkc
too_big                 anop
failed_to_read          anop
                        sec
                        bra exit
                        end

; -----------------------------------------------------------------------------
; Synchronize the sndlib ticks with the app
sndlib_manager_sync_ticks start seg_sndlib
                        using sndlib_data
                        using applib_data

                        lda >applib~current_tick
                        sta >sndlib_last_update_tick
                        lda >applib~current_tick+2
                        sta >sndlib_last_update_tick+2
                        rtl

                        end

; -----------------------------------------------------------------------------
sndlib_manager_update   start seg_sndlib
                        using sndlib_data
                        using applib_data

                        setlocaldatabank

                        lda >applib~current_tick
                        sec
                        sbc sndlib_last_update_tick
                        tax
                        lda >applib~current_tick+2
                        sbc sndlib_last_update_tick+2
                        bne big_ticks
                        txa
                        bne some_ticks

                        bra done

big_ticks               lda #2
some_ticks              sta tick_delta

                        lda >applib~current_tick
                        sta sndlib_last_update_tick
                        lda >applib~current_tick+2
                        sta sndlib_last_update_tick+2

; Go through the oscillator bindings, and find bindings that timers, and decrement them.
                        stz queued_oscillator_callback_offset                   ; clear the callback queue
                        ldx #0

loop                    lda oscillator_bindings+oscillator_binding~count,x
                        beq done                                                ; when we hit an entry with no oscillators, we are done

                        lda oscillator_bindings+oscillator_binding~timer,x
                        beq is_free
                        sec
                        sbc tick_delta
                        bcc complete
                        beq complete
                        sta oscillator_bindings+oscillator_binding~timer,x

is_free                 anop
                        txa
                        clc
                        adc #sizeof~oscillator_binding
                        tax
                        cmp #sizeof~oscillator_bindings
                        blt loop

done                    anop
                        lda queued_oscillator_callback_offset
                        bne dispatch_callbacks

exit                    restoredatabank
                        rtl

complete                anop
                        putzero {x},oscillator_bindings+oscillator_binding~timer
; Queue the callback
                        getword {x},oscillator_bindings+oscillator_binding~callback+2
                        beq is_free             ; any callback?
; Add the callback to the queue
                        ldy queued_oscillator_callback_offset
                        putword {y},queued_oscillator_callbacks+callback_queue~ptr+2
                        getword {x},oscillator_bindings+oscillator_binding~callback
                        putword {y},queued_oscillator_callbacks+callback_queue~ptr
                        txa
                        putword {y},queued_oscillator_callbacks+callback_queue~oscillator_instance
                        getword {x},oscillator_bindings+oscillator_binding~used_by
                        putword {y},queued_oscillator_callbacks+callback_queue~used_by
                        tya
                        clc
                        adc #sizeof~callback_queue
                        sta queued_oscillator_callback_offset
                        bra is_free

; Dispatch the queued callbacks
dispatch_callbacks      anop

                        ldy #0
dispatch_loop           getword {y},queued_oscillator_callbacks+callback_queue~ptr+1        ; yes, +1 is correct
                        sta patch_func+2
                        getword {y},queued_oscillator_callbacks+callback_queue~ptr
                        sta patch_func+1
                        phy                                     ; save our place
                        pushsword {y},queued_oscillator_callbacks+callback_queue~oscillator_instance
                        pushsword {y},queued_oscillator_callbacks+callback_queue~used_by
patch_func              jsl $bbaaaa
                        pla                                     ; get our offset back
                        clc
                        adc #sizeof~callback_queue
                        cmp queued_oscillator_callback_offset
                        beq exit
                        tay
                        bra dispatch_loop

tick_delta              ds 2

                        end
; -----------------------------------------------------------------------------
; Convert an input Khz frequency, to a doc playback frequency
; Parameters:
; wKHz              - the input Khz sampling rate.  Must be less than 26320Khz
; wDOCAdvance       - The amount it takes to advance the DOC to the next sample.
;                     This is based on the wavetable size and the bus resolution.
;                     Overall, it is 'easiest' to just keep the bus resolution and the wavetable
;                     size bits the same, when setting up a sound, so that the 'advance'
;                     is 512.  That is, it takes an advance of 512 in the 24-bit oscillator
;                     counter, to advance to the next sample in the wavetable.
sndlib_khz_to_doc_frequency start seg_sndlib

                        begin_locals
dwDividend              decl long
dwDivisor               decl long
dwFreqencyRatio         decl long
dwDocFrequency          decl long
work_area_size          end_locals

                        sub (2:wKhz,2:wDOCAdvance),work_area_size

; We are going to shift up the dividends, so that we preserve the fractional part.  i.e. using FP 16.16
; This isn't particularly fast

; (doc_scan_frequency * 16) / sample frequency
                        lda #doc_scan_frequency
                        sta <dwDividend+2
                        stz <dwDividend
                        lda <wkHz
                        sta <dwDivisor
                        stz <dwDivisor+2

                        div4 dwDividend,dwDivisor,dwFreqencyRatio

; (DOC Advance * 16) / frequency ratio
                        lda <wDOCAdvance
                        sta <dwDividend+2
                        stz <dwDividend

                        div4 dwDividend,dwFreqencyRatio,dwDocFrequency

                        ret 2:dwDocFrequency
                        end

; -----------------------------------------------------------------------------
; Take the wave size in A and return the table size in X
; Returns:
; 0 - 256
; 1 - 512
; 2 - 1024
; 3 - 2048
; 4 - 4096
; 5 - 8192
; 6 - 16384
; 7 - 32768
; Carry will be clear if no error, set if the input size was too large.
sndlib_get_table_size_from_byte_size start seg_sndlib

; This just rounds up A to the next power of 2
                        ldx #0
                        cmp #1+(256|0)
                        blt found
                        inx
                        cmp #1+(256|1)
                        blt found
                        inx
                        cmp #1+(256|2)
                        blt found
                        inx
                        cmp #1+(256|3)
                        blt found
                        inx
                        cmp #1+(256|4)
                        blt found
                        inx
                        cmp #1+(256|5)
                        blt found
                        inx
                        cmp #1+(256|6)
                        blt found
                        inx
                        cmp #1+(256|7)
                        blt found
; This is an error, we can't have a table larger than 32k
                        assert_brk "invalid_wave_size"
                        ldx #0
found                   rtl
                        end


; -----------------------------------------------------------------------------
; Take the table offset index in Y and the table size index in X
; and return a DOC RAM address
sndlib_get_table_address start seg_sndlib
                        using sndlib_data

                        cpy #0
                        beq is_zero

                        tya
                        xba                         ; put in the high byte
                        cpx #0
                        beq done
loop                    asl a
                        dex
                        bne loop

done                    rtl
is_zero                 anop
                        assert_brk 'zero_is_reserved'               ; 0 position is reserved by the system.
                        lda #$0000
                        rtl
                        end

; -----------------------------------------------------------------------------
; Take the table offset index in Y and the table size index in A
; and return a packed DOC page / DOC size value in A
sndlib_packed_doc_binding start seg_sndlib
                        using sndlib_data

                        begin_locals
work_area_size          end_locals

                        sub (2:wTableIndex,2:wTableSize),work_area_size

; Put the page in the high byte
                        lda <wTableIndex
                        xba
                        ldx <wTableSize
                        beq zero
loop                    asl a
                        dex
                        bne loop
; put the size in the low byte
zero                    asl <wTableSize
                        ldx <wTableSize
                        ora >doc_table_size_to_doc_size,x
                        sta <wTableSize
                        ret 2:wTableSize
                        end

; -----------------------------------------------------------------------------
; Copy a block of data to the doc
; Parameters:
; pSource       - source data
; wLength       - length of the source data
; spDest        - destination in the doc ram (short pointer)
sndlib_copy_to_doc      start seg_sndlib
                        using sndlib_data
                        using softswitch_definitions

                        begin_locals
work_area_size          end_locals

                        sub (4:pSource,2:wLength,2:spDest),work_area_size

                        lda >sndlib_enabled
                        beq is_disabled

                        setlocaldatabank

                        getword <pSource
                        putword patch_source+1
                        getword <pSource+1
                        putword patch_source+2
                        getword <wLength
                        putword patch_length+1

                        sei
                        shortm

                        lda sndlib_doc_control_write_ram
                        sta >doc_reg~sound_control

                        lda <spDest
                        sta >doc_reg~address
                        lda <spDest+1
                        sta >doc_reg~address+1

; Since we will be writing a lot to the DOC registers, map the DP to the soft-switch area so we can use DP writes
                        phd
; This would be 1 cycle faster, but looks ugly
;                       lda #^ssw~bank
;                       xba
;                       lda #0
;                       tcd
                        pea ssw~bank
                        pld

                        ldx #$0000
loop                    anop
patch_source            lda >$bbaaaa,x
                        sta <doc_reg~data
                        inx
patch_length            cpx #$0000
                        bne loop

; Put in zeros for sound stop?  Hmm, I don't want to overwrite the next bank if the length was a multiple of 256

                        longm
                        pld
                        cli

                        restoredatabank

is_disabled             anop
                        ret
                        end

; -----------------------------------------------------------------------------
; Fill the doc with a value (usually $80)
; Parameters:
; wValue        - byte to fill
; wLength       - length of the source data
; spDest        - destination in the doc ram (short pointer)
sndlib_fill_doc         start seg_sndlib
                        using sndlib_data
                        using softswitch_definitions

                        begin_locals
work_area_size          end_locals

                        sub (2:wValue,2:wLength,2:spDest),work_area_size

                        lda >sndlib_enabled
                        beq is_disabled

                        setlocaldatabank

                        getword <wLength
                        putword patch_length+1

                        sei
                        shortm

                        lda sndlib_doc_control_write_ram
                        sta >doc_reg~sound_control

                        lda <spDest
                        sta >doc_reg~address
                        lda <spDest+1
                        sta >doc_reg~address+1

                        lda <wValue
; Since we will be writing a lot to the DOC registers, map the DP to the soft-switch area so we can use DP writes
                        phd
; This would be 1 cycle faster, but looks ugly
;                       lda #^ssw~bank
;                       xba
;                       lda #0
;                       tcd
                        pea ssw~bank
                        pld

patch_length            ldx #$0000
loop                    anop
                        sta <doc_reg~data
                        dex
                        bne loop

; Put in zeros for sound stop?  Hmm, I don't want to overwrite the next bank if the length was a multiple of 256

                        longm
                        pld
                        cli

                        restoredatabank

is_disabled             anop
                        ret
                        end

; -----------------------------------------------------------------------------
; Start a one-shot sound playing
; Parameters:
; wOscillator       - the first oscillator to use.
; wOscillatorCount  - the oscillator count.
; wFrequency        - the frequency value for playback.  This is in DOC format, and is dependent on the wWaveTableSize value.
; wWaveTablePage    - doc ram page the sound starts in. Remember, the bits used in this value, depend on the wave-table size.
; wWaveTableSize    - the size of wave-table.  This is in doc format, so it includes the bus resolution.
;
; TODO: This only supports wOscillatorCount == 2 (stereo)
sndlib_play_one_shot    start seg_sndlib
                        using sndlib_data
                        using softswitch_definitions

                        begin_locals
work_area_size          end_locals

                        ssub (2:wOscillator,2:wOscillatorCount,2:wFrequency,2:wWaveTablePage,2:wWaveTableSize),work_area_size

                        lda >sndlib_enabled
                        jeq is_disabled

                        setlocaldatabank

; Map the DP to the soft-switch area
                        phd
                        lda #ssw~bank
                        tcd

                        sei
                        shortmx

stack_adjust            equ 3                                   ; at this point, there are 3 bytes on the stack we have to adjust for

busy_loop               lda <doc_reg~sound_control
                        bmi busy_loop

; Set the DOC to read / write the registers
                        lda sndlib_doc_control_rw_registers
                        sta <doc_reg~sound_control

; How many oscillators?  We assume they are sequential
                        getword {s},#wOscillatorCount+stack_adjust
                        cmp #2
                        bge stereo

stereo                  anop
; Make sure the oscillators are stopped, before futzing with the values.
                        getword {s},#wOscillator+stack_adjust
                        tax                                                     ; x will have the first oscillator number for the rest of the function
                        clc
                        adc #doc_reg~oscillator_control
                        tay
                        sta <doc_reg~address
; Note, when halting, it seems like you have to set the one_shot/freerun mode to what the oscillator is set to already, else the sound doesn't play
; later on, when it gets started at the end.  Still not quite sure why.  Might be due to how the oscillator pointer address is 'reset' to the beginning of the buffer.
                        lda #doc_oscillator_control~halt+doc_oscillator_control~one_shot
                        sta <doc_reg~data

                        iny                                                     ; + 1
                        sty <doc_reg~address
                        sta <doc_reg~data
; Set frequency
                        txa
                        sta <doc_reg~address
                        getword {s},#wFrequency+stack_adjust
                        sta <doc_reg~data
                        txa
                        clc
                        adc #doc_reg~frequency_control_high
                        tay
                        sta <doc_reg~address
                        getword {s},#wFrequency+1+stack_adjust
                        sta <doc_reg~data

                        txa
                        inc a                                                   ; + 1
                        sta <doc_reg~address
                        getword {s},#wFrequency+stack_adjust
                        sta <doc_reg~data
                        iny                                                     ; + 1
                        sty <doc_reg~address
                        getword {s},#wFrequency+1+stack_adjust
                        sta <doc_reg~data

; Oscillator volume
                        txa
                        clc
                        adc #doc_reg~oscillator_volume
                        tay
                        sta <doc_reg~address
                        lda #doc_oscillator_volume~max                          ; Need to get this from somewhere.  Pass it in?  Make assumptions based on placement?
                        sta <doc_reg~data

                        iny                                                     ; +1
                        sty <doc_reg~address
                        sta <doc_reg~data
; Wave Table Address
                        txa
                        clc
                        adc #doc_reg~oscillator_wave_table_addr
                        tay
                        sta <doc_reg~address
                        getword {s},#wWaveTablePage+1+stack_adjust              ; Storing only the high byte
                        sta <doc_reg~data

                        iny                                                     ; +1
                        sty <doc_reg~address
                        sta <doc_reg~data

; Wave Table Size
                        txa
                        clc
                        adc #doc_reg~oscillator_wave_table_size
                        sta <doc_reg~address
                        tay
                        getword {s},#wWaveTableSize+stack_adjust
                        sta <doc_reg~data

                        iny                                                     ; +1
                        sty <doc_reg~address
                        sta <doc_reg~data

; Start the sound playing
                        txa
                        clc
                        adc #doc_reg~oscillator_control
                        tay
                        sta <doc_reg~address
                        lda #doc_oscillator_control~one_shot+doc_oscillator_control~channel_right
                        sta <doc_reg~data

                        iny                                                     ; +1
                        sty <doc_reg~address
                        lda #doc_oscillator_control~one_shot+doc_oscillator_control~channel_left
                        sta <doc_reg~data

                        longmx

                        pld
                        cli

                        restoredatabank

is_disabled             anop
                        sret
                        end

; -----------------------------------------------------------------------------
; Start streamed sound playing
; This is a low-level call, use the sfx interface instead
; Parameters:
; pSource           - the source data to stream
; dwSourceLength    - the source data length.  Can be > 64k.
; wOscillator       - the first oscillator to use.
; wOscillatorCount  - the oscillator count.
; wFrequency        - the frequency value for playback.  This is in DOC format, and is dependent on the wWaveTableSize value.
; wWaveTablePage    - doc ram page the sound starts in. Remember, the bits used in this value, depend on the wave-table size.
; wWaveTableSize    - the size of wave-table.  This is in doc format, so it includes the bus resolution.
;
; TODO: This only supports wOscillatorCount == 2 (stereo)
sndlib_play_streamed    start seg_sndlib
                        using sndlib_data
                        using softswitch_definitions

                        begin_locals
work_area_size          end_locals

                        ssub (4:pSource,4:dwSourceLength,2:wOscillator,2:wOscillatorCount,2:wFrequency,2:wWaveTablePage,2:wWaveTableSize),work_area_size

                        lda >sndlib_enabled
                        jeq is_disabled

                        setlocaldatabank

; How many oscillators?  We assume they are sequential
                        getword {s},#wOscillatorCount+1         ; + 1 for stack adjust
                        cmp #3                                  ; 1 timer, 2 audio?
                        bge stereo

stereo                  anop

; Map the DP to the soft-switch area
                        phd
                        lda #ssw~bank
                        tcd

                        sei

stack_adjust            equ 3                                   ; at this point, there are 3 bytes on the stack we have to adjust for

                        shortmx

; Set the DOC to read / write the registers
                        lda sndlib_doc_control_rw_registers
                        sta <doc_reg~sound_control

; Make sure the oscillators are stopped, before futzing with the values.
                        getword {s},#wOscillator+stack_adjust
                        clc
                        adc #doc_reg~oscillator_control
                        tay
                        sta <doc_reg~address
                        lda #doc_oscillator_control~halt+doc_oscillator_control~one_shot    ; The one_shot flag seems necessary, to make sure the playback is correct, even when we are using a different mode
                        sta <doc_reg~data

                        iny                                                     ; + 1
                        sty <doc_reg~address
                        sta <doc_reg~data
                        iny                                                     ; + 2
                        sty <doc_reg~address
                        sta <doc_reg~data
                        longmx

; Fill the DOC RAM buffer.  We are going to support multiple sizes, but we have to balance the overhead of doing the copy
; vs. the frequency of the interrupts, to back fill the buffer.  On the low-end, we are using a 512 byte playback buffer,
; and a 256 byte timer buffer. Assuming 11025Hz sampling rate, that means we go through 256 sample bytes in
; about 23.2 milliseconds, meaning we will get an interrupt 1 or 2 times a 'frame', targeting 30fps.
; Going to the next size up, having a 1024 byte buffer, and copying 512 bytes, would cut the frequency
; of interrupts in half, but increase the copy time.

                        getword {s},#wOscillator+stack_adjust                   ; The timing oscillator will serve as the streaming ID
                        static_assert_equal sizeof~sound_interrupt_entry,16
                        shiftleft 4
                        tay

                        getword {s},#wWaveTablePage+stack_adjust
                        sta sound_interrupt_entries+sound_interrupt_entry~doc_sptr,y
                        lda #0
                        sta sound_interrupt_entries+sound_interrupt_entry~doc_offset,y
; Source pointers
                        getword {s},#pSource+stack_adjust
                        sta sound_interrupt_entries+sound_interrupt_entry~streaming_ptr,y
                        clc
                        adcword {s},#dwSourceLength+stack_adjust
                        sta sound_interrupt_entries+sound_interrupt_entry~streaming_end_ptr,y
                        getword {s},#pSource+stack_adjust+2
                        sta sound_interrupt_entries+sound_interrupt_entry~streaming_ptr+2,y
                        adcword {s},#dwSourceLength+stack_adjust+2
                        sta sound_interrupt_entries+sound_interrupt_entry~streaming_end_ptr+2,y

                        getword {s},#wWaveTableSize+stack_adjust
                        and #doc_oscillator_wave_table_size~size_mask
                        shiftright 2                        ; shift one less, so we have x 2
                        tax
                        jsr (stream_bootstrap,x)

; Apply the common register values
                        shortmx
; Set the DOC to read / write the registers
                        lda sndlib_doc_control_rw_registers
                        sta <doc_reg~sound_control
; Set frequency of all the oscillators to be the same
                        getword {s},#wOscillator+stack_adjust
                        tax                                                     ; x will have the first oscillator number for the rest of the function
                        sta <doc_reg~address
                        getword {s},#wFrequency+stack_adjust
                        sta <doc_reg~data
                        txa
                        clc
                        adc #doc_reg~frequency_control_high
                        tay
                        sta <doc_reg~address
                        getword {s},#wFrequency+1+stack_adjust
                        sta <doc_reg~data

                        txa
                        inc a                                                   ; + 1
                        sta <doc_reg~address
                        getword {s},#wFrequency+stack_adjust
                        sta <doc_reg~data
                        iny                                                     ; + 1
                        sty <doc_reg~address
                        getword {s},#wFrequency+1+stack_adjust
                        sta <doc_reg~data

                        txa
                        inc a
                        inc a                                                   ; + 2
                        sta <doc_reg~address
                        getword {s},#wFrequency+stack_adjust
                        sta <doc_reg~data
                        iny                                                     ; + 2
                        sty <doc_reg~address
                        getword {s},#wFrequency+1+stack_adjust
                        sta <doc_reg~data

; Oscillator volume
                        txa
                        clc
                        adc #doc_reg~oscillator_volume
                        tay
                        sta <doc_reg~address
                        lda #0                                                  ; timer volume = 0
                        sta <doc_reg~data

                        lda #doc_oscillator_volume~max                          ; Need to get this from somewhere.  Pass it in?  Make assumptions based on placement?
                        iny                                                     ; + 1
                        sty <doc_reg~address
                        sta <doc_reg~data
                        iny                                                     ; + 2
                        sty <doc_reg~address
                        sta <doc_reg~data

; Wave Table Address
                        txa
                        clc
                        adc #doc_reg~oscillator_wave_table_addr
                        tay
                        sta <doc_reg~address
                        lda #0                                                  ; timer buffer is at 0x0000
                        sta <doc_reg~data

                        getword {s},#wWaveTablePage+1+stack_adjust              ; Storing only the high byte
                        iny                                                     ; + 1
                        sty <doc_reg~address
                        sta <doc_reg~data
                        iny                                                     ; + 2
                        sty <doc_reg~address
                        sta <doc_reg~data

; Wave Table Size
                        txa
                        clc
                        adc #doc_reg~oscillator_wave_table_size
                        sta <doc_reg~address
                        tay
; This is a bit of a hack to get a 'half-size' of the buffer.
                        getword {s},#wWaveTableSize+stack_adjust
                        and #doc_oscillator_wave_table_size~size_mask
                        shiftright 3
                        dec a
                        sta temp
                        shiftleft 3
                        ora temp
                        sta <doc_reg~data

                        getword {s},#wWaveTableSize+stack_adjust
                        iny                                                     ; + 1
                        sty <doc_reg~address
                        sta <doc_reg~data
                        iny                                                     ; + 2
                        sty <doc_reg~address
                        sta <doc_reg~data

; Start the sound playing
                        txa
                        clc
                        adc #doc_reg~oscillator_control
                        tay
                        sta <doc_reg~address
                        lda #doc_oscillator_control~free_run+doc_oscillator_control~interrupt_enable  ; timer is in free-run mode, with an interrupt
                        sta <doc_reg~data

                        iny                                                     ; +1
                        sty <doc_reg~address
                        lda #doc_oscillator_control~free_run+doc_oscillator_control~channel_right
                        sta <doc_reg~data
                        iny                                                     ; +1
                        sty <doc_reg~address
                        lda #doc_oscillator_control~free_run+doc_oscillator_control~channel_left
                        sta <doc_reg~data

                        longmx
                        pld
                        cli

                        restoredatabank

is_disabled             anop
                        sret

temp                    ds 2

;;; Support functions

stream_bootstrap_error  anop
                        assert_brk 'Unsupported stream buffer size'
                        rts

stream_bootstrap_512    anop
                        lda #512
                        putword {y},sound_interrupt_entries+sound_interrupt_entry~doc_end_offset
                        lda #1
                        putword {y},sound_interrupt_entries+sound_interrupt_entry~doc_tblsize

                        jsr copy_page_to_doc
                        jsr copy_next_page_to_doc                       ; skips setting the doc registers, they are already set correctly
                        rts

; Copy a page to the DOC.  Assumes that the doc is in register write mode
copy_page_to_doc        entry
                        shortm

; Put into doc ram, auto-increment mode
                        lda sndlib_doc_control_write_ram
                        sta <doc_reg~sound_control

; Set the doc ram write address
                        getword {y},sound_interrupt_entries+sound_interrupt_entry~doc_sptr
                        clc
                        adcword {y},sound_interrupt_entries+sound_interrupt_entry~doc_offset
                        sta <doc_reg~address
                        getword {y},sound_interrupt_entries+sound_interrupt_entry~doc_sptr+1
                        adcword {y},sound_interrupt_entries+sound_interrupt_entry~doc_offset+1
                        sta <doc_reg~address+1

copy_next_page_to_doc   anop
                        ldx sound_interrupt_entries+sound_interrupt_entry~streaming_ptr,y           ; put the low address of the source in x
                        shortm
                        getword {y},sound_interrupt_entries+sound_interrupt_entry~streaming_ptr+2   ; set the bank to the bank of the source
                        phb
                        pha
                        plb
; Unrolled copy code, that is geared toward copying an entire page to DOC RAM
; Each copy instruction is 5 bytes per byte copied
;
;                       lda |$0000,x                    ;3 bytes
;                       sta <doc_reg~data               ;2 bytes
;                       lda |$0001,x
;                       sta <doc_reg~data
;                       ...
                        unrolled_sound_data_loop <doc_reg~data,256

                        longm

                        plb

                        getword {y},sound_interrupt_entries+sound_interrupt_entry~streaming_ptr
                        clc
                        adc #256
                        putword {y},sound_interrupt_entries+sound_interrupt_entry~streaming_ptr
                        getword {y},sound_interrupt_entries+sound_interrupt_entry~streaming_ptr+2
                        adc #0
                        putword {y},sound_interrupt_entries+sound_interrupt_entry~streaming_ptr+2

                        getword {y},sound_interrupt_entries+sound_interrupt_entry~doc_offset
                        clc
                        adc #256
                        cmp sound_interrupt_entries+sound_interrupt_entry~doc_end_offset,y
                        blt no_doc_end
                        lda #0                              ; wrap back to the start
no_doc_end              putword {y},sound_interrupt_entries+sound_interrupt_entry~doc_offset

                        rts

; Copy a a partial page to the DOC.  Assumes that the doc is in register write mode
; Assumes x contains the number of bytes to copy to the doc (can be 0)
; The remainder, up to 8 bytes, will be set to 0
copy_partial_page_to_doc entry
                        phb
                        phy
                        phx                                                                         ; store the count
                        ldx sound_interrupt_entries+sound_interrupt_entry~streaming_ptr,y           ; put the low address of the source in x
                        shortm

; Put into doc ram, auto-increment mode
                        lda sndlib_doc_control_write_ram
                        sta <doc_reg~sound_control

; Set the doc ram write address
                        getword {y},sound_interrupt_entries+sound_interrupt_entry~doc_sptr
                        clc
                        adcword {y},sound_interrupt_entries+sound_interrupt_entry~doc_offset
                        sta <doc_reg~address
                        getword {y},sound_interrupt_entries+sound_interrupt_entry~doc_sptr+1
                        adcword {y},sound_interrupt_entries+sound_interrupt_entry~doc_offset+1
                        sta <doc_reg~address+1

                        getword {y},sound_interrupt_entries+sound_interrupt_entry~streaming_ptr+2   ; set the bank to the bank of the source
                        ply                                                                         ; y will be our countdown
                        phy                                                                         ; gonna still need it on the stack
                        beq no_partial_bytes
                        pha
                        plb

; Copy the remaining.
partial_copy_loop       lda |$0000,x
                        sta <doc_reg~data
                        inx
                        dey
                        bne partial_copy_loop

no_partial_bytes        anop
; Get the remaining bytes
                        lda #256
                        sec
                        sbc 1,s
                        beq partial_no_remaining
                        cmp #9
                        blt partial_less_than_9
                        lda #8                          ; only need at least 8 zeros
partial_less_than_9     tax
                        lda #0
partial_zero_fill_loop  sta <doc_reg~data
                        dex
                        bne partial_zero_fill_loop
partial_no_remaining    anop
                        longm
                        pla                             ; discard temporary count
                        ply                             ; get Y back
                        plb                             ; get data bank back

; Should we even bother doing this?  Probably not, we are ending after the partial copy.
                        ago .skip
                        getword {y},sound_interrupt_entries+sound_interrupt_entry~streaming_end_ptr
                        putword {y},sound_interrupt_entries+sound_interrupt_entry~streaming_ptr
                        getword {y},sound_interrupt_entries+sound_interrupt_entry~streaming_end_ptr+2
                        putword {y},sound_interrupt_entries+sound_interrupt_entry~streaming_ptr+2

                        getword {y},sound_interrupt_entries+sound_interrupt_entry~doc_offset
                        clc
                        adc #256
                        cmp sound_interrupt_entries+sound_interrupt_entry~doc_end_offset,y
                        blt partial_no_doc_end
                        lda #0                              ; wrap back to the start
partial_no_doc_end      putword {y},sound_interrupt_entries+sound_interrupt_entry~doc_offset
.skip
                        rts

stream_bootstrap        dc a2'stream_bootstrap_error'
                        dc a2'stream_bootstrap_512'
                        dc a2'stream_bootstrap_error'
                        dc a2'stream_bootstrap_error'
                        dc a2'stream_bootstrap_error'
                        dc a2'stream_bootstrap_error'
                        dc a2'stream_bootstrap_error'
                        dc a2'stream_bootstrap_error'

                        end

; -----------------------------------------------------------------------------
; Halt oscillator(s)
; Parameters:
; wOscillator       - the first oscillator.
; wOscillatorCount  - the number to halt
;
sndlib_halt_oscillators start seg_sndlib
                        using sndlib_data
                        using softswitch_definitions

                        begin_locals
work_area_size          end_locals

                        ssub (2:wOscillator,2:wOscillatorCount),work_area_size

                        lda >sndlib_enabled
                        jeq is_disabled

                        setlocaldatabank

                        sei
                        shortmx

; Map the DP to the soft-switch area
                        phd
                        pea ssw~bank
                        pld

stack_adjust            equ 3                                   ; at this point, there are 3 bytes on the stack we have to adjust for

; Set the DOC to read / write the registers
                        lda sndlib_doc_control_rw_registers
                        sta <doc_reg~sound_control

; How many oscillators?  We assume they are sequential
                        getword {s},#wOscillatorCount+stack_adjust
                        tax
                        beq done

                        getword {s},#wOscillator+stack_adjust
                        clc
                        adc #doc_reg~oscillator_control
                        tay
                        sta <doc_reg~address
                        lda #doc_oscillator_control~halt+doc_oscillator_control~one_shot    ; The one_shot flag seems necessary, to make sure the later playback is correct, even when we are using a different mode
                        sta <doc_reg~data

                        dex
                        beq done
loop                    iny                                                     ; + 1
                        sty <doc_reg~address
                        sta <doc_reg~data
                        dex
                        bne loop

done                    anop
                        longmx

                        pld
                        cli

                        restoredatabank

is_disabled             anop
                        sret
                        end

; -----------------------------------------------------------------------------
; Sound Interrupt Handler
sndlib_irq_handler      start seg_sndlib
                        using sndlib_data
                        using softswitch_definitions

                        phb
                        phd

                        phk
                        plb
; We are called in emulation mode
                        clc
                        xce
                        longmx

; Set DP to the soft-switches
                        lda #ssw~bank
                        tcd

                        lda sndlib_doc_control_rw_registers
                        sta <doc_reg~sound_control

                        lda >irq_oscillator         ; get the cached copy of the Oscillator Interrupt Register
loop                    and #%00111110              ; oscillator number, x 2
                        lsr a
                        sta handling_oscillator
                        static_assert_equal sizeof~sound_interrupt_entry,16
                        shiftleft 4
                        tay

                        lda sound_interrupt_entries+sound_interrupt_entry~doc_end_offset,y
                        beq not_streaming

                        lda sound_interrupt_entries+sound_interrupt_entry~doc_tblsize,y
                        asl a
                        tax
                        jsr (streaming_irq_handlers,x)

not_streaming           anop

                        ago .skip
                        shortm

wait_loop               lda <doc_reg~sound_control
                        bmi wait_loop
; This is code that NTP does, and it seems like it is trying to get the next oscillator that is in 'interrupt'
; However, it is a bit confusing with the register reading.  Unfortunately the hardware-reference manual is also not
; very clear.  The odd bit is the read of the data, then store of 0 at the address and then the reading again
; Is this trying to 'clear' the existing one, first?
                        lda #doc_reg~oscillator_interrupt
                        sta <doc_reg~address
                        lda <doc_reg~data
                        lda #0                              ; dummy wait?
                        sta <doc_reg~address
                        lda <doc_reg~data
                        longm
                        bpl loop                            ; bit 7 = 0, means interrupt has happend for oscillator (odd that it is a bit backward)
.skip

                        pld
                        plb

                        clc                         ; we handled it
                        rtl

; DP will be set to the soft-switch bank
stream_fill_512         anop

; See if there is less than 256 bytes remaining.
; Could do this by precalculating the start of the partial page and do a compare, like I'm doing for the end_ptr.  Would be slightly faster.
                        sec
                        lda sound_interrupt_entries+sound_interrupt_entry~streaming_end_ptr,y
                        sbc sound_interrupt_entries+sound_interrupt_entry~streaming_ptr,y
                        tax
                        lda sound_interrupt_entries+sound_interrupt_entry~streaming_end_ptr+2,y
                        sbc sound_interrupt_entries+sound_interrupt_entry~streaming_ptr+2,y
                        bne at_least_256
                        cpx #256
                        bge at_least_256
;
                        jsr copy_partial_page_to_doc
; We are done
                        shortm
; Set the DOC to read / write the registers
                        lda sndlib_doc_control_rw_registers
                        sta <doc_reg~sound_control
; Stop the timer
                        lda handling_oscillator
                        clc
                        adc #doc_reg~oscillator_control
                        sta <doc_reg~address
                        lda #doc_oscillator_control~free_run+doc_oscillator_control~halt
                        sta <doc_reg~data
; Could also look at the oscillator_binding~timer, and set it to 1, if it is greater than that, since the remaining will be done within a tick.

                        longm
                        rts

; We assume the playing oscillators will run into some 0's and stop themselves.

at_least_256            jsr copy_page_to_doc
                        shortm
; Set the DOC to read / write the registers
                        lda sndlib_doc_control_rw_registers
                        sta <doc_reg~sound_control
                        longm
                        rts

stream_irq_error        anop
                        rts

streaming_irq_handlers  anop

                        dc a2'stream_irq_error'
                        dc a2'stream_fill_512'
                        dc a2'stream_irq_error'
                        dc a2'stream_irq_error'
                        dc a2'stream_irq_error'
                        dc a2'stream_irq_error'
                        dc a2'stream_irq_error'
                        dc a2'stream_irq_error'

handling_oscillator     ds 2

                        end
