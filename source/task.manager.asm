                            copy lib/source/debug.definitions.asm
                            copy lib/source/system.ids.asm
                            copy lib/source/object.definitions.asm
                            copy lib/source/container.definitions.asm

                            copy source/gameplay.constants.asm
                            copy source/task.definitions.asm

                            mcopy generated/task.manager.macros

                            longa on
                            longi on

; Uncomment, to turn on some task validation
; There is a similar define in task.list.asm
;task_debugging              gequ 1

; ----------------------------------------------------------------------------
; Functions for managing all tasks

task_manager_data           data seg_task

task_manager_initialized    dc i'0'

; Task lists, that tick at different rates
; It is expected that these are sequential, as access will assume these
; form an array of task lists
task_list_array             anop
task_list_1                 ds sizeof~task_list                 ; always checks backlog priority
task_list_2                 ds sizeof~task_list                 ; checked if bit 0 is set on task_clock
task_list_4                 ds sizeof~task_list                 ; checked if bit 1 is set on task_clock
task_list_8                 ds sizeof~task_list                 ; checked if bit 2 is set on task_clock
task_list_16                ds sizeof~task_list                 ; checked if bit 3 is set on task_clock
task_list_32                ds sizeof~task_list                 ; checked if bit 4 is set on task_clock
task_list_64                ds sizeof~task_list                 ; checked if bit 5 is set on task_clock
task_list_128               ds sizeof~task_list                 ; checked if bit 6 is set on task_clock
task_list_256               ds sizeof~task_list                 ; checked if bit 7 is set on task_clock
task_list_0                 ds sizeof~task_list                 ; only processed, if all other lists have backlog of 0

task_list_1_offset          equ 0
task_list_2_offset          equ sizeof~task_list*1
task_list_4_offset          equ sizeof~task_list*2
task_list_8_offset          equ sizeof~task_list*3
task_list_16_offset         equ sizeof~task_list*4
task_list_32_offset         equ sizeof~task_list*5
task_list_64_offset         equ sizeof~task_list*6
task_list_128_offset        equ sizeof~task_list*7
task_list_256_offset        equ sizeof~task_list*8
task_list_0_offset          equ sizeof~task_list*9
task_list_end_offset        equ sizeof~task_list*10


task_list_addresses         anop
                            dc a4'task_list_1'
                            dc a4'task_list_2'
                            dc a4'task_list_4'
                            dc a4'task_list_8'
                            dc a4'task_list_16'
                            dc a4'task_list_32'
                            dc a4'task_list_64'
                            dc a4'task_list_128'
                            dc a4'task_list_256'
                            dc a4'task_list_0'

current_task_list_offset    ds 2                                    ; offset to the current task list we are working on, relative to task_list_array (TLEVEL)
prev_task_ptr               ds 4                                    ; the previous task executed. (PRTASK)  Note, because of the use of the 'fake prev node',
;                                                                     the only valid field for this pointer is task_header~next_ptr
task_clock                  ds 2                                    ; (TCLOCK)
task_counter                ds 2                                    ; total number of tasks in all the lists
is_processing_tasks         dc i'0'                                 ; if non-zero, tasks are processing.  A task can clear this to stop the processing
task_manager~update_rate    equ 1
;task_manager~last_tick     ds 4
task_manager~pass_count     ds 4
                            end

; ----------------------------------------------------------------------------
; A note about the task lists.
; They are doubly-linked, unlike the original code, but one thing that
; is similar to the original code is that there is a permanent
; 'last node', that does have a functional callback.
; The callback does work to reset values in the list.
; The other oddity about the last node is that its 'next' pointer,
; points to itself.

; ----------------------------------------------------------------------------
; Initialize the task manager and its lists.
task_manager_initialize     start seg_task
                            using task_manager_data

                            debugtag 'initialize'
                            debugtag 'task_manager'

                            begin_locals
wLoopTaskListOffset         decl word
pTask                       decl ptr
work_area_size              end_locals

                            sub ,work_area_size

                            setlocaldatabank

                            lda task_manager_initialized
                            beq do_init
                            assert_brk 'task_manager, already initialized'
                            brl exit

