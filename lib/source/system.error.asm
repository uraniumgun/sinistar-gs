                            copy lib/source/debug.definitions.asm
                            copy lib/source/system.ids.asm
                            copy lib/source/string.definitions.asm
                            copy 13/Ainclude/E16.GSOS
                            copy 13/Ainclude/E16.Memory

                            mcopy generated/system.error.macros

                            longa on
                            longi on

; -----------------------------------------------------------------------------
; System error handling.
; This system handles other systems registering their error reporting.
; This is user primarily to display a message to the end user that some
; fatal thing has happened.  The app will usually try to exit afterward.
;
; The error system assumes that the 16-bit error code is formatted
; so that the upper 8-bits are the system id, and the lower 8-bits are
; the system specific error code.
;
; The general display for the errors will be
;
; System Code: 0x0000
; Error: Out of memory
; Extra context information
;
; Press any key to exit.
; -----------------------------------------------------------------------------
system_error_data           data seg_slib

; Extra data for an error
system_error~last_system_breadcrumb dc i'0'                         ; The last breadcrumb value.  Use to help locate the issue
system_error~last_toolbox_code      dc i'0'                         ; The last toolbox error code, if relevant.
system_error~errors_are_fatal       dc i'1'                         ; If true, errors are fatal, and the app will exit after displaying the error

system_error~str_error              cstring 'Error: '
system_error~str_location           cstring 'Location: '
system_error~str_toolbox_code       cstring 'Toolbox Code: '
system_error~str_press_any_key      cstring 'Press any key to exit'
system_error~str_file_not_found     cstring 'File not found'
system_error~str_out_of_memory      cstring 'Out of Memory'         ; '

; An extra string that will be displayed on an 'out of memory' error
; The application side can set this to tell the user how much memory is required.
system_error~str_memory_needed_ptr  dc a4'0'

system_error~known_toolbox_codes    anop
                                    dc i'memErr'
                                    dc i'fileNotFound'
                                    dc i'0'                         ; terminator

system_error~known_toolbox_codes_strs anop
                                    dc a4'system_error~str_out_of_memory'
                                    dc a4'system_error~str_file_not_found'
                                    dc a4'0'                        ; terminator

system_error~max_registered_systems equ 32

system_error_entry~id               gequ 0                          ; The system id for the entry
system_error_entry~get_error_str    gequ system_error_entry~id+2    ; Function to fill the error string
system_error_entry~pad              gequ system_error_entry~get_error_str+4 ; Pad so the struct is 8 bytes
sizeof~system_error_entry           gequ system_error_entry~pad+2

system_error~registered_system_count dc i'0'
system_error~registered_systems     ds system_error~max_registered_systems*sizeof~system_error_entry

; Not expecting a novel, so just reserve a few strings.

system_error~max_display_strings    equ 16
system_error~valid_string_count     dc i'0'
; Array of string pointers to display.  The array does not own the strings.
; These can point into the system_error temporary string buffer or to external
; buffers.  If the latter, it is expected that the pointer is valid until
; the system error is displayed.  After that, this array will be reset.
system_error~valid_strings          ds system_error~max_display_strings*4

; A temporary string buffer that systems can use to format strings.
; It is not broken up into any particular set of strings, it is up to
; the system to use the buffer as it sees fit.
; The error system itself will not use this buffer, except with the generic error handler.
system_error~current_string_start   dc i'0'                     ; start of the string under construction.
system_error~current_string_end     dc i'0'                     ; end of the string under construction
system_error~temporary_string_buffer_size equ 512
system_error~temporary_strings      ds system_error~temporary_string_buffer_size

                            end

; -----------------------------------------------------------------------------
; Initialize the system
system_error_initialize     start seg_slib
;                           using system_error_data
; Static initialization should cover everything
                            clc
                            rtl
                            end
; -----------------------------------------------------------------------------
; Initialize the system
system_error_uninitialize   start seg_slib
                            rtl
                            end
