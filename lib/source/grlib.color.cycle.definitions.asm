  AIF  C:sizeof~value_transform,.past
  ERR 'Must include value.transform.definitions before this file'
.past

; Definitions for color cycling and the color cycled palette
color_cycle_entry~transform         gequ 0
color_cycle_entry~start             gequ color_cycle_entry~transform+sizeof~value_transform       ; First color of the color ramp
color_cycle_entry~end               gequ color_cycle_entry~start+62                               ; Last color of the color ramp
sizeof~color_cycle_entry            gequ color_cycle_entry~end+2

color_cycle_type~up                 gequ 0        ; Cycle from the start color, to the end color
color_cycle_type~up_smoothed        gequ 1        ; Cycle from the start color, to the end color
color_cycle_type~up_down            gequ 2        ; Cycle from the start color, to the end color, then backward to the start color
color_cycle_type~up_down_smoothed   gequ 3        ; Cycle from the start color, to the end color, then backward to the start color

color_cycled_palette~palette        gequ 0
color_cycled_palette~entries        gequ color_cycled_palette~palette+sizeof~palette_scb                ; 16 pointers to a color_cycle_entry.  color_cycled_palette does not own them!
sizeof~color_cycled_palette         gequ color_cycled_palette~entries+(16*4)