do_init                     stz <wLoopTaskListOffset

                            lda #1
                            sta task_manager_initialized

                            ldx #0
loop                        anop
                            stz task_list_array+task_list~head_ptr,x
                            stz task_list_array+task_list~head_ptr+2,x
                            stz task_list_array+task_list~last_processed_ptr,x
                            stz task_list_array+task_list~last_processed_ptr+2,x
                            stz task_list_array+task_list~backlog_counter,x
                            stz task_list_array+task_list~count,x
                            txa
                            sta task_list_array+task_list~offset,x                  ; have the list, know its offset too.

; Add the special tail node
                            pushsword <wLoopTaskListOffset
; task_list_0, has its own callback
                            cpx #task_list_0_offset
                            bne not_task_list_0
                            pushdword #task_0_tail_node_callback
                            lda #1                                          ; We also want the backlog count for task0 to start at 1
                            sta task_list_array+task_list~backlog_counter,x
                            bra next_push
not_task_list_0             pushdword #task_tail_node_callback
next_push                   pushsword #0
                            jsl task_manager_create_task

; Create task, returns the 'extra data' pointer, but I want to modify the task_header, back-track a bit
                            sec
                            sbc #sizeof~task_header
                            sta <pTask
                            stx <pTask+2

; Put in the loopback of the next pointer.
; Also, put the tail task as the last_processed_ptr
                            ldx <wLoopTaskListOffset

                            lda <pTask
                            putptrlow [<pTask],#task_header~next_ptr
                            lda <pTask+2
                            putptrhigh [<pTask],#task_header~next_ptr

; Put in the fake prev node as the last processed
                            lda #task_list_array+task_list~fake_prev_node
                            clc
                            adc <wLoopTaskListOffset
                            sta task_list_array+task_list~last_processed_ptr,x
                            lda #^task_list_array+task_list~fake_prev_node
                            sta task_list_array+task_list~last_processed_ptr+2,x

                            txa
                            clc
                            adc #sizeof~task_list
                            sta <wLoopTaskListOffset
                            tax
                            cmp #task_list_end_offset
                            blt loop

; Setup task0 to kick things off
                            lda #task_list_0_offset
                            sta current_task_list_offset
                            tax
                            lda task_list_array+task_list~last_processed_ptr,x
                            sta prev_task_ptr
                            lda task_list_array+task_list~last_processed_ptr+2,x
                            sta prev_task_ptr+2

                            stz task_counter
;                           stz task_manager~last_tick
;                           stz task_manager~last_tick+2
                            stz task_manager~pass_count
                            stz task_manager~pass_count+2

exit                        anop
                            restoredatabank
                            ret
                            end
; ----------------------------------------------------------------------------
; Special tail node that is always present in the list.
; Note, it also has a 'next' pointer to itself.
; Also note that this is for every task_list, other than task_list_0, which has a special callback.
task_tail_node_callback     start seg_task
                            using applib_data
                            using task_manager_data
                            debugtag 'tail_node_callback_task_1-256'

                            begin_locals
wHighestBackloggedList      decl word
                            aif C:task_debugging=0,.skip
pTask                       decl ptr
.skip
work_area_size              end_locals

                            sub (4:pTaskData),work_area_size
                            setlocaldatabank

                            ldx current_task_list_offset
; Put a special 'kick-off' pointer, into the last_processed_ptr
                            lda #task_list_array+task_list~fake_prev_node
                            clc
                            adc current_task_list_offset
                            sta task_list_array+task_list~last_processed_ptr,x
                            lda #^task_list_array+task_list~fake_prev_node
                            sta task_list_array+task_list~last_processed_ptr+2,x
; Decrement the backlog counter (should this test for 0 first?)
                            lda task_list_array+task_list~backlog_counter,x
                            bne not_0
                            assert_brk 'was_0'
                            bra was_0
not_0                       dec a
                            sta task_list_array+task_list~backlog_counter,x
was_0                       stx <wHighestBackloggedList