; -----------------------------------------------------------------------------
; Register a handler for a system.
; The main requirement is for a system to have a handler to translate its
; error code, into a message to display to the end user.
;
system_error_register_handler start seg_slib
                            using system_error_data

                            debugtag 'register_handler'
                            debugtag 'system_error'

                            begin_locals
wCount                      decl word
wLocalBank                  decl word
work_area_size              end_locals

                            sub (2:wSystemID,4:pStringFunc),work_area_size
                            setlocaldatabank

                            lda <wSystemID
                            jsr system_error_get_handler_entry
                            bcc is_registered                                   ; Already registered, update
; Not registered, add it.
                            lda system_error~registered_system_count
                            cmp #system_error~max_registered_systems
                            bge too_many

                            static_assert_equal sizeof~system_error_entry,8
                            shiftleft 3
is_registered               tax
                            lda <wSystemID
                            sta system_error~registered_systems+system_error_entry~id,x
                            lda <pStringFunc
                            sta system_error~registered_systems+system_error_entry~get_error_str,x
                            lda <pStringFunc+2
                            sta system_error~registered_systems+system_error_entry~get_error_str+2,x
                            inc system_error~registered_system_count
                            clc
exit                        restoredatabank
                            retkc

too_many                    sec
                            bra exit
                            end

; -----------------------------------------------------------------------------
; Get the offset to a system's error handler
; Assumes the databank is already set to local
; Returns:
; a-reg     - offset to entry
; carry clear if found, set if not
system_error_get_handler_entry private seg_slib
                            using system_error_data

                            debugtag 'get_handler_entry'
                            debugtag 'system_error'

                            begin_locals
wCompare                    decl word
work_area_size              end_locals

                            pha                         ; save the compare

                            lda system_error~registered_system_count
                            beq not_found

                            dec a
                            shiftleft 3                 ; assuming that the entry is 8 bytes
                            tax

loop                        lda system_error~registered_systems+system_error_entry~id,x
                            cmp <wCompare,s
                            beq found
                            txa
                            sec
                            sbc #sizeof~system_error_entry
                            bmi not_found
                            tax
                            bra loop

found                       pla
                            txa
                            clc
                            rts

not_found                   pla
                            sec
                            rts
                            end

; -----------------------------------------------------------------------------
; Take the input error code and translate it to a set of strings
; that can be displayed.
; The output of the strings is to a shared area that can then be accessed
; by the display function.
; This will not display the error message
system_error_generate_error_msg start seg_slib
                            using system_error_data

                            debugtag 'generate_error_msg'
                            debugtag 'system_error'

                            begin_locals
wCount                      decl word
wLocalBank                  decl word
work_area_size              end_locals

                            sub (2:wError),work_area_size
                            setlocaldatabank

                            lda <wError
                            and #system_id~id_mask
                            jsr system_error_get_handler_entry
                            bcs no_handler
                            tax
                            lda system_error~registered_systems+system_error_entry~get_error_str+1,x
                            beq no_handler
                            sta patch+2
                            lda system_error~registered_systems+system_error_entry~get_error_str,x
                            sta patch+1

                            pushsword <wError

patch                       jsl >$000000

exit                        restoredatabank
                            ret

no_handler                  pushsword <wError
                            jsl system_error_generate_generic_error_msg
                            bra exit

                            end

; -----------------------------------------------------------------------------
; Generate a generic error message
; Assumes the databank is already local
system_error_generate_generic_error_msg start seg_slib
                            using system_error_data

                            debugtag 'generate_generic_error_msg'
                            debugtag 'system_error'

                            begin_locals
pStr                        decl ptr
wBufferOffset               decl word
work_area_size              end_locals

                            sub (2:wError),work_area_size

                            jsl system_error_reset_strings

; Add the Error string
                            pushptr #system_error~str_error
                            jsl system_error_append_string
                            pushsword <wError
                            jsl system_error_append_hex_word
                            jsl system_error_commit_string

