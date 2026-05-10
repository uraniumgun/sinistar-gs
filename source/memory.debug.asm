                            copy lib/source/debug.definitions.asm
                            copy lib/source/system.ids.asm
                            copy lib/source/object.definitions.asm
                            copy lib/source/string.definitions.asm
                            copy lib/source/container.definitions.asm
                            copy lib/source/fixed.buffer.pool.definitions.asm
                            copy lib/source/string.manager.definitions.asm
                            copy lib/source/input.constants.asm

                            copy source/app.debug.definitions.asm

                            mcopy generated/memory.debug.macros

                            longa on
                            longi on

; ----------------------------------------------------------------------------
memory_debug_initialize     start seg_app

                            debugtag 'initialize_memory_debug'

                            setlocaldatabank

; Install the debug handler
                            pushptr #memory_debug_handler
                            pushsword #0                                    ; start off disabled
                            jsl appdebug_install_handler

                            restoredatabank
                            rtl

; Debug Handler
memory_debug_handler_priority equ $0001

memory_debug_handler        dc i'memory_debug_handler_id'
                            dc i'memory_debug_handler_priority'
                            dc a4'memory_debug_handler_show_info'
                            dc a4'memory_debug_handler_show_help'
                            dc a4'memory_debug_handler_keypress'
                            end

; ----------------------------------------------------------------------------
; A debug handler for showing system level allocations and the SBA state
; Uses the current textbox location.
memory_debug_handler_show_info start seg_app
                            using memory_manager_data
                            using sba_manager_data
                            using string_manager_data
                            using appdata
                            using appdebug_data
                            using applib_data
                            using textlib_global_data
                            using inputlib_data
                            using task_manager_data

                            begin_locals
wStartLine                  decl word
wPoolCount                  decl word
wSlotSize                   decl word
wSlotsInUse                 decl word
wBlockSize                  decl word
wBlockCount                 decl word
wTotalSlotsInUse            decl word
dwTotalSlotBytes            decl long
wTotalBlockCount            decl word
dwTotalBlockBytes           decl long
wTotalSlots                 decl word
wIndex                      decl word
pPool                       decl ptr
dwSBATotalSize              decl long
work_area_size              end_locals

                            sub (2:wStatus),work_area_size
                            setlocaldatabank

                            lda <wStatus
                            bit #debug_handler~status~displayed
                            bne not_first
; First time here
                            stz prev_draw_lines

not_first                   anop

                            lda >textbox_primary~cursor_y
                            sta <wStartLine

;                           lda #textbox_option~inverse+textbox_option~line_fill
;                           jsl textbox_set_options
;                           pushptr #os_memory_title_string
;                           jsl textbox_print_string
;                           jsl textbox_newline
;                           jsl textbox_set_option_normal

                            pushptr #str_newhandle
                            jsl textbox_print_string
                            pushsword #$20
                            jsl textbox_print_char
                            pushptr #str_count
                            jsl textbox_print_string
                            lda >memlib~os_allocation_count
                            pha
                            jsl textbox_print_hex_word
                            pushsword #$20
                            jsl textbox_print_char
                            pushptr #str_size
                            jsl textbox_print_string
                            lda >memlib~os_allocation_size+2
                            pha
                            jsl textbox_print_hex_word
                            lda >memlib~os_allocation_size
                            pha
                            jsl textbox_print_hex_word
                            jsl textbox_newline
; SBA General Info
                            jsl textbox_newline

; Individual SBAs
                            jsr print_individual_sbas

; Tasks
                            jsl textbox_newline
                            pushptr #str_task_count
                            jsl textbox_print_string
                            lda >task_counter
                            pha
                            jsl textbox_print_hex_word
                            jsl textbox_newline
; String manager
                            pushptr #str_string_count
                            jsl textbox_print_string
                            lda >global_string_manager+string_manager~alloc_count
                            pha
                            jsl textbox_print_hex_word
                            jsl textbox_newline

; exit
                            lda >textbox_primary~cursor_y
                            sec
                            sbc <wStartLine
                            sta <wStartLine

                            lda prev_draw_lines
                            sec
                            sbc <wStartLine
                            bcc no_erase
                            beq no_erase
; We have to erase some previous lines
                            pha
                            pushsword #$20
                            jsl textbox_fill_lines

no_erase                    lda <wStartLine
                            sta prev_draw_lines

                            restoredatabank
                            ret

;;
;; Local functions

get_sba_totals              anop

                            lda >global_sba_manager~pool_count
                            sta <wPoolCount

                            stz dwSBATotalSize
                            stz dwSBATotalSize+2
                            stz <wIndex

sba_totals_loop             lda <wIndex
                            asl a
                            tax
                            lda >global_sba_manager~pool_bank
                            sta <pPool+2
                            lda >global_sba_manager~pool_sptrs,x
                            sta <pPool

                            getword [<pPool],#fixed_buffer_pool~block_size
                            tax
                            getword [<pPool],#fixed_buffer_pool~blocks_vector+vector_definition~size
                            jsl math~mul2r4
                            clc
                            adc <dwSBATotalSize
                            sta <dwSBATotalSize
                            txa
                            adc <dwSBATotalSize+2
                            sta <dwSBATotalSize+2
                            lda <wIndex
                            inc a
                            sta <wIndex
                            cmp <wPoolCount
                            bne sba_totals_loop

                            rts

