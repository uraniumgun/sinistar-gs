                            copy lib/source/debug.definitions.asm
                            mcopy generated/grlib.blockmove.macros

                            longa on
                            longi on
;------------------------------------------------------------------------------
; Copy a section of the background screen image and draw on top of the alt-screen.
; It is expected that the input values are already clipped.
;
; This version is using an unrolled inner loop, where a jump into the unrolled loop
; is calculated and patched in.  The patch only has to be done once per call
; and the jump cost 6 cycles per line, but the savings is 9 cycles per copy.
;
; Parameters:
;  <area_width      - Width of area in pixels.
;  <area_height     - Height of the area
;  <draw_x           - X coordinate, in pixels
;  <draw_y           - Y coordinate, in pixels
;
_back_buffer_to_alt_screen_area_unrolled start seg_grlib
                            using grlib_global_equates
                            using YLookupData

                            debugtag '_back_to_alt_unrolled'

; Pixel x to byte x
                            lsr <draw_x
                            lda <area_width
                            adc #0                      ; If the x was odd, pixel width goes up by 1
; Convert the pixel width into a byte width
                            lsr a
                            adc #0
                            sta <area_width
                            bit #1
                            jne odd_byte_width
*
* This routine assumes there is an even # of bytes across
*
; The lda/sta pairs are conveniently 8 bytes.
; acc already has the number of bytes, so number of words * 2, so we just need to asl two more times to get 8
                            asl a
                            asl a
; Invert and add to the run end, to get the jump location.  Not doing a clc, the asl above will have cleared it.
                            negate a
                            adc #even_run_end
                            sta >patch_even_jump+1

                            lda <draw_y
                            asl a
                            tax
                            lda >gYLookup,x             ; Get the memory offset for the line.  NOTE: Using short addressing.  Are we sure that the data bank is correct?
;                           clc                         ; Don't need this, the asl will have cleared it.
                            adc <draw_x
                            tax                         ; x now has the offset to the first byte on the line we want to copy

                            ldy <area_height
                            jmp patch_even_jump         ; skip the update of X on the first one, we have the correct value

; Insert the unrolled loop
; this 80 pairs of
;        lda >$000000,x
;        sta >$000000,x
; That are patched so that the X can access any location in the buffers.
patch_even_unrolled         UnrolledBlockCopyLineLoop 80
*
even_run_end                anop
*
                            dey                         ;finished?
                            beq even_done

                            txa
                            adc #160                    ; Move to the next line.  No need for a clc, the carry should be clear
                            tax

patch_even_jump             jmp |even_run_end

even_done                   rts
;--------------------------------------------
; This loop operates if there is an odd number of bytes across
odd_byte_width              anop
                            dec a                       ; Strip off the odd count
; acc already has the number of bytes, so number of words * 2, so we just need to asl two more times to get 8
                            asl a
                            asl a
; The 'odd' one is wrapped in sep/rep, add that separately
;                           clc                         ; asl will have cleared this
                            adc #8+2+2
; Invert and add to the run end, to get the jump location.  Not doing a clc, it should still be clear
                            negate a
                            adc #odd_run_end
                            sta >patch_odd_jump+1

                            lda <draw_y
                            asl a
                            tax
                            lda >gYLookup,x             ; Get the memory offset for the line.  NOTE: Using short addressing.  Are we sure that the data bank is correct?
;                           clc                         ; Don't need this, the asl will have cleared it.
                            adc <draw_x
                            tax                         ; x now has the offset to the first byte on the line we want to copy

                            ldy <area_height
                            jmp patch_odd_jump         ; skip the update of X on the first one, we have the correct value

; Insert the unrolled loop
; this 79 pairs of
;        lda >$000000,x
;        sta >$000000,x
; That are patched so that the X can access any location in the buffers.
patch_odd_unrolled          UnrolledBlockCopyLineLoop 79
; The last pair just does a byte
                            shortm
                            lda >$000000,x
                            sta >$000000,x
                            longm
*
odd_run_end                 anop

                            dey                         ;finished?
                            beq odd_done

                            txa
                            adc #160                    ; Move to the next line.  No need for a clc, the carry should be clear
                            tax

patch_odd_jump              jmp |odd_run_end

odd_done                    rts

; -----------------------------------------------------------------------------
; The grlib will call this to patch the function
_restore_area_unrolled_initialize_patch entry

                            lda #patch_even_unrolled
                            ldy #^patch_even_unrolled
                            jsr _patch_unrolled_word_move_even

                            lda #patch_odd_unrolled
                            ldy #^patch_odd_unrolled
                            jsr _patch_unrolled_word_move_odd

                            rts

; Takes the address in <back_ptr and <altscr_ptr and patches the unrolled word move code
; lda >$000000,x        back_ptr
; sta >$000000,x        altscr_ptr
; This is the 'even' version, so the first pair will have back_ptr + (160-2) and altscr_ptr + (160-2)
; going downward to 0
_patch_unrolled_word_move_even   anop
                            sta <patch_ptr
                            sty <patch_ptr+2
; Patch the lower 16 bits of the load
                            ldy #1
                            lda <back_ptr
                            jsr _grlib_block_move_patch_low_even
; Patch the lower 16 bits of the store
                            ldy #5
                            lda <altscr_ptr
                            jsr _grlib_block_move_patch_low_even

; Patch the high byte (bank) of the load
                            ldy #3                          ; Offset to the high byte
                            lda <back_ptr+2
                            jsr _grlib_block_move_patch_high_even

; Patch the high byte (bank) of the store
                            ldy #7                          ; Offset to the high byte
                            lda <altscr_ptr+2
                            jsr _grlib_block_move_patch_high_even
                            rts
; -----------------------------------------------------------------------------
; Takes the address in <back_ptr and <altscr_ptr and patches the unrolled word move code
; lda >$000000,x        back_ptr
; sta >$000000,x        altscr_ptr
; This is the odd version, so the first pair will have back_ptr + (160-3) and altscr_ptr + (160-3)
; going downward to 1
; The last
_patch_unrolled_word_move_odd   anop
                            sta <patch_ptr
                            sty <patch_ptr+2
; Patch the lower 16 bits of the load
                            ldy #1
                            lda <back_ptr
                            jsr _grlib_block_move_patch_low_odd
; Patch the lower 16 bits of the store
                            ldy #5
                            lda <altscr_ptr
                            jsr _grlib_block_move_patch_low_odd

; Patch the high byte (bank) of the load
                            ldy #3                          ; Offset to the high byte
                            lda <back_ptr+2
                            jsr _grlib_block_move_patch_high_odd

