                            copy lib/source/debug.definitions.asm
                            copy lib/source/system.ids.asm
                            copy lib/source/object.definitions.asm
                            copy lib/source/string.definitions.asm
                            copy lib/source/container.definitions.asm
                            copy lib/source/datalib.constants.asm
                            copy lib/source/sndlib.definitions.asm

                            copy source/gameplay.constants.asm

                            mcopy generated/gameplay.sound.macros

                            longa on
                            longi on
; -----------------------------------------------------------------------------
; Gameplay related functions and data for sound playback
gameplay_sound_data         data seg_sndlib         ; NOTE: This is in the sndlib segment, so we can define gameplay definitions here, but have the sndlib access it more easily

id_WAVE~beware_coward       equ_id 'AU00'
id_WAVE~beware_i_live       equ_id 'AU01'
id_WAVE~bounce              equ_id 'AU02'
id_WAVE~player_collect_crystal equ_id 'AU03'
id_WAVE~crystal_flash       equ_id 'AU04'
id_WAVE~EEERRAAURGH         equ_id 'AU05'
id_WAVE~i_am_sinistar       equ_id 'AU06'
id_WAVE~i_hunger_coward     equ_id 'AU07'
id_WAVE~i_hunger            equ_id 'AU08'
id_WAVE~max_bomb_pickup     equ_id 'AU09'
id_WAVE~message             equ_id 'AU10'
id_WAVE~new_ship            equ_id 'AU11'
id_WAVE~player_explosion_1  equ_id 'AU12'
id_WAVE~player_explosion_2  equ_id 'AU13'
id_WAVE~player_shot         equ_id 'AU14'
; id_WAVE~robotron_shot     equ_id 'AU15'
id_WAVE~run_coward          equ_id 'AU16'
id_WAVE~run_run_run         equ_id 'AU17'
; id_WAVE~scratchy_static_1 equ_id 'AU18'
; id_WAVE~scratchy_static_2 equ_id 'AU19'
id_WAVE~sinibomb_launch     equ_id 'AU20'
id_WAVE~tough_luck_loss     equ_id 'AU21'
id_WAVE~turn_start          equ_id 'AU22'
id_WAVE~explosion           equ_id 'AU23'
id_WAVE~warrior_shot        equ_id 'AU24'
; id_WAVE~wavy_tone         equ_id 'AU25'
id_WAVE~worker_collect_crystal equ_id 'AU26'
id_WAVE~deliver_crystal     equ_id 'AU27'

id_sound_data~player_shot               equ 0
id_sound_data~warrior_shot              equ 1
id_sound_data~player_collect_crystal    equ 2
id_sound_data~worker_collect_crystal    equ 3
id_sound_data~bounce                    equ 4
id_sound_data~explosion                 equ 5
id_sound_data~message                   equ 6
id_sound_data~deliver_crystal           equ 7
id_sound_data~max_bomb_pickup           equ 8
id_sound_data~new_ship                  equ 9
id_sound_data~player_explosion_1        equ 10
id_sound_data~player_explosion_2        equ 11
id_sound_data~crystal_flash             equ 12
id_sound_data~sinibomb_launch           equ 13
id_sound_data~turn_start                equ 14
id_sound_data~tough_luck_loss           equ 15
id_sound_data~i_hunger                  equ 16
id_sound_data~beware_i_live             equ 17
id_sound_data~beware_coward             equ 18
id_sound_data~EEERRAAURGH               equ 19
id_sound_data~i_am_sinistar             equ 20
id_sound_data~i_hunger_coward           equ 21
id_sound_data~run_coward                equ 22
id_sound_data~run_run_run               equ 23

