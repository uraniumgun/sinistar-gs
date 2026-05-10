
  AIF  C:sizeof~vector_definition,.past
  ERR 'Must include container.definitions before this file'
.past
;
; Value Transform Definitions.  See value.transform.asm for details
;
value_transform_node~value      gequ 0                                          ; The current value of the node
value_transform_node~value_start gequ value_transform_node~value+2              ; Starting value of the node
value_transform_node~value_end  gequ value_transform_node~value_start+2         ; Ending value of the node
value_transform_node~value_range gequ value_transform_node~value_end+2          ; Calculated from the end - start, for convenience
value_transform_node~value_delta gequ value_transform_node~value_range+2        ; Calculated or pre-set delta to be added to the value, per-tick
value_transform_node~value_intermediate gequ value_transform_node~value_delta+2 ; Intermediate value, used by some nodes
value_transform_node~tick_length gequ value_transform_node~value_intermediate+2 ; The number of ticks the node calculates its value for.
value_transform_node~type       gequ value_transform_node~tick_length+2         ; Type of node
value_transform_node~flags      gequ value_transform_node~type+2                ; Status flags
value_transform_node~loop_to    gequ value_transform_node~flags+2               ; The node index to loop to, if the node loops.  It can loop to itself.
value_transform_node~loop_count gequ value_transform_node~loop_to+2             ; Number of times to loop.  Note, this is inclusive, so 1, means the node plays 2 times, one default pass, then loop once. -1 means infinite
value_transform_node~loop_remaining gequ value_transform_node~loop_count+2      ; Number of loops remaining.  This will be set by the transform
sizeof~value_transform_node     gequ value_transform_node~loop_remaining+2

; Node Status Flags

; Is the transform node initialized for a pass?
; This determines if the looping needs to get reset or not
value_transform_node_flag~pass_initialized gequ 1

; A tick state struct, used to know when the transform is complete, but also help with tracking the delta
; of ticks that have been processed so far.
value_transform_tick_state      gequ 0
value_transform_tick_state~last  gequ value_transform_tick_state                          ; Last tick time processd
value_transform_tick_state~start gequ value_transform_tick_state~last+4                   ; Starting tick time
sizeof~value_transform_tick_state gequ value_transform_tick_state~start+4

value_transform~current_node    gequ 0                                                    ; Current node the transform is processing
value_transform~flags           gequ value_transform~current_node+2                       ; Status flags
value_transform~tick_state      gequ value_transform~flags+2                              ; Current tick state.  See the tick_state struct aboce
value_transform~last_result     gequ value_transform~tick_state+sizeof~value_transform_tick_state ; Last transform state
sizeof~value_transform_header   gequ value_transform~last_result+2                        ; All the values, before the node array
value_transform~nodes           gequ sizeof~value_transform_header                        ; The nodes in the transform
sizeof~value_transform          gequ value_transform~nodes+sizeof~vector_definition

; Bit flag state

; No changes
value_transform_state~none      gequ 0
; The node/transform changed
value_transform_state~changed   gequ 1
; Reached the end of the node
value_transform_state~node_end  gequ 2
; Calculation has overflowed, the next node should be calculated
value_transform_state~node_overflowed  gequ 4
; Reached the end of all nodes in the transform
value_transform_state~transform_end gequ 8

; Transform Status flags

; Is the transform initialized?
value_transform_flag~initialized gequ 1
