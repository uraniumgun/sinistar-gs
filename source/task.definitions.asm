; Task Definitions
task_header                 gequ 0
task_header~prev_ptr        gequ task_header                    ; prev node in the list
task_header~next_ptr        gequ task_header~prev_ptr+4         ; next node in the list
task_header~func_ptr        gequ task_header~next_ptr+4         ; function pointer to call
task_header~list_offset     gequ task_header~func_ptr+4         ; the list offset that this node is on
sizeof~task_header          gequ task_header~list_offset+2

; Optional short pointer to 'jump' to, once the task is in the func_ptr.
; This needs to be placed as the first part of the *user* task data.
; This can be done by starting your task data, with a sizeof~task_control
; or just reserving 2 bytes, though using sizeof~task_control is better.
; This is required in the user portion of the header, because the task handler
; needs to access it, and it is easier to do so, if it is in the user
; portion.  i.e. going backward into the header, incurs overhead
; Having this in the user header, also make sure any overhead to
; support sleeping a task, is only in tasks that need use it.
task_control~func_sptr      gequ 0
sizeof~task_control         gequ task_control~func_sptr+2

; A definition for supporting generic 'timer' functionality in a task
; For use with the task_timer_resume macro.
; This will allow for a task to do a wait-for, inside the task itself.
; The timer simply counts down, and resumes if 0, or exits again if not.
; Since the countdown is just decremented, time must be adjusted to the task list frequency
task_timer_header           gequ sizeof~task_control
task_timer_header~timer     gequ task_timer_header
sizeof~task_timer_header    gequ task_timer_header~timer+2

; A list of tasks_header entries.  Note that this list is doubly-linked, however
; there is always a 'last' node, and that node points to itself.
; Also of note is that the position of head_ptr, must align so that the processed_ptr and head_ptr
; match up to where the prev_ptr and next_ptr would be in a task_header.
; This is used by the code as a fake a node, to kick off the list processing.
task_list                   gequ 0
task_list~fake_prev_node    gequ task_list                      ; used to help identify the start of the 'fake' prev node
task_list~last_processed_ptr gequ task_list~fake_prev_node      ; points to the last processed entry, can be null.
task_list~head_ptr          gequ task_list~last_processed_ptr+4 ; the head node, can be null
task_list~backlog_counter   gequ task_list~head_ptr+4           ; incremented when a list is started, and decremented in its tail node.  Used to signal that a list was interrupted.
task_list~count             gequ task_list~backlog_counter+2    ; number of tasks in the list.  Almost always will be at least 1, because of the permanent tail node
task_list~offset            gequ task_list~count+2              ; the lists offset.  Note, matches up the alignment to where this is, in the task_header
sizeof~task_list            gequ task_list~offset+2

