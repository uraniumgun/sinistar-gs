; Test for needed globals.
  AIF  C:sizeof~grlib_entity,.past
  ERR 'Must include grlib.entity.definitions.asm before this file'
.past

; Supported types for responders.  This is all that the original code supported, I may extend it
; Note, that I'm having the 'type' be times 2, so that I can use it as an offset, into arrays of words.
responder_type~worker               gequ 0*2
responder_type~warrior              gequ 1*2
responder_type~count                gequ 2

; Entity types
; These are all the ones, used in the game.
; I'm keeping these somewhat in the same order as the 'ai' types, but I don't think it has to be.
entity_type~planetoid               gequ 0
entity_type~player                  gequ 1
entity_type~sinistar                gequ 2
entity_type~bomb                    gequ 3
entity_type~crystal                 gequ 4
entity_type~worker                  gequ 5
entity_type~warrior                 gequ 6
entity_type~player_shot             gequ 7
entity_type~warrior_shot            gequ 8
entity_type~explosion               gequ 9          ; sprite based explosion
entity_type~count                   gequ 10         ; keep last

; Sub-structures

; Base entity definition, that most playfield objects use
; This contains a grlib_entity, which describes a basic rendered shape.
; A direction the entity is going in.
; The entity's sort list pointer, null if not in a sort list
;
; grlib_entity at the root
playfield_entity~grentity           gequ 0
; Type of the entity, can be used to see what list this is manage by
playfield_entity~type               gequ playfield_entity~grentity+sizeof~grlib_entity
; Current direction (0 - 31) (playfield_entity~direction_range - 1)
playfield_entity~direction          gequ playfield_entity~type+2
; Desired direction
playfield_entity~desired_direction  gequ playfield_entity~direction+2
; Turret direction (for warriors)
playfield_entity~turret_direction   gequ playfield_entity~desired_direction+2
; Last known angle to target. (0 - 255)
playfield_entity~target_angle       gequ playfield_entity~turret_direction+2
; Average target angle change
playfield_entity~target_angle_change_avg gequ playfield_entity~target_angle+2
; The animation timer for entities that have animated frames.
playfield_entity~frame_animation_timer gequ playfield_entity~target_angle_change_avg+2
; The animation rate, used to reset the timer.
playfield_entity~frame_animation_rate gequ playfield_entity~frame_animation_timer+2
; Rotation flags, used to get from the current direction, to the desired direction.
; The high bit, determines the direction, off = clock-wise, on = counter-clockwise
; This may not be the shortest way to the desired direction.  This is used to simulate
; the user rotating through a joystick perimeter.
; The lower bits are a positive number as to how fast the rotation should go.
; This is not a linear add, but rather an index into a table, so that the rotation
; speed can be on a curve, based on how far away from the desired direction
; the entity is currently.
playfield_entity~rotation_flags     gequ playfield_entity~frame_animation_rate+2
; State flags, see State Flags definitions below.
playfield_entity~state_flags        gequ playfield_entity~rotation_flags+2
; The slot index x 2 where entity is located in the entity's manager's list.
playfield_entity~manager_slot_index gequ playfield_entity~state_flags+2
; If non-zero, this is a short pointer (must be in the entity segment), to a custom draw function.
; The address should be -1 of the function.
playfield_entity~custom_draw_sptr   gequ playfield_entity~manager_slot_index+2
; Short-pointer directly to the location in the collision list.
playfield_entity~collision_list_entry_sptr gequ playfield_entity~custom_draw_sptr+2
; The move accumulator values are a 8:8 fractional amount.
; The upper bits will be added to final position, and the lower bits will remain as
; the factional amount to carry over to the next update.
playfield_entity~move_accum_x       gequ playfield_entity~collision_list_entry_sptr+2
playfield_entity~move_accum_y       gequ playfield_entity~move_accum_x+2
; The speed vector.  This is the x / y delta the entity moves, per update.
playfield_entity~speed_x            gequ playfield_entity~move_accum_y+2
playfield_entity~speed_y            gequ playfield_entity~speed_x+2
; Characteristic Definition for the entity.
playfield_entity~characteristic_id  gequ playfield_entity~speed_y+2
; Personality.  This is used for various things, for each entity type.
playfield_entity~personality        gequ playfield_entity~characteristic_id+2
; Task pointers, can be null.
playfield_entity~task1_ptr          gequ playfield_entity~personality+2
playfield_entity~task2_ptr          gequ playfield_entity~task1_ptr+4
; Vibration task pointer.  Not everything uses this
playfield_entity~vibration_task_ptr gequ playfield_entity~task2_ptr+4
; 'Caller/responder' sub-structure -----------------------------------------------
; These fields are valid on the responder only (ex. worker)
; The pointer to the caller (sptr)
playfield_entity~caller_sptr        gequ playfield_entity~vibration_task_ptr+4
; The priority of the caller
playfield_entity~caller_priority    gequ playfield_entity~caller_sptr+2
; The current distance (absolute) to the caller.
playfield_entity~caller_dist_x      gequ playfield_entity~caller_priority+2
playfield_entity~caller_dist_y      gequ playfield_entity~caller_dist_x+2
; The current mission type.  This is specific to the type of entity.
playfield_entity~mission_id         gequ playfield_entity~caller_dist_y+2
playfield_entity~mission_priority   gequ playfield_entity~mission_id+2
; ID of the next sibling in a responder chain.  If 0, then no further siblings
playfield_entity~next_sibling_sptr  gequ playfield_entity~mission_priority+2
; These fields are valid, only on the caller (ex. player)
; Quotas of responders.  This is an array of 16-bit counts, with the array index
; being the responder type. The count is the number of entities, of that type, who are being called.
playfield_entity~responder_quota       gequ playfield_entity~next_sibling_sptr+2
; The sptr of the first/head responder.  Additional responders are in a singly linked-list, in the responder (not the caller!).
; See playfield_entity~next_sibling_sptr
playfield_entity~responder_root_sptr gequ playfield_entity~responder_quota+(responder_type~count*2)
; End 'Caller' sub-structure --------------------------------------------------
sizeof~playfield_entity             gequ playfield_entity~responder_root_sptr+2

