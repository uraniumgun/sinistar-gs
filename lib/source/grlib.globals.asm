                            copy lib/source/debug.definitions.asm
                            copy lib/source/system.ids.asm
                            copy lib/source/object.definitions.asm
                            copy lib/source/container.definitions.asm
                            copy lib/source/fixed.buffer.pool.definitions.asm
                            copy lib/source/grlib.definitions.asm
                            copy lib/source/grlib.sprite.definitions.asm
                            copy lib/source/grlib.font.definitions.asm
                            copy lib/source/framelib.definitions.asm
                            copy lib/source/grlib.entity.definitions.asm
                            copy lib/source/grlib.entity.sort.definitions.asm

                            mcopy generated/grlib.globals.macros

*-----------------------------------------------------------------
* Global locations used by the graphics routines.
* appdata~grlib_dp should be set to the direct page that is reserved
* for the graphics library routines.
*-----------------------------------------------------------------
grlib_global_equates        data seg_grlib

; Just equates in here please.
; Note, I'm using an arbitrary start offset, because I'm assuming that the DP is shared with
; the app-side on startup, that needs a few DP values.
; We currently have plenty of space, so this is ok, but really, it might be best that the grlib gets
; a DP page to itself, since there is plenty of that at startup.
; Might be nice to have all of these have a grdp~ prefix, as even with this in a different
; data segment, they names can collide with other usage, and some of these equates have
; very generic names.

                            begin_struct 8
shape_ptr                   decl ptr                                ; long pointer to the shape data
draw_x                      decl word
draw_y                      decl word
area_width                  decl word
area_height                 decl word
shape_width                 decl word
shape_height                decl word
mask_offset                 decl word                               ; offset, from shape_ptr, to the mask
*
clipy_top                   decl word
clipy_bottom                decl word
clipx_left                  decl word
clipx_right                 decl word
*
* These are temporary vars. that the animation routine uses
* Using ZP's for speed, as well as because we re-point the data bank to the shape's bank for most of the operations.
*
shape_x_offset              decl word                               ; X, relative to the left of the shape
shape_y_offset              decl word                               ; Y, relative to the top of the shape
shape_byte_width            decl word                               ; byte width of pixels to draw
shape_rowbytes              decl word                               ; rowbytes of a shape line (block shape). This can differ from shape_byte_width, to allow for drawing a segment in a larger block shape
fore_color                  decl word
back_color                  decl word
block_shape_blit_func       decl word                               ; Blit mode * 2, for use in a jump table
font_blit_func              decl word                               ; Blit mode * 2, for use in a jump table
; { Start PRLE drawing specific values
shape_byte_clip_left        decl word
shape_byte_clip_right       decl word
dest_left_edge_byte_offset  decl word
dest_left_edge_byte_ptr     decl sptr                               ; short pointer
group_data_byte_size        decl word
group_data_store_ptr        decl sptr                               ; short pointer
group_data_load_ptr         decl sptr                               ; short pointer
group_dest_indent           decl word
group_data_offset_adjust    decl word
group_info                  decl word
area_height_countdown       decl word
; } End PRLE drawing specific values
row_offset                  decl word
dest_ptr                    decl ptr
src_ptr                     decl ptr
altscr_ptr                  decl ptr
back_ptr                    decl ptr
targetscr_ptr               decl ptr
param_ptr                   decl ptr
patch_ptr                   decl ptr
scratch_word                decl word                               ; A scratch word value
sizeof~grdp~internals       end_struct grdp~end_internal

; Update rects values, that persist over multiple updates
                                begin_struct grdp~end_internal
urdp~to_screen_space_offset_x   decl word
urdp~to_screen_space_offset_y   decl word
urdp~max~top                    decl word
urdp~max~left                   decl word
urdp~max~bottom                 decl word
urdp~max~right                  decl word
sizeof~urdp~persistent          end_struct urdp~persistent_end_internal

; Active Font 1
                            begin_struct urdp~persistent_end_internal
grdp~font1                  decl sizeof~grlib~font_dp_def
sizeof~grdp~font1           end_struct grdp~font1_end

; The remaining is allowed to be used by the caller.
grdp~caller_scratch_buffer  equ grdp~font1_end
; Check that we didn't overflow
                            static_assert_greater_than 256,grdp~caller_scratch_buffer
grdp~caller_scratch_buffer_size equ 256-grdp~caller_scratch_buffer

                            end

; ------------------------------------------------------------------------------
; Global storage for the grlib
grlib_global_data           data seg_grlib
grlib~shr_screen            equ $00e12000
grlib~shadowed_shr_screen   equ $00012000
grlib~shr_palettes          equ $00e19e00