; Search for the list that has the highest backlog count.
; Special Note, this is the only place where task0 can be switched to.
; If all lists, other than task0, have a backlog of 0, then task0 will be picked, as it always has a backlog of 1
                            lda #0
loop                        cmp task_list_array+task_list~backlog_counter,x
                            bge next
; New higher list
                            stx <wHighestBackloggedList
                            lda task_list_array+task_list~backlog_counter,x

next                        tay
                            txa
                            clc
                            adc #sizeof~task_list
                            tax
                            tya
                            cpx #task_list_end_offset
                            blt loop

                            ldx <wHighestBackloggedList
                            stx current_task_list_offset
                            lda task_list_array+task_list~last_processed_ptr,x
                            sta prev_task_ptr
                            lda task_list_array+task_list~last_processed_ptr+2,x
                            sta prev_task_ptr+2

                            aif C:task_debugging=0,.skip
; Validation
                            sta <pTask+2
                            lda prev_task_ptr
                            sta <pTask
                            getword [<pTask],#task_header~list_offset
                            cmp current_task_list_offset
                            assert_brk_cond beq,,$91
.skip
                            restoredatabank
                            ret
                            end

; ----------------------------------------------------------------------------
; Special tail node, for task_list_0, that is always present in the list.
; Note, it also has a 'next' pointer to itself.
task_0_tail_node_callback   start seg_task
                            using task_manager_data
                            debugtag 'tail_node_callback_task_0'

                            begin_locals
                            aif C:task_debugging=0,.skip
pTask                       decl ptr
.skip
work_area_size              end_locals

                            sub (4:pTaskData),work_area_size
                            setlocaldatabank

; Just set back to the start.
                            ldx current_task_list_offset
; Put the fake prev node, into the last processed position
                            lda #task_list_array+task_list~fake_prev_node
                            clc
                            adc current_task_list_offset
                            sta task_list_array+task_list~last_processed_ptr,x
                            sta prev_task_ptr
                            lda #^task_list_array+task_list~fake_prev_node
                            sta task_list_array+task_list~last_processed_ptr+2,x
                            sta prev_task_ptr+2

                            aif C:task_debugging=0,.skip
; Validation
                            sta <pTask+2
                            lda prev_task_ptr
                            sta <pTask
                            getword [<pTask],#task_header~list_offset
                            cmp current_task_list_offset
                            assert_brk_cond beq,,$92
.skip
; We want to stop processing tasks, and allow the task_manager to determine the next, best thing to do.
                            stz is_processing_tasks

done                        restoredatabank
                            ret
                            end
; ----------------------------------------------------------------------------
; Tick the task manager.
; The expectation is that this will be called once every 60th of a second.
; If the update rate of the app is slower, the app should compensate by calling
; this more often.
task_manager_tick           start seg_task
                            using task_manager_data
                            using applib_data

                            debugtag 'task_manager_tick'

                            begin_locals
pPrevTask                   decl ptr
pTask                       decl ptr
wLoopTaskListOffset         decl word
wTaskCounter                decl word
work_area_size              end_locals

                            sub ,work_area_size

                            setlocaldatabank

;                           lda >applib~current_tick
;                           sec
;                           sbc task_manager~last_tick
;                           tax
;                           lda >applib~current_tick+2
;                           sbc task_manager~last_tick+2
;                           bne do_update
;                           cpx #task_manager~update_rate
;                           blt exit

;do_update                  lda >applib~current_tick
;                           sta task_manager~last_tick
;                           lda >applib~current_tick+2
;                           sta task_manager~last_tick+2

                            inc4 task_manager~pass_count

                            lda task_counter
                            bne ok_count
                            lda #1                      ; Do at least one pass
ok_count                    sta <wTaskCounter

; Start processing.
; This will loop for a maximum of the number of tasks that are instanced.
; However, it usually won't do that.  It is going to start the current_task_list_offset
; which is where the previous pass left off.  Once it finishes that list, its tail node handler,
; task_tail_node_callback, will search for any other lists that are 'backlogged', i.e. they did not finish.
; Those will then be processed.  If there are no backlogged lists, task0 list is run, and that has a special
; tail node callback that will halt processing.
;
                            lda #1
                            sta is_processing_tasks

