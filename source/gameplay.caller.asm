                            copy lib/source/debug.definitions.asm
                            copy lib/source/system.ids.asm
                            copy lib/source/object.definitions.asm
                            copy lib/source/string.definitions.asm
                            copy lib/source/container.definitions.asm
                            copy lib/source/fixed.buffer.pool.definitions.asm
                            copy lib/source/datalib.constants.asm
                            copy lib/source/grlib.definitions.asm
                            copy lib/source/framelib.definitions.asm
                            copy lib/source/grlib.palette.definitions.asm
                            copy lib/source/grlib.sprite.definitions.asm
                            copy lib/source/grlib.entity.definitions.asm
                            copy lib/source/value.transform.definitions.asm
                            copy lib/source/grlib.color.cycle.definitions.asm
                            copy lib/source/grlib.font.definitions.asm
                            copy lib/source/grlib.entity.sort.definitions.asm

                            copy source/gameplay.constants.asm
                            copy source/playfield.definitions.asm
                            copy source/playfield.entity.definitions.asm
                            copy source/gameplay.entity.characteristic.definitions.asm
                            copy source/worker.entity.definitions.asm

                            mcopy generated/gameplay.caller.macros

                            longa on
                            longi on

; ----------------------------------------------------------------------------
; Contains gameplay related functions for the generic 'caller'.
; A caller can be any kind of entity, that attracts and gives missions to other
; entities.  The entity specific code will be in the entity's source file.

; ----------------------------------------------------------------------------

gameplay_caller_logic_data  data seg_gameplay
                            using worker_entity_manager_data
                            using gameplay_worker_logic_data
                            using warrior_entity_manager_data
                            using gameplay_warrior_logic_data

; The last time the logic was updated
gameplay_caller_logic~last_tick   ds 4
; Rate at which logic is updated
gameplay_caller_logic~update_rate equ 2

; Task data for the caller task
gameplay_caller_task_data       equ 0
gameplay_caller_task_data~entity_ptr equ gameplay_caller_task_data
sizeof~gameplay_caller_task_data equ gameplay_caller_task_data~entity_ptr+4

mission_special_priority        equ $00ff

responder_worst_priority        equ 1
min_unconditional_distance_modifier equ $00f8               ; If the distance modifier of a responder candidate is *above* this value, we assume it is close enough.

responder_distance_modifier_max gequ $0040

; Reserving a 16-bit word, for each responder type
responder_type_entry_size       equ responder_type~count*2

responder_type_lists            dc a4'worker_entity_count'
                                dc a4'warrior_entity_count'

responder_default_mission       gequ 0                       ; This is the default mission of a responder.  It is required to not need a caller

