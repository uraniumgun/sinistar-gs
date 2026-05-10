; A sprite definition.
; This binds a shape pointer with basic position/bounds information as well as
; past positioning, to assist in erasing the shape.
;
; For the moment, this is mirroring the anmframe_def, with a bit of renaming
; of the secondary bounds rectangle.
;
; See grlib.sprite.asm for more details
sprite~primary_shape_ptr    gequ 0                              ; Address of the primary shape definition (shapedef) (long)
sprite~secondary_shape_ptr  gequ sprite~primary_shape_ptr+4     ; Address of the shape secondary definition (shapedef) (long), this is used while supporting clipped and unclipped paths
; Erase bounds.  This holds the bounds for the last draw of the shape, and is valid if sprite~info~needs_erase is set
; Note that this rect is in screen-space, not view space.
sprite~erase~left           gequ sprite~secondary_shape_ptr+4
sprite~erase~top            gequ sprite~erase~left+2
sprite~erase~right          gequ sprite~erase~top+2
sprite~erase~bottom         gequ sprite~erase~right+2
; Draw bounds.  Current draw bounds, however, it does not mean that the shape has been drawn to these bounds.
; This rect is in view space.
sprite~bounds               gequ sprite~erase~bottom+2
sprite~bounds~left          gequ sprite~bounds
sprite~bounds~top           gequ sprite~bounds~left+2
sprite~bounds~right         gequ sprite~bounds~top+2
sprite~bounds~bottom        gequ sprite~bounds~right+2

sprite~info                 gequ sprite~bounds+8                ; Info (word)
; Information about the attached primary_shape_ptr, that is copied into the sprite.  Helps with lookups.
sprite~offset_x             gequ sprite~info+2
sprite~offset_y             gequ sprite~offset_x+2
sprite~width                gequ sprite~offset_y+2
sprite~height               gequ sprite~width+2
sizeof~sprite               gequ sprite~height+2

; bit 15 signifies that there is something to erase
sprite~info~needs_erase     gequ $8000
; bit 14 signifies if the x/y is relative to the shape origin upper left.  Set is origin relative.
sprite~info~origin_relative gequ $4000