; These must match the order they appear in the sfx_entries table
id_sfx~player_shot                      equ 0
id_sfx~warrior_shot                     equ 1
id_sfx~player_collect_crystal           equ 2
id_sfx~worker_collect_crystal           equ 3
id_sfx~bounce                           equ 4
id_sfx~explosion                        equ 5
id_sfx~message                          equ 6
id_sfx~deliver_crystal                  equ 7
id_sfx~max_bomb_pickup                  equ 8
id_sfx~new_ship                         equ 9
id_sfx~player_explosion_1               equ 10
id_sfx~player_explosion_2               equ 11
id_sfx~crystal_flash                    equ 12
id_sfx~sinibomb_launch                  equ 13
id_sfx~turn_start                       equ 14
id_sfx~tough_luck_loss                  equ 15
id_sfx~i_hunger                         equ 16
id_sfx~beware_i_live                    equ 17
id_sfx~beware_coward                    equ 18
id_sfx~EEERRAAURGH                      equ 19
id_sfx~i_am_sinistar                    equ 20
id_sfx~i_hunger_coward                  equ 21
id_sfx~run_coward                       equ 22
id_sfx~run_run_run                      equ 23
id_sfx~EEERRAAURGH_death                equ 24

; Need to know some lengths in ticks.  Could figure this out on load and store in a global
id_sfx~EEERRAAURGH~tick_length          equ 146             ; (2436 milliseconds) * 16.666

sfx_priority~low            equ 0
sfx_priority~medium         equ 1
sfx_priority~high           equ 2

sfx_priority~default        equ sfx_priority~medium
sfx_flags~default           equ 0

sfx_entries                 anop
; id_sfx~player_shot
                            dc i'id_sound_data~player_shot'
                            dc i'sfx_priority~default'
; id_sfx~warrior_shot
                            dc i'id_sound_data~warrior_shot'
                            dc i'sfx_priority~default'
; id_sfx~player_collect_crystal
                            dc i'id_sound_data~player_collect_crystal'
                            dc i'sfx_priority~default'
; id_sfx~worker_collect_crystal
                            dc i'id_sound_data~worker_collect_crystal'
                            dc i'sfx_priority~default'
; id_sfx~bounce
                            dc i'id_sound_data~bounce'
                            dc i'sfx_priority~default'
; id_sfx~explosion
                            dc i'id_sound_data~explosion'
                            dc i'sfx_priority~default'
; id_sfx~message
                            dc i'id_sound_data~message'
                            dc i'sfx_priority~default'
; id_sfx~deliver_crystal
                            dc i'id_sound_data~deliver_crystal'
                            dc i'sfx_priority~default'
; id_sfx~max_bomb_pickup
                            dc i'id_sound_data~max_bomb_pickup'
                            dc i'sfx_priority~default'
; id_sfx~new_ship
                            dc i'id_sound_data~new_ship'
                            dc i'sfx_priority~default'
; id_sfx~player_explosion_1
                            dc i'id_sound_data~player_explosion_1'
                            dc i'sfx_priority~default'
; id_sfx~player_explosion_2
                            dc i'id_sound_data~player_explosion_2'
                            dc i'sfx_priority~default'
; id_sfx~crystal_flash
                            dc i'id_sound_data~crystal_flash'
                            dc i'sfx_priority~default'
; id_sfx~sinibomb_launch
                            dc i'id_sound_data~sinibomb_launch'
                            dc i'sfx_priority~default'
; id_sfx~turn_start
                            dc i'id_sound_data~turn_start'
                            dc i'sfx_priority~default'
; id_sfx~tough_luck_loss
                            dc i'id_sound_data~tough_luck_loss'
                            dc i'sfx_priority~default'
; id_sfx~i_hunger
                            dc i'id_sound_data~i_hunger'
                            dc i'sfx_priority~default'
; id_sfx~beware_i_live
                            dc i'id_sound_data~beware_i_live'
                            dc i'sfx_priority~default'
; id_sfx~beware_coward
                            dc i'id_sound_data~beware_coward'
                            dc i'sfx_priority~default'
; id_sfx~EEERRAAURGH
                            dc i'id_sound_data~EEERRAAURGH'
                            dc i'sfx_priority~default'
; id_sfx~i_am_sinistar
                            dc i'id_sound_data~i_am_sinistar'
                            dc i'sfx_priority~default'
; id_sfx~i_hunger_coward
                            dc i'id_sound_data~i_hunger_coward'
                            dc i'sfx_priority~default'
; id_sfx~run_coward
                            dc i'id_sound_data~run_coward'
                            dc i'sfx_priority~default'
; id_sfx~run_run_run
                            dc i'id_sound_data~run_run_run'
                            dc i'sfx_priority~default'
