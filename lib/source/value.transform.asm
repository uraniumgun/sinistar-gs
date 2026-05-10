                            copy lib/source/debug.definitions.asm
                            copy lib/source/system.ids.asm
                            copy lib/source/object.definitions.asm
                            copy lib/source/container.definitions.asm
                            copy lib/source/value.transform.definitions.asm

                            mcopy generated/value.transform.macros

                            longa on
                            longi on

; -----------------------------------------------------------------------------
; A node has a desired length of time it does its transform over.
; The calculation provides a current tick and a starting/last tick
; and the elapsed time is usually turned into a scalar value,
; which is then applied to its starting value to get the current value.
;
; Since we are using tables for calculation, the max time range
; for a node is fixed.  Currently 512 ticks.
;
; The value is also assumed to be 16-bit fixed point, where the upper
; 8 bits is the integer portion and the lower is the fractional.
; Most nodes are actually somewhat agnostic to the value's actual bits
; and what the values bits are actually used for is up to the user of
; the result.
;
; Note that the C++ implementation relies heavily on virtual functions.
; For now, there will just be some type checks as needed, I can think about
; using an internal vTable for 'real' overriding, if needed.

; -----------------------------------------------------------------------------
value_transform_data            data seg_slib

; Note that some of these node types have multiple implementations.
; The usual case is if a node is 'incremental' or 'sampled'
value_transform_node_type~none  equ 0
value_transform_node_type~lerp  equ 1
value_transform_node_type~lerp_s equ 2
value_transform_node_type~lerp_s_smoothed equ 3

value_transform_node_object     dc i'sizeof~value_transform_node'
                                dc a4'value_transform_node_object~vtable'

value_transform_node_object~vtable anop
                                dc a4'value_transform_node_construct'
                                dc a4'0'
                                dc a4'0'
                                dc a4'value_transform_node_destruct'

value_transform_object          dc i'sizeof~value_transform'
                                dc a4'value_transform_object~vtable'

value_transform_object~vtable   anop
                                dc a4'value_transform_construct'
                                dc a4'0'
                                dc a4'0'
                                dc a4'value_transform_destruct'

                                end

; -----------------------------------------------------------------------------
; Construct Value Transform object
value_transform_node_construct  start seg_slib
                                using std_errors
                                using std_objects

                                debugtag 'node_construct'
                                debugtag 'value_transform'

                                begin_locals
result                          decl word                                           ; result value inside our local work area
work_area_size                  end_locals

                                sub (4:pThis),work_area_size

                                testptr <pThis
                                beq null_pointer
; Clear memory.
                                ldy #sizeof~value_transform_node-2
                                lda #0
loop                            sta [<pThis],y
                                dey
                                dey
                                bpl loop

                                clc
                                stz <result
exit                            anop
                                retkc 2:result
null_pointer                    lda #system_id_value_transform+std_error_null_pointer
                                sta <result
                                sec
                                bra exit

                                end

; -----------------------------------------------------------------------------
; Destruct Value Transform object
value_transform_node_destruct   start seg_slib
                                using std_errors

                                debugtag 'node_destruct'
                                debugtag 'value_transform'

                                begin_locals
work_area_size                  end_locals

                                sub (4:pThis),work_area_size

                                testptr <pThis
                                beq null_pointer

                                clc
exit                            anop
                                retkc
null_pointer                    sec
                                bra exit
                                end

; -----------------------------------------------------------------------------
; Assume that some values have been manually updated and validate them
; and do any caching.
;
; Parameters:
;   pThis           - this
;   wStart          - the start value
;   wEnd            - the end value
; Returns:
; nothing
value_transform_node_apply_values start seg_slib
                                using std_errors
                                using math_tables
                                using value_transform_data

                                debugtag 'node_apply_values'
                                debugtag 'value_transform'

                                begin_locals
