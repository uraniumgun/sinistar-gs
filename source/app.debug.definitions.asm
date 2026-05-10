debug_handlers~max_count        gequ 16

; Status flags
debug_handler~status~displayed  gequ $0001

; An instanced debug handler
; The initial values come from when the handler is registered.
debug_handler                   gequ 0
debug_handler~id                gequ debug_handler                          ; id
debug_handler~priority          gequ debug_handler~id+2                     ; priority
debug_handler~text_display      gequ debug_handler~priority+2               ; text display handler function
debug_handler~help_display      gequ debug_handler~text_display+4           ; help display handler function
debug_handler~key_pressed       gequ debug_handler~help_display+4           ; keypress handler function
debug_handler~enabled           gequ debug_handler~key_pressed+4            ; non-zero if enabled
debug_handler~status            gequ debug_handler~enabled+2                ; status flags.  See above.  The handler can be 'enabled' but not displayed
sizeof~debug_handler            gequ debug_handler~status+2

; Need a central location for the IDs, so i can see that they don't collide
; Could also hand them out on registration?
collision_debug_handler_id      gequ $0010
player_debug_handler_id         gequ $0020
sort_list_debug_handler_id      gequ $0030
playfield_entity_debug_handler_id gequ $0040
gameplay_debug_handler_id       gequ $0050
system_debug_handler_id         gequ $0060
gameplay_difficulty_debug_handler_id gequ $0070
memory_debug_handler_id         gequ $0080