grlib~shr_scbs              equ $e19d00
grlib~shr_scb_resolution_mask equ %10000000
grlib~shr_scb_320           equ %00000000
grlib~shr_scb_640           equ %10000000
grlib~shr_scb_interrupt     equ %01000000
grlib~shr_scb_color_fill    equ %00100000
grlib~shr_scb_reserved_mask equ %00010000
grlib~shr_scb_palette_mask  equ %00001111
grlib~shr_scb_not_palette_mask equ %11110000

grlb~shr_palette_reserved_mask equ $F000
grlb~shr_palette_color_mask equ $0FFF

grlib~shr_palette_count     equ 16                      ; number of hardware palettes available

grlib~switch_on             equ $8000
grlib~switch_off            equ $0000

grlib~blit_mode_0           equ 0                       ; Straight copy to destination
grlib~blit_mode_1           equ 1                       ; Colorize source foreground with mask. Used for fonts.
grlib~blit_mode_2           equ 2                       ; Colorize source foreground with mask, merge with destination. Used for fonts.
grlib~blit_mode_3           equ 3                       ; Colorize source foreground with mask, and colorize source background (invert of foreground), copy to destination. Used for fonts.
grlib~blit_mode_4           equ 4                       ; Merge source with destination, through a pixel mask.

grlib~dp                    ds 2
; Pointers to various buffers.  These are also in the DP for the grlib, but sometimes that is not convenient to access, so we have them here too.
grlib~back_ptr              dc a4'0'
grlib~altscr_ptr            dc a4'0'
grlib~targetscr_ptr         dc a4'0'

; Some boolean switches.  Note, we use the high bit, because it allows for using the 'bit' opcode to test the value without changing any register
grlib~wait_for_vbl          dc i2'$8000'                 ; High bit on, we wait for the VBL
grlib~in_text_mode          dc i2'$0000'
grlib~altscr_is_shadowed    dc i2'$0000'                 ; High bit on, the alt-screen is at the shadowed shr screen location.
grlib~targetscr_is_visible  dc i2'$0000'                 ; High bit on, the target-screen is the 'real' screen
grlib~do_break              entry                        ; Making this an entry, so it is easier to use, as it is almost always hidden in a macro.
                            dc i2'$0000'                 ; High bit on, we want a break to be called.  This is used for debugging and the test code will check this flag

grlib~prle_clipped_draw_count dc i2'$0000'
grlib~prle_unclipped_draw_count dc i2'$0000'

grlib~color_fills           dc i'$0000'
                            dc i'$1111'
                            dc i'$2222'
                            dc i'$3333'
                            dc i'$4444'
                            dc i'$5555'
                            dc i'$6666'
                            dc i'$7777'
                            dc i'$8888'
                            dc i'$9999'
                            dc i'$AAAA'
                            dc i'$BBBB'
                            dc i'$CCCC'
                            dc i'$DDDD'
                            dc i'$EEEE'
                            dc i'$FFFF'

; Reserved shr palette slots.  non-0 == in-use.
; Maybe use the value is a hint has to what system is using the slot?
; Maybe use the value as a reserve reference count?
grlib~reserved_shr_palettes dc i1'0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0'

grlib~active_font_ptr       dc a'0'

sprite_object               dc i'sizeof~sprite'
                            dc a4'sprite_object~vtable'

; vtable for the sprite object
sprite_object~vtable        anop
                            dc a4'sprite_construct'
                            dc a4'0'
                            dc a4'0'
                            dc a4'sprite_destruct'

grlib_entity_object         dc i'sizeof~grlib_entity'
                            dc a4'grlib_entity_object~vtable'

; vtable for the grlib_entity object
grlib_entity_object~vtable  anop
                            dc a4'grlib_entity_construct'
                            dc a4'0'
                            dc a4'0'
                            dc a4'grlib_entity_destruct'

grlib_entity_sort_entry_object dc i'sizeof~grlib_entity_sort_entry'
                            dc a4'grlib_entity_sort_entry_object~vtable'

; vtable for the grlib_entity_sort_entry object
grlib_entity_sort_entry_object~vtable  anop
                            dc a4'grlib_entity_sort_entry_construct'
                            dc a4'0'
                            dc a4'0'
                            dc a4'grlib_entity_sort_entry_destruct'


grlib_entity_sort_list_object dc i'sizeof~grlib_entity_sort_list'
                            dc a4'grlib_entity_sort_list_object~vtable'

; vtable for the grlib_entity_sort_list object
grlib_entity_sort_list_object~vtable  anop
                            dc a4'grlib_entity_sort_list_construct'
                            dc a4'0'
                            dc a4'0'
                            dc a4'grlib_entity_sort_list_destruct'

                            end
