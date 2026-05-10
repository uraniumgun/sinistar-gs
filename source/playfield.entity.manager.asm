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
                                copy lib/source/grlib.update.rects.definitions.asm
                                copy lib/source/id.list.definitions.asm
                                copy lib/source/shape.definitions.asm

                                copy source/app.system.ids.asm
                                copy source/playfield.definitions.asm
                                copy source/playfield.entity.definitions.asm
                                copy source/collision.definitions.asm
                                copy source/app.debug.definitions.asm

                                mcopy generated/playfield.entity.manager.macros

                                longa on
                                longi on

; --------------------------------------------------------------------------------------------
playfield_entity_manager_data   data seg_entity
                                using rock_entity_manager_data
                                using worker_entity_manager_data
                                using warrior_entity_manager_data
                                using sinistar_entity_manager_data
                                using crystal_entity_manager_data
                                using shot_entity_manager_data
                                using explosion_entity_manager_data
                                using bomb_entity_manager_data

; Entity Manager object
playfield_entity_manager~pool   gequ 0
sizeof~playfield_entity_manager gequ playfield_entity_manager~pool+sizeof~fixed_buffer_pool

global_playfield_entity_manager_is_initialized dc i'0'

; The global entity manager
global_playfield_entity_manager ds sizeof~playfield_entity_manager

acceleration_functions          dc a2'asr_0'
                                dc a2'asr_1'
                                dc a2'asr_2'
                                dc a2'asr_3'
                                dc a2'asr_4'
                                dc a2'asr_5'
                                dc a2'asr_6'
                                dc a2'asr_7'

entity_type_names               anop
                                dc a4'entity_type_name_planetoid'
                                dc a4'entity_type_name_player'
                                dc a4'entity_type_name_sinistar'
                                dc a4'entity_type_name_bomb'
                                dc a4'entity_type_name_crystal'
                                dc a4'entity_type_name_worker'
                                dc a4'entity_type_name_warrior'
                                dc a4'entity_type_name_player_shot'
                                dc a4'entity_type_name_warrior_shot'
                                dc a4'entity_type_name_explosion'

entity_type_name_planetoid      cstring 'planetoid'
entity_type_name_player         cstring 'player'
entity_type_name_sinistar       cstring 'sinistar'
entity_type_name_bomb           cstring 'bomb'
entity_type_name_crystal        cstring 'crystal'
entity_type_name_worker         cstring 'worker'
entity_type_name_warrior        cstring 'warrior'
entity_type_name_player_shot    cstring 'p_shot'
entity_type_name_warrior_shot   cstring 'w_shot'
entity_type_name_explosion      cstring 'explosion'

entity_type_name_unknown        cstring 'unknown'

; An array of pointers to the lists for each type of entity.
; Some entries, point to the a common list, (shots)
playfield_entity_instance_lists anop
                                dc a4'rock_entity_count'        ; entity_type~planetoid
                                dc a4'0'                        ; entity_type~player
                                dc a4'sinistar_entity_count'    ; entity_type~sinistar
                                dc a4'bomb_entity_count'        ; entity_type~bomb
                                dc a4'crystal_entity_count'     ; entity_type~crystal
                                dc a4'worker_entity_count'      ; entity_type~worker
                                dc a4'warrior_entity_count'     ; entity_type~warrior
                                dc a4'shot_entity_count'        ; entity_type~player_shot
                                dc a4'shot_entity_count'        ; entity_type~warrior_shot
                                dc a4'explosion_entity_count'   ; entity_type~explosion

; Debug Handler
playfield_entity_debug_handler_priority equ $0080          ; later in the display order

playfield_entity_debug_handler dc i'playfield_entity_debug_handler_id'
                            dc i'playfield_entity_debug_handler_priority'
                            dc a4'playfield_entity_debug_display'
                            dc a4'playfield_entity_debug_show_help'
                            dc a4'playfield_entity_debug_keypress'

; What entity type to display in the debug list
debug_display_entity_type   dc i'0'

playfield_entity~speed_modifier ds 2          ; flag to signal how to adjust 'speed' calculations for the frame.

                                end
; --------------------------------------------------------------------------------------------
playfield_entity_manager_errors     data seg_entity

playfield_entity_manager_error_none equ 0
playfield_entity_manager_error_null_pointer equ system_id_playfield_entity_manager+1
playfield_entity_manager_error_allocation equ system_id_playfield_entity_manager+2
playfield_entity_manager_error_not_managed equ system_id_playfield_entity_manager+3
playfield_entity_manager_error_invalid_parameter equ system_id_playfield_entity_manager+4
playfield_entity_manager_error_out_of_ids equ system_id_playfield_entity_manager+5

                                end

; --------------------------------------------------------------------------------------------
; Initialize the global entity manager.
; This will allocate the global_playfield_entity_manager object and make it ready for use.
; It will allocate a pool for managing entity instances.
; Having the manager allocate entity instances, rather than just using the sba,
; allows for better tracking, as these will be the most pref-intensive objects of the application.
;
; Note that this manager provides the fixed buffer object for the entities, however the allocation
; and deallocation is done in the playfield.entity.asm file, using playfield_entity_new and playfield_entity_delete
;
playfield_entity_manager_initialize start seg_entity
                                using playfield_entity_manager_data

                                debugtag 'initialize'
                                debugtag 'playfield_entity_manager'

                                lda >global_playfield_entity_manager_is_initialized
                                bne is_initialized

; Using fully dynamic allocation?
                                aif grlib~use_static_entity_buffer=1,.skip
                                pushptr #global_playfield_entity_manager
                                pushsword #32                                ; 32 entities per block.
                                jsl playfield_entity_manager_construct
