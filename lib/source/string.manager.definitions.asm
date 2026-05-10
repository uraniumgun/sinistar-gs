; String Manager object
string_manager              gequ 0
string_manager~alloc_count  gequ string_manager
string_manager~pools        gequ string_manager~alloc_count+2
string_manager_object_size  gequ string_manager~pools+sizeof~vector_definition