wTemp                           decl word
work_area_size                  end_locals

                                sub (4:pThis),work_area_size

                                testptr <pThis
                                beq null_pointer

                                getword [<pThis],#value_transform_node~value_start
                                putword [<pThis],#value_transform_node~value
                                sta <wTemp
                                getword [<pThis],#value_transform_node~value_end
                                sec
                                sbc <wTemp
                                putword [<pThis],#value_transform_node~value_range

; Check for type-specific initialization
                                getword [<pThis],#value_transform_node~type
                                cmp #value_transform_node_type~lerp
                                jeq lerp1_apply_values
                                cmp #value_transform_node_type~lerp_s
                                jeq lerp1_sampled_apply_values
                                cmp #value_transform_node_type~lerp_s_smoothed
                                jeq lerp1_sampled_smoothed_apply_values

success                         clc
exit                            anop
                                retkc
null_pointer                    anop
delta_error                     anop
                                sec
                                bra exit

; =====================================
; Internal functions
lerp1_apply_values              anop
; Calculate the delta, per tick
                                getword [<pThis],#value_transform_node~tick_length
                                beq delta_error
                                tax
                                getword [<pThis],#value_transform_node~value_range              ; Can be negative!
                                jsl ~div2
                                putword [<pThis],#value_transform_node~value_delta
                                bra success

lerp1_sampled_apply_values      anop
lerp1_sampled_smoothed_apply_values anop
; Calculate the delta, per tick
; This delta will be for the intermediate value and we always go from 0 - 127 (fixed point)
                                getword [<pThis],#value_transform_node~tick_length
                                beq delta_error
                                tax
                                lda #(127|8)
                                jsl ~div2
                                putword [<pThis],#value_transform_node~value_delta
                                bra success

                                end

; -----------------------------------------------------------------------------
; Set the value range
;
; Parameters:
;   pThis           - this
;   wStart          - the start value
;   wEnd            - the end value
; Returns:
; nothing
value_transform_node_set_start_end start seg_slib
                                using std_errors
                                using math_tables
                                using value_transform_data

                                debugtag 'node_set_start_end'
                                debugtag 'value_transform'

                                begin_locals
work_area_size                  end_locals

                                sub (4:pThis,2:wStart,2:wEnd),work_area_size

                                testptr <pThis
                                beq null_pointer

                                lda <wStart
                                putword [<pThis],#value_transform_node~value_start
                                putword [<pThis],#value_transform_node~value
                                lda <wEnd
                                putword [<pThis],#value_transform_node~value_end
                                sec
                                sbc <wStart
                                putword [<pThis],#value_transform_node~value_range

                                clc
exit                            anop
                                retkc
null_pointer                    sec
                                bra exit
                                end
; -----------------------------------------------------------------------------
; Set the tick length for the node
;
; Parameters:
;   pThis           - this
;   wTicks          - the number of ticks the node evaluates over
; Returns:
; nothing
value_transform_node_set_ticks  start seg_slib
                                using std_errors
                                using math_tables
                                using value_transform_data

                                debugtag 'node_set_ticks'
                                debugtag 'value_transform'

                                begin_locals
work_area_size                  end_locals

                                sub (4:pThis,2:wTicks),work_area_size

                                testptr <pThis
                                beq null_pointer

                                lda <wTicks
                                putword [<pThis],#value_transform_node~tick_length

                                clc
exit                            anop
                                retkc
null_pointer                    sec
                                bra exit
                                end
; -----------------------------------------------------------------------------
; Intialize the node, preparing it for calculation.
;
; The interface is from C++, but we aren't using any of the parameters right now.
; Maybe remove them?  It takes time and space to set them up.
;
; Parameters:
;   pThis           - this
;   dwTick          - the current tick
;   pLastTick       - pointer to the last tick.  This can be updated by the node
; Returns:
; nothing
value_transform_node_pass_initialize private seg_slib
                                using std_errors
                                using math_tables
                                using value_transform_data

                                debugtag 'node_initialize'
                                debugtag 'value_transform'

                                begin_locals