.skip

; Using a fixed buffer?
                                aif grlib~use_static_entity_buffer=0,.skip
                                pushptr #global_playfield_entity_manager
                                jsl playfield_entity_manager_construct
.skip
                                bcs error

; Initalize the collision support
                                jsl collision_support_initialize

; Attach the debug display
                                pushptr #playfield_entity_debug_handler
                                pushsword #1                                    ; start off enabled
                                jsl appdebug_install_handler

                                lda #1
                                sta >global_playfield_entity_manager_is_initialized

is_initialized                  anop
error                           anop
                                rtl
                                end

; --------------------------------------------------------------------------------------------
; Uninitialize the global entity manager.
playfield_entity_manager_uninitialize start seg_entity
                                using playfield_entity_manager_data

                                debugtag 'uninitialize'
                                debugtag 'playfield_entity_manager'

                                lda >global_playfield_entity_manager_is_initialized
                                beq exit

                                pushptr #global_playfield_entity_manager
                                jsl playfield_entity_manager_destruct

                                jsl collision_support_uninitialize

                                lda #0
                                sta >global_playfield_entity_manager_is_initialized

exit                            anop
                                rtl

                                end

                                aif grlib~use_static_entity_buffer=1,.skip
; --------------------------------------------------------------------------------------------
; Make a new playfield_entity_manager.
; Note, this creates a standard fixed buffer pool, that is dynamically allocate.
;
; Params:
; pThis                 - the entity manager
; wBlockCapacity        - the number of entities per block allocation
; Returns:
; carry clear on success
playfield_entity_manager_construct start seg_entity
                                using playfield_entity_manager_data
                                using playfield_entity_manager_errors

                                debugtag 'construct'
                                debugtag 'playfield_entity_manager'

; Define our work area data
                                begin_locals
pArray                          decl ptr
work_area_size                  end_locals

                                sub (4:pThis,2:wBlockCapacity),work_area_size

                                testptr <pThis
                                beq null_pointer

                                pushptr <pThis,#playfield_entity_manager~pool
                                pushsword #sizeof~playfield_entity
                                lda <wBlockCapacity
                                bne ok_capacity
                                lda #32                                             ; Use an input of 0 as a signal to use the default.
ok_capacity                     pha
                                jsl fixed_buffer_pool_construct
                                bne allocation_error

                                clc
exit                            anop
                                retkc

null_pointer                    lda #playfield_entity_manager_error_null_pointer
allocation_error                jsl appdebug_set_last_error
                                bra exit
param_error                     lda #playfield_entity_manager_error_invalid_parameter
                                jsl appdebug_set_last_error
                                bra exit

                                end
.skip

                                aif grlib~use_static_entity_buffer=0,.skip
; --------------------------------------------------------------------------------------------
; Make a new playfield_entity_manager.
;
; Note, this assumes that a static buffer in a data segment will be used.
; This allows for indexed long addressing to access the entities, using OMF remapping.
;
; Params:
; pThis                 - the entity manager
; wBlockCapacity        - the number of entities per block allocation
; Returns:
; carry clear on success
playfield_entity_manager_construct start seg_entity
                                using playfield_entity_manager_data
                                using playfield_entity_manager_errors
                                using appdata_segment_data

                                debugtag 'construct'
                                debugtag 'playfield_entity_manager'

; Define our work area data
                                begin_locals
pArray                          decl ptr
work_area_size                  end_locals

                                sub (4:pThis),work_area_size

                                testptr <pThis
                                beq null_pointer

                                pushptr <pThis,#playfield_entity_manager~pool
                                pushdword #entity_buffers
                                pushsword #sizeof~playfield_entity
                                pushsword #entities_buffer_size/sizeof~playfield_entity
                                jsl fixed_buffer_pool_construct_static
                                bne allocation_error

                                clc
exit                            anop
                                retkc

null_pointer                    lda #playfield_entity_manager_error_null_pointer
allocation_error                jsl appdebug_set_last_error
                                bra exit
param_error                     lda #playfield_entity_manager_error_invalid_parameter
                                jsl appdebug_set_last_error
                                bra exit

                                end
.skip
; --------------------------------------------------------------------------------------------
; Destruct a entity manager.  All allocated entities will become invalid!
;
; Params:
; pThis                 - the entity manager
playfield_entity_manager_destruct start seg_entity
                                using playfield_entity_manager_data

                                debugtag 'destruct'
                                debugtag 'playfield_entity_manager'
; Define our work area data
                                begin_locals
work_area_size                  end_locals

                                sub (4:pThis),work_area_size

                                testptr <pThis
                                beq exit

                                pushptr <pThis,#playfield_entity_manager~pool
                                jsl fixed_buffer_pool_destruct

exit                            anop
                                ret
                                end

; --------------------------------------------------------------------------------------------
; Do any manager actions, needed for a new playfield entity construction.
; Returns:
; carry clear and 0 in acc if no error
playfield_entity_manager_on_entity_construct start seg_entity
                                using playfield_entity_manager_data
                                using playfield_entity_manager_errors

                                debugtag 'on_entity_construct'
                                debugtag 'playfield_entity_manager'

                                begin_locals
work_area_size                  end_locals

                                sub (4:pEntity),work_area_size

                                brk $99                             ; remove if this function gets used.
                                clc
exit                            retkc

                                end
; --------------------------------------------------------------------------------------------
playfield_entity_manager_on_entity_destruct start seg_entity
                                using playfield_entity_manager_data

                                debugtag 'on_entity_destruct'
                                debugtag 'playfield_entity_manager'

                                begin_locals