tick_loop                   anop
; Get the previous task.
; Note, this can be be changed by task processing, do not rely on it being the last task processed in this loop
; i.e. it might not be pTask from the previous iteration.
; Also note, this can point to a fake node.  Only access task_header~next_ptr!
                            getptr prev_task_ptr,<pPrevTask

                            aif C:task_debugging=0,.skip
; Validation
                            getword [<pPrevTask],#task_header~list_offset
                            cmp current_task_list_offset
                            assert_brk_cond beq,,$93
.skip
                            getptr [<pPrevTask],#task_header~next_ptr,<pTask

                            aif C:task_debugging=0,.skip
; Validation
                            getword [<pTask],#task_header~list_offset
                            cmp current_task_list_offset
                            assert_brk_cond beq,,$94
.skip
; Set this before execution
                            ldx current_task_list_offset
                            lda <pTask
                            sta task_list_array+task_list~last_processed_ptr,x
                            sta prev_task_ptr
                            lda <pTask+2
                            sta task_list_array+task_list~last_processed_ptr+2,x
                            sta prev_task_ptr+2

                            aif C:task_debugging=0,.skip
; Validation
                            getword [<pTask],#task_header~list_offset
                            cmp current_task_list_offset
                            assert_brk_cond beq,,$95
.skip
; Patch the address in.  Note, doing this in an overlapping manner, so I don't have to change the acc size.
                            getword [<pTask],#task_header~func_ptr+1
                            beq no_callback                 ; if this is 0, then its null
                            sta patch_func+2
                            getword [<pTask],#task_header~func_ptr
                            sta patch_func+1

; Push the address of the task, extra data.  Note, assuming we never cross banks, so only adding to the lower word
                            pushsword <pTask+2
                            pushsword <pTask,#sizeof~task_header

patch_func                  jsl $ffffff

                            lda is_processing_tasks             ; Allowing for a task or, mote likely, reaching the end of the task0 list, to cancel processing
                            beq stop_processing

no_callback                 anop
                            dec <wTaskCounter
                            bne tick_loop

stop_processing             stz is_processing_tasks

                            jsr task_manager_advance_clock
; Original code seemed iterate over on-screen 'object workspaces' at this point, then just looped back to the top
exit                        anop
                            restoredatabank
                            ret
                            end

; ----------------------------------------------------------------------------
; Advance the task_clock and select the next task list to process based on
; the clock, as well as the backlog state
task_manager_advance_clock  private seg_task
                            using applib_data
                            using task_manager_data

                            debugtag 'advance_clock'
                            debugtag 'task_manager'

                            begin_locals
wNextTaskListOffset         decl word
pTask                       decl ptr
work_area_size              end_locals

                            lsub ,work_area_size

                            ldx current_task_list_offset
                            stx <wNextTaskListOffset

                            lda task_clock
                            inc a
                            sta task_clock
                            cmp #256
                            blt check_others
; Hit our limit for this list
                            stz task_clock
                            bra check_task_list_1

check_others                anop
                            lda #task_list_2_offset
                            sta <wNextTaskListOffset
                            lda task_clock
next_list                   anop
                            lsr a
                            bcs do_list
                            tay
                            lda <wNextTaskListOffset
                            clc
                            adc #sizeof~task_list
                            sta <wNextTaskListOffset
                            tya
                            bra next_list
do_list                     anop
; Increment the blocklog counter
                            ldx <wNextTaskListOffset
                            lda task_list_array+task_list~backlog_counter,x
                            inc a
                            assert_brk_cond bne,,$96
                            sta task_list_array+task_list~backlog_counter,x
; Compare to the current list's backlog counter
                            ldx current_task_list_offset
                            cmp task_list_array+task_list~backlog_counter,x
                            blt less_backlogged
                            bne more_backlogged
; Equally backlogged
                            cpx <wNextTaskListOffset            ; compare to our desired next offset
                            bge less_backlogged                 ; If the current is greater than the desired next offset, then keep the desired next one
