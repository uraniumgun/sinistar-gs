                                copy lib/source/debug.definitions.asm
                                copy lib/source/system.ids.asm
                                copy lib/source/object.definitions.asm
                                copy lib/source/container.definitions.asm
                                copy lib/source/fixed.buffer.pool.definitions.asm
                                copy lib/source/grlib.definitions.asm
                                copy lib/source/grlib.sprite.definitions.asm
                                copy lib/source/framelib.definitions.asm
                                copy lib/source/grlib.entity.definitions.asm
                                copy lib/source/grlib.entity.sort.definitions.asm
                                copy lib/source/id.list.definitions.asm
                                copy lib/source/shape.definitions.asm

                                copy source/app.system.ids.asm
                                copy source/playfield.definitions.asm
                                copy source/playfield.entity.definitions.asm
                                copy source/app.debug.definitions.asm
                                copy source/app.ui.definitions.asm
                                copy source/gameplay.constants.asm

                                mcopy generated/playfield.scanner.macros

                                longa on
                                longi on

; --------------------------------------------------------------------------------------------
; Note that the scanner is in the seg_entity segment, so it is in the same segement as
; the contol tables for the entities that it will display.
playfield_scanner_data          data seg_entity
                                using rock_entity_manager_data
                                using worker_entity_manager_data
                                using warrior_entity_manager_data
                                using sinistar_entity_manager_data
                                using bomb_entity_manager_data
;                               using crystal_entity_manager_data
                                using appdata

; gameplay_playfield_width / gameplay_ui_scanner_width
playfield_scanner_width_shift_ratio gequ 5
; gameplay_playfield_height / gameplay_ui_scanner_height
playfield_scanner_height_shift_ratio gequ 5

; Address of the top left pixel of the scanner
; Where it is, bank relative
playfield_scanner_top_left_local gequ $2000+(gameplay_ui_scanner_y*160)+(gameplay_ui_scanner_x/2)
; Full address
playfield_scanner_top_left      gequ $010000+playfield_scanner_top_left_local
; And one line below it
playfield_scanner_top_left_y_plus_1 gequ playfield_scanner_top_left+160

; An array of pointers to the lists for each type of entity to
; draw in the scanner.  This is not in entity ID order, I want to
; draw sinistar, after the other entities, so he is always on top.
playfield_scanner_entity_instance_lists_size gequ 4
playfield_scanner_entity_instance_lists anop
                                dc a4'rock_entity_count'        ; entity_type~planetoid
                                dc a4'worker_entity_count'      ; entity_type~worker
                                dc a4'warrior_entity_count'     ; entity_type~warrior
                                dc a4'sinistar_entity_count'    ; entity_type~sinistar
                                dc a4'bomb_entity_count'        ; entity_type~bomb
                                dc a4'0'                        ; end of list

playfield_scanner_entity_instance_colors anop
                                dc i'appdata~ui_color~blue~bits,(appdata~ui_color~blue~pixel|grlib~right_pixel_shift)+(appdata~ui_color~blue~pixel|grlib~high_left_pixel_shift)'                    ; entity_type~planetoid
                                dc i'appdata~ui_color~red~bits,(appdata~ui_color~red~pixel|grlib~right_pixel_shift)+(appdata~ui_color~red~pixel|grlib~high_left_pixel_shift)'                       ; entity_type~worker
                                dc i'appdata~ui_color~light_gray~bits,(appdata~ui_color~light_gray~pixel|grlib~right_pixel_shift)+(appdata~ui_color~light_gray~pixel|grlib~high_left_pixel_shift)'  ; entity_type~warrior
                                dc i'appdata~ui_color~yellow~bits,(appdata~ui_color~yellow~pixel|grlib~right_pixel_shift)+(appdata~ui_color~yellow~pixel|grlib~high_left_pixel_shift)'              ; entity_type~sinistar
                                dc i'appdata~ui_color~yellow~bits,(appdata~ui_color~yellow~pixel|grlib~right_pixel_shift)+(appdata~ui_color~yellow~pixel|grlib~high_left_pixel_shift)'              ; entity_type~bomb

                                end

; --------------------------------------------------------------------------------------------
playfield_scanner_initialize    start seg_entity
                                using playfield_scanner_data

                                debugtag 'initialize'
                                debugtag 'playfield_scanner'

                                rtl
                                end

; --------------------------------------------------------------------------------------------
playfield_scanner_uninitialize  start seg_entity
                                using playfield_scanner_data

                                debugtag 'uninitialize'
                                debugtag 'playfield_scanner'

                                rtl

                                end