work_area_size                  end_locals

                                sub (4:pEntity),work_area_size

                                brk $99                             ; remove if this function gets used.

exit                            ret

                                end

; --------------------------------------------------------------------------------------------
; Functions to do an asr, x number of times.
; Since we only have lsr, we test if the upper bit was on, and if so,'or' them in at the end.

asr_7                       start seg_entity
                            bit #$8000
                            bne negative
                            shiftright 7
                            rts
negative                    anop
                            shiftright 7
                            ora #%1111111000000000
                            rts
                            end
;
asr_6                       start seg_entity
                            bit #$8000
                            bne negative
                            shiftright 6
                            rts
negative                    anop
                            shiftright 6
                            ora #%1111110000000000
                            rts
                            end
;
asr_5                       start seg_entity
                            bit #$8000
                            bne negative
                            shiftright 5
                            rts
negative                    anop
                            shiftright 5
                            ora #%1111100000000000
                            rts
                            end
;
asr_4                       start seg_entity
                            bit #$8000
                            bne negative
                            shiftright 4
                            rts
negative                    anop
                            shiftright 4
                            ora #%1111000000000000
                            rts
                            end
;
asr_3                       start seg_entity
                            bit #$8000
                            bne negative
                            shiftright 3
                            rts
negative                    anop
                            shiftright 3
                            ora #%1110000000000000
                            rts
                            end
;
asr_2                       start seg_entity
                            bit #$8000
                            bne negative
                            shiftright 2
                            rts
negative                    anop
                            shiftright 2
                            ora #%1100000000000000
                            rts
                            end
;
asr_1                       start seg_entity
                            bit #$8000
                            bne negative
                            shiftright 1
                            rts
negative                    anop
                            shiftright 1
                            ora #%1000000000000000
                            rts
                            end
;
asr_0                       start seg_entity
                            rts
                            end

; --------------------------------------------------------------------------------------------
; Get a playfield string name for its type, will return a valid string
;
; Params:
; wType                         - the entity type
playfield_entity_get_type_name  start seg_entity
                                using playfield_entity_manager_data

                                debugtag 'get_type_name'
                                debugtag 'playfield_entity'
; Define our work area data
                                begin_locals
result                          decl ptr
work_area_size                  end_locals

                                sub (2:wType),work_area_size

                                lda <wType
                                cmp #entity_type~count
                                blt ok_type
                                lda #entity_type_name_unknown
                                sta <result
                                lda #^entity_type_name_unknown
                                sta <result+2
                                bra exit
ok_type                         asl a
                                asl a
                                tax
                                lda >entity_type_names,x
                                sta <result
                                lda >entity_type_names+2,x
                                sta <result+2

exit                            ret 4:result
                                end

; -----------------------------------------------------------------------------
; Iterate over the update rects, drawing any sprites that overlap a rect.
; This can result in a sprite getting drawn more than once, but it should be clipped
; so that it will never overdraw itself.
;
; This implementation uses a sort list.  A sort list is a sorted, linked list of
; grlib_entity objects.
;
; It is expected that all the enties have been 'invalidated' at their current
; position, so that their bounds_rect, reflects where they are in the playfield.
;

playfield_draw_collision_list_into_invalidated_rects start seg_entity

                            using grlib_global_equates
                            using grlib_global_data
                            using grlib_update_rects_data
                            using grlib_update_rects_data2
                            using collision_entry_data

                            debugtag 'draw_cl_list_into_rects'

; Going to use values in the grlib scratch buffer area
                            begin_struct grdp~caller_scratch_buffer
wLeft                       decl word
wRight                      decl word
wClipLeft                   decl word
wClipRight                  decl word
wClipTop                    decl word
wClipBottom                 decl word
wRectCount                  decl word
wRectsOffset                decl word
pSortHeadEntry              decl ptr
pSortEntry                  decl ptr
spEntity                    decl ptr
                            end_struct

; Switch to the grlib dp
                            phd
                            lda >grlib~dp
                            tcd

                            lda >collision_entries~head_sptr
                            beq no_entries                                  ; pretty rare that it will be 0.

                            sta <pSortHeadEntry
                            lda #^collision~entry_pool                      ; All entries are in the same bank
                            sta <pSortEntry+2                               ; just store this once, and we will not change it.

; Using the databank where the update rects are located
                            lda #^update_rects
                            setdatabanktoreg a

                            ldx #urlib_group~update*2
                            lda |update_rects_count,x
                            beq no_rects

                            sta <wRectCount

; Copy the clip rect, we will be changing it
                            lda <clipx_left
                            sta <wClipLeft
                            lda <clipx_right
                            sta <wClipRight
                            lda <clipy_top
                            sta <wClipTop
                            lda <clipy_bottom
                            sta <wClipBottom

                            lda |update_rects_group_offset,x
                            sta <wRectsOffset
                            tax

; Get the update rect, these are screen-space rects and are already clipped to the playfield's clip rect.
loop                        anop
; Put the update rect into the grlib-clip rect, as well as some locals
                            lda |update_rects~left,x
                            sta <wLeft
                            and #$fffe                              ; make sure it is not odd
                            sta <clipx_left

                            lda |update_rects~right,x
                            sta <wRight
                            bit #1                                  ; make sure it is not odd
                            beq not_odd
                            inc a
not_odd                     sta <clipx_right

                            lda |update_rects~top,x
                            sta <clipy_top

                            lda |update_rects~bottom,x
                            sta <clipy_bottom