; id_sfx~EEERRAAURGH_death
                            dc i'id_sound_data~EEERRAAURGH'
                            dc i'sfx_priority~default'

                            end

; -----------------------------------------------------------------------------
; Initialize the gameplay sound system
gameplay_sound_initialize   start seg_gameplay
                            using gameplay_sound_data

                            debugtag 'initialize_gameplay_sound'

; Using oscillator bindings 0-10 for non-streamed sounds
; This will use oscillators 0-23
                            pushsword #0                    ; binding index
                            pushsword #11                   ; binding count
                            pushsword #0                    ; oscillator index
                            pushsword #2                    ; 2 oscillators per binding
                            pushsword #id_oscillator_group~resident
                            jsl sndlib_set_oscillator_binding_range

; Using oscillator bindings 11-12 for streamed sounds
; This will use oscillators 24-29
; Each streamed entry needs a binding to an area in DOC RAM for streaming.
                            pushsword #11                   ; binding index
                            pushsword #24                   ; oscillator index
                            pushsword #3                    ; 3 oscillators per binding
                            pushsword #id_oscillator_group~streaming
                            pushsword #1                    ; DOC RAM
                            pushsword #doc_table_size_512
                            jsl sndlib_packed_doc_binding
                            pha
                            jsl sndlib_set_oscillator_binding

                            pushsword #12                   ; binding index
                            pushsword #27                   ; oscillator index
                            pushsword #3                    ; 3 oscillators per binding
                            pushsword #id_oscillator_group~streaming
                            pushsword #127                   ; DOC RAM.  Note, filling in at the end for better packing.
                            pushsword #doc_table_size_512
                            jsl sndlib_packed_doc_binding
                            pha
                            jsl sndlib_set_oscillator_binding

; Load the sounds

; Doc RAM usage

; $0000-$00FF               - $0100, timer
; $0100-$01FF               - $0100, free?
; $0200-$03FF               - $0200, streaming buffer 1
; $0400-$07FF               - $0400, id_sound_data~bounce
; $0800-$0FFF               - $0800, id_sound_data~worker_collect_crystal
; $1000-$1FFF               - $1000, id_sound_data~player_shot
; $2000-$2FFF               - $1000, id_sound_data~warrior_shot
; $3000-$3FFF               - $1000, id_sound_data~player_collect_crystal
; $4000-$7FFF               - $4000, id_sound_data~explosion
; $8000-$BFFF               - $4000, id_sound_data~sinibomb_launch
; $C000-$DFFF               - $2000, id_sound_data~crystal_flash
; $E000-$E7FF               - $0800, id_sound_data~deliver_crystal
; $FE00-$FFFF               - $0200, streaming buffer 2

                            pushsword #id_sound_data~player_shot
                            pushdword #id_WAVE~player_shot
                            pushsword #1                                ; at $1000
                            pushsword #doc_table_size_4096
                            jsl sndlib_load_sound_data

                            pushsword #id_sound_data~warrior_shot
                            pushdword #id_WAVE~warrior_shot
                            pushsword #2                                ; at $2000
                            pushsword #doc_table_size_4096
                            jsl sndlib_load_sound_data

                            pushsword #id_sound_data~player_collect_crystal
                            pushdword #id_WAVE~player_collect_crystal
                            pushsword #3                                ; at $3000
                            pushsword #doc_table_size_4096
                            jsl sndlib_load_sound_data

                            pushsword #id_sound_data~worker_collect_crystal
                            pushdword #id_WAVE~worker_collect_crystal
                            pushsword #1
                            pushsword #doc_table_size_2048              ; at $0800
                            jsl sndlib_load_sound_data

                            pushsword #id_sound_data~bounce
                            pushdword #id_WAVE~bounce
                            pushsword #1                                ; at $0400
                            pushsword #doc_table_size_1024
                            jsl sndlib_load_sound_data

                            pushsword #id_sound_data~explosion
                            pushdword #id_WAVE~explosion
                            pushsword #1                                ; at $4000
                            pushsword #doc_table_size_16384
                            jsl sndlib_load_sound_data

                            pushsword #id_sound_data~sinibomb_launch
                            pushdword #id_WAVE~sinibomb_launch
                            pushsword #2                                ; at $8000
                            pushsword #doc_table_size_16384
                            jsl sndlib_load_sound_data

                            pushsword #id_sound_data~crystal_flash
                            pushdword #id_WAVE~crystal_flash
                            pushsword #6                                ; at $C000
                            pushsword #doc_table_size_8192
                            jsl sndlib_load_sound_data

                            pushsword #id_sound_data~deliver_crystal
                            pushdword #id_WAVE~deliver_crystal
                            pushsword #28                               ; at $E000
                            pushsword #doc_table_size_2048
                            jsl sndlib_load_sound_data