; --------------------------------------------------------------------------------------------
; Draw the scanner area.
; There are many assumed things, to help speed this up.
; * The size and location of the scanner is fixed.
; * The ratio of sizes between the world coordinates and the scanner coordinates is a power of 2.
; * The scanner objects are drawn as 2x2 pixel blocks.
playfield_scanner_update        start seg_entity
                                using playfield_scanner_data
                                using YLookupData
                                using grlib_global_equates
                                using grlib_global_data
                                using rock_entity_manager_data

                                debugtag 'update'
                                debugtag 'playfield_scanner'

; Using the grlib_dp scratch space
                                begin_struct grdp~caller_scratch_buffer
pEntityList                     decl ptr
wList                           decl word
wCount                          decl word
wOffset                         decl word
wEvenColor                      decl word
wOddColor                       decl word
                                end_struct

; Save databank register
                                phb

; Set the databank to bank $01
                                pea $0101
                                plb
                                plb

; 5 cycles per stz * 8, * 32 = 1280 cycles to erase the area.
; 768 bytes
                                UnrolledBlockSTZ playfield_scanner_top_left_local,16,32         ; Erases 16 (bytes), by 32 lines

; Set databank to the local bank
                                phk
                                plb

; Use the grlib_dp scratch space, since we need that DP later.

                                phd
                                lda >grlib~dp
                                tcd

                                stz <wList

list_loop                       lda <wList
                                shiftleft 2
                                tax
                                lda playfield_scanner_entity_instance_lists,x
                                sta <pEntityList
                                lda playfield_scanner_entity_instance_lists+2,x
                                sta <pEntityList+2
                                jeq done

                                lda [<pEntityList]
                                jeq none
                                sta <wCount

                                lda playfield_scanner_entity_instance_colors,x
                                sta <wEvenColor
                                lda playfield_scanner_entity_instance_colors+2,x
                                sta <wOddColor
; Skip the count
                                lda <pEntityList
                                inc a
                                inc a
                                sta <pEntityList

loop                            lda [<pEntityList]
                                tax                             ; only need the short pointer
                                lda <pEntityList                ; advance to the next
                                inc a
                                inc a
                                sta <pEntityList

                                getword {x},>entities_root+playfield_entity~state_flags
                                bit #playfield_entity~state_marked_for_removal
                                bne next

                                getword {x},>entities_root+playfield_entity~grentity+grlib_entity~x
                                tay                     ; save this for later
                                getword {x},>entities_root+playfield_entity~grentity+grlib_entity~y
                                clc
                                adc #gameplay_playfield_max_y
                                cmp #gameplay_playfield_height
                                bge next
                                shiftright playfield_scanner_width_shift_ratio
                                asl a
                                tax
                                lda >gYLookup,x
                                sta <wOffset

                                tya
                                clc
                                adc #gameplay_playfield_max_x
                                cmp #gameplay_playfield_width
                                bge next
                                shiftright playfield_scanner_width_shift_ratio
                                bit #$0001
                                bne odd

                                lsr a                           ; to bytes
                                adc <wOffset                    ; add to Y offset.  We can assume the carry is already clear
                                tax
                                shortm
                                lda <wEvenColor
                                sta >playfield_scanner_top_left,x
                                sta >playfield_scanner_top_left_y_plus_1,x
                                longm
                                bra next

odd                             anop

                                lsr a                           ; to bytes
                                clc
                                adc <wOffset                    ; add to Y offset.
                                tax
                                lda >playfield_scanner_top_left,x
                                and #grlib~left_pixel_mask+grlib~high_right_pixel_mask
                                ora <wOddColor
                                sta >playfield_scanner_top_left,x

                                lda >playfield_scanner_top_left_y_plus_1,x
                                and #grlib~left_pixel_mask+grlib~high_right_pixel_mask
                                ora <wOddColor
                                sta >playfield_scanner_top_left_y_plus_1,x

next                            dec <wCount
                                bne loop

none                            anop
                                inc <wlist
                                brl list_loop

done                            anop

; Copy to the screen

; This will do an unrolled block of TSBs.  A custom block of PEI, with the requisite stack/dp adjustments
; would be a bit faster, but this has the benefit of not needing to disable the interrupts.

                                shr_shadow on,push
; 8 cycles per tsb * 8, * 32 = 2048 cycles
; 768 bytes
                                lda #0
                                UnrolledBlockTSB playfield_scanner_top_left_local,16,32
                                shr_shadow off,pop

; Can optionally use the general PEI code, but with the setup overhead, this is slower than the dedicated code.
                                ago .skip
                                lda #gameplay_ui_scanner_x
                                sta <draw_x
                                lda #gameplay_ui_scanner_y
                                sta <draw_y
                                lda #gameplay_ui_scanner_width
                                sta <area_width
                                lda #gameplay_ui_scanner_height
                                sta <area_height
                                jsl grlib_custom_alt_screen_to_screen_rect_noclip
.skip

                                pld

                                restoredatabank
                                rtl

                                end