; We now have the clipped rect locally.  See what entries overlap it
                            jsr _pf_draw_sort_list

                            ldx <wRectsOffset
                            inx
                            inx
                            stx <wRectsOffset

                            dec <wRectCount
                            bne loop
; Restore the clip rect
                            lda <wClipTop
                            sta <clipy_top
                            lda <wClipBottom
                            sta <clipy_bottom
                            lda <wClipLeft
                            sta <clipx_left
                            lda <wClipRight
                            sta <clipx_right

no_rects                    restoredatabank
no_entries                  anop
                            pld
                            rtl
                            end

; -----------------------------------------------------------------------------
; This draws the collision list into the full view area.
;
; This implementation uses a sort list.  A sort list is a sorted, linked list of
; grlib_entity objects.
;
; It is expected that all the enties have been 'invalidated' at their current
; position, so that their bounds_rect, reflects where they are in the playfield.
;

playfield_draw_collision_list_into_view start seg_entity
                            using grlib_global_equates
                            using grlib_global_data
                            using grlib_update_rects_data
                            using grlib_update_rects_data2
                            using collision_entry_data
                            using gameplay_level_data

                            debugtag 'draw_cl_into_view'

; Going to use values in the grlib scratch buffer area
; Note, these are must be the same in the sub-functions
                            begin_struct grdp~caller_scratch_buffer
wLeft                       decl word
wRight                      decl word
wClipLeft                   decl word
wClipRight                  decl word
wClipTop                    decl word
wClipBottom                 decl word
wRectCount                  decl word
wRectsOffset                decl word
pSortHeadEntry              decl ptr
pSortEntry                  decl ptr
spEntity                    decl ptr
                            end_struct

; Switch to the grlib dp
                            phd
                            lda >grlib~dp
                            tcd

                            lda >collision_entries~head_sptr
                            beq no_entries                                  ; pretty rare that it will be 0.

                            sta <pSortHeadEntry
                            lda #^collision~entry_pool                      ; All entries are in the same bank
                            sta <pSortEntry+2                               ; just store this once, and we will not change it.

; Copy the clip rect, we will be changing it
                            lda <clipx_left
                            sta <wClipLeft
                            lda <clipx_right
                            sta <wClipRight
                            lda <clipy_top
                            sta <wClipTop
                            lda <clipy_bottom
                            sta <wClipBottom

                            lda >gameplay_level~playfield_view+playfield_view~bounds+grlib_rect~left
                            sta <clipx_left                                 ; expected to be an even value
                            sta <wLeft                                      ; used in sub-functions, expected to be the exact pixel value
                            lda >gameplay_level~playfield_view+playfield_view~bounds+grlib_rect~top
                            sta <clipy_top
                            lda >gameplay_level~playfield_view+playfield_view~bounds+grlib_rect~right
                            sta <clipx_right                                ; expected to be an even value
                            sta <wRight                                     ; used in sub-functions, expected to be the exact pixel value
                            lda >gameplay_level~playfield_view+playfield_view~bounds+grlib_rect~bottom
                            sta <clipy_bottom

                            jsr _pf_draw_sort_list

; Restore the clip rect
                            lda <wClipTop
                            sta <clipy_top
                            lda <wClipBottom
                            sta <clipy_bottom
                            lda <wClipLeft
                            sta <clipx_left
                            lda <wClipRight
                            sta <clipx_right

no_rects                    anop
no_entries                  anop
                            pld
                            rtl
                            end

; - Local ---------------------------------------------------------------------
; Making this a local function, just so its more readable, and we have less need for long branches
; Also making it a fully separate function, so that ORCA exports the function
; to the linker map, so I can see it in the profiler.
_pf_draw_sort_list          private seg_entity
                            using grlib_global_equates
                            using grlib_global_data
                            using grlib_update_rects_data
                            using grlib_update_rects_data2

; Duplicate the DP layout from the parent call
                            begin_struct grdp~caller_scratch_buffer
wLeft                       decl word
wRight                      decl word
wClipLeft                   decl word
wClipRight                  decl word
wClipTop                    decl word
wClipBottom                 decl word
wRectCount                  decl word
wRectsOffset                decl word
pSortHeadEntry              decl ptr
pSortEntry                  decl ptr
spEntity                    decl ptr
                            end_struct

                            lda <pSortHeadEntry
                            sta <pSortEntry

_draw_sprite_loop           getword [<pSortEntry],#collision_entry~entity_sptr
                            beq sprite_next
                            sta <spEntity
                            tax                     ; entity short pointer in x

                            getword {x},>entities_root+grlib_entity~sprite+sprite~primary_shape_ptr+2
                            beq sprite_next         ; no shape?
; See if it is completely clipped
                            getword {x},>entities_root+grlib_entity~sprite+sprite~bounds~left
                            cmp <wRight
                            bsge sprite_next
                            sta <draw_x

                            getword {x},>entities_root+grlib_entity~sprite+sprite~bounds~right
                            cmp <wLeft
                            bslt sprite_next
                            putword {x},>entities_root+grlib_entity~sprite+sprite~erase~right

                            getword {x},>entities_root+grlib_entity~sprite+sprite~bounds~top
                            cmp <clipy_bottom
                            bsge done                   ; Because we are using a list, sorted by the top of the sprites, if this is off the bottom, then the rest will be too.
                            sta <draw_y

                            getword {x},>entities_root+grlib_entity~sprite+sprite~bounds~bottom
                            cmp <clipy_top
                            bslt sprite_next
                            putword {x},>entities_root+grlib_entity~sprite+sprite~erase~bottom