; Add the Location string
                            pushptr #system_error~str_location
                            jsl system_error_append_string
                            pushsword system_error~last_system_breadcrumb
                            jsl system_error_append_hex_word
                            jsl system_error_commit_string

; Add the Toolbox code string, if not 0.
                            lda system_error~last_toolbox_code
                            beq skip

                            pushptr #system_error~str_toolbox_code
                            jsl system_error_append_string
                            pushsword system_error~last_toolbox_code
                            jsl system_error_append_hex_word
                            jsl system_error_commit_string

; See if we have a toolbox code string to print
                            ldx #0
loop                        lda system_error~known_toolbox_codes,x
                            beq not_found
                            cmp system_error~last_toolbox_code
                            beq found
                            inx
                            inx
                            bra loop

found                       phx
                            pushptr #0
                            jsl system_error_set_string                 ; Empty line
                            pla
                            asl a
                            tax
                            lda system_error~known_toolbox_codes_strs+2,x
                            pha
                            lda system_error~known_toolbox_codes_strs,x
                            pha
                            jsl system_error_set_string

not_found                   anop

; If it was an out of memory error, support showing some static string from the app side
; This can be something that tells the user how much memory is required.
                            lda system_error~last_toolbox_code
                            cmp #memErr
                            bne skip

                            lda system_error~str_memory_needed_ptr+2
                            beq skip
                            ldx system_error~str_memory_needed_ptr
                            beq skip
                            pha
                            phx
                            jsl system_error_set_string

skip                        anop
                            ret

                            end

; -----------------------------------------------------------------------------
; Show any generated error message.
system_error_show_error_msg start seg_slib
                            using system_error_data
                            using softswitch_definitions
                            using grlib_global_data

                            debugtag 'show_error_msg'
                            debugtag 'system_error'

                            begin_locals
wStringIndex                decl word
wPrevTextMode               decl word
work_area_size              end_locals

                            sub ,work_area_size

                            setlocaldatabank

                            lda system_error~valid_string_count
                            beq no_strings

                            lda >grlib~in_text_mode
                            sta <wPrevTextMode
                            bne already_in_text_mode

                            lda #1
                            jsl grlib_set_text_mode

already_in_text_mode        jsl textbox_clear_options
                            jsl textbox_reset_size

                            pushsword #$20
                            jsl textbox_clear

                            pushsword #0
                            pushsword #0
                            jsl textbox_set_cursor

                            lda #0
                            sta <wStringIndex

loop                        shiftleft 2
                            tax
                            lda system_error~valid_strings+2,x
                            pha
                            lda system_error~valid_strings,x
                            pha
                            jsl textbox_print_string
                            jsl textbox_newline
                            lda <wStringIndex
                            inc a
                            sta <wStringIndex
                            cmp system_error~valid_string_count
                            bne loop

; Show a 'press any key to exit' at the end.
; Might want to support a key-combo to drop into the debugger?
                            pushsword #(80-21)/2                    ; center the text. Assumes what the message is.
                            pushsword #23
                            jsl textbox_set_cursor
                            pushptr #system_error~str_press_any_key
                            jsl textbox_print_string

; Clear any buffered key
                            shortm
                            sta >ssw~kbd_strobe
                            longm

wait                        jsl get_key_press
                            beq wait

                            lda <wPrevTextMode
                            beq was_not_in_text_mode

                            lda #0
                            jsl grlib_set_text_mode

was_not_in_text_mode        anop
no_strings                  anop
                            restoredatabank
                            ret

                            end

; -----------------------------------------------------------------------------
; Handle a system error.
; This is meant to be called externally
; Parameters:
; a-reg     - system error code
system_error_handle_error   start seg_slib

                            debugtag 'handle_error'
                            debugtag 'system_error'

                            pha
                            jsl system_error_generate_error_msg
                            jsl system_error_show_error_msg
                            jsl system_error_handle_fatal
                            sec
                            rtl
                            end