; Patch the high byte (bank) of the store
                            ldy #7                          ; Offset to the high byte
                            lda <altscr_ptr+2
                            jsr _grlib_block_move_patch_high_odd
                            rts
                            end

;------------------------------------------------------------------------------
; Copy a section of the alt-screen screen image and copy it to the real screen.
;
; This does obey the clipping region. Mostly.
; The PEI version will only do whole words, so it may do an extra byte of transfer on the right edge.
;
; This version is using an unrolled inner loop, where a jump into the unrolled loop
; is calculated and patched in.  The patch only has to be done once per call
; and the jump cost 6 cycles per line, but the savings is 9 cycles per copy.
;
; Parameters:
;  <area_width      - Width of area in pixels.
;  <area_height     - Height of the area
;  <draw_x           - X coordinate, in pixels
;  <draw_y           - Y coordinate, in pixels
;
_transfer_area_to_screen_unrolled start seg_grlib
                            using grlib_global_equates
                            using grlib_global_data
                            using YLookupData

                            jsr _clip_coords
                            bcc ok
                            rts
ok                          anop

_transfer_area_to_screen_unrolled_noclip entry

                            lda >grlib~altscr_is_shadowed
                            bpl not_shadowed
                            jsr _PEI_shadow_area_to_screen_unrolled
                            rts
not_shadowed                anop

; Pixel x to byte x
                            lsr <draw_x
                            lda <area_width
                            adc #0                              ; If X was odd, increase the width by 1
; Convert the pixel width into a byte width
                            lsr a
                            adc #0
                            sta <area_width
                            bit #1
                            jne odd_byte_width
*
* This routine assumes there is an even # of bytes across
*
; The lda/sta pairs are conveniently 8 bytes.
; acc already has the number of bytes, so number of words * 2, so we just need to asl two more times to get 8
                            asl a
                            asl a
; Invert and add to the run end, to get the jump location.  Not doing a clc, the asl above will have cleared it.
                            negate a
                            adc #even_run_end
                            sta >patch_even_jump+1

                            lda <draw_y
                            asl a
                            tax
                            lda >gYLookup,x             ; Get the memory offset for the line.  NOTE: Using short addressing.  Are we sure that the data bank is correct?
;                           clc                         ; Don't need this, the asl will have cleared it.
                            adc <draw_x
                            tax                         ; x now has the offset to the first byte on the line we want to copy

                            ldy <area_height
                            jmp patch_even_jump         ; skip the update of X on the first one, we have the correct value
; Insert the unrolled loop
; this 80 pairs of
;        lda >$000000,x
;        sta >$000000,x
; That are patched so that the X can access any location in the buffers.
patch_even_unrolled         UnrolledBlockCopyLineLoop 80
*
even_run_end                anop
*
                            dey                         ;finished?
                            beq even_done

                            txa
                            adc #160                    ; Move to the next line.  No need for a clc, the carry should be clear
                            tax

patch_even_jump             jmp |even_run_end

even_done                   rts
;--------------------------------------------
; This loop operates if there is an odd number of bytes across
odd_byte_width              anop
                            dec a                       ; Strip off the odd count
; acc already has the number of bytes, so number of words * 2, so we just need to asl two more times to get 8
                            asl a
                            asl a
; The 'odd' one is wrapped in sep/rep, add that separately
;                           clc                             ; the asl will have cleared this
                            adc #8+2+2
; Invert and add to the run end, to get the jump location.  Not doing a clc, the asl above will have cleared it.
                            negate a
                            adc #odd_run_end
                            sta >patch_odd_jump+1

                            lda <draw_y
                            asl a
                            tax
                            lda >gYLookup,x             ; Get the memory offset for the line.  NOTE: Using short addressing.  Are we sure that the data bank is correct?
;                           clc                         ; Don't need this, the asl will have cleared it.
                            adc <draw_x
                            tax                         ; x now has the offset to the first byte on the line we want to copy

                            ldy <area_height
                            jmp patch_odd_jump         ; skip the update of X on the first one, we have the correct value
; Insert the unrolled loop
; this 79 pairs of
;        lda >$000000,x
;        sta >$000000,x
; That are patched so that the X can access any location in the buffers.
patch_odd_unrolled          UnrolledBlockCopyLineLoop 79
; The last pair just does a byte
                            shortm
                            lda >$000000,x
                            sta >$000000,x
                            longm
*
odd_run_end                 anop

                            dey                         ;finished?
                            beq odd_done

                            txa
                            adc #160                    ; Move to the next line.  No need for a clc, the carry should be clear
                            tax

patch_odd_jump              jmp |odd_run_end
odd_done                    rts

; -----------------------------------------------------------------------------
; The grlib will call this to patch the function
_transfer_area_to_screen_unrolled_initialize_patch entry

                            lda #patch_even_unrolled
                            ldy #^patch_even_unrolled
                            jsr _patch_unrolled_word_move_even

                            lda #patch_odd_unrolled
                            ldy #^patch_odd_unrolled
                            jsr _patch_unrolled_word_move_odd

                            rts

; Takes the address in <back_ptr and <altscr_ptr and patches the unrolled word move code
; lda >$000000,x        altscr_ptr
; sta >$000000,x        <targetscr_ptr
; This is the 'even' version, so the first pair will have altscr_ptr + (160-2) and <targetscr_ptr + (160-2)
; going downward to 0
_patch_unrolled_word_move_even   anop
                            sta <patch_ptr
                            sty <patch_ptr+2
; Patch the lower 16 bits of the load
                            ldy #1
                            lda <altscr_ptr
                            jsr _grlib_block_move_patch_low_even
; Patch the lower 16 bits of the store
                            ldy #5
                            lda <targetscr_ptr
                            jsr _grlib_block_move_patch_low_even

; Patch the high byte (bank) of the load
                            ldy #3                          ; Offset to the high byte
                            lda <altscr_ptr+2
                            jsr _grlib_block_move_patch_high_even

; Patch the high byte (bank) of the store
                            ldy #7                          ; Offset to the high byte
                            lda <targetscr_ptr+2
                            jsr _grlib_block_move_patch_high_even
                            rts
; -----------------------------------------------------------------------------
; Takes the address in <back_ptr and <altscr_ptr and patches the unrolled word move code
; lda >$000000,x        back_ptr
; sta >$000000,x        altscr_ptr
; This is the odd version, so the first pair will have back_ptr + (160-3) and altscr_ptr + (160-3)
; going downward to 1
; The last
_patch_unrolled_word_move_odd   anop
                            sta <patch_ptr
                            sty <patch_ptr+2