; The sprite falls in the rect, draw it
                            jsr _pf_draw_sprite
                            ldx <spEntity

sprite_next                 anop
; See if we have any child entities.
                            getword {x},>entities_root+grlib_entity~child_entity_ptr+2
                            bne _draw_children

; Advance to the next entry in the linked list, note all the entries are in the same bank
; so we only advance the lower word
next_sort_list_entry        getword [<pSortEntry],#collision_entry~next_sptr
                            sta <pSortEntry
                            bne _draw_sprite_loop

done                        rts

; Draw all the children
_draw_children              anop
                            getword {x},>entities_root+grlib_entity~child_entity_ptr
                            sta <spEntity
                            tax                         ; short pointer in x

sibling_loop                anop
                            getword {x},>entities_root+grlib_entity~sprite+sprite~primary_shape_ptr+2
                            beq no_sibling_shape         ; no shape?
; See if it is completely clipped
                            getword {x},>entities_root+grlib_entity~sprite+sprite~bounds~left
                            cmp <wRight
                            bsge no_sibling_shape
                            sta <draw_x

                            getword {x},>entities_root+grlib_entity~sprite+sprite~bounds~right
                            cmp <wLeft
                            bslt no_sibling_shape
                            putword {x},>entities_root+grlib_entity~sprite+sprite~erase~right

                            getword {x},>entities_root+grlib_entity~sprite+sprite~bounds~top
                            cmp <clipy_bottom
                            bsge no_sibling_shape
                            sta <draw_y

                            getword {x},>entities_root+grlib_entity~sprite+sprite~bounds~bottom
                            cmp <clipy_top
                            bslt no_sibling_shape
                            putword {x},>entities_root+grlib_entity~sprite+sprite~erase~bottom

; The sprite falls in the rect, draw it
                            jsr _pf_draw_sprite
                            ldx <spEntity

no_sibling_shape            getword {x},>entities_root+grlib_entity~sibling_entity_ptr          ; using short pointers for the siblings
                            beq next_sort_list_entry
                            sta <spEntity
                            tax
                            bra sibling_loop

                            rts
                            end

; - Local ---------------------------------------------------------------------
; Draw a single sprite from <spEntity, at <draw_x, <draw_y
; This assumes clipping has been done.
; Making it a fully separate function, so that ORCA exports the function
; to the linker map, so I can see it in the profiler, and so this can be re-used.
_pf_draw_sprite             private seg_entity
                            using grlib_global_equates
                            using grlib_global_data
                            using grlib_update_rects_data
                            using grlib_update_rects_data2

                            getword {x},>entities_root+grlib_entity~sprite+sprite~primary_shape_ptr
                            sta <shape_ptr
                            getword {x},>entities_root+grlib_entity~sprite+sprite~primary_shape_ptr+2
                            sta <shape_ptr+2

; At this point, we assume that the bounds rect was generated, so that the upper left of the rect,
; is the draw location of the sprite, pre-adjusted for origin drawing.

; As we were doing the clipping, we turned the sprites bounds into a screen space rect.
; Finish filling in the erase rect for later
                            lda <draw_x
                            putword {x},>entities_root+grlib_entity~sprite+sprite~erase~left
                            lda <draw_y
                            putword {x},>entities_root+grlib_entity~sprite+sprite~erase~top

                            getword {x},>entities_root+grlib_entity~sprite+sprite~info
                            ora #sprite~info~needs_erase
                            putword {x},>entities_root+grlib_entity~sprite+sprite~info

                            getword [<shape_ptr],#shapedef~width
                            sta <shape_width

                            getword [<shape_ptr],#shapedef~height
                            sta <shape_height

                            getword {x},>entities_root+grlib_entity~sprite+sprite~secondary_shape_ptr+2
                            beq is_clipped                 ; null high word == null pointer

; See if the shape will be clipped at all
                            lda <draw_x
                            cmp <clipx_left
                            bslt is_clipped
                            clc
                            adc <shape_width
                            dec a                           ; -1 to compensate for the bge test
                            cmp <clipx_right
                            bsge is_clipped

                            lda <draw_y
                            cmp <clipy_top
                            bslt is_clipped
                            clc
                            adc <shape_height
                            dec a                           ; -1 to compensate for the bge test
                            cmp <clipy_bottom
                            bsge is_clipped

; The shape is not clipped, we can switch to the shape the does not support clipping
                            getword {x},>entities_root+grlib_entity~sprite+sprite~secondary_shape_ptr+2
                            putword <shape_ptr+2
                            getword {x},>entities_root+grlib_entity~sprite+sprite~secondary_shape_ptr
                            putword <shape_ptr

is_clipped                  anop
not_clipped                 anop

; Do we have a custom draw function?
                            getword {x},>entities_root+playfield_entity~custom_draw_sptr
                            beq standard_draw
                            pha                             ; assuming the pointer is -1
                            rts

standard_draw               anop

                            getword [<shape_ptr],#shapedef~type
                            cmp #shape_data_type~prle
                            bne not_prle
; prle shape
                            jsl _prle_shape_draw
                            bra sprite_done

not_prle                    cmp #shape_data_type~block
                            bne not_block
; block/solid shape
                            jsl _block_shape_draw
                            bra sprite_done

not_block                   anop
                            cmp #shape_data_type~compiled_basic
                            bne not_compiled_basic

; compiled basic
                            jsl _compiled_basic_shape_draw

not_compiled_basic          anop

sprite_done                 anop
                            rts

                            end


