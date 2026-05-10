; -----------------------------------------------------------------------------
; Some layout constants
; We will have some reserved lines at the top, for UI
; and some reserved lines at the bottom.  Everything in-between will be
; the playfield.
gameplay_ui_top_height          gequ 34
gameplay_ui_bottom_height       gequ 1

gameplay_ui_playfield_left      gequ 0
gameplay_ui_playfield_top       gequ gameplay_ui_top_height
gameplay_ui_playfield_right     gequ 320
gameplay_ui_playfield_bottom    gequ 200-gameplay_ui_bottom_height

gameplay_ui_playfield_width     gequ gameplay_ui_playfield_right-gameplay_ui_playfield_left
gameplay_ui_playfield_height    gequ gameplay_ui_playfield_bottom-gameplay_ui_playfield_top

gameplay_ui_playfield_center_x  gequ gameplay_ui_playfield_width/2
gameplay_ui_playfield_center_y  gequ gameplay_ui_playfield_height/2

; This is about the number of pixels available on either side of the scanner, including the scanner fins
gameplay_ui_player_side_width   gequ 124

gameplay_ui_player_1_left_edge  gequ 2
gameplay_ui_player_2_left_edge  gequ 320-gameplay_ui_player_side_width

gameplay_ui_bombs_remaining_y   gequ 1
gameplay_ui_bombs_remaining_player_1_x gequ gameplay_ui_player_1_left_edge
gameplay_ui_bombs_remaining_row_height gequ 5
gameplay_ui_bombs_remaining_col_width  gequ 6

gameplay_ui_score_width         gequ 64
gameplay_ui_score_height        gequ 8
gameplay_ui_score_y             gequ gameplay_ui_bombs_remaining_y+(gameplay_ui_bombs_remaining_row_height*2)+1
gameplay_ui_score_player_1_x    gequ gameplay_ui_player_1_left_edge

gameplay_ui_bonus_at_width      gequ 64
gameplay_ui_bonus_at_height     gequ 5                                      ; font_teeny~height
gameplay_ui_bonus_at_y          gequ gameplay_ui_score_y+9
gameplay_ui_bonus_at_player_1_x gequ gameplay_ui_player_1_left_edge

; Maximum ships remaining we can display
gameplay_ui_ships_remaining_max_display gequ 10

gameplay_ui_ships_remaining_y   gequ gameplay_ui_bonus_at_y+6               ; plus font_teeny~height
gameplay_ui_ships_remaining_player_1_x gequ gameplay_ui_player_1_left_edge
gameplay_ui_ships_remaining_row_height gequ 5
gameplay_ui_ships_remaining_col_width  gequ 6
gameplay_ui_ships_remaining_height gequ gameplay_ui_ships_remaining_row_height
gameplay_ui_ships_remaining_width gequ gameplay_ui_ships_remaining_col_width*gameplay_ui_ships_remaining_max_display


gameplay_ui_message_width       gequ 60
gameplay_ui_message_height      gequ +(6*3)-1                               ; (font_teeny~height+1)*3 + 1
gameplay_ui_message_y           gequ gameplay_ui_top_height-((6*3)+1)
gameplay_ui_message_line_1_y    gequ gameplay_ui_message_y+5
gameplay_ui_message_line_2_y    gequ gameplay_ui_message_line_1_y+6
gameplay_ui_message_line_3_y    gequ gameplay_ui_message_line_2_y+6
gameplay_ui_message_player_1_x  gequ gameplay_ui_player_1_left_edge+gameplay_ui_score_width+2
gameplay_ui_message_player_2_x  gequ gameplay_ui_player_2_left_edge+gameplay_ui_score_width+2

; scanner location
gameplay_ui_scanner_x           gequ 144
gameplay_ui_scanner_y           gequ 1

gameplay_ui_scanner_width       gequ 32
gameplay_ui_scanner_height      gequ 32

; Playfield size.  It is very handy to have it a power of 2, so we will do so and put some
; other equates in.  Use a static_assert to make sure when using though!
gameplay_playfield_width        gequ 1024
gameplay_playfield_height       gequ 1024

gameplay_playfield_width_mask   gequ gameplay_playfield_width-1
gameplay_playfield_height_mask  gequ gameplay_playfield_height-1

; Min and max playfield coordinates.
gameplay_playfield_min_x        gequ -(gameplay_playfield_width/2)
gameplay_playfield_max_x        gequ +(gameplay_playfield_width/2)
gameplay_playfield_min_y        gequ -(gameplay_playfield_height/2)
gameplay_playfield_max_y        gequ +(gameplay_playfield_height/2)

; Same, but in 'bounds' terminology
gameplay_playfield_bounds_left  gequ -(gameplay_playfield_width/2)
gameplay_playfield_bounds_right gequ +(gameplay_playfield_width/2)
gameplay_playfield_bounds_top   gequ -(gameplay_playfield_height/2)
gameplay_playfield_bounds_bottom gequ +(gameplay_playfield_height/2)

; We are not moving the origin, the objects move within the playfield and the camera is always at 0,0
gameplay_playfield_origin_min_x gequ 0
gameplay_playfield_origin_min_y gequ 0
gameplay_playfield_origin_max_x gequ gameplay_playfield_width ; +gameplay_ui_playfield_width
gameplay_playfield_origin_max_y gequ gameplay_playfield_height ; +gameplay_ui_playfield_height

; The number of discreet levels (specific data defined)
gameplay_levels_discreet_count  gequ 8

; Scanner to pixel conversion, from the original game
; Using a short label, because I have to squeeze it into a lot of tables
s2pix                       gequ 4