; -----------------------------------------------------------------------------
; Handle a system error, with an additional string
; This is meant to be called externally
; Parameters:
; wError        - the system error
; pStr          - the string to add
system_error_handle_error_with_string start seg_slib

                            debugtag 'handle_error_with_string'
                            debugtag 'system_error'

                            begin_locals
work_area_size              end_locals

                            sub (2:wError,4:pStr),work_area_size

                            pushsword <wError
                            jsl system_error_generate_error_msg
; Add the extra string
                            pushptr <pStr
                            jsl system_error_set_string

                            jsl system_error_show_error_msg
                            jsl system_error_handle_fatal
                            sec
                            retkc
                            end

; -----------------------------------------------------------------------------
; Handle a system error, with an additional pascal (pathname) string
; This is meant to be called externally
; Parameters:
; wError        - the system error
; pStr          - the pascal string to add
system_error_handle_error_with_pstring start seg_slib

                            debugtag 'handle_error_with_pstring'
                            debugtag 'system_error'

                            begin_locals
work_area_size              end_locals

                            sub (2:wError,4:pStr),work_area_size

                            pushsword <wError
                            jsl system_error_generate_error_msg
; Add the pascal/path string.
                            lda <pStr+1
                            beq no_string

                            lda [<pStr]                     ; assuming the length is a word
                            beq no_string
                            pushsword <pStr+2
                            ldx <pStr                       ; skip the length, assuming that no banks are crossed.
                            inx
                            inx
                            phx
                            pha
                            jsl system_error_append_string_view
                            jsl system_error_commit_string

no_string                   jsl system_error_show_error_msg
                            jsl system_error_handle_fatal
                            sec
                            retkc
                            end

; -----------------------------------------------------------------------------
; Handle a toolbox and system error.
; This is meant to be called externally
; Parameters:
; a-reg     - system error code
; y-reg     - toolbox error code
system_error_handle_toolbox_error start seg_slib
                            using system_error_data

                            debugtag 'handle_error'
                            debugtag 'system_error'

                            pha
                            tya
                            sta >system_error~last_toolbox_code
                            jsl system_error_generate_error_msg
                            jsl system_error_show_error_msg
                            jsl system_error_handle_fatal
                            sec
                            rtl
                            end

; -----------------------------------------------------------------------------
; Exit the app, if the error system is set to fatal.
; Parameters:
; a-reg     - system error code
; y-reg     - toolbox error code
system_error_handle_fatal   start seg_slib
                            using system_error_data

                            lda >system_error~errors_are_fatal
                            bne is_fatal
                            rtl

is_fatal                    anop
; Call the app to do some cleanup.
                            jsl app_handle_abort
; Bye!
                            _QuitGS quit_params

quit_params                 dc    i2'$0002'
                            dc    i4'0'
                            dc    i2'0'
                            end

; -----------------------------------------------------------------------------
; Reset the display strings and temporary buffer
system_error_reset_strings  start seg_slib
                            using system_error_data

                            lda #0
                            sta >system_error~valid_string_count
                            sta >system_error~current_string_start
                            sta >system_error~current_string_end
                            rtl
                            end

; -----------------------------------------------------------------------------
; Sets a user string to the display string list, and advances the list index
system_error_set_string     start seg_slib
                            using system_error_data

                            debugtag 'set_string'
                            debugtag 'system_error'

                            begin_locals
work_area_size              end_locals

                            sub (4:pStr),work_area_size

                            setlocaldatabank

                            lda system_error~valid_string_count
                            cmp #system_error~max_display_strings
                            bge too_many
                            shiftleft 2
                            tax

                            lda <pStr
                            sta system_error~valid_strings,x
                            lda <pStr+2
                            sta system_error~valid_strings+2,x

                            inc system_error~valid_string_count

too_many                    restoredatabank
                            ret
                            end