; -----------------------------------------------------------------------------
; This draws the input entity list into the full view area.
;
; It is expected that all the enties have been 'invalidated' at their current
; position, so that their bounds_rect, reflects where they are in the playfield.
; This will check the 'marked for removal' flag and will not draw that entity
;
; Parameters:
; x-reg - short pointer to entity list.  It must be in seg_entity
; y-reg - the number of entities in the list
;
; Note, expecting the caller to check if there are no entities in the list
; and not call this function.

playfield_draw_entity_list_into_view start seg_entity
                            using grlib_global_equates
                            using grlib_global_data
                            using grlib_update_rects_data
                            using grlib_update_rects_data2
                            using gameplay_level_data

                            debugtag 'draw_el_into_view'

; Going to use values in the grlib scratch buffer area
; Note, these are must be the same in the sub-functions
                            begin_struct grdp~caller_scratch_buffer
wLeft                       decl word
wRight                      decl word
wClipLeft                   decl word
wClipRight                  decl word
wClipTop                    decl word
wClipBottom                 decl word
wRectCount                  decl word
wRectsOffset                decl word
wEntityCount                decl word
pEntry                      decl ptr
spEntity                    decl ptr
                            end_struct

; Switch to the grlib dp
                            phd
                            lda >grlib~dp
                            tcd

                            stx <pEntry
                            sty <wEntityCount
                            lda #^playfield_draw_entity_list_into_view      ; get our bank
                            sta <pEntry+2

; Copy the clip rect, we will be changing it
                            lda <clipx_left
                            sta <wClipLeft
                            lda <clipx_right
                            sta <wClipRight
                            lda <clipy_top
                            sta <wClipTop
                            lda <clipy_bottom
                            sta <wClipBottom

                            lda >gameplay_level~playfield_view+playfield_view~bounds+grlib_rect~left
                            sta <clipx_left                                 ; expected to be an even value
                            sta <wLeft                                      ; used in sub-functions, expected to be the exact pixel value
                            lda >gameplay_level~playfield_view+playfield_view~bounds+grlib_rect~top
                            sta <clipy_top
                            lda >gameplay_level~playfield_view+playfield_view~bounds+grlib_rect~right
                            sta <clipx_right                                ; expected to be an even value
                            sta <wRight                                     ; used in sub-functions, expected to be the exact pixel value
                            lda >gameplay_level~playfield_view+playfield_view~bounds+grlib_rect~bottom
                            sta <clipy_bottom

                            jsr _pf_draw_entity_list

; Restore the clip rect
                            lda <wClipTop
                            sta <clipy_top
                            lda <wClipBottom
                            sta <clipy_bottom
                            lda <wClipLeft
                            sta <clipx_left
                            lda <wClipRight
                            sta <clipx_right

no_rects                    anop
no_entries                  anop
                            pld
                            rtl
                            end

; - Local ---------------------------------------------------------------------
; Making this a local function, just so its more readable, and we have less need for long branches
; Also making it a fully separate function, so that ORCA exports the function
; to the linker map, so I can see it in the profiler.
_pf_draw_entity_list        private seg_entity
                            using grlib_global_equates
                            using grlib_global_data
                            using grlib_update_rects_data
                            using grlib_update_rects_data2

; Duplicate the DP layout from the parent call
                            begin_struct grdp~caller_scratch_buffer
wLeft                       decl word
wRight                      decl word
wClipLeft                   decl word
wClipRight                  decl word
wClipTop                    decl word
wClipBottom                 decl word
wRectCount                  decl word
wRectsOffset                decl word
wEntityCount                decl word
pEntry                      decl ptr
spEntity                    decl ptr
                            end_struct

_draw_sprite_loop           getword [<pEntry]
                            sta <spEntity
                            tax                     ; entity short pointer in x

; Marked for removal?
                            getword {x},>entities_root+playfield_entity~state_flags
                            bmi sprite_next

                            getword {x},>entities_root+grlib_entity~sprite+sprite~primary_shape_ptr+2
                            beq sprite_next         ; no shape?
; See if it is completely clipped
                            getword {x},>entities_root+grlib_entity~sprite+sprite~bounds~left
                            cmp <wRight
                            bsge sprite_next
                            sta <draw_x

                            getword {x},>entities_root+grlib_entity~sprite+sprite~bounds~right
                            cmp <wLeft
                            bslt sprite_next
                            putword {x},>entities_root+grlib_entity~sprite+sprite~erase~right

                            getword {x},>entities_root+grlib_entity~sprite+sprite~bounds~top
                            cmp <clipy_bottom
                            bsge done                   ; Because we are using a list, sorted by the top of the sprites, if this is off the bottom, then the rest will be too.
                            sta <draw_y

                            getword {x},>entities_root+grlib_entity~sprite+sprite~bounds~bottom
                            cmp <clipy_top
                            bslt sprite_next
                            putword {x},>entities_root+grlib_entity~sprite+sprite~erase~bottom

; The sprite falls in the rect, draw it
                            jsr _pf_draw_sprite
                            ldx <spEntity

sprite_next                 anop
; See if we have any child entities.
                            getword {x},>entities_root+grlib_entity~child_entity_ptr+2
                            bne _draw_children

; Advance to the next entry
next_entry                  dec <wEntityCount
                            beq done

                            lda <pEntry
                            inc a
                            inc a
                            sta <pEntry
                            bne _draw_sprite_loop

done                        rts

; Draw all the children
_draw_children              anop
                            getword {x},>entities_root+grlib_entity~child_entity_ptr
                            sta <spEntity
                            tax                         ; short pointer in x

sibling_loop                anop
                            getword {x},>entities_root+grlib_entity~sprite+sprite~primary_shape_ptr+2
                            beq no_sibling_shape         ; no shape?
