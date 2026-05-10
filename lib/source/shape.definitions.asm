; -----------------------------------------------------------------------------
; The shape definition, see gs.packplot.asm for more information
;
; The header of the shape in a file.  This is read in separately, and is not part of the runtime data
shapedef_file_header            gequ 0
shapedef_file_header~version    gequ shapedef_file_header
sizeof~shapedef_file_header     gequ shapedef_file_header~version+2

; The current (most recent) version of the header
shapedef_file_header_current_version gequ 1

; Runtime data that is kept in memory.  This is usually kept as a single block of data.
; There are offsets in the data loaded data, but no pointers. i.e. pointer-fixup is currently not needed.

; The header of the shape/sprite/pixel map definition
;
; (I suck at naming and I kinda wanted to use 'sprite' as the term for the structure that contains
; positional information, and this structure is a bit more that just a single pixel map, so I went with shape)
;
; Since there are 2 pixels per byte and we don't want to 'shift' on the fly, the data
; is expected to be drawn on a byte boundary.  i.e. The x pixel draw location is expected
; to be div 2.  To support the appearance of drawing on an odd pixel boundary,
; there is a second copy of the data, that is shifted to the right one pixel, which
; can be drawn on a byte boundary.
; Note that the odd pixel data offset and the mask offsets can be zero, meaning they are not present
; These are there, even for the compiled shapes, just so the header is consistent.
shapedef~data_size              gequ 0                                      ; data size for the entire shape, header and all, including any 'odd' data.
shapedef~type                   gequ shapedef~data_size+2                   ; type of shape data
shapedef~width                  gequ shapedef~type+2
shapedef~height                 gequ shapedef~width+2
shapedef~origin_x               gequ shapedef~height+2
shapedef~origin_y               gequ shapedef~origin_x+2
shapedef~metadata_id            gequ shapedef~origin_y+2                    ; Currently, the PALT id, might morph into a shared meta-data ID, that has the palette and other things.
shapedef~even_data_offset       gequ shapedef~metadata_id+4                 ; offset to the beginning even data, should always have a value.
shapedef~even_mask_offset       gequ shapedef~even_data_offset+4            ; Offset from the start of the pixel data, to the mask data.  If 0, there is no mask data
shapedef~odd_data_offset        gequ shapedef~even_mask_offset+2            ; If not == 0, then this is the offset to the beginning of the line offsets for the shape that is drawn at an 'odd' pixel value.
; Yes, the above is a 4 byte offset, I may support the odd data being in another bank, or maybe having this be a pointer at runtime
shapedef~odd_mask_offset        gequ shapedef~odd_data_offset+4             ; Offset from the start of the odd pixel data, to the odd mask data.  If 0, there is no mask data
shapedef~outline_data_offset    gequ shapedef~odd_mask_offset+2             ; Offset to the outline data, 0 if none.
sizeof~shapedef_header          gequ shapedef~outline_data_offset+4
; Between the header and the data groups, are offsets for each line in the shape, to its datagroup.
; i.e. there are shapedef~height * 2 bytes of data
shapedef~line_offsets           gequ sizeof~shapedef_header                 ; This is the first line offset
; Data group for a line of shape data.
shape_datagroup~data_byte_size  gequ 0
shape_datagroup~indent          gequ shape_datagroup~data_byte_size+2
sizeof~shape_datagroup          gequ shape_datagroup~indent+2

shape_datagroup_indent~byte_count_mask gequ $00ff
shape_datagroup_indent~left_edge_mask gequ $0100
shape_datagroup_indent~right_edge_mask gequ $0200
shape_datagroup_indent~left_right_edge_mask gequ shape_datagroup_indent~left_edge_mask+shape_datagroup_indent~right_edge_mask

shape_datagroup_indent~another_group_mask gequ $8000

shape_data_type~prle            gequ 0
shape_data_type~block           gequ 1
shape_data_type~compiled_basic  gequ 2                  ; a compiled shape in the 'basic' format.  This does not require interrupt disabling, but is slower and larger
shape_data_type~compiled_stack  gequ 3                  ; a compiled shape in the 'stack' format.  This requires interrupt disabling and stack remapping.

; When a shapedef is loaded from disk and managed by the datalib, there is a header on the data, that
; caches some often used runtime data, like a pointer to the library the shape came from
datalib_shapedef                gequ 0
datalib_shapedef~data_entry_ptr gequ datalib_shapedef                   ; Storing the data_entry, as it has links to everything I need, though most of the time I just need the library.
; datalib_shapedef~palette_ptr  maybe add this too?
sizeof~datalib_shapedef         gequ datalib_shapedef~data_entry_ptr+4
datalib_shapedef~shapedef       gequ sizeof~datalib_shapedef            ; This is where the shapedef starts


