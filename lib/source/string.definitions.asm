; A string object
;
; A string object contains some meta data, then a pointer to the zero-terminated string buffer it manages.
; The metadata consists of a word, that is the current length of the string
; It is first, primarily because it makes it easy to get at without a y index.
; The next word is the capacity of the buffer.
; The next byte is a pool index, used to denote if the string was allocated from a specific pool.
; If it is 0, then the allocation is 'user/unmanaged'
; The next byte are bit flags, describing some features of the string.
;
; I waffled on whether to have the length or not, because it adds space overhead
; and the overhead of keeping it up-to-date.  However, it is handy to not have to
; constantly search for the zero-terminator. So, a compromise.
;
; It might be possible to get rid of the capacity, by inferring it from the pool
; but that leaves the 'unmanaged' strings to have to externally manage the capacity or
; just assume the length of the string is the max, which is fine for constant strings
; but would be a pain for local/temporary strings.
;
; I also thought of having it so that the 'header' and the string buffer itself was all in one buffer, rather than
; having another indirection to the string buffer itself.  However, that makes it trick to keep a pointer to the object itself
; as it would have to re-allocate, if the capacity needed to change.
;
string_object~length        gequ 0                          ; Length of the valid character in the string, not including the zero terminator
string_object~capacity      gequ string_object~length+2     ; Capacity of the string buffer.  This includes the space needed for the zero terminator
string_object~info          gequ string_object~capacity+2   ; Info bits
string_object~str           gequ string_object~info+2       ; Pointer to the zero-terminated string buffer.  Can be null!
sizeof~string_object        gequ string_object~str+4        ; Note, that the size of the 'object', is just the header, because the string part is variable.

string_object_info~pool_mask gequ $00FF                     ; The lower bits are the string pool, the string was allocated from. 0 == unmanaged
string_object_info~wide      gequ $0100                     ; The string is wide character (UTF-16)
string_object_info~mbcs      gequ $0200                     ; The string is multi-byte, usually UTF-8

string_object_pool~unmanaged    gequ $00                    ; Unmanage strings are really, managed by whatever specifically allocated them, the string system will not try and change/free the memory

; Result object from an allocation call.  Keeping this in this definition file, rather than the string.manager.defintions, because the later has container dependencies.
string_manager_alloc_result             gequ 0
string_manager_alloc_result~ptr         gequ string_manager_alloc_result            ; The pointer to the buffer
string_manager_alloc_result~pool        gequ string_manager_alloc_result~ptr+4      ; The pool ID the buffer came from (will be pool index + 1, but only compare to string_object_pool~unmanaged)
string_manager_alloc_result~capacity    gequ string_manager_alloc_result~pool+2     ; The capacity of the buffer, this is in valid characters.  The buffer is at least +1 of this value
string_manager_alloc_result_object_size gequ string_manager_alloc_result~capacity+2
