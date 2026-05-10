; A file descriptor
file_descriptor~refnum      gequ 0                                  ; The OS reference number for the open file.  0 if no file is opened
file_descriptor~length      gequ file_descriptor~refnum+2           ; Length of the file.
sizeof~file_descriptor      gequ file_descriptor~length+4           ; Size of the object, this must be last

; In an attempt to be 'quick', I'm going to have the buffer embedded in with the rest of the members
; This way I don't have to dereference another pointer.
;
; Overall, there are multiple ways of doing this, all with their own compromises.
; One option, that would help keep the buffer separate, would be to have a one or more
; of these live in ZP memory, and then to get to the buffer it could be lda [<pThis+buffer_ptr]
; However, access to 'fixed' ZP locations is complicated by the use of subs, which move
; the zp around.
; Note: I tried it with an offset and a remaining, rather than a size, it was a fraction
; faster in some instances, but the fact that I'd have to update two values, both the offset
; and the remaining, for each read would be worse in some cases.
file_reader~default_buffer_size gequ 512

file_reader~offset          gequ 0                                                      ; next location in the buffer to read from.  Note this is from the start of the file_reader, so this is always at least file_reader~buffer
file_reader~size            gequ file_reader~offset+2                                   ; the is the size of the valid buffer data, *plus* file_reader~buffer
file_reader~file_desc       gequ file_reader~size+2                                     ; the inline file_descriptor.  The reader does not own this and should not do a destructor call.
file_reader~buffer          gequ file_reader~file_desc+sizeof~file_descriptor           ; the inline file buffer
sizeof~file_reader          gequ file_reader~buffer+file_reader~default_buffer_size

; File writer.  This differs from the read, in that the buffer is allocated and can grow
; This is to support buffering a complete file of unknown (but currently less that 64k) size
; then flushing the buffer to the file.
file_writer~offset          gequ 0
file_writer~capacity        gequ file_writer~offset+2                                   ; capacity of  buffer.
file_writer~file_desc       gequ file_writer~capacity+2                                 ; the inline file_descriptor.  The write does not own this and should not do a destructor call.
file_writer~buffer_ptr      gequ file_writer~file_desc+sizeof~file_descriptor           ; the pointer to a buffer
sizeof~file_writer          gequ file_writer~buffer_ptr+4
