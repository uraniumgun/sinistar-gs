; Debug / Conditional asm equates
; Note, comment these out, don't just set to equal 0
; Most tests for these, check the existence of the equate, not the value
; If you do change these, be sure to clean the objs, and do a full rebuild
;
; If defined, the app will compile so it can be run in the GoldenGate emulator
; This means no graphics/event manager, etc.  It is essentially a console app.
;debug~golden_gate       gequ 1
; If defined, a regular memory buffer will be used for the target screen, not the real screen.
;debug~use_fake_screen   gequ 1
; If defined, any profile macros will be activated
;debug~profile           gequ 1
; If defined, any inner-profile macros will be activated.  Keep this off, with the main equate on to turn off inner profiling.
;debug~profile2          gequ 1
; If defined, the app has profile 'state' that can be enabled.
; This is used for setting up repeatable profile situations
;debug~use_profile_state gequ 1
; If defined, any debugtag macros will be active
;debug~use_tags          gequ 1
; If defined, debugging statistics will be on
;debug~stats             gequ 1
; If defined, keyed breaks will be enabled
;debug~use_keyed_breaks  gequ 1
; If defined, asserts will be enabled
;debug~use_asserts       gequ 1
; If defined, messages will be enabled
;debug~use_messages      gequ 1
; If defined, use minimal Toolbox calls
debug~use_min_toolbox   gequ 1
; If defined, scramble memory allocations so they are not 0
;debug~scramble_allocations gequ 1
; If defined, there is a bit of overhead for tracking os level memory state
debug~os_memory_tracking gequ 1
; If defined, the task system will validate deletes.  Helps find double-deletes
;debug~task_validate_deletes gequ 1