; See if it is completely clipped
                            getword {x},>entities_root+grlib_entity~sprite+sprite~bounds~left
                            cmp <wRight
                            bsge no_sibling_shape
                            sta <draw_x

                            getword {x},>entities_root+grlib_entity~sprite+sprite~bounds~right
                            cmp <wLeft
                            bslt no_sibling_shape
                            putword {x},>entities_root+grlib_entity~sprite+sprite~erase~right

                            getword {x},>entities_root+grlib_entity~sprite+sprite~bounds~top
                            cmp <clipy_bottom
                            bsge no_sibling_shape
                            sta <draw_y

                            getword {x},>entities_root+grlib_entity~sprite+sprite~bounds~bottom
                            cmp <clipy_top
                            bslt no_sibling_shape
                            putword {x},>entities_root+grlib_entity~sprite+sprite~erase~bottom

; The sprite falls in the rect, draw it
                            jsr _pf_draw_sprite
                            ldx <spEntity

no_sibling_shape            getword {x},>entities_root+grlib_entity~sibling_entity_ptr          ; using short pointers for the siblings
                            beq next_entry
                            sta <spEntity
                            tax
                            bra sibling_loop

                            rts
                            end

; ----------------------------------------------------------------------------
; A helper function to construct a pre-load framelib object
; Really, this should be in some helper file, or maybe even the a framelib
; file, but I may extend this for specific playfield use, though it is not right now
; Parameters:
; pFramelib     - the framelib entity to preload into
; dwCollectionID - the collection ID to apply to the framelib
; Returns:
; carry clear if successful
playfield_preload_framelib_collection start seg_entity

                            begin_locals
work_area_size              end_locals

                            sub (4:pFramelib,4:dwCollectionID),work_area_size

                            pushptr <pFramelib
                            jsl framelib_entity_construct

                            lda <dwCollectionID
                            putptrlow [<pFramelib],#framelib_entity~collection_id
                            lda <dwCollectionID+2
                            putptrhigh [<pFramelib],#framelib_entity~collection_id

                            pushptr <pFramelib
                            jsl framelib_entity_load_collection
                            bcs failed

                            pushptr <pFramelib
                            jsl framelib_entity_cache_collection

failed                      anop
                            retkc
                            end

; ----------------------------------------------------------------------------
; A debug function to print some info about the entities to the text screen
playfield_entity_debug_display start seg_entity
                            using appdata
                            using appdata_segment_data
                            using playfield_entity_manager_data
                            using sinistar_entity_data
                            using applib_data
                            using appdebug_data
                            using textlib_global_data
                            using collision_entry_data

                            begin_locals
pEntity                     decl ptr
pEntityList                 decl ptr
pCharacteristic             decl ptr
wIndex                      decl word
wCount                      decl word
wDrawLines                  decl word
work_area_size              end_locals

                            sub (2:wStatus),work_area_size

id_column_width             equ 12
x_column_width              equ 6
y_column_width              equ 6
speedx_column_width         equ 8
speedy_column_width         equ 8
sort_column_width           equ 6
mission_column_width        equ 16

                            setlocaldatabank

                            lda <wStatus
                            bit #debug_handler~status~displayed
                            bne not_first
; First time here
                            stz prev_draw_lines

not_first                   anop

                            stz <wCount

                            lda debug_display_entity_type
                            shiftleft 2
                            tax
                            lda playfield_entity_instance_lists,x
                            sta <pEntityList
                            lda playfield_entity_instance_lists+2,x
                            sta <pEntityList+2
                            beq no_list

                            lda [<pEntityList]
                            sta <wCount

no_list                     anop
                            lda #textbox_option~inverse+textbox_option~line_fill
                            jsl textbox_set_options
                            pushptr #title_string
                            jsl textbox_print_string
                            jsl textbox_newline
                            jsl textbox_set_option_normal

; Type
                            pushdword #Type_title_string
                            jsl textbox_print_string
                            pushsword debug_display_entity_type
                            jsl playfield_entity_get_type_name
                            pushretptr
                            jsl textbox_print_string
; Count
                            pushdword #Count_title_string
                            jsl textbox_print_string
                            pushsword <wCount
                            jsl textbox_print_decimal_word

                            jsl textbox_newline

                            stz <wDrawLines

; Columns
                            pushptr #column_header
                            jsl textbox_print_columns

                            pushsword #ascii~mousetext~horizontal_bar
                            jsl textbox_fill_line
                            jsl textbox_newline

                            lda <wCount
                            jeq none

; Skip the count
                            lda <pEntityList
                            inc a
                            inc a
                            sta <pEntityList

                            stz <wIndex

; This doesn't change, so do it once
                            lda #^entities_root
                            sta <pEntity+2

loop                        ldy <wIndex
                            lda [<pEntityList],y
                            sta <pEntity
                            iny
                            iny
                            sty <wIndex

                            inc <wDrawLines
; ID
                            pushsword #id_column_width
                            jsl textbox_set_column
                            pushsword <pEntity
                            jsl textbox_print_hex_word

; X
                            pushsword #x_column_width
                            jsl textbox_next_column
                            pushsword [<pEntity],#playfield_entity~grentity+grlib_entity~x
                            jsl textbox_print_hex_word

; Y
                            pushsword #y_column_width
                            jsl textbox_next_column
                            pushsword [<pEntity],#playfield_entity~grentity+grlib_entity~y
                            jsl textbox_print_hex_word