; -----------------------------------------------------------------------------
; Commit the current string in the temporary buffer
system_error_commit_string  start seg_slib
                            using system_error_data

                            setlocaldatabank

                            lda system_error~valid_string_count
                            cmp #system_error~max_display_strings
                            bge too_many
                            shiftleft 2
                            tax

                            lda system_error~current_string_start
                            cmp #system_error~temporary_string_buffer_size
                            bge too_many

                            clc
                            adc #system_error~temporary_strings
                            sta system_error~valid_strings,x
                            lda #^system_error~temporary_strings
                            sta system_error~valid_strings+2,x

                            lda system_error~current_string_end
                            inc a                               ; skip past the null terminator
                            sta system_error~current_string_end
                            sta system_error~current_string_start

                            inc system_error~valid_string_count

too_many                    anop
                            restoredatabank
                            rtl
                            end
; -----------------------------------------------------------------------------
; Append a string to the temporary buffer area
system_error_append_string  start seg_slib
                            using system_error_data

                            debugtag 'append_string'
                            debugtag 'system_error'

                            begin_locals
work_area_size              end_locals

                            sub (4:pStr),work_area_size

                            setlocaldatabank

                            pushptr #system_error~temporary_strings
                            pushsword system_error~current_string_end
                            pushsword #system_error~temporary_string_buffer_size
                            pushptr <pStr
                            jsl str_append
                            sta system_error~current_string_end

                            restoredatabank

                            ret
                            end

; -----------------------------------------------------------------------------
; Append a string view to the temporary buffer area
system_error_append_string_view  start seg_slib
                            using system_error_data

                            debugtag 'append_string_view'
                            debugtag 'system_error'

                            begin_locals
work_area_size              end_locals

                            sub (4:pStr,2:wLength),work_area_size

                            setlocaldatabank

                            pushptr #system_error~temporary_strings
                            pushsword <wLength
                            pushsword system_error~current_string_end
                            pushsword #system_error~temporary_string_buffer_size
                            pushptr <pStr
                            jsl str_append_view
                            sta system_error~current_string_end

                            restoredatabank

                            ret
                            end

; -----------------------------------------------------------------------------
; Append a hex word as a string to the temporary buffer area
system_error_append_hex_word  start seg_slib
                            using system_error_data

                            debugtag 'append_hex_word'
                            debugtag 'system_error'

                            begin_locals
work_area_size              end_locals

                            sub (2:wValue),work_area_size

                            setlocaldatabank

                            pushptr #system_error~temporary_strings
                            pushsword system_error~current_string_end
                            pushsword #system_error~temporary_string_buffer_size
                            pushsword <wValue
                            pushsword #4
                            jsl str_append_hex_word
                            sta system_error~current_string_end

                            restoredatabank

                            ret
                            end

; -----------------------------------------------------------------------------
; Set the last toolbox error
; Parameters:
; y-reg  - the toolbox error
; No registers or the carry flag will be changed
system_error_set_toolbox_error start seg_slib
                            using system_error_data

                            debugtag 'set_toolbox_error'
                            debugtag 'system_error'

                            setlocaldatabank
; Why use Y?  It is often the easiest place to have the toolbox error after calling
; a toolbox function, as A and X are often needed to pull off return values.
                            sty system_error~last_toolbox_code
                            restoredatabank
                            rtl
                            end

; -----------------------------------------------------------------------------
; Set the last location breadcrumb
; Note, eventually I want this to be a push and pop system so there is a 'depth'
; to the locations, as well as preserving the location across subroutines
; Parameters:
; a-reg  - the location breadcrumb
; No registers or the carry flag will be changed
system_error_push_location  start
                            using system_error_data
                            sta >system_error~last_system_breadcrumb
                            rtl
                            end

; -----------------------------------------------------------------------------
system_error_pop_location   start
                            using system_error_data
                            rtl
                            end

; -----------------------------------------------------------------------------
; Set a string to show when out of memory.
; Note, this string is not copied, it has to stay around
system_error_set_required_memory_string start
                            using system_error_data

                            sub (4:pStr),0

                            lda pStr
                            sta >system_error~str_memory_needed_ptr
                            lda <pStr+2
                            sta >system_error~str_memory_needed_ptr+2
                            ret
                            end