work_area_size                  end_locals

                                sub (4:pThis,4:dwTick,4:pLastTick),work_area_size

                                testptr <pThis
                                beq null_pointer

                                getword [<pThis],#value_transform_node~value_start
                                putword [<pThis],#value_transform_node~value
                                lda #0
                                putword [<pThis],#value_transform_node~value_intermediate
; Setup the last_tick and node_start_tick
                                lda <dwTick
                                putword [<pLastTick],#value_transform_tick_state~last
                                putword [<pLastTick],#value_transform_tick_state~start
                                lda <dwTick+2
                                putword [<pLastTick],#value_transform_tick_state~last+2
                                putword [<pLastTick],#value_transform_tick_state~start+2

                                getword [<pThis],#value_transform_node~flags
                                bit #value_transform_node_flag~pass_initialized
                                bne loop_initialized
; Looping is not yet initialized (first time pass)
                                ora #value_transform_node_flag~pass_initialized
                                sta [<pThis],y

                                getword [<pThis],#value_transform_node~loop_count
                                putword [<pThis],#value_transform_node~loop_remaining

loop_initialized                anop
                                clc
exit                            retkc

null_pointer                    sec
                                bra exit
                                end
; -----------------------------------------------------------------------------
; Do a calculate for the time input
;
; Parameters:
;   pThis           - this
;   dwCurrentTick   - the current tick
;   pLastTick       - pointer to the last tick.  See desgin for why this is a pointer
; Returns:
; State of the node

value_transform_node_calculate  private seg_slib
                                using std_errors
                                using math_tables
                                using value_transform_data

                                debugtag 'node_calculate'
                                debugtag 'value_transform'

                                begin_locals
result                          decl word
wTemp                           decl word
work_area_size                  end_locals

                                sub (4:pThis,4:dwCurrentTick,4:pLastTick),work_area_size

                                testptr <pThis
                                beq null_pointer

; This needs to be something quicker, and more extensible. Maybe there is a type_handler short pointer in the instance
; where we could do a get, push, rts
                                getword [<pThis],#value_transform_node~type
                                cmp #value_transform_node_type~lerp
                                jeq lerp1_calculate
                                cmp #value_transform_node_type~lerp_s
                                jeq lerp1_sampled_calculate
                                cmp #value_transform_node_type~lerp_s_smoothed
                                jeq lerp1_sampled_smoothed_calculate

exit                            anop
                                clc
                                sta <result
                                retkc 2:result
null_pointer                    sec
                                bra exit

; Internal functions

; =====================================
; Lerp1, Incremental
; Note that we do NOT check or clamp the value after adding the delta(s)
; We assume that the number of ticks we add the delta will not overflow
; the target end value.  It is ok, because of rounding/precision, that
; the number of ticks * the delta underflows the target, as once the number
; of target ticks is reached, the value will be set to value_end.
; This does mean that the last tick may be a bit of a jump to the
; end value.
lerp1_calculate                 anop
; Completely done?
                                lda <dwCurrentTick
                                sec
                                ldy #value_transform_tick_state~start
                                sbc [<pLastTick],y
; Assuming that our delta will never be more than a word (should be a lot less)
                                ldy #value_transform_node~tick_length
                                cmp [<pThis],y
                                bge lerp1_done

; Get the elapsed delta
                                lda <dwCurrentTick
                                sec
                                sbc [<pLastTick]                ; value_transform_tick_state~last
                                beq lerp1_same
                                tax
; Store the sampled tick time back in the transform
                                lda <dwCurrentTick
                                putword [<pLastTick],#value_transform_tick_state~last
                                lda <dwCurrentTick+2
                                putword [<pLastTick],#value_transform_tick_state~last+2

                                clc
                                getword [<pThis],#value_transform_node~value
                                ldy #value_transform_node~value_delta
