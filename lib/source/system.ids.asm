; System IDs
; This file is meant to include (copy)

system_id_memory                gequ $0000
system_id_object                gequ $0100
system_id_container             gequ $0200
system_id_string                gequ $0300
system_id_string_manager        gequ $0400
system_id_sba                   gequ $0500
system_id_fixed_buffer          gequ $0600
system_id_file                  gequ $0700
system_id_datalib               gequ $0800
system_id_sprite_manager        gequ $0900
system_id_grlib_entity_manager  gequ $0A00
system_id_value_transform       gequ $0B00
system_id_startup               gequ $0C00
system_id_sound                 gequ $0D00

; Mask value for the system.  The lower bits represent system specific information,
; usually a system specific error code.
system_id~id_mask               gequ $ff00
