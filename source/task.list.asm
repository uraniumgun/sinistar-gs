                            copy lib/source/debug.definitions.asm
                            copy lib/source/system.ids.asm
                            copy lib/source/object.definitions.asm
                            copy lib/source/container.definitions.asm

                            copy source/gameplay.constants.asm
                            copy source/task.definitions.asm

                            mcopy generated/task.list.macros

                            longa on
                            longi on

; Uncomment, to turn on some task validation
; There is a similar define in task.manager.asm
;task_debugging              gequ 1

; ----------------------------------------------------------------------------
; Functions for managing a task list

; ----------------------------------------------------------------------------
; Add to the task list.
; This always adds to the head of the list.
; Parameters:
; wTaskList         - the task list offset in the task_list_array
; pTask             - the task pointer

task_list_add               start seg_task
                            using task_manager_data

                            debugtag 'list_add'
                            debugtag 'task'

                            begin_locals
pHead                       decl ptr
work_area_size              end_locals

                            sub (2:wTaskList,4:pTask),work_area_size

                            setlocaldatabank

                            lda <wTaskList
                            putword [<pTask],#task_header~list_offset           ; track what list we are on, since we can move around
                            tax
                            lda task_list_array+task_list~head_ptr+2,x
                            bne has_head
; first one
                            lda <pTask
                            sta task_list_array+task_list~head_ptr,x
                            lda <pTask+2
                            sta task_list_array+task_list~head_ptr+2,x
                            lda #0
                            putptr [<pTask],#task_header~prev_ptr
                            putptr [<pTask],#task_header~next_ptr
                            bra exit

has_head                    anop
                            sta <pHead+2
                            lda task_list_array+task_list~head_ptr,x
                            sta <pHead

                            lda <pTask
                            sta task_list_array+task_list~head_ptr,x
                            lda <pTask+2
                            sta task_list_array+task_list~head_ptr+2,x

                            lda #0
                            putptr [<pTask],#task_header~prev_ptr
; Hook the node up to the old head node
                            lda <pHead
                            putptrlow [<pTask],#task_header~next_ptr
                            lda <pHead+2
                            putptrhigh [<pTask],#task_header~next_ptr

                            lda <pTask
                            putptrlow [<pHead],#task_header~prev_ptr
                            lda <pTask+2
                            putptrhigh [<pHead],#task_header~prev_ptr

exit                        anop
; increment the count
                            inc task_list_array+task_list~count,x
                            restoredatabank
                            ret
                            end

; ----------------------------------------------------------------------------
; Remove from the task list
; Parameters:
; pTask             - the task pointer.  This must be the header, not the data.

task_list_remove            start seg_task
                            using task_manager_data

                            debugtag 'list_remove'
                            debugtag 'task'

                            begin_locals
pPrev                       decl ptr
pNext                       decl ptr
work_area_size              end_locals

                            sub (4:pTask),work_area_size
                            setlocaldatabank

; Is this task, the current task?
                            lda <pTask
                            cmp prev_task_ptr
                            bne not_active
                            lda <pTask+2
                            cmp prev_task_ptr+2
                            bne not_active

; Must adjust the active task ptr
                            aif C:task_debugging=0,.skip
; Validation
                            getword [<pTask],#task_header~list_offset
                            cmp current_task_list_offset
                            assert_brk_cond beq,,$90
.skip

; The previous task, will be the new global previous task
                            getptr [<pTask],#task_header~prev_ptr,prev_task_ptr

; Was it null?
                            testptr prev_task_ptr
                            bne valid_prev
; Not a valid previous (we are removing the header pointer)
; Patch in the fake_prev node, to be the previous, which has a next_ptr in line with the head_ptr
                            ldx current_task_list_offset
                            lda #task_list_array+task_list~fake_prev_node
                            clc
                            adc current_task_list_offset
                            sta task_list_array+task_list~last_processed_ptr,x
                            sta prev_task_ptr
                            lda #^task_list_array+task_list~fake_prev_node
                            sta task_list_array+task_list~last_processed_ptr+2,x
                            sta prev_task_ptr+2

                            bra fixup_done

valid_prev                  anop
                            ldx current_task_list_offset
                            lda prev_task_ptr
                            sta task_list_array+task_list~last_processed_ptr,x
                            lda prev_task_ptr+2
                            sta task_list_array+task_list~last_processed_ptr+2,x
                            bra fixup_done

not_active                  anop
; Not active, but still have to check if we were the last processed task on the list
                            jsr _fixup_last_processed