delta_loop                      adc [<pThis],y
                                dex
                                bne delta_loop
                                putword [<pThis],#value_transform_node~value
; Value is different
                                lda #value_transform_state~changed
                                jmp exit

lerp1_done                      getword [<pThis],#value_transform_node~value_end
                                putword [<pThis],#value_transform_node~value
                                lda #value_transform_state~changed+value_transform_state~node_end
                                jmp exit

lerp1_same                      lda #value_transform_state~none
                                jmp exit

; =====================================
; Lerp1, Sampled
; This internally uses an increment, but for the intermediate value,
; which goes from 0 - 127.  This value is then used as an index into
; a table of fixed point values that go from 0 - 1.
; This value is multiplied by the range, and added to the start, to give
; the current sampled value.  This is slower that the increment-only
; lerp, but has some added flexibility in that the table lookup
; does not have to contain a linear progression from 0 - 1,
; though this version uses that.  lerp1_s_smoothed, uses a
; smoothed curve.
lerp1_sampled_calculate         anop
; Completely done?
                                lda <dwCurrentTick
                                sec
                                ldy #value_transform_tick_state~start
                                sbc [<pLastTick],y
; Assuming that our delta will never be more than a word (should be a lot less)
                                ldy #value_transform_node~tick_length
                                cmp [<pThis],y
                                bge lerp1_s_done

; Get the elapsed delta
                                lda <dwCurrentTick
                                sec
                                sbc [<pLastTick]                ; value_transform_tick_state~last
                                beq lerp1_s_same
                                tax
; Store the sampled tick time back in the transform
                                lda <dwCurrentTick
                                putword [<pLastTick],#value_transform_tick_state~last
                                lda <dwCurrentTick+2
                                putword [<pLastTick],#value_transform_tick_state~last+2

                                clc
                                getword [<pThis],#value_transform_node~value_intermediate
                                ldy #value_transform_node~value_delta
lerp1_s_delta_loop              adc [<pThis],y
                                dex
                                bne lerp1_s_delta_loop
                                putword [<pThis],#value_transform_node~value_intermediate
                                xba
                                and #$00ff
                                asl a
                                tax
                                lda >math~fixed_point_0_to_1_128_steps,x
                                tax
                                getword [<pThis],#value_transform_node~value_range
                                jsl math~mul2r4
; The retured value is scaled up by 8 bits
                                xba
                                and #$00ff
                                sta <wTemp
                                txa
                                xba
                                and #$ff00
                                ora <wTemp
                                ldy #value_transform_node~value_start
                                adc [<pThis],y
                                putword [<pThis],#value_transform_node~value
; Value is different (hmm, the value can actually be the same, if the same sample point in the lookup table was used. Fix?)
                                lda #value_transform_state~changed
                                jmp exit

lerp1_s_done                    getword [<pThis],#value_transform_node~value_end
                                putword [<pThis],#value_transform_node~value
                                lda #value_transform_state~changed+value_transform_state~node_end
                                jmp exit

lerp1_s_same                    lda #value_transform_state~none
                                jmp exit

; =====================================
; Lerp1, Sampled, Smoothed
; This internally uses an increment, but for the intermediate value,
; which goes from 0 - 127.  This value is then used as an index into
; a table of fixed point values that go from 0 - 1, however that
; table has a smoothed progression between 0 - 1, with the ends
; having a slower progression to and from the mid-point.
; This value is multiplied by the range, and added to the start, to give
; the current sampled value.
; Other than the table lookup, this code is the same as the lerp1_sampled
; Maybe make this into an include or something?  Giant macro?
lerp1_sampled_smoothed_calculate anop
; Completely done?
                                lda <dwCurrentTick
                                sec
                                ldy #value_transform_tick_state~start
                                sbc [<pLastTick],y
; Assuming that our delta will never be more than a word (should be a lot less)
                                ldy #value_transform_node~tick_length
                                cmp [<pThis],y
                                bge lerp1_s_smoothed_done