; Patch the lower 16 bits of the load
                            ldy #1
                            lda <altscr_ptr
                            jsr _grlib_block_move_patch_low_odd
; Patch the lower 16 bits of the store
                            ldy #5
                            lda <targetscr_ptr
                            jsr _grlib_block_move_patch_low_odd

; Patch the high byte (bank) of the load
                            ldy #3                          ; Offset to the high byte
                            lda <altscr_ptr+2
                            jsr _grlib_block_move_patch_high_odd

; Patch the high byte (bank) of the store
                            ldy #7                          ; Offset to the high byte
                            lda <targetscr_ptr+2
                            jsr _grlib_block_move_patch_high_odd
                            rts
                            end



;------------------------------------------------------------------------------
; This assumes that the altscr_ptr is pointing to the shadowed SHR area
; which allows us to turn shadowing on, then load and store the same memory location
; and it will get 'shadowed' to the real screen.
; This doesn't do any tricky stuff (other functions will), and is a test to see
; if we can avoid the 1Mhz stalls that accessing the real-screen will have
;
; Parameters:
;  <area_width      - Width of area in pixels.
;  <area_height     - Height of the area
;  <draw_x           - X coordinate, in pixels
;  <draw_y           - Y coordinate, in pixels
;
_shadow_area_to_screen_unrolled start seg_grlib
                            using grlib_global_equates
                            using YLookupData
                            using softswitch_definitions

                            jsr _clip_coords
                            bcc ok
                            rts
ok                          anop
                            shortm
                            lda >ssw~shadow
                            and #(ssw~shadow~shr_inhibit*-1)-1
                            sta >ssw~shadow
                            longm
; Pixel x to byte x
                            lsr <draw_x
                            lda <area_width
                            adc #0                              ; If X was odd, increase the width by 1
; Convert the pixel width into a byte width
                            lsr a
                            adc #0
                            sta <area_width

                            bit #1
                            jne odd_byte_width
*
* This routine assumes there is an even # of bytes across
*
; The lda/sta pairs are conveniently 8 bytes.
; acc already has the number of bytes, so number of words * 2, so we just need to asl two more times to get 8
                            asl a
                            asl a
; Invert and add to the run end, to get the jump location.  Not doing a clc, the asl above will have cleared it.
                            negate a
                            adc #even_run_end
                            sta >patch_even_jump+1

                            lda <draw_y
                            asl a
                            tax
                            lda >gYLookup,x             ; Get the memory offset for the line.  NOTE: Using short addressing.  Are we sure that the data bank is correct?
;                           clc                         ; Don't need this, the asl will have cleared it.
                            adc <draw_x
                            tax                         ; x now has the offset to the first byte on the line we want to copy

                            ldy <area_height
                            jmp patch_even_jump         ; skip the update of X on the first one, we have the correct value
; Insert the unrolled loop
; this 80 pairs of
;        lda >$000000,x
;        sta >$000000,x
; That are patched so that the X can access any location in the buffers.
patch_even_unrolled         UnrolledBlockCopyLineLoop 80
*
even_run_end                anop
*
                            dey                         ;finished?
                            beq even_done

outer_even_loop             txa
                            adc #160                    ; Move to the next line.  No need for a clc, the carry should be clear
                            tax

patch_even_jump             jmp |even_run_end

even_done                   anop
                            shortm
                            lda >ssw~shadow
                            ora #ssw~shadow~shr_inhibit
                            sta >ssw~shadow
                            longm
                            rts
;--------------------------------------------
; This loop operates if there is an odd number of bytes across
odd_byte_width              anop
                            dec a                       ; Strip off the odd count
; acc already has the number of bytes, so number of words * 2, so we just need to asl two more times to get 8
                            asl a
                            asl a
; The 'odd' one is wrapped in sep/rep, add that separately
;                           clc                             ; the asl will have cleared this
                            adc #8+2+2
; Invert and add to the run end, to get the jump location.  Not doing a clc, the asl above will have cleared it.
                            negate a
                            adc #odd_run_end
                            sta >patch_odd_jump+1

                            lda <draw_y
                            asl a
                            tax
                            lda >gYLookup,x             ; Get the memory offset for the line.  NOTE: Using short addressing.  Are we sure that the data bank is correct?
;                           clc                         ; Don't need this, the asl will have cleared it.
                            adc <draw_x
                            tax                         ; x now has the offset to the first byte on the line we want to copy

                            ldy <area_height
                            jmp patch_odd_jump         ; skip the update of X on the first one, we have the correct value
; Insert the unrolled loop
; this 79 pairs of
;        lda >$000000,x
;        sta >$000000,x
; That are patched so that the X can access any location in the buffers.
patch_odd_unrolled          UnrolledBlockCopyLineLoop 79
; The last pair just does a byte
                            shortm
                            lda >$000000,x
                            sta >$000000,x
                            longm
*
odd_run_end                 anop
                            dey                         ;finished?
                            beq odd_done

                            txa
                            adc #160                    ; Move to the next line.  No need for a clc, the carry should be clear
                            tax

patch_odd_jump              jmp |odd_run_end

odd_done                    anop
                            shortm
                            lda >ssw~shadow
                            ora #ssw~shadow~shr_inhibit
                            sta >ssw~shadow
                            longm
                            rts

; -----------------------------------------------------------------------------
; The grlib will call this to patch the function
_shadow_area_to_screen_unrolled_initialize_patch entry

                            lda #patch_even_unrolled
                            ldy #^patch_even_unrolled
                            jsr _patch_unrolled_word_move_even

                            lda #patch_odd_unrolled
                            ldy #^patch_odd_unrolled
                            jsr _patch_unrolled_word_move_odd

                            rts

; Takes the address in <back_ptr and <altscr_ptr and patches the unrolled word move code
; lda >$000000,x        altscr_ptr
; sta >$000000,x        <targetscr_ptr
; This is the 'even' version, so the first pair will have altscr_ptr + (160-2) and <targetscr_ptr + (160-2)
; going downward to 0
_patch_unrolled_word_move_even   anop
                            sta <patch_ptr
                            sty <patch_ptr+2
; Patch the lower 16 bits of the load
                            ldy #1
                            lda <altscr_ptr
                            jsr _grlib_block_move_patch_low_even
; Patch the lower 16 bits of the store
                            ldy #5
                            lda <altscr_ptr
                            jsr _grlib_block_move_patch_low_even

; Patch the high byte (bank) of the load
                            ldy #3                          ; Offset to the high byte
                            lda <altscr_ptr+2
                            jsr _grlib_block_move_patch_high_even

