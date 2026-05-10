; Palette definitions
;
; The current (most recent) version of the header
palette_file_header_current_version gequ 1
; Header of the serialized data
palette_file_header             gequ 0
palette_file_header~version     gequ palette_file_header
sizeof~palette_file_header      gequ palette_file_header~version+2

; Color entry formats
palette_color_format~argb       gequ 0
palette_color_format~collapsed  gequ 1

; Sizes of color entry formats
sizeof~argb_color               gequ 4
sizeof~collapsed_color          gequ 2

; The palette definition.  I'm currently not adding all the extra information that is in the PC version
; Though we will support the palette being 'full' RGB or 'collapsed'
; Note that the size of the palette will be as if the palette was 'full', even in collapsed mode and serialized.
; i.e. palette~color_count * sizeof~argb_color
; It is not much extra overhead and I want to keep the possibility of runtime, remapping on the table
; and full RGB matches will be easier and having the alpha is also nice.
palette~color_count             gequ 0
palette~color_format            gequ palette~color_count+2
sizeof~palette_header           gequ palette~color_format+2
palette~colors                  gequ sizeof~palette_header           ; First color in the array
sizeof~palette_scb              gequ palette~colors+32               ; Size of, for a 16 color palette in the collapsed/scb format