; Non-resident definitions.  Not all of these are 'large', some are just infrequently used.
; If there is DOC RAM available to load any of these, add them in at a later date, when all
; the higher frequency ones are loaded.

                            pushsword #id_sound_data~turn_start
                            pushdword #id_WAVE~turn_start
                            pushsword #0                                ; non-resident
                            pushsword #0
                            jsl sndlib_load_sound_data

                            pushsword #id_sound_data~tough_luck_loss
                            pushdword #id_WAVE~tough_luck_loss
                            pushsword #0                                ; non-resident
                            pushsword #0
                            jsl sndlib_load_sound_data

                            pushsword #id_sound_data~message
                            pushdword #id_WAVE~message
                            pushsword #0                                ; non-resident
                            pushsword #0
                            jsl sndlib_load_sound_data

                            pushsword #id_sound_data~max_bomb_pickup
                            pushdword #id_WAVE~max_bomb_pickup
                            pushsword #0                                ; non-resident
                            pushsword #0
                            jsl sndlib_load_sound_data

                            pushsword #id_sound_data~new_ship
                            pushdword #id_WAVE~new_ship
                            pushsword #0                                ; non-resident
                            pushsword #0
                            jsl sndlib_load_sound_data

                            pushsword #id_sound_data~player_explosion_1
                            pushdword #id_WAVE~player_explosion_1
                            pushsword #0                                ; non-resident
                            pushsword #0
                            jsl sndlib_load_sound_data

                            pushsword #id_sound_data~player_explosion_2
                            pushdword #id_WAVE~player_explosion_2
                            pushsword #0                                ; non-resident
                            pushsword #0
                            jsl sndlib_load_sound_data

                            pushsword #id_sound_data~i_hunger
                            pushdword #id_WAVE~i_hunger
                            pushsword #0                                ; non-resident
                            pushsword #0
                            jsl sndlib_load_sound_data

                            pushsword #id_sound_data~beware_i_live
                            pushdword #id_WAVE~beware_i_live
                            pushsword #0                                ; non-resident
                            pushsword #0
                            jsl sndlib_load_sound_data

                            pushsword #id_sound_data~beware_coward
                            pushdword #id_WAVE~beware_coward
                            pushsword #0                                ; non-resident
                            pushsword #0
                            jsl sndlib_load_sound_data

                            pushsword #id_sound_data~EEERRAAURGH
                            pushdword #id_WAVE~EEERRAAURGH
                            pushsword #0                                ; non-resident
                            pushsword #0
                            jsl sndlib_load_sound_data

                            pushsword #id_sound_data~i_am_sinistar
                            pushdword #id_WAVE~i_am_sinistar
                            pushsword #0                                ; non-resident
                            pushsword #0
                            jsl sndlib_load_sound_data

                            pushsword #id_sound_data~i_hunger_coward
                            pushdword #id_WAVE~i_hunger_coward
                            pushsword #0                                ; non-resident
                            pushsword #0
                            jsl sndlib_load_sound_data

                            pushsword #id_sound_data~run_coward
                            pushdword #id_WAVE~run_coward
                            pushsword #0                                ; non-resident
                            pushsword #0
                            jsl sndlib_load_sound_data

                            pushsword #id_sound_data~run_run_run
                            pushdword #id_WAVE~run_run_run
                            pushsword #0                                ; non-resident
                            pushsword #0
                            jsl sndlib_load_sound_data

                            rtl

                            end

; -----------------------------------------------------------------------------
gameplay_sound_uninitialize start seg_gameplay

                            rtl

                            end