; Patch the high byte (bank) of the store
                            ldy #7                          ; Offset to the high byte
                            lda <altscr_ptr+2
                            jsr _grlib_block_move_patch_high_even
                            rts
; -----------------------------------------------------------------------------
; Takes the address in <back_ptr and <altscr_ptr and patches the unrolled word move code
; lda >$000000,x        back_ptr
; sta >$000000,x        altscr_ptr
; This is the odd version, so the first pair will have back_ptr + (160-3) and altscr_ptr + (160-3)
; going downward to 1
; The last
_patch_unrolled_word_move_odd   anop
                            sta <patch_ptr
                            sty <patch_ptr+2
; Patch the lower 16 bits of the load
                            ldy #1
                            lda <altscr_ptr
                            jsr _grlib_block_move_patch_low_odd
; Patch the lower 16 bits of the store
                            ldy #5
                            lda <altscr_ptr
                            jsr _grlib_block_move_patch_low_odd

; Patch the high byte (bank) of the load
                            ldy #3                          ; Offset to the high byte
                            lda <altscr_ptr+2
                            jsr _grlib_block_move_patch_high_odd

; Patch the high byte (bank) of the store
                            ldy #7                          ; Offset to the high byte
                            lda <altscr_ptr+2
                            jsr _grlib_block_move_patch_high_odd
                            rts
                            end