; Get the elapsed delta
                                lda <dwCurrentTick
                                sec
                                sbc [<pLastTick]                ; value_transform_tick_state~last
                                beq lerp1_s_smoothed_same
                                tax
; Store the sampled tick time back in the transform
                                lda <dwCurrentTick
                                putword [<pLastTick],#value_transform_tick_state~last
                                lda <dwCurrentTick+2
                                putword [<pLastTick],#value_transform_tick_state~last+2

                                clc
                                getword [<pThis],#value_transform_node~value_intermediate
                                ldy #value_transform_node~value_delta
lerp1_s_smoothed_delta_loop     adc [<pThis],y
                                dex
                                bne lerp1_s_smoothed_delta_loop
                                putword [<pThis],#value_transform_node~value_intermediate
                                xba
                                and #$00ff
                                asl a
                                tax
                                lda >math~fixed_point_0_to_1_128_steps_smoothed,x
                                tax
                                getword [<pThis],#value_transform_node~value_range
                                jsl math~mul2r4
; The retured value is scaled up by 8 bits
                                xba
                                and #$00ff
                                sta <wTemp
                                txa
                                xba
                                and #$ff00
                                ora <wTemp
                                clc
                                ldy #value_transform_node~value_start
                                adc [<pThis],y
                                putword [<pThis],#value_transform_node~value
; Value is different (hmm, the value can actually be the same, if the same sample point in the lookup table was used. Fix?)
                                lda #value_transform_state~changed
                                jmp exit

lerp1_s_smoothed_done           getword [<pThis],#value_transform_node~value_end
                                putword [<pThis],#value_transform_node~value
                                lda #value_transform_state~changed+value_transform_state~node_end
                                jmp exit

lerp1_s_smoothed_same           lda #value_transform_state~none
                                jmp exit

                                end


; =============================================================================
; value_transform functions
; =============================================================================

; -----------------------------------------------------------------------------
; Construct Value Transform object
value_transform_construct       start seg_slib
                                using std_errors
                                using std_objects
                                using value_transform_data

                                debugtag 'value_transform_construct'

                                begin_locals
result                          decl word                                           ; result value inside our local work area
work_area_size                  end_locals

                                sub (4:pThis),work_area_size

                                testptr <pThis
                                beq null_pointer
; Clear memory.  Make this into a macro?  memclear [<pThis],#sizeof~value_transform_header
                                ldy #sizeof~value_transform_header-2
                                lda #0
loop                            sta [<pThis],y
                                dey
                                dey
                                bpl loop
; Construct the vector
                                pushptr <pThis,#value_transform~nodes
                                pushptr #value_transform_node_object
                                jsl container_vector_construct

                                clc
exit                            anop
                                sta <result
                                retkc 2:result
null_pointer                    lda #system_id_value_transform+std_error_null_pointer
                                sec
                                bra exit

                                end

; -----------------------------------------------------------------------------
; Destruct Value Transform object
value_transform_destruct        start seg_slib
                                using std_errors

                                debugtag 'value_transform_destruct'

                                begin_locals
work_area_size                  end_locals

                                sub (4:pThis),work_area_size

                                testptr <pThis
                                beq null_pointer

; Destruct the vector
                                pushptr <pThis,#value_transform~nodes
                                jsl container_vector_destruct

                                clc
exit                            anop
                                retkc
null_pointer                    sec
                                bra exit

                                end

; -----------------------------------------------------------------------------
; Append a node by type
;
; Parameters:
;  pThis        - the transform
;  wNodeType    - the type of node to add
; Returns:
; Carry clear if no error, the pointer to the node in a/x
; Carry set on error, nullptr returned
value_transform_append_node_type start seg_slib
                                using std_errors

                                debugtag 'append_node_type'
                                debugtag 'value_transform'

                                begin_locals