fixup_done                  anop
                            getword [<pTask],#task_header~list_offset
                            tax
                            getptr [<pTask],#task_header~prev_ptr,<pPrev
                            beq was_head                    ; assuming that if the high word was 0, then null ptr

                            getptr [<pTask],#task_header~next_ptr,<pNext

                            sta [<pPrev],y                  ; y will be set correctly from the previous copy, and A will have the high word
                            lda <pNext
                            putptrlow [<pPrev],#task_header~next_ptr
                            ora <pNext+2
                            beq no_next                     ; should not be possible, task lists always have a tail

                            lda <pPrev
                            putptrlow [<pNext],#task_header~prev_ptr
                            lda <pPrev+2
                            putptrhigh [<pNext],#task_header~prev_ptr
                            bra done

was_head                    anop
                            getword [<pTask],#task_header~next_ptr
                            sta <pNext
                            sta task_list_array+task_list~head_ptr,x
                            getword [<pTask],#task_header~next_ptr+2
                            sta <pNext+2
                            sta task_list_array+task_list~head_ptr+2,x
                            lda #0
                            putptr [<pNext],#task_header~prev_ptr

no_next                     anop
done                        anop
; decrement the count
                            dec task_list_array+task_list~count,x
; Validation
                            aif C:task_debugging=0,.skip
                            lda task_list_array+task_list~last_processed_ptr,x
                            cmp <pTask
                            bne ok
                            lda task_list_array+task_list~last_processed_ptr+2,x
                            cmp <pTask+2
                            assert_brk_cond bne,,$9a
ok                          anop
.skip
                            restoredatabank
                            ret

;;
; Test the current task, which we have check to see is not the global previous task, to see if it was the last processed in its list.
_fixup_last_processed       anop
                            getword [<pTask],#task_header~list_offset
                            tax
                            lda task_list_array+task_list~last_processed_ptr,x
                            cmp <pTask
                            bne _fixup_last_processed_exit
                            lda task_list_array+task_list~last_processed_ptr+2,x
                            cmp <pTask+2
                            bne _fixup_last_processed_exit

; We were the last processed in our list
                            getword [<pTask],#task_header~prev_ptr+2
                            bne _fixup_last_processed_valid_prev
; Not a valid previous (we are removing the header pointer)
; Patch in the fake_prev node, to be the previous, which has a next_ptr in line with the head_ptr
                            txa
                            clc
                            adc #task_list_array+task_list~fake_prev_node
                            sta task_list_array+task_list~last_processed_ptr,x
                            lda #^task_list_array+task_list~fake_prev_node
                            sta task_list_array+task_list~last_processed_ptr+2,x
                            rts

; Valid previous, put as last processed
_fixup_last_processed_valid_prev anop
                            sta task_list_array+task_list~last_processed_ptr+2,x
                            getword [<pTask],#task_header~prev_ptr
                            sta task_list_array+task_list~last_processed_ptr,x
_fixup_last_processed_exit  rts

                            end

                            aif C:debug~task_validate_deletes=0,.skip
; ----------------------------------------------------------------------------
; Validate the input task is in the list
; Parameters:
; pTask             - the task pointer.  This must be the header, not the data.
task_validate_in_list       start seg_task
                            using task_manager_data

                            debugtag 'validate_in_list'
                            debugtag 'task'

                            begin_locals
pNode                       decl ptr
wTaskList                   decl word
work_area_size              end_locals

                            sub (4:pTask),work_area_size

                            getword [<pTask],#task_header~list_offset
                            sta <wTaskList
; Validate the list offset is ok
                            cmp #task_list_1_offset
                            beq ok_list
                            cmp #task_list_2_offset
                            beq ok_list
                            cmp #task_list_4_offset
                            beq ok_list
                            cmp #task_list_8_offset
                            beq ok_list
                            cmp #task_list_16_offset
                            beq ok_list
                            cmp #task_list_32_offset
                            beq ok_list
                            cmp #task_list_64_offset
                            beq ok_list
                            cmp #task_list_128_offset
                            beq ok_list
                            cmp #task_list_256_offset
                            beq ok_list
                            cmp #task_list_0_offset
                            beq ok_list
                            brk $60
exit                        ret

ok_list                     tax
                            lda >task_list_array+task_list~head_ptr+2,x
                            bne has_head
; List is empty
                            brk $61
                            bra exit

has_head                    sta <pNode+2
                            lda >task_list_array+task_list~head_ptr,x
                            sta <pNode

; Compare pNode to pTask
loop                        cmp <pTask
                            bne not_node
                            lda <pNode+2
                            cmp <pTask+2
                            beq exit

not_node                    getword [<pNode],#task_header~next_ptr+2
                            tax
                            getword [<pNode],#task_header~next_ptr
; See if the node loops on itself (next points back to itself).  This is the tail node
                            cmp <pNode
                            bne not_last
                            cpx <pNode+2
                            beq found_last
not_last                    stx <pNode+2
                            sta <pNode
                            bra loop

found_last                  brk $63
                            bra exit

                            end
.skip
