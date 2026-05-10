; A system allocation
std_system_allocation        gequ 0
std_system_allocation~handle gequ std_system_allocation           ; The handle value.  Can be null
std_system_allocation~ptr    gequ std_system_allocation~handle+4  ; The dereferenced handle
std_system_allocation_object_size gequ std_system_allocation~ptr+4

memory_error_none            gequ 0
memory_error_null_pointer    gequ system_id_memory+1
memory_error_allocation      gequ system_id_memory+2
memory_error_invalid_handle  gequ system_id_memory+3
memory_error_bad_range       gequ system_id_memory+4