result                          decl ptr
work_area_size                  end_locals

                                sub (4:pThis,2:wNodeType),work_area_size

                                testptr <pThis
                                beq null_pointer

                                pushptr <pThis,#value_transform~nodes
                                getword [<pThis],#value_transform~nodes+vector_definition~size
                                inc a
                                pushword
                                jsl container_vector_resize
                                bcs error

                                pushptr <pThis,#value_transform~nodes
                                jsl container_vector_data_back
                                bcs error               ; Really shouldn't happen, the resize would have failed.
                                putretptr <result

; Just set the type for now.  Probably should call a function to set it.
; Also, validate the type sometime, too.
                                lda <wNodeType
                                putword [<result],#value_transform_node~type

                                clc
exit                            anop
                                retkc 4:result
null_pointer                    anop
error                           anop
                                clearptr <result
                                sec
                                bra exit

                                end

; -----------------------------------------------------------------------------
; Clear all the nodes in the transform
;
; Parameters:
;  pThis        - the transform
; Returns:
; Nothing
value_transform_clear_nodes     start seg_slib
                                using std_errors

                                debugtag 'clear_nodes'
                                debugtag 'value_transform'

                                begin_locals
work_area_size                  end_locals

                                sub (4:pThis),work_area_size

                                testptr <pThis
                                beq null_pointer

                                pushptr <pThis,#value_transform~nodes
                                pushsword #0
                                jsl container_vector_resize

                                clc
exit                            anop
                                retkc
null_pointer                    anop
error                           anop
                                sec
                                bra exit

                                end

; -----------------------------------------------------------------------------
; Calculate the transforms value
;
; Parameters:
;  pThis            - the transform
;  dwCurrentTick    - the current tick
; Returns:
; Carry clear if no error, and value_transform_state in acc.
; Carry set on error
value_transform_update          start seg_slib
                                using std_errors

                                debugtag 'update'
                                debugtag 'value_transform'

                                begin_locals
result                          decl word
wNodeCount                      decl word
pNode                           decl ptr
work_area_size                  end_locals

                                sub (4:pThis,4:dwCurrentTick),work_area_size

                                testptr <pThis
                                jeq null_pointer

                                getword [<pThis],#value_transform~nodes+vector_definition~size
                                jeq no_nodes
                                sta <wNodeCount

                                getword [<pThis],#value_transform~flags
                                bit #value_transform_flag~initialized
                                beq initialize                                  ; Uninitialied?
                                getword [<pThis],#value_transform~last_result
                                bit #value_transform_state~transform_end
                                beq use_current                                 ; at the end?
                                sta <result
                                brl done
; Initialize the transform
initialize                      anop
                                ora #value_transform_flag~initialized
                                sta [<pThis],y
                                lda #0
                                putword [<pThis],#value_transform~current_node
                                putword [<pThis],#value_transform~last_result

                                pushptr <pThis,#value_transform~nodes
                                jsl container_vector_data
                                jcs no_nodes

                                putretptr <pNode
                                jsr initialize_nodes_for_calculation

                                jsr initialize_node_for_pass
                                bra calculate_current

use_current                     anop
                                pushptr <pThis,#value_transform~nodes
                                pushsword [<pThis],#value_transform~current_node
                                jsl container_vector_data_at
                                jcs no_nodes

                                putretptr <pNode

calculate_current               anop
                                pushptr <pNode
                                pushdword <dwCurrentTick
                                pushptr <pThis,#value_transform~tick_state
                                jsl value_transform_node_calculate
                                sta <result
                                putword [<pThis],#value_transform~last_result

                                bit #value_transform_state~node_end             ; Did it hit the end?
                                beq done                                        ; if no, we are done.  Not checking the overflowed bit, because the end would have been set too.
; End of the node. Check for looping.
                                getword [<pNode],#value_transform_node~loop_remaining
                                beq no_loop
                                bmi loop_infinite