slot_size_col_width         equ 10
slots_in_use_col_width      equ 13
slots_total_col_width       equ 12
slot_bytes_col_width        equ 11
block_size_col_width        equ 11
block_count_col_width       equ 12
block_bytes_col_width       equ 11

;;;
print_individual_sbas       anop

                            stz <wTotalSlotsInUse
                            stz <dwTotalSlotBytes
                            stz <dwTotalSlotBytes+2
                            stz <wTotalBlockCount
                            stz <dwTotalBlockBytes
                            stz <dwTotalBlockBytes+2
                            stz <wTotalSlots

                            pushptr #sba_column_header
                            jsl textbox_print_columns

                            pushsword #ascii~mousetext~horizontal_bar
                            jsl textbox_fill_line
                            jsl textbox_newline

                            lda >global_sba_manager~pool_count
                            sta <wPoolCount

                            stz dwSBATotalSize
                            stz dwSBATotalSize+2
                            stz <wIndex

sba_loop                    lda <wIndex
                            asl a
                            tax
                            lda >global_sba_manager~pool_bank
                            sta <pPool+2
                            lda >global_sba_manager~pool_sptrs,x
                            sta <pPool

                            getword [<pPool],#fixed_buffer_pool~block_size
                            tax
                            getword [<pPool],#fixed_buffer_pool~blocks_vector+vector_definition~size
; Slot Size
                            pushsword #slot_size_col_width
                            jsl textbox_set_column
                            getword [<pPool],#fixed_buffer_pool~slot_size
                            sta <wSlotSize
                            pha
                            jsl textbox_print_hex_word
; Slots In Use
                            pushsword #slots_in_use_col_width
                            jsl textbox_next_column
                            getword [<pPool],#fixed_buffer_pool~slots_inuse
                            sta <wSlotsInUse
                            pha
                            clc
                            adc <wTotalSlotsInUse
                            sta <wTotalSlotsInUse
                            jsl textbox_print_hex_word

; Slots Total
                            pushsword #slots_total_col_width
                            jsl textbox_next_column
                            getword [<pPool],#fixed_buffer_pool~blocks_vector+vector_definition~size
                            sta <wBlockCount
                            tax
                            getword [<pPool],#fixed_buffer_pool~slots_per_block
                            jsl math~umul2r2
                            pha
                            clc
                            adc <wTotalSlots
                            sta <wTotalSlots
                            jsl textbox_print_hex_word
; Slot Bytes
                            pushsword #slot_bytes_col_width
                            jsl textbox_next_column
                            lda <wSlotsInUse
                            ldx <wSlotSize
                            jsl math~mul2r4
                            pha
                            phx
                            clc
                            adc <dwTotalSlotBytes
                            sta <dwTotalSlotBytes
                            txa
                            adc <dwTotalSlotBytes+2
                            sta <dwTotalSlotBytes+2
                            jsl textbox_print_hex_word
                            jsl textbox_print_hex_word
; Block Size
                            pushsword #block_size_col_width
                            jsl textbox_next_column
                            getword [<pPool],#fixed_buffer_pool~block_size
                            sta <wBlockSize
                            pha
                            jsl textbox_print_hex_word

; Block Count
                            pushsword #block_count_col_width
                            jsl textbox_next_column
                            getword <wBlockCount
                            pha
                            clc
                            adc <wTotalBlockCount
                            sta <wTotalBlockCount
                            jsl textbox_print_hex_word

; Block Bytes
                            pushsword #block_bytes_col_width
                            jsl textbox_next_column
                            lda <wBlockCount
                            ldx <wBlockSize
                            jsl math~mul2r4
                            pha
                            phx
                            clc
                            adc <dwTotalBlockBytes
                            sta <dwTotalBlockBytes
                            txa
                            adc <dwTotalBlockBytes+2
                            sta <dwTotalBlockBytes+2
                            jsl textbox_print_hex_word
                            jsl textbox_print_hex_word

                            jsl textbox_next_row_end_columns

                            lda <wIndex
                            inc a
                            sta <wIndex
                            cmp <wPoolCount
                            jne sba_loop

; Totals
                            pushptr #str_totals
                            jsl textbox_print_string
                            jsl textbox_newline
; Slot Size
                            pushsword #slot_size_col_width
                            jsl textbox_set_column
; Slots In Use
                            pushsword #slots_in_use_col_width
                            jsl textbox_next_column
                            pushsword <wTotalSlotsInUse
                            jsl textbox_print_hex_word
; Slots Total
                            pushsword #slots_total_col_width
                            jsl textbox_next_column
                            pushsword <wTotalSlots
                            jsl textbox_print_hex_word