; Task data for the Vibrate
vibrate_task_data                   gequ 0
vibrate_task~entity_ptr             gequ vibrate_task_data              ; Entity
vibrate_task~step                   gequ vibrate_task~entity_ptr+4      ; what step we are at in the task
vibrate_task~delta_x                gequ vibrate_task~step+2            ; amount of delta added to the x position
vibrate_task~delta_y                gequ vibrate_task~delta_x+2         ; amount of delta added to the y position
vibrate_task~scale                  gequ vibrate_task~delta_y+2         ; the scale of vibration
sizeof~vibrate_task_data            gequ vibrate_task~scale+2


; Velocity Table Entry
; Each entry has a distance, a velocity and an acceleration function ID
; If the target distance is greater than or equal to, the entry distance, that entry is used
target_velocity_entry               gequ 0
target_velocity_entry~distance      gequ target_velocity_entry
target_velocity_entry~velocity      gequ target_velocity_entry~distance+2
target_velocity_entry~acceleration  gequ target_velocity_entry~velocity+2
sizeof~target_velocity_entry        gequ target_velocity_entry~acceleration+2

; This is the direction range used by every playfield entity.
; Not all art needs to support the full direction range.  The display will be scaled
; to what the art provides.
playfield_entity~direction_range gequ 32
playfield_entity~direction_range_mask gequ playfield_entity~direction_range-1

playfield_entity~rotation_clockwise gequ $0000
playfield_entity~rotation_counter_clockwise gequ $8000
playfield_entity~rotation_curve_mask gequ $00ff