; The Intelligence Types (I'm using AI for short)
; Note, that the type index is * 2, as it is in the Sinistar code, so that it doesn't have to shift for some tables.  I might change this, because it is geared toward some 8-bit tables
; with two sub-values.
ai_type_planetoid           equ 0*responder_type_entry_size
ai_type_player              equ 1*responder_type_entry_size
ai_type_sinistar            equ 2*responder_type_entry_size
ai_type_bomb                equ 3*responder_type_entry_size
ai_type_crystal             equ 4*responder_type_entry_size
; Responders.  The original code, only supports Workers and Warriors are things that are 'called'.  I might extend this
ai_type_workers             equ 5*responder_type_entry_size
ai_type_warriors            equ 6*responder_type_entry_size
; Things that don't have AI types in their characteristics table, will have this
ai_type_invalid             equ -1

; A helper, for testing if an ai type is a valid caller
ai_type_end_callers         equ ai_type_workers

; A table of assignment quotas, where the index is the AI type, and the entry members are the responder offsets.
; These define how many responders are called, by a caller, that has the AI type
; (Quota in the original)
gameplay_assignment_quotas  anop
                            dc i'3,1'                       ; Planetoids, 3 workers, 1 warrior
                            dc i'3,9'                       ; Player
                            dc i'0,6'                       ; Sinistar
                            dc i'1,1'                       ; Sinbombs
                            dc i'3,1'                       ; Crystals

; A table of base priorities for assignment.  Same layout as the quotas
; (Prios in the original)
gameplay_assignment_priorities anop
                            dc i'$0058,$0058'               ; Planetoids
                            dc i'$0048,$005B'               ; Player
                            dc i'$0000,$0054'               ; Sinistar
                            dc i'$0070,$0070'               ; Sinibombs
                            dc i'$0068,$0058+3'             ; Crystals

; Mission matrix, with the same AI type, responder offset format
; (MisAss in the original)
gameplay_mission_matrix     anop
                            dc i'id_worker_mission_tail,id_warrior_mission_tail'    ; Planetoids (should be id_warrior_mission_mine)
                            dc i'id_worker_mission_tail,id_warrior_mission_attack'  ; Player
                            dc i'id_worker_mission_drift,id_warrior_mission_tail'   ; Sinistar
                            dc i'id_worker_mission_intercept,id_warrior_mission_intercept'   ; Sinibombs
                            dc i'id_worker_mission_intercept,id_warrior_mission_intercept'   ; Crystals
                            end

; ----------------------------------------------------------------------------
; Functions related to the 'caller' functionality of an entity
;
; ----------------------------------------------------------------------------
; Initialize an entity to be a 'caller' of other entities.
; This flow is ported as close as possible, from the original code.
; Parameters:
; x-reg       - the caller entity
gameplay_caller_initialize  start seg_gameplay
                            using appdata
                            using gameplay_caller_logic_data
                            using gameplay_level_data
                            using math_tables
                            using task_manager_data

                            debugtag 'initialize_gameplay_caller'

                            begin_locals
spCaller                    decl word
pTaskData                   decl ptr
work_area_size              end_locals

                            sub ,work_area_size

                            stx <spCaller

                            lda #0
; Zero the responder list and quota
                            putword {x},>entities_root+playfield_entity~responder_root_sptr
; Assuming that only the workers and the warriors are responder types
                            static_assert_equal responder_type~count,2
                            putword {x},>entities_root+playfield_entity~responder_quota+responder_type~worker
                            putword {x},>entities_root+playfield_entity~responder_quota+responder_type~warrior

; Note, the original code did some special handling if the ai_type is a Crystal and in demo mode.

                            pushsword #task_list_1_offset
                            pushptr #gameplay_task_caller_first_pass
                            pushsword #sizeof~gameplay_caller_task_data
                            jsl task_manager_create_task
                            bcs error
                            putretptr <pTaskData

; Put the caller pointer into the task data
                            lda <spCaller
                            putptrlow [<pTaskData],#gameplay_caller_task_data~entity_ptr
                            lda #^entities_root
                            putptrhigh [<pTaskData],#gameplay_caller_task_data~entity_ptr

; And the task pointer, into the caller.  Using the task1 slot
                            ldx <spCaller
                            lda <pTaskData
                            putptrlow {x},>entities_root+playfield_entity~task1_ptr
                            lda <pTaskData+2
                            putptrhigh {x},>entities_root+playfield_entity~task1_ptr

error                       anop
                            ret
                            end

; ----------------------------------------------------------------------------
; The caller assignment logic.
; This flow is ported as close as possible, from the original Caller code.
gameplay_task_caller_first_pass start seg_gameplay
                            using appdata
                            using gameplay_caller_logic_data
                            using gameplay_entity_data
                            using gameplay_level_data
                            using math_tables
                            using task_manager_data

                            debugtag 'first_pass'
                            debugtag 'gameplay_task_caller'

                            begin_locals
work_area_size              end_locals

                            sub (4:pTaskData),work_area_size
                            setlocaldatabank

                            pushptr <pTaskData
                            jsl gameplay_caller_logic_tick

; Is the entity the player?
                            getword [<pTaskData],#gameplay_caller_task_data~entity_ptr
                            tax
                            getword {x},>entities_root+playfield_entity~characteristic_id
                            tax
                            lda >characteristics_table+gameplay_entity_characteristic~ai_type,x
                            cmp #ai_type_player
                            bne not_player

; Call the player's caller function, more often
                            pushptr <pTaskData
                            pushsword #task_list_64_offset
                            pushptr #gameplay_caller_logic_tick
                            jsl task_manager_change_list_and_callback
                            bra exit

not_player                  pushptr <pTaskData
                            pushsword #task_list_256_offset
                            pushptr #gameplay_caller_logic_tick
                            jsl task_manager_change_list_and_callback

exit                        anop
                            restoredatabank
                            ret
                            end
; ----------------------------------------------------------------------------
; The caller assignment logic.
; This flow is ported as close as possible, from the original Caller code.
;
; This is the task logic that each caller has, to keep its responder
; slots full.  There are separate quotas for each responder type.
; If there is a slot open, this will search that particular responder
; list and see if it can find a suitable candidate.  This can include stealing
; a responder from another caller.
;
; A caller has a set base priority value for each responder, which is
; adjusted downward, as slots are filled.  This helps prevent a caller from
; claiming more responders that another caller, especially of the same type.
; The priority is also adjusted by distance to the caller.
; Each potential responder calculates what its 'final' priority would be if
; the caller claimed the responder and compares that against the current priority
; that the responder has for any existing caller, adjusting that to a 'final' priority
; by checking the current distance to its current caller.
;
; This distance modifier is a bit expensive, and I'm unsure why this is not just
; stored in the responder, and updated, when its distance to its caller is updated
; in its mission logic tick.  Maybe to cut down on memory?  It would also calculate it
; every time, but is only needed here, so maybe the on-demand is better?
gameplay_caller_logic_tick  start seg_gameplay
                            using appdata
                            using gameplay_caller_logic_data
                            using gameplay_level_data
                            using math_tables
                            using gameplay_entity_data
                            using gameplay_sinistar_logic_data

                            debugtag 'logic_tick'
                            debugtag 'gameplay_caller'

                            begin_locals
wResponderTypeOffset        decl word
wCallerX                    decl word
wCallerY                    decl word
wCallerAIType               decl word
wResponderMissionMatrix     decl word
wResponderCount             decl word
wResponderIndex             decl word
wDistX                      decl word
wDistY                      decl word
wQuotaFactor                decl word
wDistanceModified           decl word
wPriorityModified           decl word
wPriorityMax                decl word
wPriorityFinal              decl word
wBestPriority               decl word
spBestResponder             decl word
wBestDistX                  decl word
wBestDistY                  decl word
pCaller                     decl ptr
pResponder                  decl ptr
pPrevCallerEntity           decl ptr
pResponderSibling           decl ptr
pResponderTypeList          decl ptr
work_area_size              end_locals

                            sub (4:pTaskData),work_area_size
                            setlocaldatabank

                            getptr [<pTaskData],#gameplay_caller_task_data~entity_ptr,<pCaller

                            getword [<pCaller],#playfield_entity~grentity+grlib_entity~x,<wCallerX
                            getword [<pCaller],#playfield_entity~grentity+grlib_entity~y,<wCallerY
                            getword [<pCaller],#playfield_entity~characteristic_id
                            tax
                            lda characteristics_table+gameplay_entity_characteristic~ai_type,x
                            sta <wCallerAIType
                            bpl not_invalid_type

ai_not_caller               anop
                            assert_brk 'invalid_ai_type'
                            brl done

not_invalid_type            cmp #ai_type_end_callers
                            bge ai_not_caller
                            cmp #ai_type_sinistar
                            bne not_sinistar
                            lda gameplay_sinistar_logic~in_sector
                            bne in_sector
                            brl done                                    ; if sinistar is not in the sector, he doesn't call anything.  This just leads Warriors away, to their deaths.

in_sector                   anop
;                           keyed_break 3
not_sinistar                anop
;                            cmp #ai_type_crystal
;                            assert_brk_cond bne

                            lda #responder_type~worker
                            sta <wResponderTypeOffset                  ; note, this will always contain the type * 2

loop                        clc
                            adc <wCallerAIType
                            sta <wResponderMissionMatrix               ; This is the entry in the mission matrix we want to give the responder
                            tax

                            lda #playfield_entity~responder_quota
                            clc
                            adc <wResponderTypeOffset
                            tay
                            lda [<pCaller],y                        ; get the current quota, for this responder type
                            cmp gameplay_assignment_quotas,x        ; compare to the max
                            blt add_responder
; Move to the next responder type.  Note, we are assuming just the two types right now
next_responder_type         anop
                            lda <wResponderTypeOffset
                            inc a
                            inc a                                   ; Advance by 2, as we are indexing 16 bit values
                            sta <wResponderTypeOffset
                            cmp #responder_type~count*2
                            bne loop
                            brl done                                ; assignment quotas are full, or we could not find anyone to fill them.

; Add a responder, if we can find a suitable one
add_responder               anop
;                           lda [<pCaller],y                        ; Get the amount we have filled already
; Scale it.  In the original code, it multiplied it by QuoMod, which was 6.  I will do that manually now
                            asl a                                   ; x2
                            sta <wQuotaFactor
                            asl a                                   ; x4
                            adc <wQuotaFactor                       ; x6.  Note, we don't need a clc, because we know the previous asl cleared it.
                            and #$00FF                              ; only using the lower bits.
                            sta <wQuotaFactor
; Use that to reduce the priority.  Essentially, the more slots that are filled, the less of a priority to fill the rest.
                            lda gameplay_assignment_priorities,x
                            sec
                            sbc <wQuotaFactor
                            sta <wPriorityModified
; Start searching through the responders
                            clc
                            adc #responder_distance_modifier_max
                            sta <wPriorityMax
                            lda #responder_worst_priority
                            sta <wBestPriority
                            stz <spBestResponder

                            lda <wResponderTypeOffset
; Get the list address
                            asl a
                            tax
                            lda responder_type_lists,x
                            sta <pResponderTypeList
                            lda responder_type_lists+2,x
                            sta <pResponderTypeList+2
; First word is the count
                            lda [<pResponderTypeList]
                            beq next_responder_type                     ; If none, go to the next type
                            sta <wResponderCount
; Skip the count
                            lda <pResponderTypeList                     ; yes, faster then two incs of memory
                            inc a
                            inc a
                            sta <pResponderTypeList

                            ldy #0
                            sty <wResponderIndex
                            bra skip_in

next_responder              dec <wResponderCount
                            jeq check_best_responder                   ; done with the responder list?
                            ldy <wResponderIndex
                            iny                                        ; entity lists are just the short pointer, advance by 2
                            iny
                            sty <wResponderIndex

skip_in                     lda [<pResponderTypeList],y
                            sta <pResponder
                            lda #^entities_root
                            sta <pResponder+2
; Are we already called by the caller?
                            getword [<pResponder],#playfield_entity~caller_sptr
                            cmp <pCaller
                            beq next_responder
; Check the mission priority
                            lda <wPriorityMax
                            cmpword [<pResponder],#playfield_entity~caller_priority
                            blt next_responder             ; If our mission is not higher than the one it has, skip to the next
                            lda #mission_special_priority
                            cmp [<pResponder],y
                            beq next_responder             ; Don't override special priority missions
; Get the distance from the caller
                            getword [<pResponder],#playfield_entity~grentity+grlib_entity~x
                            sec
                            sbc <wCallerX
                            bpl ok_x
; We overflowed, negate to make positive
                            negate a
ok_x                        sta <wDistX
                            getword [<pResponder],#playfield_entity~grentity+grlib_entity~y
                            sec
                            sbc <wCallerY
                            bpl ok_y
                            negate a
ok_y                        sta <wDistY
                            ldy <wDistX
                            jsr calc_distance_modifier
                            sta <wDistanceModified
                            clc
                            adc <wPriorityModified
                            sta <wPriorityFinal
; Get the distance to the current caller (hmm, what if it doesn't have one?)
                            getword [<pResponder],#playfield_entity~caller_dist_x
                            tax
                            getword [<pResponder],#playfield_entity~caller_dist_y
                            txy
; Calculate priority and compare it to what ours would be.
                            jsr calc_distance_modifier
                            clc
                            ldy #playfield_entity~caller_priority
                            adc [<pResponder],y
                            cmp <wPriorityFinal
                            bge next_responder                                  ; If the other priority is higher, move on.
; Eligible responder
                            lda <wPriorityFinal
                            cmp <wBestPriority
                            jle next_responder
; New, best priority
                            sta <wBestPriority
                            lda <pResponder
                            sta <spBestResponder
                            lda <wDistX
                            sta <wBestDistX
                            lda <wDistY
                            sta <wBestDistY
; See if the distance modifier is at or above the minimum, if so, we can stop searching.
                            lda <wDistanceModified
                            cmp #min_unconditional_distance_modifier
                            jle next_responder                     ; compare is reversed, because the modifier value uses inverted distance values.
; We got here either from falling through from above, or we are at the end of the list, and we want to see if we have a best or not.
check_best_responder        anop
                            lda <wBestPriority
                            cmp #responder_worst_priority          ; Is the priority terrible?
                            jle next_responder_type                ; do the next type
; Use the 'best' one found.
                            lda <spBestResponder
                            sta <pResponder
; Does the responder already have caller? Non-zero, if yes.  (this check is a bit different from the original, in that the orignal code, had the responder use its own ID as the caller)
                            getword [<pResponder],#playfield_entity~caller_sptr
                            beq attach_responder
; Get the previous caller
                            sta <pPrevCallerEntity
                            lda #^entities_root
                            sta <pPrevCallerEntity+2

; Adjust the caller's quota for this responder type
                            lda #playfield_entity~responder_quota
                            clc
                            adc <wResponderTypeOffset
                            tay
                            lda [<pPrevCallerEntity],y           ; get the current quota, for this responder type
                            dec a
                            sta [<pPrevCallerEntity],y
                            jmi error3
; Remove the responder from the responder list of the previous caller
; Get the root id
                            getword [<pPrevCallerEntity],#playfield_entity~responder_root_sptr
                            cmp <spBestResponder
                            bne search_siblings
; The responder was the head of its previous caller, put the responders 'next', into the head
                            getword [<pResponder],#playfield_entity~next_sibling_sptr
                            putword [<pPrevCallerEntity],#playfield_entity~responder_root_sptr
                            bra attach_responder
; The responder is somewhere in the sibling chain
search_siblings             anop
                            sta <pResponderSibling
                            lda #^entities_root
                            sta <pResponderSibling+2
                            getword [<pResponderSibling],#playfield_entity~next_sibling_sptr
                            jeq error5                      ; at the end?  Uh, oh.  We are not in the chain.
                            cmp <spBestResponder
                            bne search_siblings             ; No match, loop to the next one
; Get the next_sibling of the one we are detaching (can be null), and put it in the next of the sibling that was referencing us.
                            getword [<pResponder],#playfield_entity~next_sibling_sptr
                            putword [<pResponderSibling],#same
attach_responder            anop
; Update the quota
                            lda #playfield_entity~responder_quota
                            clc
                            adc <wResponderTypeOffset
                            tay
                            lda [<pCaller],y           ; get the current quota, for this responder type
                            inc a
                            sta [<pCaller],y
; Attach the new responder to the head
                            getword [<pCaller],#playfield_entity~responder_root_sptr
                            putword [<pResponder],#playfield_entity~next_sibling_sptr
                            lda <spBestResponder
                            putword [<pCaller],#playfield_entity~responder_root_sptr

                            lda <wPriorityModified
                            putword [<pResponder],#playfield_entity~caller_priority
                            lda <pCaller
                            putword [<pResponder],#playfield_entity~caller_sptr
                            lda <wBestDistX
                            putword [<pResponder],#playfield_entity~caller_dist_x
                            lda <wBestDistY
                            putword [<pResponder],#playfield_entity~caller_dist_y

                            ldx <wResponderMissionMatrix
                            lda gameplay_mission_matrix,x
                            putword [<pResponder],#playfield_entity~mission_id
; Move to the next type
                            brl next_responder_type

done                        anop
                            restoredatabank
                            ret

error                       assert_brk '1caller_search'
                            bra done
error2                      assert_brk '2caller_search'
                            bra done
error3                      assert_brk '3caller_search'
                            getword [<pResponder],#playfield_entity~caller_sptr
                            getword [<pPrevCallerEntity],#playfield_entity~type
                            bra done
error4                      assert_brk '4caller_search'
                            bra done
error5                      assert_brk '5caller_search'
                            brl done

; This is an approximation of what the Sinistar code was doing.  We have 16-bit distances, rather than 8-bit
; This inverts the bits of a component of the x/y distance, then takes only the upper bits, and squares the
; result, taking only the upper bits of that.  Does the same for the other component, then adds them together
; Essentially doing a rounded SQR(X) + SQR(Y), which of course, is the squared distance.
; That value is then multiplied by responder_distance_modifier_max, and again, only the upper bits are used.
; Since the responder_distance_modifier_max is 64, we (thankfully) don't have to do a real multiply and
; since the upper bits are used, we can just do one set of shifts and clip the value.
calc_distance_modifier      anop
; We're gonna clamp the input, because I don't want any accidentaly oddball values making subtle bugs
; We need to clamp because we are going strip bits and having an input value just over $3ff, would end up looking like it was very close
; The original didn't need this, because it was using the full range of the register.
                            cmp #gameplay_playfield_width       ; assuming that the width and height are the same
                            blt oK_d1
                            lda #gameplay_playfield_width-1
; Invert the bits.  This helps in two ways.  One is that we want the result to be a higher number,
; the smaller the distance to the target.  Second is that since we are squaring things, inverting the distance
; will make it so that smaller increments in distance at the closer range, will result in a larger
; difference between the possible outputs.
oK_d1                       eor #$ffff                          ; invert so closer distances have more bits
; Our max, absolute range is 1024, so shift down, so the MBS are in the lower 8-bits
; However, we are going to immediately shift it back up by 1, so just shift down by 1 and mask the bits
                            shiftright 1
                            and #$01fe
                            tax
                            lda >math~squared,x
                            xba                                 ; only using the upper bits
                            and #$00ff
                            lsr a                               ; shift down.  Sinistar did this because of 8-bit registers
                            pha                                 ; save on the stack

                            tya                                 ; get the x component
                            cmp #gameplay_playfield_width       ; gameplay_playfield_width
                            blt oK_d2
                            lda #gameplay_playfield_width-1
oK_d2                       eor #$ffff                          ; invert so closer distances have more bits
                            shiftright 1
                            and #$01fe
                            tax
                            lda >math~squared,x
                            xba                                 ; only using the upper bits
                            and #$00ff
                            lsr a                               ; shift down.  Sinistar did this because of 8-bit registers

                            clc
                            adc 1,S                             ; add to the modified Y component on the stack

                            static_assert_equal responder_distance_modifier_max,64
;                           ldx #responder_distance_modifier_max
;                           jsl math~umul1r2

;                           xba                                 ; only using the upper bits
;                           and #$00ff
; Optimization, if the multiplier is 64, then it would be a shift up 6, but we only use the upper bits,
; so then it is a shift down 8.
; We will just shift the original down 2 and chop it
                            shiftright 2
                            and #$00ff

                            ply                                 ; remove our temporary from the stack
                            rts

                            end

; --------------------------------------------------------------------------------------------
; Update the responder's distance to its target
; This, like the original, is keeping the absolute distance.
; Also, it is not adjusted for wrapping.
;
; Parameters:
; pResponder        - the responder pointer.
; pCaller           - the caller pointer.
;
; Deprecated:  Use inline_responder_update_distance macro
gameplay_responder_update_distance start seg_entity
                            using playfield_entity_manager_data
                            using math_tables
                            using appdata

                            begin_locals
work_area_size              end_locals

                            debugtag 'update_distance'
                            debugtag 'gameplay_caller'

                            sub (4:pResponder,4:pCaller),work_area_size

                            getword [<pResponder],#playfield_entity~grentity+grlib_entity~x
                            sec
                            sbc [<pCaller],y
                            bpl bigger_x
                            negate a
bigger_x                    putword [<pResponder],#playfield_entity~caller_dist_x

                            getword [<pResponder],#playfield_entity~grentity+grlib_entity~y
                            sec
                            sbc [<pCaller],y
                            bpl bigger_y
                            negate a
bigger_y                    putword [<pResponder],#playfield_entity~caller_dist_y

                            ret
                            end

; --------------------------------------------------------------------------------------------
; Update the responder's distance to its target
; This, like the original, is keeping the absolute distance.
; Also, it is not adjusted for wrapping.
;
; Parameters:
; pResponder        - the responder pointer.
; wTargetX          - the target x position
; wTargetY          - the target y position
;
; Use the inline_responder_update_distance_xy macro
gameplay_responder_update_distance_xy start seg_entity
                            using playfield_entity_manager_data
                            using math_tables
                            using appdata

                            begin_locals
work_area_size              end_locals

                            debugtag 'update_distance_xy'
                            debugtag 'gameplay_caller'

                            sub (4:pResponder,2:wTargetX,2:wTargetY),work_area_size

                            getword [<pResponder],#playfield_entity~grentity+grlib_entity~x
                            sec
                            sbc <wTargetX
                            bpl bigger_x
                            negate a
bigger_x                    putword [<pResponder],#playfield_entity~caller_dist_x

                            getword [<pResponder],#playfield_entity~grentity+grlib_entity~y
                            sec
                            sbc <wTargetY
                            bpl bigger_y
                            negate a
bigger_y                    putword [<pResponder],#playfield_entity~caller_dist_y

                            ret
                            end

; -----------------------------------------------------------------------------
; Get the type name of a mission, for debug display
; This will always return a valid string.
; Parameters:
; wMissionType      - the mission ID
; wEntityType       - the type of the entity, as mission types are specific to the entity
gameplay_get_mission_type_name start seg_gameplay
                            using playfield_entity_manager_data
                            using gameplay_worker_logic_data
                            using gameplay_warrior_logic_data

                            begin_locals
result                      decl ptr
work_area_size              end_locals

                            sub (2:wMissionType,2:wEntityType),work_area_size

                            setlocaldatabank

                            lda <wEntityType
                            cmp #entity_type~worker
                            bne not_worker
                            lda <wMissionType
                            cmp #id_worker_mission_count
                            bge unknown
                            asl a
                            asl a
                            tax
                            lda worker_mission_names,x
                            sta <result
                            lda worker_mission_names+2,x
                            sta <result+2
                            bra exit

not_worker                  cmp #entity_type~warrior
                            bne unknown
                            lda <wMissionType
                            cmp #id_warrior_mission_count
                            bge unknown
                            asl a
                            asl a
                            tax
                            lda warrior_mission_names,x
                            sta <result
                            lda warrior_mission_names+2,x
                            sta <result+2
                            bra exit

exit                        restoredatabank
                            ret 4:result

unknown                     lda #entity_type_name_unknown
                            sta <result
                            lda #^entity_type_name_unknown
                            sta <result+2
                            bra exit

worker_mission_names        dc a4'str_drift'
                            dc a4'str_tail'
                            dc a4'str_intercept'
                            dc a4'str_bring_crystal'
                            dc a4'str_evade'

warrior_mission_names       dc a4'str_drift'
                            dc a4'str_tail'
                            dc a4'str_intercept'
                            dc a4'str_attack'
                            dc a4'str_evade'

str_drift                   cstring 'drift'
str_tail                    cstring 'tail'
str_intercept               cstring 'intercept'
str_bring_crystal           cstring 'bring_crystal'
str_evade                   cstring 'evade'
str_attack                  cstring 'attack'

                            end

; -----------------------------------------------------------------------------
; Remove a responder from its caller's list
; This is safe to call, even if the entity is not a responder
; This also supports where the caller doesn't have the responder
; in its responder chain.  This is to support some missions
; that are not driven by the caller, ex. Worker bringing a crystal to Sinistar
; Parameters:
;  short pointer to responder in Y
gameplay_responder_remove_from_caller start seg_entity
                            using playfield_entity_data
                            using gameplay_caller_logic_data

                            debugtag 'remove_from_caller'
                            debugtag 'gameplay_responder'

                            begin_locals
spResponder                 decl word
spCaller                    decl word
work_area_size              end_locals

                            sub ,work_area_size

                            tyx
; Get the caller id and do a quick check if we have to do anything at all
                            getword {x},>entities_root+playfield_entity~caller_sptr
                            beq exit                                        ; 0, means not called

                            sty <spResponder                                ; y will always have the responder short pointer
                            sta <spCaller
                            tax                                             ; x will have the caller short pointer, but will have other thingst too!

                            setdatabanktolabel entities_root

; Remove the responder from the responder list of the caller
; Get the root id
                            getword {x},#playfield_entity~responder_root_sptr
                            beq not_found                                   ; caller has no responders, this is 'ok', for some responders to not be in the list (worker with crystal going to sinistar)
                            cmp <spResponder
                            bne search_siblings
; The responder was the head of its caller, put the responders 'next', into the head
                            getword {y},#playfield_entity~next_sibling_sptr
                            putword {x},#playfield_entity~responder_root_sptr
                            bra found
; The responder is somewhere in the sibling chain
search_siblings             anop
                            tax
                            getword {x},#playfield_entity~next_sibling_sptr
                            beq not_found                   ; at the end?
                            cmp <spResponder
                            bne search_siblings             ; No match, loop to the next one
; Get the next_sibling of the one we are detaching (can be null), and put it in the next of the sibling that was referencing us.
                            getword {y},#playfield_entity~next_sibling_sptr
                            putword {x},#playfield_entity~next_sibling_sptr
found                       anop
; Found the responder in the list
; Adjust the caller's quota for this responder type
                            getword {y},#playfield_entity~type
                            asl a
                            tax
                            lda >entity_responder_types,x
                            bmi error_invalid_responder                     ; -1, means we are not a responder, and shouldn't be here!
                            clc
                            adc <spCaller                                   ; adjust the pointer by the offset
                            tax
                            getword {x},#playfield_entity~responder_quota   ; decrement the quota
                            dec a
                            bmi error_negative_quota
                            putword {x},#playfield_entity~responder_quota
; Clear some things
not_found                   anop                                                ; note, not found is 'ok' for some missions, like bringing a crystal to sinistar
                            lda #responder_default_mission
                            putword {y},#playfield_entity~mission_id
; These clears, assume acc has zero
                            static_assert_equal responder_default_mission,0
                            putword {y},#playfield_entity~caller_priority
                            putword {y},#playfield_entity~mission_priority
                            putword {y},#playfield_entity~next_sibling_sptr
                            putword {y},#playfield_entity~caller_sptr
                            restoredatabank
exit                        ret

error                       anop
                            assert_brk 'rfc_not_found'
                            bra not_found
error_invalid_responder     anop
                            assert_brk 'rfc_invalid_responder'
                            bra not_found
error_negative_quota        anop
                            assert_brk 'rfc_neg_quota'
                            bra not_found
                            end

; -----------------------------------------------------------------------------
; Remove all the rsponders from the caller.
; This is safe to call for something that is not actually a caller.
; This will not affect any responders who are not explicitly in the callers
; responder list.
; Parameters:
;  short pointer to the entity in Y
gameplay_caller_remove_all_reponders start seg_entity
                            using playfield_entity_data

                            debugtag 'remove_all_responders'
                            debugtag 'gameplay_caller'

                            begin_locals
spCaller                    decl word
work_area_size              end_locals

                            sub ,work_area_size

                            sty <spCaller
                            tyx

; Loop and have the responders remove themselves.
; Not the most efficient thing to do, since the responder will not know that all the other
; siblings are going to get removed and they will fixup links, but the code is clearer.
loop                        getword {x},>entities_root+playfield_entity~responder_root_sptr
                            beq no_responders
                            tay
                            jsl gameplay_responder_remove_from_caller
                            ldx <spCaller
                            bra loop

no_responders               anop
                            ret
error                       anop
                            assert_brk 'remove_all_reponders'
                            bra no_responders

                            end