; The current task list is more backlogged than the desired next one, set the desired next to the current one
more_backlogged             stx <wNextTaskListOffset
less_backlogged             anop
check_task_list_1           anop
; task_list_1 is high-priority, increment it's backlog, and see if it is more backlogged.
                            lda task_list_1+task_list~backlog_counter
                            inc a
                            assert_brk_cond bne,,$97
                            sta task_list_1+task_list~backlog_counter
                            ldx <wNextTaskListOffset
                            cmp task_list_array+task_list~backlog_counter,x
                            blt task_1_less_backlogged
                            ldx #task_list_1_offset             ; task list 1 is more backlogged, it wins
task_1_less_backlogged      anop
                            stx current_task_list_offset

                            lda task_list_array+task_list~last_processed_ptr,x
                            sta prev_task_ptr
                            lda task_list_array+task_list~last_processed_ptr+2,x
                            sta prev_task_ptr+2

                            aif C:task_debugging=0,.skip
; Validation
                            sta <pTask+2
                            lda prev_task_ptr
                            sta <pTask
                            getword [<pTask],#task_header~list_offset
                            cmp current_task_list_offset
                            assert_brk_cond beq,,$98
.skip

; Original code update the 'random crystal animation' CRYTBL
; Original code checked for attract mode, and stopped if it was
; Original code did a lot of what looks like drawing, as well as input handling
                            lret

                            end

; ----------------------------------------------------------------------------
; Create a task and add it to a task list.
; Parameters:
; wTaskList         - the task list offset to add to
; pCallback         - the task callback
; wTaskPayload      - the extra data to allocate for the task.
;                     this data will be directly after the task_header, and the caller can use it
;                     for any purpose.
; Returns:
; carry clear, pointer to the start of the extra payload data in the task.
; carry set, is an error.
task_manager_create_task    start seg_task
                            using task_manager_data
                            debugtag 'create_task'
                            debugtag 'task_manager'

                            begin_locals
pTask                       decl ptr
work_area_size              end_locals

                            sub (2:wTaskList,4:pCallback,2:wTaskPayload),work_area_size

                            setlocaldatabank

                            lda task_manager_initialized
                            assert_brk_cond bne,,$99

; Allocate the header + any extra the caller wants
                            pushsword <wTaskPayload,#sizeof~task_header
                            jsl sba_alloc
                            bcs error
                            putretptr <pTask

; Put the function pointer in
                            lda <pCallback
                            putptrlow [<pTask],#task_header~func_ptr
                            lda <pCallback+2
                            putptrhigh [<pTask],#task_header~func_ptr

; Add the task to the list, it will fill out the rest of the header
                            pushsword <wTaskList
                            pushptr <pTask
                            jsl task_list_add

                            inc task_counter

; This function is user facing, and the caller will not need to know about the header, but will want
; a pointer to any user data it requested.  Push the pointer to that.
; Note, it might be nice to return null, if wTaskPayload was 0.
; However, this is currently called internally by the manager, and it does need the pointer
; all the time, even if there is no extra data.
                            lda <pTask
                            clc
                            adc #sizeof~task_header
                            sta <pTask
; Clear the payload to 0
                            lda <wTaskPayload
                            beq no_payload

; This is usually pretty small. Make this inline with a macro or something.
                            pushptr <pTask
                            pushsword <wTaskPayload
                            jsl zero_memory

no_payload                  anop
                            clc
error                       anop
                            restoredatabank
                            retkc 4:pTask
                            end

; ----------------------------------------------------------------------------
; Remove a task from its list and delete it.
; Note this does NOT call the task callback, to tell it that it is getting removed.
; That should be done at a higher level.
; This is safe to call on the active task.
; Parameters:
; pTask             - the task pointer, can be null.
;                     Note, that since this is a user facing call, the pointer is the data pointer!
;
; Returns:
; carry clear, pointer to the task
; carry set, is an error.
task_manager_free_task      start seg_task
                            using task_manager_data

                            debugtag 'free_task'
                            debugtag 'task_manager'

                            begin_locals