; State flags
; If this bit is set in the state_flags, the entity is on the list to be removed
playfield_entity~state_marked_for_removal gequ $8000
; If this bit is set, the entity has already been removed from screen (its last drawn image was sent to the erase rects)
playfield_entity~state_removed_from_screen gequ $4000
; If this bit is set, the entity is on its collision list
playfield_entity~state_on_collision_list gequ $2000
; If this bit is set, the entity was added to the playfield, but has not
; been draw or updated yet.  This is handy to skip some processing
; in the update loop, so that the first frame gets displayed
playfield_entity~state_first_update gequ $1000
; If this bit is set, the entity uses its turret_direction for the diplay direction
playfield_entity~state_use_turret   gequ $0800

; Bounce counter.  The last two bits are a bounce counter
; This is used to prevent too many bounces from happening in quick succession.
playfield_entity~state_bounce_bits      gequ $0003
playfield_entity~state_bounce_mask      gequ 0+((playfield_entity~state_bounce_bits)*-1)-1
; When a bounce happens, these bits are set
playfield_entity~state_bounce_set_value gequ $0002

; Maximum entities
max_playfield_entities          gequ 512
; IDs are sequential, from 1 and are recycled.  An ID of 0 is invalid.
min_playfield_entity_id         gequ 1
max_playfield_entity_id         gequ min_playfield_entity_id+max_playfield_entities
invalid_playfield_entity_id     gequ 0

; It is super handy to have lookup arrays, that convert an ID to a pointer
sizeof~playfield_entity_id_to_ptr_array gequ max_playfield_entities*4
; Also, a doubly linked list of entities.
;playfield_entity_index_list_entry~prev gequ 0
;playfield_entity_index_list_entry~next gequ playfield_entity_index_list_entry~prev+2
;sizeof~playfield_entity_index_list_entry gequ playfield_entity_index_list_entry~next+2
; The index in the list is the entity, and the entry is a prev/next index
;sizeof~playfield_entity_index_list_array gequ max_playfield_entities*sizeof~playfield_entity_index_list_entry

; Directions
direction~north             gequ 0
direction~north_east        gequ 4
direction~east              gequ 8
direction~south_east        gequ 12
direction~south             gequ 16
direction~south_west        gequ 20
direction~west              gequ 24
direction~north_west        gequ 28
direction~range             gequ 32

; Speeds
speed~0                     gequ 0
speed~0_25                  gequ 1
speed~0_50                  gequ 2
speed~0_75                  gequ 3
speed~1_00                  gequ 4
speed~1_25                  gequ 5
speed~1_50                  gequ 6
speed~1_75                  gequ 7
speed~2_00                  gequ 8
speed~2_25                  gequ 9
speed~2_50                  gequ 10
speed~2_75                  gequ 11
speed~3_00                  gequ 12
speed~3_25                  gequ 13
speed~3_50                  gequ 14
speed~3_75                  gequ 15
speed~4_00                  gequ 16
speed~4_25                  gequ 17
speed~4_50                  gequ 18
speed~4_75                  gequ 19
speed~5_00                  gequ 20
speed~5_25                  gequ 21
speed~5_50                  gequ 22
speed~5_75                  gequ 23
speed~6_00                  gequ 24
speed~6_25                  gequ 25
speed~6_50                  gequ 26
speed~6_75                  gequ 27
speed~7_00                  gequ 28
speed~7_25                  gequ 29
speed~7_50                  gequ 30
speed~7_75                  gequ 31
speed~8_00                  gequ 32

acceleration_function~0     gequ 0
acceleration_function~1     gequ 1
acceleration_function~2     gequ 2
acceleration_function~3     gequ 3
acceleration_function~4     gequ 4
acceleration_function~5     gequ 5
acceleration_function~6     gequ 6
acceleration_function~7     gequ 7

; Animation helper return values

frame_change~no_crossing        gequ 0
frame_change~crossed_forward    gequ 1
frame_change~crossed_backward   gequ 2

