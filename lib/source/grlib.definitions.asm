grlib_rect                  gequ 0
grlib_rect~left             gequ grlib_rect
grlib_rect~top              gequ grlib_rect~left+2
grlib_rect~right            gequ grlib_rect~top+2
grlib_rect~bottom           gequ grlib_rect~right+2
sizeof~grlib_rect           gequ grlib_rect~bottom+2

; 2D point, 16 bit x/y
grlib~point2~x              gequ 0
grlib~point2~y              gequ grlib~point2~x+2
sizeof~grlib~point2         gequ grlib~point2~y+2

grlib~left_pixel_mask       gequ $F0                        ; Left pixel on screen, is the high-nybble
grlib~right_pixel_mask      gequ $0F                        ; Right pixel on screen, is the lower-nybble

; Helpers, when defining the values in a word format
grlib~low_left_pixel_mask   gequ grlib~left_pixel_mask
grlib~low_right_pixel_mask  gequ grlib~right_pixel_mask
grlib~high_left_pixel_mask  gequ $F000                      ; Left pixel, in the high byte of a word
grlib~high_right_pixel_mask gequ $0F00                      ; Right pixel, in the high byte of a word

grlib~left_pixel_shift      gequ 4
grlib~right_pixel_shift     gequ 0

grlib~high_left_pixel_shift gequ 12
grlib~high_right_pixel_shift gequ 8

grlib~real_screen_address   gequ $e12000

grlib~shr_palette_mask      gequ $0FFF
grlib~shr_palette_blue_mask gequ $000F
grlib~shr_palette_blue_shift gequ 0
grlib~shr_palette_green_mask gequ $00F0
grlib~shr_palette_green_shift gequ 4
grlib~shr_palette_red_mask  gequ $0F00
grlib~shr_palette_red_shift  gequ 8
grlib~shr_palette_reserved_mask gequ $F000

grlib~screen_width          gequ 320
grlib~screen_byte_width     gequ 160
grlib~screen_height         gequ 200

; Set to 1, to support a coordinate wrapping update-rect / playfield system.
; Set to 0, to turn off coordinate wrapping support, which is a little faster
grlib~support_coordinate_wrapping gequ 0

; If 1, then the code assumes a static entity buffer is used.
; This allows for indexed long addressing to be used when accessing the entities.
grlib~use_static_entity_buffer gequ 1