work_area_size              end_locals

                            sub (4:pTask),work_area_size

                            setlocaldatabank

                            testptr <pTask
                            beq null_pointer

                            aif C:debug~task_validate_deletes=0,.skip
                            lda task_counter
                            bne ok_count
                            assert_brk 'tmfr'
ok_count                    anop
.skip
; Input is the data section pointer, adjust backward to get the header pointer
                            lda <pTask
                            sec
                            sbc #sizeof~task_header                 ; must get the header pointer, from the data pointer
                            sta <pTask
; no need to continue the subtraction, we don't allow bank crossing.
                            aif C:debug~task_validate_deletes=0,.skip
; Validate the input task is in the task list
                            pushptr <pTask
                            jsl task_validate_in_list
.skip
                            pushptr <pTask
                            jsl task_list_remove

                            aif C:task_debugging=0,.skip
; Zap this, so if it gets called, we will crash
                            lda #_deleted_task_crasher
                            putptrlow [<pTask],#task_header~func_ptr
                            lda #^_deleted_task_crasher
                            putptrhigh [<pTask],#task_header~func_ptr
.skip
                            pushptr <pTask
                            jsl sba_free

                            dec task_counter

null_pointer                clc
                            restoredatabank
                            retkc
                            end

                            aif C:task_debugging=0,.skip
; ----------------------------------------------------------------------------
_deleted_task_crasher       private seg_task
                            assert_brk 'deleted_task'
                            rtl
                            end
.skip
; ----------------------------------------------------------------------------
; Change a task node from one list, to another
; Parameters:
; pTask             - the task payload pointer from an existing task
; wTaskList         - the new task list offset
;
; Returns:
; carry clear, pointer to the start of the extra payload data in the task.
; carry set, is an error.
task_manager_change_list    start seg_task
                            using task_manager_data
                            debugtag 'change_list_and_callback'
                            debugtag 'task_manager'

                            begin_locals
work_area_size              end_locals

                            sub (4:pTask,2:wTaskList),work_area_size
                            setlocaldatabank

; The input task is pointing to where the user data is, get the task_header back
                            lda <pTask
                            sec
                            sbc #sizeof~task_header
                            sta <pTask

; Is the task list the same? If so, skip moving.
; Maybe move it regardless?  This would move it to the top of the list.  Hmmm.
                            getword [<pTask],#task_header~list_offset           ; the list the task is on now.
                            cmp <wTaskList
                            beq same

                            pushptr <pTask
                            jsl task_list_remove                                ; remove from the old list

                            pushsword <wTaskList                                ; add to the new one
                            pushptr <pTask
                            jsl task_list_add

same                        anop
                            restoredatabank
                            ret
                            end

; ----------------------------------------------------------------------------
; Change a task node from one list, to another, also changing its callback
; Parameters:
; pTask             - the task payload pointer from an existing task
; wTaskList         - the new task list offset
; pCallback         - the task callback
;
; Returns:
; carry clear, pointer to the start of the extra payload data in the task.
; carry set, is an error.
task_manager_change_list_and_callback start seg_task
                            using task_manager_data
                            debugtag 'change_list_and_callback'
                            debugtag 'task_manager'

                            begin_locals
work_area_size              end_locals

                            sub (4:pTask,2:wTaskList,4:pCallback),work_area_size
                            setlocaldatabank

; The input task is pointing to where the user data is, get the task_header back
                            lda <pTask
                            sec
                            sbc #sizeof~task_header
                            sta <pTask

; Is the task list the same? If so, skip moving.
; Maybe move it regardless?  This would move it to the top of the list.  Hmmm.
                            getword [<pTask],#task_header~list_offset           ; the list the task is on now.
                            cmp <wTaskList
                            beq same

                            pushptr <pTask
                            jsl task_list_remove                                ; remove from the old list

                            pushsword <wTaskList                                ; add to the new one
                            pushptr <pTask
                            jsl task_list_add

same                        anop
                            getword <pCallback
                            putptrlow [<pTask],#task_header~func_ptr
                            getword <pCallback+2
                            putptrhigh [<pTask],#task_header~func_ptr

                            restoredatabank
                            ret
                            end