;------------------------------------------------------------------------------
; This assumes that the altscr_ptr is pointing to the shadowed SHR area
; which allows us to turn shadowing on, then load and store the same memory location
; and it will get 'shadowed' to the real screen.
;
; This uses the PEI Slammer technique (why slammer, I don't know)
; The DP is used as a pointer to the screen, as well as the stack pointer
; This only does whole words, so it may do more horizontal area than what is passed in.
;
; This is a post-clipping function.
;
; Parameters:
;  <area_width      - Width of area in pixels.
;  <area_height     - Height of the area
;  <draw_x           - X coordinate, in pixels
;  <draw_y           - Y coordinate, in pixels
;
_PEI_shadow_area_to_screen_unrolled start seg_grlib
                            using grlib_global_equates
                            using YLookupData
                            using softswitch_definitions

pause_for_interrupts_count  equ 8                                       ; default value, but we patch over this from a table

                            shortm
                            lda >ssw~shadow
                            and #(ssw~shadow~shr_inhibit*-1)-1
                            sta >ssw~shadow
                            longm
; Convert the pixel width into a byte width
; Pixel x to byte x
                            lsr <draw_x
; If X was odd, increase the width by 1
                            lda <area_width
                            adc #0

                            lsr a                                       ; pixel width -> byte width
                            adc #0                                      ; increase if odd
; We also want the width to be in whole words
                            lsr a                                       ; word width
                            adc #0                                      ; increase if odd
                            asl a                                       ; back to bytes
                            tax                                         ; save word width * 2 for later
                            sta <area_width
; Make sure we are not off the edge
                            adc <draw_x
                            cmp #161                                    ; 160 + 1, so we can use a blt
                            blt ok_right
                            sec
                            sbc #160
                            negate a
                            clc
                            adc <draw_x
                            sta <draw_x
ok_right                    anop

; Get the number of lines before we panic and turn the interrupts back on for a bit, so we don't stall the audio, etc.
                            lda >pei_interrupt_breather_lines,x
                            cmp <area_height
                            jlt need_breather

; No breather in this loop, we have determined that the interrupts will be off for a 'reasonable' amount of time.

; The PEI $00 is 2 bytes, and area_width is the number of bytes
                            lda #run_end_a
                            sec
                            sbc <area_width
                            sta >patch_jump_a+1

                            lda <area_width
                            dec a
                            sta >patch_stack_adjust_a_1+1               ; Width - 1
                            sta >patch_stack_adjust_a_2+1

                            lda <draw_y
                            asl a
                            tax
                            lda >gYLookup,x                             ; Get the memory offset for the line.
;                           clc                                         ; carry will be clear from asl above
                            adc #$2000
                            adc <draw_x                                 ; c now has the offset to the first byte on the line we want to copy

                            ldy <area_height                            ; y will count down the height, get it now, while DP is ok
                            phd                                         ; save the DP
                            tcd
; Careful, no using dp values below here
; Adjust where the stack will go
patch_stack_adjust_a_1      adc #$0000                                  ; Point stack pointer to the end of the line
; Save the stack
                            tsx
; Hold our breath!
                            sei
; Set the stack
                            tcs

; Set to read/write bank 1
; Swapping into 8-bit mode, even though it will take 6 cycles. This should be within 1 cycle of the
; 16-bit read trick (ssw~state_reg+1 is not a functioning switch, so reading and writing to it should be 'safe'),
; The savings from working with 8 bit values (-3) and the fact that the sta will be a byte, which will update the slow-ram,
; and that should 2 'fast' cycles faster than writing 16-bits to slow-ram.
; I feel better about not writing to undocumented soft-switches, and it reduces the warnings shown in some emulators
                            shortm
                            lda >ssw~state_reg
                            ora #(ssw~state_reg~ramwrt+ssw~state_reg~ramrd)
                            sta >ssw~state_reg
                            longm
;
                            jmp patch_jump_a                ; go!

                            PEIBlockCopyLineLoop
run_end_a                   anop

                            dey
                            beq done_a                      ; finished?

                            tdc
                            adc #160                        ; Move the DP to the next line.  No need for a clc, the carry should be clear
                            tcd
patch_stack_adjust_a_2      adc #$0000                      ; Move stack pointer
                            tcs

patch_jump_a                jmp |run_end_a                  ; per-line overhead, 20 cycles

done_a                      anop
; Set to read/write bank 0
                            shortm
                            lda >ssw~state_reg              ; Note, doing a word read, there is nothing defined at ssw~state_reg+1
                            and #((ssw~state_reg~ramwrt+ssw~state_reg~ramrd)*-1)-1
                            sta >ssw~state_reg
                            lda >ssw~shadow
                            ora #ssw~shadow~shr_inhibit
                            sta >ssw~shadow
                            longm
                            txs                             ; restore the stack
                            pld
                            cli

                            rts

;; loop with pauses for re-enabling interrupts
need_breather               anop
                            sta >patch_breather_1+1
                            sta >patch_breather_2+1

; The PEI $00 is 2 bytes, and area_width is the number of bytes
                            lda #run_end_b
                            sec
                            sbc <area_width
                            sta >patch_jump_b+1

                            lda <area_width
                            dec a
                            sta >patch_stack_adjust_b_1+1                 ; Width - 1
                            sta >patch_stack_adjust_b_2+1

                            lda <draw_y
                            asl a
                            tax
                            lda >gYLookup,x                             ; Get the memory offset for the line.
;                           clc                                         ; carry will be clear from asl above
                            adc #$2000
                            adc <draw_x                                 ; c now has the offset to the first byte on the line we want to copy

                            ldy <area_height                            ; y will count down the height, get it now, while DP is ok
                            phd                                         ; save the DP
                            tcd
; Careful, no using dp values below here
; Save the stack
                            tsc
                            sta >patch_saved_stack_ptr_b_1+1
                            sta >patch_saved_stack_ptr_b_2+1
; Adjust where the stack will go
                            tdc
patch_stack_adjust_b_1      adc #$0000                                  ; Point stack pointer to the end of the line
; Hold our breath!
                            sei
; Set the stack
                            tcs

; Set to read/write bank 1
; Swapping into 8-bit mode, even though it will take 6 cycles. This should be within 1 cycle of the
; 16-bit read trick (ssw~state_reg+1 is not a functioning switch, so reading and writing to it should be 'safe'),
; The savings from working with 8 bit values (-3) and the fact that the sta will be a byte, which will update the slow-ram,
; and that should 2 'fast' cycles faster than writing 16-bits to slow-ram.
; I feel better about not writing to undocumented soft-switches, and it reduces the warnings shown in some emulators
                            shortm
                            lda >ssw~state_reg
                            ora #(ssw~state_reg~ramwrt+ssw~state_reg~ramrd)
                            sta >ssw~state_reg
                            longm
;
patch_breather_1            ldx #pause_for_interrupts_count
                            jmp patch_jump_b            ; go!

                            PEIBlockCopyLineLoop
run_end_b                   anop

                            dey
                            beq done_b                  ; finished?

                            dex
                            beq pause_for_interrupts

outer_loop                  tdc
                            adc #160                        ; Move the DP to the next line.  No need for a clc, the carry should be clear
                            tcd
patch_stack_adjust_b_2      adc #$0000                      ; Move stack pointer
                            tcs

patch_jump_b                jmp |run_end_b

pause_for_interrupts        anop
patch_saved_stack_ptr_b_1   lda  #$0000                     ; 3
                            tcs                             ; 2
; Set to read/write bank 0
                            shortm                          ; 3
                            lda >ssw~state_reg              ; 5
                            and #((ssw~state_reg~ramwrt+ssw~state_reg~ramrd)*-1)-1 ; 2
                            sta >ssw~state_reg              ; 5
                            longa on
; Interrupts back on, as well as setting M back to 16 bits
;                           cli
                            rep #%00100100              ; ..m..i..  3
patch_breather_2            ldx #pause_for_interrupts_count ; restore the interrupt countdown   ; 3
; Hope that was enough time!  Maybe add a nop?
;                           sei
                            sep #%00100100              ; ..m..i..     3
; Set to read/write bank 1
                            longa off
                            lda >ssw~state_reg          ; 5
                            ora #(ssw~state_reg~ramwrt+ssw~state_reg~ramrd) ; 3
                            sta >ssw~state_reg          ; 5
                            longm
                            bra outer_loop              ; 3
; 45 cycles total for the interrupt 'breather'

done_b                      anop
; Set to read/write bank 0
                            shortm
                            lda >ssw~state_reg          ; Note, doing a word read, there is nothing defined at ssw~state_reg+1
                            and #((ssw~state_reg~ramwrt+ssw~state_reg~ramrd)*-1)-1
                            sta >ssw~state_reg
                            lda >ssw~shadow
                            ora #ssw~shadow~shr_inhibit
                            sta >ssw~shadow
                            longm
patch_saved_stack_ptr_b_2   lda  #$0000
                            tcs
                            pld
                            cli

                            rts

; Index table where the input is the number if PEI opcodes that will be used
; and the output is the number of lines to process before a breather is in order
; The table is targeting a max of 3072 cycles between pauses
pei_interrupt_breather_lines anop
    dc i'$00c8,$0066,$0053,$0045,$003c,$0034,$002f,$002a,$0026,$0023,$0021,$001e,$001c,$001a,$0019,$0018'
    dc i'$0016,$0015,$0014,$0013,$0012,$0012,$0011,$0010,$0010,$000f,$000e,$000e,$000e,$000d,$000d,$000c'
    dc i'$000c,$000c,$000b,$000b,$000b,$000a,$000a,$000a,$000a,$0009,$0009,$0009,$0009,$0009,$0008,$0008'
    dc i'$0008,$0008,$0008,$0008,$0007,$0007,$0007,$0007,$0007,$0007,$0007,$0007,$0006,$0006,$0006,$0006'
    dc i'$0006,$0006,$0006,$0006,$0006,$0006,$0005,$0005,$0005,$0005,$0005,$0005,$0005,$0005,$0005,$0005'
    dc i'$0005'
                            end

;------------------------------------------------------------------------------
; This assumes that the altscr_ptr is pointing to the shadowed SHR area
; which allows us to turn shadowing on, then load and store the same memory location
; and it will get 'shadowed' to the real screen.
; This doesn't do any tricky stuff (other functions will), and is a test to see
; if we can avoid the 1Mhz stalls that accessing the real-screen will have
;
; Parameters:
;  <area_width      - Width of area in pixels.
;  <area_height     - Height of the area
;  <draw_x           - X coordinate, in pixels
;  <draw_y           - Y coordinate, in pixels
;
_fake_shadow_area_to_screen_unrolled start seg_grlib
                            using grlib_global_equates
                            using YLookupData
                            using softswitch_definitions

                            jsr _clip_coords
                            bcc ok
                            rts
ok                          anop
                            shortm
                            lda >ssw~shadow
                            and #(ssw~shadow~shr_inhibit*-1)-1
                            sta >ssw~shadow
                            longm
; Pixel x to byte x
                            lsr <draw_x
                            lda <area_width
                            adc #0                              ; If X was odd, increase the width by 1
; Convert the pixel width into a byte width
                            lsr a
                            adc #0
                            sta <area_width

                            bit #1
                            beq not_odd_width
                            inc a                               ; we want an even number of bytes, we are doing words only
not_odd_width               anop
*
* This routine assumes there is an even # of bytes across
*
; The sta is conveniently 4 bytes.
; acc already has the number of bytes, so number of words * 2, so we just need to asl one more time to get 4
                            asl a
; Invert and add to the run end, to get the jump location.  Not doing a clc, the asl above will have cleared it.
                            negate a
                            adc #even_run_end
                            sta >patch_even_jump+1

                            lda <draw_y
                            asl a
                            tax
                            lda >gYLookup,x             ; Get the memory offset for the line.  NOTE: Using short addressing.  Are we sure that the data bank is correct?
;                           clc                         ; Don't need this, the asl will have cleared it.
                            adc <draw_x
                            tax                         ; x now has the offset to the first byte on the line we want to copy

                            ldy <area_height
                            bra patch_even_jump         ; skip the update of X on the first one, we have the correct value

outer_even_loop             txa
                            adc #160                    ; Move to the next line.  No need for a clc, the carry should be clear
                            tax

                            lda #$a3a3
patch_even_jump             jmp |even_run_end
; Insert the unrolled loop
; this 80
;        sta >$000000,x
; That are patched so that the X can access any location in the buffers.
                            FakePEIBlockCopyLineLoop
*
even_run_end                anop
*
                            dey                         ;finished?
                            beq even_done               ; Too far to branch!  Note, not using the ORCA jne macro, it uses BRL, which is 4 cycles, where a jmp is 3!
                            jmp outer_even_loop
even_done                   anop
                            lda >ssw~shadow
                            ora #ssw~shadow~shr_inhibit
                            sta >ssw~shadow
                            longm
                            rts

                            end

;
; *****************************************************************************
;
; -----------------------------------------------------------------------------
; Helper functions for patching
; These assume they are patching
;   lda >$000000,x
;   sta >$000000,x
; 8 opcodes total
_grlib_block_move_helpers   start seg_grlib
                            using grlib_global_equates

; -----------------------------------------------------------------------------
_grlib_block_move_patch_low_even entry
                            clc
                            adc #(320/2)-2                  ; max bytes on a screen line - 2
                            ldx #((320/2)/2)                ; Each entry is writing a word
                            sec
patch_loop1                 anop
                            sta [<patch_ptr],y
                            sbc #2                          ; Address is going backward, by 2 bytes, since we are storing a word at a time
                            iny                             ; Unrolled loop, 8 bytes for the load/store opcodes
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            dex
                            bne patch_loop1
                            rts

_grlib_block_move_patch_high_even entry
                            ldx #((320/2)/2)                ; Each entry is writing a word
                            shortm
patch_loop2                 anop
                            sta [<patch_ptr],y              ; Bank is always the same
                            iny                             ; Unrolled loop, 8 bytes for the load/store opcodes
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            dex
                            bne patch_loop2
                            longm
                            rts
; -----------------------------------------------------------------------------
_grlib_block_move_patch_low_odd  entry
                            clc
                            adc #(320/2)-3                  ; max bytes on a screen line - 3
                            ldx #((320/2)/2)-1              ; Each entry is writing a word, except the last
                            sec
patch_loop1_odd             anop
                            sta [<patch_ptr],y
                            sbc #2                          ; Address is going backward, by 2 bytes, since we are storing a word at a time
                            iny                             ; Unrolled loop, 8 bytes for the load/store opcodes
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            dex
                            bne patch_loop1_odd
; The last one has a sep opcode in front, skip that
                            iny
                            iny
                            clc
                            adc #1                          ; We also subtracted too much, put one back
                            sta [<patch_ptr],y
                            rts

_grlib_block_move_patch_high_odd entry
                            ldx #((320/2)/2)-1              ; Each entry is writing a word, except the last
                            shortm
patch_loop2_odd             anop
                            sta [<patch_ptr],y              ; Bank is always the same
                            iny                             ; Unrolled loop, 8 bytes for the load/store opcodes
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            iny
                            dex
                            bne patch_loop2_odd
; The last one has a sep opcode in front, skip that
                            iny
                            iny
                            sta [<patch_ptr],y
                            longm
                            rts

                            end

; -----------------------------------------------------------------------------
; Takes the address in <patch_data_ptr and patches the unrolled word move code
; sta >$000000,x
; going downward to <patch_source_offset
;
; Parameters:
;  patch_code_ptr       - start of the code to patch
;  patch_code_offset    - offset from patch_code_ptr to write to.
;  patch_data_ptr       - END address to patch in
;  patch_data_offset    - the offset to to the data ptr.  This allows for the final end address to be offset.  The normal input is 0
;  patch_count          - the number of patches to make
_grlib_patch_unrolled_word_store_even start seg_grlib
                            lsub (4:patch_code_ptr,2:patch_code_offset,4:patch_data_ptr,2:patch_data_offset,2:patch_count),0

; Patch the lower 16 bits of the store
                            ldy <patch_code_offset
                            lda <patch_count
                            asl a
                            sec
                            sbc #2
                            clc
                            adc <patch_data_ptr
                            adc <patch_data_offset
                            ldx <patch_count
                            sec
patch_loop1                 anop
                            sta [<patch_code_ptr],y
                            sbc #2                          ; Address is going backward, by 2 bytes, since we are storing a word at a time
                            iny                             ; Unrolled loop, 4 bytes for the store opcodes
                            iny
                            iny
                            iny
                            dex
                            bne patch_loop1

; Patch the high byte (bank) of the store
                            ldy <patch_code_offset
                            iny
                            iny                             ; Offset to the high byte
                            lda <patch_data_ptr+2

                            ldx <patch_count
                            shortm
patch_loop2                 anop
                            sta [<patch_code_ptr],y              ; Bank is always the same
                            iny                             ; Unrolled loop, 4 bytes for the store opcodes
                            iny
                            iny
                            iny
                            dex
                            bne patch_loop2
                            longm

                            lret
                            end


; -----------------------------------------------------------------------------
; Takes the address in <patch_data_ptr and patches the unrolled word move code
; sta >$000000,x
; This is the odd version, and the last one is wrapped in a sep, to do one byte
_grlib_patch_unrolled_word_store_odd start seg_grlib
                            lsub (4:patch_code_ptr,2:patch_code_offset,4:patch_data_ptr,2:patch_data_offset,2:patch_count),0

; Patch the low word
                            ldy <patch_code_offset
                            lda <patch_count
                            asl a
                            sec
                            sbc #3
                            clc
                            adc <patch_data_ptr
                            adc <patch_data_offset
                            ldx <patch_count
                            dex                             ; The last is done separately
                            sec
patch_loop1_odd             anop
                            sta [<patch_code_ptr],y
                            sbc #2                          ; Address is going backward, by 2 bytes, since we are storing a word at a time
                            iny                             ; Unrolled loop, 4 bytes for the store opcodes
                            iny
                            iny
                            iny
                            dex
                            bne patch_loop1_odd
; The last one has a sep opcode in front, skip that
                            iny
                            iny
                            clc
                            adc #1                          ; We also subtracted too much, put one back
                            sta [<patch_code_ptr],y


; Patch the high byte (bank) of the store

                            ldy <patch_code_offset
                            iny
                            iny                             ; Offset to high byte
                            lda <patch_data_ptr+2

                            ldx <patch_count
                            dex                             ; The last is done separately
                            shortm
patch_loop2_odd             anop
                            sta [<patch_code_ptr],y              ; Bank is always the same
                            iny                             ; Unrolled loop, 4 bytes for the store opcodes
                            iny
                            iny
                            iny
                            dex
                            bne patch_loop2_odd
; The last one has a sep opcode in front, skip that
                            iny
                            iny
                            sta [<patch_code_ptr],y
                            longm

                            lret
                            end

; *********************************************************************************
; Patched, but not unrolled versions of the block moves
; *********************************************************************************

;------------------------------------------------------------------------------
; Copy a section of the background screen image and draw on top of the alt-screen.
; It is expected that the input values are already clipped.
;
; Note this this function uses a fair amout of patching.  Some can be done once
; at startup, but some parts need to be done, per-line.  This has a bit of overhead
; as compared to just using ZP addressing and [<zp],y access, especially with the
; 'odd' byte loop, as it requires two sets of patches.
; The 'even' loop only adds 2 per line and saves 2 per copy, so it is fine, but the
; 'odd' loop, adds an extra 12 cycles, so it needs 5 copies to break-even.
; which would be 18 pixels. :/
; There are some other opportunities to patch constants in the outer loop
; such as adc <draw_x and ldx <row_offset, but each would only save one cycle per line
; and add 9 cycles to do the patch.
;
; Parameters:
;  <area_width      - Width of area in pixels.
;  <area_height     - Height of the area
;  <draw_x           - X coordinate, in pixels
;  <draw_y           - Y coordinate, in pixels
;
_restore_area               start seg_grlib
                            using grlib_global_equates
                            using YLookupData

; Pixel x to byte x
                            lsr <draw_x
                            lda <area_width
                            adc #0                              ; If X was odd, increase the width by 1
; Convert the pixel width into a byte width
                            lsr a
                            adc #0
                            sta <area_width

                            dec a                       ; move a word inward.  Note, can got negative, we will catch this later
                            dec a
                            sta <row_offset

                            lda <area_width
                            lsr a                       ; 16 bits so div by 2
                            bcs odd_byte_width
*
* This routine assumes there is an even # of bytes across
*
                            lda <draw_y
                            asl a
                            tax
                            lda >gYLookup,x             ; Get the memory offset for the line.  NOTE: Using short addressing.  Are we sure that the data bank is correct?
;                           clc                         ; Don't need this, the asl will have cleared it.
                            adc <draw_x                  ; Add in the x start offset
                            sta <scratch_word            ; Save this, and we can just increment from then on, rather than re-looking it up
                            ldy <area_height
                            bra patch_even_store_add

outer_even_loop             lda <scratch_word
                            adc #160
                            sta <scratch_word
; Destination address
patch_even_store_add        adc #$0000                  ; Will be patched with <altscr_ptr
                            sta >patch_even_store+1      ; 5
*
; Source address
                            lda <scratch_word
patch_even_load_add         adc #$0000                  ; will be patched with <back_ptr
                            sta >patch_even_load+1       ; 5
*
                            ldx <row_offset             ; This will be even
*
inner_even_loop             anop
patch_even_load             lda >$000000,x
patch_even_store            sta >$000000,x
                            dex
                            dex
                            bpl inner_even_loop
*
                            dey                         ;finished?
                            bne outer_even_loop
                            rts
*
* This one operates if there is an odd number of bytes across
*
odd_byte_width              anop
                            beq one_byte_width              ; Just one byte wide?  Doing that separately, is faster, as it makes that loop simpler and the one below as well.
                            lda <draw_y
                            asl a
                            tax
                            lda >gYLookup,x             ; Get the memory offset for the line.  NOTE: Using short addressing.  Are we sure that the data bank is correct?
;                           clc                         ; carry will be clear from asl above
                            adc <draw_x                  ; Add in the x start offset
                            sta <scratch_word            ; Save this, and we can just increment from then on, rather than re-looking it up
                            ldy <area_height
                            bra patch_odd_store_add

outer_odd_loop              lda <scratch_word
                            adc #160
                            sta <scratch_word
*
patch_odd_store_add         adc #$0000                      ; will be patched with <altscr_ptr
                            sta >patch_odd_store1+1          ; 5
                            sta >patch_odd_store2+1          ; 5

*
                            lda <scratch_word
patch_odd_load_add          adc #$0000                      ; will be patched with <back_ptr
                            sta >patch_odd_load1+1           ; 5
                            sta >patch_odd_load2+1           ; 5
*
                            ldx <row_offset                 ; this will be odd, but at least 1
*
inner_odd_loop              anop
patch_odd_load1             lda >$000000,x
patch_odd_store1            sta >$000000,x
                            dex
                            dex
                            bpl   inner_odd_loop
*
* Do the last byte by itself
*
                            shortm
patch_odd_load2             lda >$000000
patch_odd_store2            sta >$000000
                            longm
*
                            dey                             ;finished?
                            bne outer_odd_loop
                            rts

; Just one byte wide
one_byte_width              anop
                            lda <altscr_ptr+2
                            sta <dest_ptr+2
                            lda <back_ptr+2
                            sta <src_ptr+2
                            lda <draw_y
                            asl a
                            tax
                            lda >gYLookup,x                 ; Get the memory offset of the line
;                           clc                             ; carry will be clear from asl above
                            adc <draw_x                      ; Add in the x start offset
                            sta <scratch_word                ; Save this, and we can just increment from then on, rather than re-looking it up
                            ldy <area_height
                            bra one_byte_loop_skip

one_byte_loop               lda <scratch_word
                            adc #160
                            sta <scratch_word
*
one_byte_loop_skip          adc <altscr_ptr
                            sta <dest_ptr
*
                            lda <scratch_word
                            adc <back_ptr
                            sta <src_ptr
*
                            shortm
                            lda [<src_ptr]
                            sta [<dest_ptr]
                            longm
*
                            dey                                 ;finished?
                            bne one_byte_loop
                            rts

; -----------------------------------------------------------------------------
_restore_area_initialize_patch entry
                            shortm                          ; 3
                            lda <altscr_ptr+2               ; 3
                            sta >patch_even_store+3          ; 4
                            sta >patch_odd_store1+3          ; 4
                            sta >patch_odd_store2+3          ; 4
                            lda <back_ptr+2                 ; 4
                            sta >patch_even_load+3           ; 4
                            sta >patch_odd_load1+3           ; 4
                            sta >patch_odd_load2+3           ; 4
                            longm
                            lda <altscr_ptr                 ; 4
                            sta >patch_even_store_add+1      ; 5
                            sta >patch_odd_store_add+1       ; 5
                            lda <back_ptr                   ; 4
                            sta >patch_even_load_add+1       ; 5
                            sta >patch_odd_load_add+1        ; 5

                            rts
                            end

; -------------------------------------------------------------------
; Transfer area
; Just like restore area but the destination is fixed (the screen)
; This function assumes clipping has already been done.
; Parameters:
;  <area_width      - Width of area in pixels
;  <area_height     - Height of the area
;  <draw_x           - X coordinate, in pixels
;  <draw_y           - Y coordinate, in pixels
;
_transfer_area_to_screen    start seg_grlib
                            using grlib_global_equates
                            using grlib_global_data
                            using YLookupData

                            jsr _clip_coords
                            bcs exit                    ; Anything in the clip?

; Pixel x to byte x
                            lsr <draw_x
                            lda <area_width
                            adc #0                              ; If X was odd, increase the width by 1
; Convert the pixel width into a byte width
                            lsr a
                            adc #0
                            sta <area_width

                            dec a                       ; move a word inward.  Note, can got negative, we will catch this later
                            dec a
                            sta <row_offset

                            lda <area_width
                            lsr a                       ; 16 bits so div by 2
                            bcs odd_byte_width
*
* This routine assumes there is an even # of bytes across
*
                            lda <draw_y
                            asl a
                            tax
                            lda >gYLookup,x             ; Get the memory offset for the line.  NOTE: Using short addressing.  Are we sure that the data bank is correct?
;                           clc                         ; Don't need this, the asl will have cleared it.
                            adc <draw_x                 ; Add in the x start offset
                            sta <scratch_word           ; Save this, and we can just increment from then on, rather than re-looking it up
                            ldy <area_height
                            bra patch_even_store_add

outer_even_loop             lda <scratch_word
                            adc #160
                            sta <scratch_word
; Destination address
patch_even_store_add        adc #$0000                  ; will be patched with <targetscr_ptr
                            sta >patch_even_store+1      ; 5
*
; Source address
                            lda <scratch_word
patch_even_load_add         adc #$0000                  ; will be patched with <altscr_ptr
                            sta >patch_even_load+1       ; 5
*
                            ldx <row_offset             ; This will be even
*
inner_even_loop             anop
patch_even_load             lda >$000000,x
patch_even_store            sta >$000000,x
                            dex
                            dex
                            bpl inner_even_loop
*
                            dey                         ;finished?
                            bne outer_even_loop
exit                        rts
*
* This one operates if there is an odd number of bytes across
*
odd_byte_width              anop
                            beq one_byte_width              ; Just one byte wide?  Doing that separately, is faster, as it makes that loop simpler and the one below as well.
                            lda <draw_y
                            asl a
                            tax
                            lda >gYLookup,x             ; Get the memory offset for the line.  NOTE: Using short addressing.  Are we sure that the data bank is correct?
;                           clc                         ; carry will be clear from asl above
                            adc <draw_x                 ; Add in the x start offset
                            sta <scratch_word           ; Save this, and we can just increment from then on, rather than re-looking it up
                            ldy <area_height
                            bra patch_odd_store_add

outer_odd_loop              lda <scratch_word
                            adc #160
                            sta <scratch_word
*
patch_odd_store_add         adc #$0000                      ; will be patched with <targetscr_ptr
                            sta >patch_odd_store1+1          ; 5
                            sta >patch_odd_store2+1          ; 5
*
                            lda <scratch_word
patch_odd_load_add          adc #$0000                      ; will be patched with <altscr_ptr
                            sta >patch_odd_load1+1           ; 5
                            sta >patch_odd_load2+1           ; 5
*
                            ldx <row_offset                 ; this will be odd, but at least 1
*
inner_odd_loop              anop
patch_odd_load1             lda >$000000,x
patch_odd_store1            sta >$000000,x
                            dex
                            dex
                            bpl   inner_odd_loop
*
* Do the last byte by itself
*
                            shortm
patch_odd_load2             lda >$000000
patch_odd_store2            sta >$000000
                            longm
*
                            dey                             ;finished?
                            bne outer_odd_loop
                            rts

; Just one byte wide
one_byte_width              anop
                            lda <targetscr_ptr+2
                            sta <dest_ptr+2
                            lda <altscr_ptr+2
                            sta <src_ptr+2
                            lda <draw_y
                            asl a
                            tax
                            lda >gYLookup,x                 ; Get the memory offset of the line
;                           clc                             ; carry will be clear from asl above
                            adc <draw_x                     ; Add in the x start offset
                            sta <scratch_word               ; Save this, and we can just increment from then on, rather than re-looking it up
                            ldy <area_height
                            bra one_byte_loop_skip

one_byte_loop               lda <scratch_word
                            adc #160
                            sta <scratch_word
*
one_byte_loop_skip          adc <targetscr_ptr
                            sta <dest_ptr

                            txa
*
                            clc
                            adc <altscr_ptr
                            sta <src_ptr
*
                            shortm
                            lda [<src_ptr]
                            sta [<dest_ptr]
                            longm
*
                            dey                             ;finished?
                            bne one_byte_loop
                            rts

; -----------------------------------------------------------------------------
_transfer_area_to_scree_initialize_patch entry
                            shortm                          ; 3
                            lda <altscr_ptr+2               ; 4
                            sta >patch_even_load+3          ; 4
                            sta >patch_odd_load1+3          ; 4
                            sta >patch_odd_load2+3          ; 4
                            lda <targetscr_ptr+2            ; 4
                            sta >patch_even_store+3         ; 4
                            sta >patch_odd_store1+3         ; 4
                            sta >patch_odd_store2+3         ; 4
                            longm
                            lda <altscr_ptr                 ; 4
                            sta >patch_even_load_add+1      ; 5
                            sta >patch_odd_load_add+1       ; 5
                            lda <targetscr_ptr              ; 4
                            sta >patch_even_store_add+1     ; 5
                            sta >patch_odd_store_add+1      ; 5

                            rts
                            end