; Loop - 1
                                dec a
                                sta [<pNode],y

loop_infinite                   getword [<pNode],#value_transform_node~loop_to
                                putword [<pThis],#value_transform~current_node
                                bra check_node

; Node does not loop, or we are done looping, next node
; Clear the pass_initialized flag
done_loop                       anop
no_loop                         getword [<pNode],#value_transform_node~flags
                                and #((value_transform_node_flag~pass_initialized*-1)-1)
                                sta [<pNode],y
                                incword [<pThis],#value_transform~current_node
; Check the node
check_node                      anop
                                cmp <wNodeCount
                                bge at_end                              ; At or past the last node?  We are done.

                                tax
                                pushptr <pThis,#value_transform~nodes
                                phx
                                jsl container_vector_data_at
                                bcs no_nodes

                                putretptr <pNode
                                jsr initialize_node_for_pass

                                lda <result
                                bit #value_transform_state~node_overflowed
                                jne calculate_current                               ; if set, go and calculate the new current one now to absorb the overflow.

no_nodes                        anop
done                            anop
                                clc
exit                            anop
                                retkc 2:result
null_pointer                    anop
error                           anop
                                sec
                                bra exit
; At the end of the transform, make sure the current node is pointing to the last, and set the result
at_end                          anop
                                lda <wNodeCount
                                dec a
                                putword [<pThis],#value_transform~current_node
                                lda #value_transform_state~transform_end
                                sta <result
                                bra done

; =====================================
; Internal functions

; Initialize a node for a pass.  This may not be the first pass it has done in the transform though.
initialize_node_for_pass        anop
                                pushptr <pNode
                                pushdword <dwCurrentTick
                                pushptr <pThis,#value_transform~tick_state
                                jsl value_transform_node_pass_initialize

                                rts

; =====================================
; Loop through all the nodes and get them ready for calculation.
; Note, this does assume that any expensive setup, such as calculating delta increments, has already been done.
initialize_nodes_for_calculation anop
; Clear the pass_initialized flag in each
; Since we are only doing that flag, we can just index off the first node
                                getword [<pThis],#value_transform~nodes+vector_definition~size
                                tax

                                ldy #value_transform_node~flags
initialize_nodes_loop           lda [<pNode],y
                                and #((value_transform_node_flag~pass_initialized*-1)-1)
                                sta [<pNode],y
                                tya
                                clc
                                adc #sizeof~value_transform_node
                                tay
                                dex
                                bne initialize_nodes_loop

                                rts

                                end

; -----------------------------------------------------------------------------
; Get the current tranform value
;
; Parameters:
;  pThis            - the transform
;  pValueOut        - where to put the value
; Returns:
; Carry clear if no error, and value size in acc
; Carry set on error
value_transform_get_current_value start seg_slib
                                using std_errors

                                debugtag 'get_current_value'
                                debugtag 'value_transform'

                                begin_locals
result                          decl word
wNodeCount                      decl word
pNode                           decl ptr
work_area_size                  end_locals

                                sub (4:pThis,4:pValueOut),work_area_size

                                testptr <pThis
                                beq null_pointer

                                getword [<pThis],#value_transform~nodes+vector_definition~size
                                beq no_nodes

                                getword [<pThis],#value_transform~flags
                                bit #value_transform_flag~initialized
                                beq not_initialized

                                pushptr <pThis,#value_transform~nodes
                                pushsword [<pThis],#value_transform~current_node
                                jsl container_vector_data_at
                                bcs no_nodes

; For the moment, to make this faster, just assume the value is the simple type
                                putretptr <pNode
                                getword [<pNode],#value_transform_node~value
                                sta [<pValueOut]

                                lda #2
                                sta <result

done                            anop
                                clc
exit                            anop
                                retkc 2:result
null_pointer                    anop
no_nodes                        anop
not_initialized                 anop
error                           anop
                                sec
                                bra exit

                                end