; Slot Bytes
                            pushsword #slot_bytes_col_width
                            jsl textbox_next_column
                            pushsword <dwTotalSlotBytes+2
                            jsl textbox_print_hex_word
                            pushsword <dwTotalSlotBytes
                            jsl textbox_print_hex_word
; Block Size
                            pushsword #block_size_col_width
                            jsl textbox_next_column

; Block Count
                            pushsword #block_count_col_width
                            jsl textbox_next_column
                            pushsword <wTotalBlockCount
                            jsl textbox_print_hex_word
; Block Bytes
                            pushsword #block_bytes_col_width
                            jsl textbox_next_column
                            pushsword <dwTotalBlockBytes+2
                            jsl textbox_print_hex_word
                            pushsword <dwTotalBlockBytes
                            jsl textbox_print_hex_word

                            jsl textbox_next_row_end_columns

                            rts

str_newhandle               cstring 'NewHandle:'
str_count                   cstring 'Count: '
str_size                    cstring 'Size: '
str_totals                  cstring 'Totals:'
str_task_count              cstring 'Task Count:'
str_string_count            cstring 'String Count:'

str_slot_size               cstring 'Slot Size'
str_in_use                  cstring 'Slots In Use'
str_slot_total              cstring 'Slots Total'
str_slot_bytes              cstring 'Slot Bytes'
str_block_size              cstring 'Block Size'    ;'
str_block_count             cstring 'Block Count'   ;'
str_block_bytes             cstring 'Block Bytes'   ;'

sba_column_header           anop
                            dc i'slot_size_col_width'
                            dc i'textbox_data~string'
                            dc a4'str_slot_size'

                            dc i'slots_in_use_col_width'
                            dc i'textbox_data~string'
                            dc a4'str_in_use'

                            dc i'slots_total_col_width'
                            dc i'textbox_data~string'
                            dc a4'str_slot_total'

                            dc i'slot_bytes_col_width'
                            dc i'textbox_data~string'
                            dc a4'str_slot_bytes'

                            dc i'block_size_col_width'
                            dc i'textbox_data~string'
                            dc a4'str_block_size'

                            dc i'block_count_col_width'
                            dc i'textbox_data~string'
                            dc a4'str_block_count'

                            dc i'block_bytes_col_width'
                            dc i'textbox_data~string'
                            dc a4'str_block_bytes'
                            dc i'0'                             ; terminator

prev_draw_lines             dc i'0'
                            end

; -----------------------------------------------------------------------------
memory_debug_get_sba_totals private seg_app
                            using sba_manager_data

                            begin_locals
wPoolCount                  decl word
wIndex                      decl word
pPool                       decl ptr
dwSBATotalSize              decl long
work_area_size              end_locals

                            sub ,work_area_size

                            lda >global_sba_manager~pool_count
                            sta <wPoolCount

                            stz dwSBATotalSize
                            stz dwSBATotalSize+2
                            stz <wIndex

loop                        lda <wIndex
                            asl a
                            tax
                            lda >global_sba_manager~pool_bank
                            sta <pPool+2
                            lda >global_sba_manager~pool_sptrs,x
                            sta <pPool

                            getword [<pPool],#fixed_buffer_pool~block_size
                            tax
                            getword [<pPool],#fixed_buffer_pool~blocks_vector+vector_definition~size
                            jsl math~mul2r4
                            clc
                            adc <dwSBATotalSize
                            sta <dwSBATotalSize
                            txa
                            adc <dwSBATotalSize+2
                            sta <dwSBATotalSize+2
                            lda <wIndex
                            inc a
                            sta <wIndex
                            cmp <wPoolCount
                            bne loop

                            ret 4:dwSBATotalSize
                            end

; ----------------------------------------------------------------------------
; Draw the help for this handler
memory_debug_handler_show_help start seg_app

                            pushptr #basic_help1
                            jsl textbox_print_string
                            jsl textbox_newline

                            rtl

basic_help1                 cstring '[M] - Memory status'

                            end

; -----------------------------------------------------------------------------
memory_debug_handler_keypress start seg_app
                            using appdata
                            using appdebug_data
                            using applib_data
                            using grlib_global_data
                            using textlib_global_data

                            begin_locals
work_area_size              end_locals

                            sub (4:pHandler,2:wKey),work_area_size

                            getword [<pHandler],#debug_handler~enabled
                            beq not_enabled

; We are enabled
                            lda >grlib~in_text_mode
                            beq not_handled                                 ; Don't handle any keys if not in text mode

                            lda <wKey
                            cmp #'M'
                            bne not_handled

disable                     anop
                            lda #0
                            putword [<pHandler],#debug_handler~enabled
                            lda #$ffff
                            sta >appdebug~clear_text_screen
                            bra handled

; We are not enabled, the only key we listen for, is the one to enable us
not_enabled                 lda <wKey
                            cmp #'M'
                            bne not_handled

enable                      jsl appdebug_disable_all_handlers                           ; Disable everything else

                            lda #$ffff
                            putword [<pHandler],#debug_handler~enabled
                            sta >appdebug~clear_text_screen

handled                     clc
exit                        retkc
not_handled                 sec
                            bra exit

                            end