; Speed X
                            pushsword #speedx_column_width
                            jsl textbox_next_column
                            pushsword [<pEntity],#playfield_entity~speed_x
                            jsl textbox_print_hex_word

; Speed Y
                            pushsword #speedy_column_width
                            jsl textbox_next_column
                            pushsword [<pEntity],#playfield_entity~speed_y
                            jsl textbox_print_hex_word

; Sort
                            pushsword #sort_column_width
                            jsl textbox_next_column
                            pushsword [<pEntity],#collision_entity_sort_member
                            jsl textbox_print_hex_word

; Mission
                            pushsword #mission_column_width
                            jsl textbox_next_column
                            pushsword [<pEntity],#playfield_entity~mission_id
                            pushsword [<pEntity],#playfield_entity~type
                            jsl gameplay_get_mission_type_name
                            pushretptr
                            jsl textbox_print_string

                            jsl textbox_next_row_end_columns
                            bcs off_end

                            dec <wCount
                            jne loop

                            jsr show_list_end_info

off_end                     anop
none                        anop
                            jsl textbox_clear_options

                            lda prev_draw_lines
                            sec
                            sbc <wDrawLines
                            bcc no_erase
                            beq no_erase
; We have to erase some previous lines
                            pha
                            pushsword #$20
                            jsl textbox_fill_lines

no_erase                    lda <wDrawLines
                            sta prev_draw_lines

exit                        anop
                            restoredatabank
                            ret

;; Show some extra info
show_list_end_info          anop
                            lda debug_display_entity_type
                            cmp #entity_type~sinistar
                            bne no_extra_info

                            jsl textbox_newline
                            pushptr #str_child_entities_visible
                            jsl textbox_print_string

                            stz <wCount
; Clear all the center piece images, except for the 'nose', which is actually the full center image, so it will draw faster.
                            ldy #0
visible_loop                lda sinistar_entity_pieces_ptrs,y
                            tax
                            getword {x},>entities_root+playfield_entity~grentity+grlib_entity~sprite+sprite~primary_shape_ptr+2
                            beq not_visible
                            inc <wCount
not_visible                 iny
                            iny
                            iny
                            iny
                            cpy #max_sinistar_pieces*4
                            blt visible_loop

                            pushsword <wCount
                            jsl textbox_print_hex_word
                            jsl textbox_newline

no_extra_info               rts

column_header               anop
                            dc i'id_column_width,textbox_data~string'
                            dc a4'debug_str~ID'

                            dc i'x_column_width,textbox_data~string'
                            dc a4'debug_str~X'

                            dc i'y_column_width,textbox_data~string'
                            dc a4'debug_str~Y'

                            dc i'speedx_column_width,textbox_data~string'
                            dc a4'speedx_title_string'

                            dc i'speedy_column_width,textbox_data~string'
                            dc a4'speedy_title_string'

                            dc i'sort_column_width,textbox_data~string'
                            dc a4'sort_title_string'

                            dc i'mission_column_width,textbox_data~string'
                            dc a4'debug_str~Mission'

                            dc i'0'                             ; terminator

title_string                cstring 'Entity List'
speedx_title_string         cstring 'Speed X'
speedy_title_string         cstring 'Speed Y'
sort_title_string           cstring 'Sort'
type_title_string           cstring 'Type: '
count_title_string          cstring ', Count: '
str_child_entities_visible  cstring 'Child entities visible:'

prev_draw_lines             dc i'0'
                            end

; ----------------------------------------------------------------------------
; Draw the help for this handler
playfield_entity_debug_show_help start seg_entity

                            pushptr #basic_help1
                            jsl textbox_print_string
                            jsl textbox_newline
                            pushptr #basic_help2
                            jsl textbox_print_string
                            jsl textbox_newline

                            rtl

basic_help1                 cstring '[E] - Show the entity list'
basic_help2                 cstring '      Use [0-9] to switch which entity type is showing'

                            end

; -----------------------------------------------------------------------------
playfield_entity_debug_keypress start seg_entity
                            using appdata
                            using appdebug_data
                            using textlib_global_data
                            using applib_data
                            using playfield_entity_manager_data
                            using grlib_global_data

                            begin_locals
work_area_size              end_locals

                            sub (4:pHandler,2:wKey),work_area_size
                            getword [<pHandler],#debug_handler~enabled
                            beq not_enabled

; We are enabled
                            lda >grlib~in_text_mode
                            beq not_handled                                 ; Don't handle any keys if not in text mode

                            lda <wKey
                            cmp #'E'
                            beq disable
                            cmp #'0'
                            blt not_handled
                            cmp #'9'+1
                            bge not_handled
; Set the type to display
                            sec
                            sbc #'0'
                            cmp #entity_type~count
                            bge not_handled                                 ; not saying we handled it, because I know that the the player controls use the number pad

                            sta >debug_display_entity_type
                            bra not_handled                                 ; not saying we handled it, because I know that the the player controls use the number pad

disable                     anop
                            lda #0
                            putword [<pHandler],#debug_handler~enabled
                            lda #$ffff
                            sta >appdebug~clear_text_screen
                            bra handled

; We are not enabled, the only key we listen for, is the one to enable us
not_enabled                 lda <wKey
                            cmp #'E'
                            bne not_handled

; Enable
; We are assuming that at our priority, other handlers have to be shut-off
                            pushsword [<pHandler],#debug_handler~priority
                            jsl appdebug_disable_handlers_of_priority

                            lda #$ffff
                            putword [<pHandler],#debug_handler~enabled
                            sta >appdebug~clear_text_screen

handled                     clc
exit                        retkc
not_handled                 sec
                            bra exit

                            end
