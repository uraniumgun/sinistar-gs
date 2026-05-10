                                copy lib/source/debug.definitions.asm
                                copy lib/source/system.ids.asm
                                copy lib/source/object.definitions.asm
                                copy lib/source/container.definitions.asm
                                copy lib/source/file.definitions.asm
                                copy 13/Ainclude/E16.GSOS
                                mcopy generated/file.manager.macros

                                longa on
                                longi on

; --------------------------------------------------------------------------------------------
file_manager_data               data seg_flib

file_manager_is_initialized     dc i2'0'

file_manager_last_error         dc i2'0'

; A temporary buffer for an OS pathname
temp_os_pathname_max_size       equ 1024-2
temp_os_pathname_ptr            dc a4'0'
temp_os_pathname2_ptr           dc a4'0'

; temporary file reader buffers
; Having temporary file_readers is a bit more important than writers, as we don't want the reader to allocate
; on the heap, then have the data it is reading into also allocate on the heap, as the file_reader might then cause
; a hole in the OS heap system (it will if the SBA doesn't have a pool to fit the file_reader)
file_manager~max_reader_temp_buffers    equ 2                   ; it is rare to need multiple readers at the same time.  Increase this if required
; I'm going to allocate the buffers, rather than having them in-situ.  Yeah, they are not too big, but I feel like it is better like this for a generalized system
file_manager~reader_temp_buffers_ptr    dc a4'0'
file_manager~reader_free_buffer_index   dc i'0'
; Lookup table to the buffers.  Note this is only the short pointer
file_manager~reader_free_buffers        ds file_manager~max_reader_temp_buffers*2

; For the read/write, note that if neither is on, then the default is used for
; the type of operation, ie. open, defaults to read, create defaults to write.
file_option~none                equ $0000
file_option~read                equ $0001               ; allow read
file_option~write               equ $0002               ; allow write
file_option~append              equ $0004               ; when creating, append to existing file, else reset eof to 0

; From https://github.com/a2infinitum/apple2-filetypes
; http://www.apple-iigs.info/techfiletype.php
file_type~non                   equ $0000
file_type~txt                   equ $0004
file_type~bin                   equ $0006               ; not really 'generic' though, more ProDOS 8 file that can be brun, with the starting location in the aux field
file_type~game_document         equ $005d               ; Seems to have been Apple's favored file type for 'game/entertainment' files
file_type~user1                 equ $00f1
file_type~user2                 equ $00f2
file_type~user3                 equ $00f3
file_type~user4                 equ $00f4
file_type~user5                 equ $00f5
file_type~user6                 equ $00f6
file_type~user7                 equ $00f7
file_type~user8                 equ $00f8

                                end
; --------------------------------------------------------------------------------------------
file_manager_errors             data seg_flib

file_manager_error_none        	equ 0
file_manager_error_null_pointer equ system_id_file+1
file_manager_error_allocation   equ system_id_file+2
file_manager_error_already_open equ system_id_file+3
file_manager_error_name_invalid equ system_id_file+4
file_manager_error_read_underflow equ system_id_file+5              ; A read request failed to read the amount requested.  Usually in the case of hitting the EOF before the request was completed.
file_manager_error_buffer_too_small equ system_id_file+6
file_manager_error_read_error   equ system_id_file+7
file_manager_error_not_open     equ system_id_file+8
file_manager_error_invalid_offset equ system_id_file+9

file_manager_msg_create_error   dw 'file_manager: create failed'
file_manager_msg_open_error     dw 'file_manager: open failed'
file_manager_msg_close_error    dw 'file_manager: close failed'
file_manager_msg_general_error  dw 'file_manager: general error'
file_manager_msg_initialize_failed dw 'file_manager: initialize failed'
file_manager_msg_read_error     dw 'file_manager: read failed'
file_manager_msg_read_underflow dw 'file_manager: read underflow'
file_manager_msg_set_eof_error  dw 'file_manager: set eof failed'
file_manager_msg_get_eof_error  dw 'file_manager: get eof failed'
                                end

; --------------------------------------------------------------------------------------------
; A file manager interface.
; This will wrap some of the basic file I/O.
; The initial implementation is using GS/OS, however I'd like to hide things enough so
; that if I have to fall back to Prodos 8, I can.
;
; Note, like a lot of the other files.  I'm explicitly using long addressing, as I don't want
; to assume the data bank register's contents.  I could do a phb;phk;plb - some code - plb
; but I don't think it is usually worth it, for the few non-indirect operations I'm doing.
; There are a few more of those in the file manager and such, as I'm usually patching up or reading
; locally defined parameter blocks.  Might look into it later.
; --------------------------------------------------------------------------------------------
; Initialize the file manager
file_manager_initialize         start seg_flib
                                using file_manager_data
                                using file_manager_errors

                                debugtag 'initialize'
                                debugtag 'file_manager'

                                setlocaldatabank

                                lda file_manager_is_initialized
                                bne is_initialized

; Allocate a few temporary pathname buffers
                                pushsword #temp_os_pathname_max_size+2
                                jsl sba_alloc
                                bcs error
                                putretptr >temp_os_pathname_ptr

                                pushsword #temp_os_pathname_max_size+2
                                jsl sba_alloc
                                bcs error
                                putretptr temp_os_pathname2_ptr

; Temporary file_reader buffers
                                pushsword #file_manager~max_reader_temp_buffers*sizeof~file_reader
                                jsl sba_alloc
                                bcs error
                                putretptr file_manager~reader_temp_buffers_ptr

                                lda #file_manager~max_reader_temp_buffers
                                sta file_manager~reader_free_buffer_index
; Fill in the free buffer table
                                ldx #0
                                lda file_manager~reader_temp_buffers_ptr
loop                            sta file_manager~reader_free_buffers,x
                                clc
                                adc #sizeof~file_reader
                                inx
                                inx
                                cpx #file_manager~max_reader_temp_buffers*2
                                bne loop

                                lda #1
                                sta file_manager_is_initialized

is_initialized                  anop
                                restoredatabank
                                rtl
error                           anop
                                debugger_msg #file_manager_msg_initialize_failed
                                restoredatabank
                                rtl
                                end

; --------------------------------------------------------------------------------------------
; Uninitialize the file manager.
file_manager_uninitialize       start seg_flib
                                using file_manager_data

                                debugtag 'uninitialize'
                                debugtag 'file_manager'

                                setlocaldatabank
                                lda file_manager_is_initialized
                                beq exit

                                pushptr temp_os_pathname_ptr
                                jsl sba_free
                                pushptr temp_os_pathname2_ptr
                                jsl sba_free

                                pushptr file_manager~reader_temp_buffers_ptr
                                jsl sba_free

                                lda #0
                                sta file_manager_is_initialized

exit                            restoredatabank
                                rtl

                                end

; --------------------------------------------------------------------------------------------
; Construct an empty file descriptor
;
; Params:
; pThis                         - the file_descriptor
; Returns:
; 0 on success or an error result.
file_descriptor_construct       start seg_flib
                                using file_manager_data
                                using file_manager_errors

; Define our work area data
                                begin_locals
result                          decl word                                           ; result value inside our local work area
work_area_size                  end_locals

                                debugtag 'construct'
                                debugtag 'file_descriptor'
                                sub (4:pThis),work_area_size

                                testptr <pThis
                                beq null_pointer

                                lda #0
                                putword [<pThis],#file_descriptor~refnum
                                putlong [<pThis],#file_descriptor~length

                                stz <result
error_exit                      ret 2:result
null_pointer                    lda #file_manager_error_null_pointer
                                sta <result
                                bra error_exit
                                end

; --------------------------------------------------------------------------------------------
; Destruct file descriptor
;
; Params:
; pThis                         - the file_descriptor
; Returns:
; 0 on success or an error result.
file_descriptor_destruct        start seg_flib
                                using file_manager_data
                                using file_manager_errors

; Define our work area data
                                begin_locals
result                          decl word                                           ; result value inside our local work area
work_area_size                  end_locals

                                debugtag 'destruct'
                                debugtag 'file_descriptor'
                                sub (4:pThis),work_area_size

                                testptr <pThis
                                beq null_pointer

                                pushptr <pThis
                                jsl file_descriptor_close

                                stz <result
error_exit                      ret 2:result

null_pointer                    lda #file_manager_error_null_pointer
                                sta <result
                                bra error_exit
                                end

; --------------------------------------------------------------------------------------------
; Is the file_descriptor open?
;
; Params:
; pThis                         - the file_descriptor
; Returns:
; 1 if open, 0 if not
file_descriptor_is_open         start seg_flib
                                using file_manager_data
; Define our work area data
                                begin_locals
result                          decl word                                           ; result value inside our local work area
work_area_size                  end_locals

                                debugtag 'is_open'
                                debugtag 'file_descriptor'
                                sub (4:pThis),work_area_size

                                testptr <pThis
                                beq not_open

                                getword [<pThis],#file_descriptor~refnum
                                beq not_open
                                lda #1
                                sta <result
exit                            ret 2:result
not_open                        stz <result
                                bra exit
                                end

; --------------------------------------------------------------------------------------------
; Open a file for reading and store the file's reference in the file_descriptor
;
; Params:
; pThis                         - the file_descriptor
; psoFileName                   -  the file name to open.
;                                  This must be a string_object.
;                                  It can be a partial path
; Returns:
; 0 on success or an error result.
file_descriptor_open            start seg_flib
                                using file_manager_data
                                using file_manager_errors
                                using system_error_data

; Define our work area data
                                begin_locals
result                          decl word                                           ; result value inside our local work area
work_area_size                  end_locals

                                debugtag 'open'
                                debugtag 'file_descriptor'
                                sub (4:pThis,4:psoFileName),work_area_size

                                testptr <pThis
                                beq null_pointer
; Already open?  We don't know if the input file is the same file or different, so this is an error
                                getword [<pThis],#file_descriptor~refnum
                                bne already_open_error

                                pushptr <psoFileName
                                pushptr >temp_os_pathname_ptr
                                pushsword #temp_os_pathname_max_size
                                jsl string_object_to_os_string
                                bne name_error

                                getptr >temp_os_pathname_ptr,>open_pb_pPathname
                                _OpenGS open_pb
                                bcs open_error
; Get the file size.  I could extend the open_pb to return the eof, but damn if it is not way down in the parameter block, seems like I'd be asking the open call to do lots of extra work
                                lda >open_pb_refnum
                                sta >get_eof_pb_refnum
                                _GetEOFGS get_eof_pb
                                bcs eof_error

                                lda >open_pb_refnum
                                putword [<pThis],#file_descriptor~refnum
                                lda >get_eof_pb_length
                                putptrlow [<pThis],#file_descriptor~length
                                lda >get_eof_pb_length+2
                                putptrhigh [<pThis],#file_descriptor~length

                                stz <result
exit                            ret 2:result                ; note, we are assuming that the Z flag will be set on exit, as 'result' is transfered to A

null_pointer                    lda #file_manager_error_null_pointer
                                sta <result
                                bra exit

already_open_error              lda #file_manager_error_already_open
                                sta <result
                                debugger_msg #file_manager_msg_open_error
                                bra exit

name_error                      lda #file_manager_error_name_invalid
                                bra fake_open_error
open_error                      sta >system_error~last_toolbox_code     ; save off the GS/OS error, also going to use that as the result?  Hmm, should use our own.
fake_open_error                 sta <result
                                cmp #fileNotFound                       ; Don't assert on a file not found
                                beq exit
                                debugger_msg #file_manager_msg_open_error
                                bra exit

eof_error                       sta >system_error~last_toolbox_code     ; save off the GS/OS error, also going to use that as the result?  Hmm, should use our own.
                                sta <result
                                debugger_msg #file_manager_msg_general_error
                                bra exit

open_pb                         dc i2'3'
open_pb_refnum                  dc i2'0'
open_pb_pPathname               dc a4'0'
open_pb_requestAccess           dc i2'readEnable'                       ; assuming read-only.  Use _create to open a file for writing.

get_eof_pb                      dc i2'2'
get_eof_pb_refnum               dc i2'0'
get_eof_pb_length               dc i4'0'

                                end

; --------------------------------------------------------------------------------------------
; Create a file for writing and store the file's reference in the file_descriptor
;
; Params:
; pThis                         - the file_descriptor
; psoFileName                   -  the file name to open.
;                                  This must be a string_object.
;                                  It can be a partial path
; wOptions                      - options for creation
;                                   See file_option
; wFileType                     - the file type to use. Only the lower 8-bits are used
; wAuxType                      - the aux-type to use

; Returns:
; 0 on success or an error result.
file_descriptor_create          start seg_flib
                                using file_manager_data
                                using file_manager_errors
                                using system_error_data

; Define our work area data
                                begin_locals
result                          decl word                                           ; result value inside our local work area
work_area_size                  end_locals

                                debugtag 'create'
                                debugtag 'file_descriptor'

                                sub (4:pThis,4:psoFileName,2:wOptions,2:wFileType,2:wAuxType),work_area_size

                                setlocaldatabank

                                testptr <pThis
                                jeq null_pointer
; Already open?  We don't know if the input file is the same file or different, so this is an error
                                getword [<pThis],#file_descriptor~refnum
                                jne already_open_error

                                pushptr <psoFileName
                                pushptr temp_os_pathname_ptr
                                pushsword #temp_os_pathname_max_size
                                jsl string_object_to_os_string
                                jne name_error

                                lda <wFileType
                                sta create_pb_filetype
                                lda <wAuxType
                                sta create_pb_auxtype

                                lda temp_os_pathname_ptr
                                sta create_pb_pPathname
                                sta open_pb_pPathname
                                lda temp_os_pathname_ptr+2
                                sta create_pb_pPathname+2
                                sta open_pb_pPathname+2

                                _CreateGS create_pb
                                bcs create_error
; Create does not open the file, we have to do that separately.
create_ok                       _OpenGS open_pb
                                jcs open_error

                                lda open_pb_refnum
                                sta get_eof_pb_refnum
                                sta set_eof_pb_refnum

                                lda <wOptions
                                and #file_option~append
                                bne append

                                _SetEOFGS set_eof_pb
                                bcc set_eof_success
                                brl set_eof_error

; Get the file size.
append                          _GetEOFGS get_eof_pb
                                bcs get_eof_error

set_eof_success                 lda open_pb_refnum
                                putword [<pThis],#file_descriptor~refnum
                                lda get_eof_pb_length
                                putptrlow [<pThis],#file_descriptor~length
                                lda get_eof_pb_length+2
                                putptrhigh [<pThis],#file_descriptor~length

success                         stz <result
                                clc
exit                            restoredatabank
                                retkc 2:result

null_pointer                    lda #file_manager_error_null_pointer
                                sta <result
                                sec
                                bra exit

create_error                    cmp #dupPathname                        ; file exists?
                                beq create_ok                           ; that's fine, just open it.
                                sta >system_error~last_toolbox_code
                                sta <result
                                debugger_msg #file_manager_msg_create_error
                                sec
                                bra exit

name_error                      lda #file_manager_error_name_invalid
                                bra fake_open_error
open_error                      sta >system_error~last_toolbox_code
fake_open_error                 sta <result
                                debugger_msg #file_manager_msg_open_error
                                sec
                                bra exit

already_open_error              lda #file_manager_error_already_open
                                sta <result
                                debugger_msg #file_manager_msg_open_error
                                sec
                                bra exit

get_eof_error                   sta >system_error~last_toolbox_code
                                sta <result
                                debugger_msg #file_manager_msg_get_eof_error
                                sec
                                bra exit

set_eof_error                   sta >system_error~last_toolbox_code
                                sta <result
                                debugger_msg #file_manager_msg_set_eof_error
                                sec
                                brl exit

create_pb                       dc i2'5'
create_pb_pPathname             dc a4'0'
create_pb_requestAccess         dc i2'readWriteEnable+destroyEnable+renameEnable'
create_pb_filetype              dc i2'$0004'                            ; default to a txt file
create_pb_auxtype               dc i4'$00000000'
create_pb_storagetype           dc i2'standardFile'

open_pb                         dc i2'3'
open_pb_refnum                  dc i2'0'
open_pb_pPathname               dc a4'0'
open_pb_requestAccess           dc i2'writeEnable'

get_eof_pb                      dc i2'2'
get_eof_pb_refnum               dc i2'0'
get_eof_pb_length               dc i4'0'

set_eof_pb                      dc i2'3'
set_eof_pb_refnum               dc i2'0'
set_eof_pb_rel                  dc i2'startPlus'
set_eof_pb_length               dc i4'0'

                                end

; --------------------------------------------------------------------------------------------
; Close an open file.
; It is OK to call this on a file_descriptor that is already closed
; Params:
; pThis                         - the file_descriptor
;
; Returns:
; 0 on success or an error result.
file_descriptor_close           start seg_flib
                                using file_manager_data
                                using file_manager_errors
; Define our work area data
                                begin_locals
result                          decl word                                           ; result value inside our local work area
work_area_size                  end_locals

                                debugtag 'close'
                                debugtag 'file_descriptor'
                                sub (4:pThis),work_area_size

                                testptr <pThis
                                beq null_pointer
; Already closed?
                                getword [<pThis],#file_descriptor~refnum
                                beq exit

                                sta >close_pb_refnum
                                _CloseGS close_pb
                                bcs close_error
clear                           lda #0
                                putword [<pThis],#file_descriptor~refnum
                                putlong [<pThis],#file_descriptor~length

null_pointer                    stz <result
exit                            ret 2:result

close_error                     anop
; We will have a place for a debugger stop, but act as if there is no error
                                debugger_msg #file_manager_msg_close_error
                                bra clear

close_pb                        dc i2'1'
close_pb_refnum                 dc i2'0'

                                end

; ===========================================================================================
; file_reader
; This is basic buffered stream of bytes.  It is best to read in large chunks, but
; this will read some amounts reasonably efficiently, as it will be taking data out of a buffer.
; GS/OS does buffer data too, so we are kinda doing extra buffering, but access should be quicker.
;
; The file_reader is attempting to stick to the 'forward read only' paradigm.
; Sticking to this makes things simpler and it also help support non-disk based streams
; as well as compressed streams.  Unlikely I'll ever get to supporting those, but who knows.
; ===========================================================================================

; --------------------------------------------------------------------------------------------
; Construct an empty reader.
;
; Parameters:
; pThis         - pointer to a file_reader object
; Returns:
; 0 or error code.
file_reader_construct           start seg_flib
                                using file_manager_data
                                using file_manager_errors
; Define our work area data
                                begin_locals
result                          decl word                                           ; result value inside our local work area
work_area_size                  end_locals
                                debugtag 'construct'
                                debugtag 'file_reader'
                                sub (4:pThis),work_area_size

                                lda #file_reader~buffer                     ; The offset includes the offset from the beginning of file_reader to the embedded bufffer area
                                putword [<pThis],#file_reader~offset
                                putword [<pThis],#file_reader~size          ; Like the offset, the size of the buffer includes file_reader~buffer
; Make an empty descriptor.  We will not 'own' the descriptor, at least not now.  Perhaps add a bit flag saying if we own it or are just sharing it?
                                pushptr <pThis,#file_reader~file_desc
                                jsl file_descriptor_construct

                                sta <result
                                ret 2:result
                                end

; --------------------------------------------------------------------------------------------
; Destruct a reader.
; The reader does not currently own its file_descriptor, so it is left alone.
;
; Parameters:
; pThis         - pointer to a file_reader object
; Returns:
; 0 or error code.
file_reader_destruct            start seg_flib
                                using file_manager_data
                                using file_manager_errors
; Define our work area data
                                begin_locals
result                          decl word                                           ; result value inside our local work area
work_area_size                  end_locals
                                debugtag 'destruct'
                                debugtag 'file_reader'
                                sub (4:pThis),work_area_size

; Currently, there is nothing to do.  In the future, we may end up being able to own the file_descriptor

                                sta <result
                                ret 2:result
                                end

; --------------------------------------------------------------------------------------------
; Construct a new pointer to an empty reader.
;
; Parameters:
; pThis         - pointer to a file_reader object
; Returns:
; if carry is clear, the pointer.
; if carry is set, null
file_reader_new                 start seg_flib
                                using file_manager_data
                                using file_manager_errors
; Define our work area data
                                begin_locals
result                          decl ptr                                    ; result value inside our local work area
work_area_size                  end_locals

                                debugtag 'new'
                                debugtag 'file_reader'
                                sub ,work_area_size

                                jsr file_reader_allocate_buffer
                                bcs allocation_error
                                sta <result
                                stx <result+2

                                phx
                                pha
                                jsl file_reader_construct
                                clc
exit                            retkc 4:result
allocation_error                anop
                                clearptr <result
                                sec
                                bra exit
                                end

; --------------------------------------------------------------------------------------------
; Construct a new pointer to an empty reader, and *copy* in the file_descriptor
; The file_reader will *not* own the file_descriptor
;
; Parameters:
; pThis         - pointer to a file_reader object
; Returns:
; if carry is clear, the pointer.
; if carry is set, null
file_reader_new_with_desc       start seg_flib
                                using file_manager_data
                                using file_manager_errors
; Define our work area data
                                begin_locals
result                          decl ptr                                    ; result value inside our local work area
work_area_size                  end_locals
                                debugtag 'new_with_desc'
                                debugtag 'file_reader'
                                sub (4:pFileDesc),work_area_size

                                jsr file_reader_allocate_buffer
                                bcs allocation_error
                                sta <result
                                stx <result+2

                                phx
                                pha
                                jsl file_reader_construct

                                testptr <pFileDesc
                                beq exit
                                pushptr <result
                                pushptr <pFileDesc
                                jsl file_reader_set_file_descriptor
                                clc
exit                            retkc 4:result
allocation_error                anop
                                clearptr <result
                                sec
                                bra exit
                                end

; --------------------------------------------------------------------------------------------
; Deallocate a file_reader object.
;
; Parameters:
; pThis     - pointer to a file_reader
; Returns: nothing
file_reader_delete              start seg_flib
; Define our work area data
                                begin_locals
work_area_size                  end_locals

                                debugtag 'delete'
                                debugtag 'file_reader'
                                sub (4:pThis),work_area_size

                                testptr <pThis
                                beq exit

                                pushptr <pThis
                                jsl file_reader_destruct

                                pushptr <pThis
                                jsr file_reader_deallocate_buffer

exit                            ret
                                end

; --------------------------------------------------------------------------------------------
file_reader_allocate_buffer     private seg_flib
                                using file_manager_data

; Allocating from a set of temporary buffers, so as to not make a general allocation.
; With the default pool sizes, the sba will make a general allocation for a file_reader buffer, because of its size.
;                               pushsword #sizeof~file_reader
;                               jsl sba_alloc
                                setlocaldatabank

                                lda file_manager~reader_free_buffer_index
                                beq error
                                dec a
                                sta file_manager~reader_free_buffer_index
                                asl a                                       ; short pointer
                                tax
                                lda file_manager~reader_free_buffers,x
                                ldx file_manager~reader_temp_buffers_ptr+2  ; bank is always the same
                                clc
                                restoredatabank
                                rts

error                           anop
                                assert_brk 'reader_alloc'
                                sec
                                restoredatabank
                                rts

                                end
; --------------------------------------------------------------------------------------------
file_reader_deallocate_buffer   private seg_flib
                                using file_manager_data

                                lsub (4:pThis),0

                                setlocaldatabank
; Put the short pointer back in the free list
                                lda file_manager~reader_free_buffer_index
                                asl a
                                tax
                                lda <pThis
                                sta file_manager~reader_free_buffers,x

                                inc file_manager~reader_free_buffer_index
; Validate the pointer, just a bit
                                lda <pThis+2
                                cmp file_manager~reader_temp_buffers_ptr+2
                                beq ok
                                assert_brk 'reader_dealloc'
ok                              restoredatabank
                                lret

                                end
; --------------------------------------------------------------------------------------------
; Set the descriptor reference for the reader.
; The reader does not own the descriptor
file_reader_set_file_descriptor start seg_flib
                                using file_manager_data
                                using file_manager_errors
; Define our work area data
                                begin_locals
result                          decl word                                           ; result value inside our local work area
work_area_size                  end_locals
                                debugtag 'set_file_descriptor'
                                debugtag 'file_reader'
                                sub (4:pThis,4:pFileDesc),work_area_size

; Note, the file_reader will not own the file_descriptor
                                static_assert_equal sizeof~file_descriptor,6
                                getword [<pFileDesc],#file_descriptor~refnum
                                putword [<pThis],#file_reader~file_desc+file_descriptor~refnum
                                getword [<pFileDesc],#file_descriptor~length
                                putword [<pThis],#file_reader~file_desc+file_descriptor~length
                                getword [<pFileDesc],#file_descriptor~length+2
                                putword [<pThis],#file_reader~file_desc+file_descriptor~length+2
                                stz <result
                                ret 2:result
                                end
; --------------------------------------------------------------------------------------------
; Set the offset of the file reader locaton in the source file.
; Note, this will currently reset any buffering, as we don't keep track of where we are in the file
; Maybe fix this?
;
; Parameters:
; pThis         - the file reader
; dwOffset      - offset in the file
;
; Returns:
; 0 or error code, also sets the carry on error.
file_reader_set_offset          start seg_flib
                                using file_manager_data
                                using file_manager_errors
                                using system_error_data
; Define our work area data
                                begin_locals
result                          decl word                                           ; result value inside our local work area
work_area_size                  end_locals
                                debugtag 'set_offset'
                                debugtag 'file_reader'
                                sub (4:pThis,4:dwOffset),work_area_size

                                getword [<pThis],#file_reader~file_desc+file_descriptor~refnum
                                beq error_no_refnum
                                sta >set_mark_refnum
; Should we compare this to the offset was have saved?
                                lda <dwOffset
                                sta >set_mark_offset
                                lda <dwOffset+2
                                sta >set_mark_offset+2

                                _SetMarkGS set_mark_pb
                                bcs error_set_mark
; Reset the buffer
                                lda #file_reader~buffer
                                putword [<pThis],#file_reader~offset
                                putword [<pThis],#file_reader~size          ; Like the offset, the size of the buffer includes file_reader~buffer

                                lda #0
                                clc
error_exit                      sta <result
                                retkc 2:result

error_no_refnum                 lda #file_manager_error_not_open
                                sec
                                bra error_exit

error_set_mark                  sta >system_error~last_toolbox_code
                                lda #file_manager_error_invalid_offset
                                bra error_exit

set_mark_pb                     dc i2'3'
set_mark_refnum                 dc i2'0'
                                dc i2'0'                                ; from start of file
set_mark_offset                 dc i4'0'
                                end

; --------------------------------------------------------------------------------------------
; Read a single word and return it in A.
;
; Parameters:
; pThis         - the file reader
;
; Returns:
; if the carry flag is clear, the word read from the stream.
; if the carry flag is set, the return value is an error code.
file_reader_get_word            start seg_flib
                                using file_manager_data
                                using file_manager_errors
; Define our work area data
                                begin_locals
result                          decl word                                           ; result value inside our local work area
work_area_size                  end_locals
                                debugtag 'get_word'
                                debugtag 'file_reader'
                                sub (4:pThis),work_area_size
; Get the reamaining
                                getword [<pThis],#file_reader~size
                                sec
                                sbc [<pThis]
                                cmp #2
                                bge ok
; Need to load more
                                pushptr <pThis
                                jsl _file_reader_fill_internal_buffer
; Retest the buffer size, we may still not have enough
                                getword [<pThis],#file_reader~size
                                sec
                                sbc [<pThis]
                                cmp #2
                                blt not_enough

ok                              getword [<pThis],#file_reader~offset        ; the offset
                                tay                                         ; save this.  Note, we assume that file_reader~offset is 0, and will not reset y.
                                inc a                                       ; inc twice is faster than clc, adc #2, but only by 1 cycle
                                inc a
                                putword [<pThis],#file_reader~offset        ; Update the offset
; Get the data
                                lda [<pThis],y
                                sta <result
                                clc                                         ; No error!
error_exit                      retkc 2:result
not_enough                      lda #file_manager_error_read_underflow
                                sta <result
                                debugger_msg #file_manager_msg_read_underflow
                                sec
                                bra error_exit
                                end
; --------------------------------------------------------------------------------------------
; Read a long and return it in A/X (low/high).
;
; Parameters:
; pThis         - the file reader
;
; Returns:
; if the carry flag is clear, the long read from the stream.
; if the carry flag is set, the return value is an error code.
file_reader_get_long            start seg_flib
                                using file_manager_data
                                using file_manager_errors
; Define our work area data
                                begin_locals
result                          decl long                                           ; result value inside our local work area
work_area_size                  end_locals
                                debugtag 'get_long'
                                debugtag 'file_reader'
                                sub (4:pThis),work_area_size
; Get the reamaining
                                getword [<pThis],#file_reader~size
                                sec
                                sbc [<pThis]
                                cmp #4
                                bge ok
; Need to load more
                                pushptr <pThis
                                jsl _file_reader_fill_internal_buffer
; Retest the buffer size, we may still not have enough
                                getword [<pThis],#file_reader~size
                                sec
                                sbc [<pThis]
                                cmp #4
                                blt not_enough

ok                              getword [<pThis],#file_reader~offset        ; the offset
                                tay                                         ; save this.  Note, we assume that file_reader~offset is 0, and will not reset y.
                                clc
                                adc #4
                                putword [<pThis],#file_reader~offset        ; Update the offset
; Get the data
                                lda [<pThis],y
                                sta <result
                                iny
                                iny
                                lda [<pThis],y
                                sta <result+2
                                clc                                         ; No error!
error_exit                      retkc 4:result
not_enough                      lda #file_manager_error_read_underflow
                                sta <result
                                debugger_msg #file_manager_msg_read_underflow
                                sec
                                bra error_exit
                                end
; --------------------------------------------------------------------------------------------
; Get a pointer to a location in the read buffer that contains the
; requested amount of data.
; The file reader will advance its internal offset to past the requested size.
; The returned pointer will become invalid after any further read calls to the file_reader.
; Note, this cannot return a pointer to a block, bigger than the file_reader's
; internal buffer.  If data bigger than the internal buffer is need,
; use file_reader_put_in_buffer
;
; Parameters:
; pThis         - the file reader
; iReqAmount    - the amount of data requested
;
; Returns:
; if the carry flag is clear, a pointer to the buffer with the requested data.
; if the carry flag is set, a null pointer will be returned and file_manager_last_error will have the error code.
file_reader_get_buffered_data   start seg_flib
                                using file_manager_data
                                using file_manager_errors
; Define our work area data
                                begin_locals
result                          decl ptr                                          ; result value inside our local work area
work_area_size                  end_locals
                                debugtag 'get_buffered_data'
                                debugtag 'file_reader'
                                sub (4:pThis,2:iReqAmount),work_area_size
; Test request size
                                lda <iReqAmount
                                cmp #file_reader~default_buffer_size+1
                                bge request_too_large
; Get the reamaining
                                getword [<pThis],#file_reader~size
                                sec
                                sbc [<pThis]
                                cmp <iReqAmount
                                bge ok
; Need to load more
                                pushptr <pThis
                                jsl _file_reader_fill_internal_buffer
; Retest the buffer size, we may still not have enough
                                getword [<pThis],#file_reader~size
                                sec
                                sbc [<pThis]
                                cmp <iReqAmount
                                blt not_enough

ok                              getword [<pThis],#file_reader~offset        ; the offset
                                tay                                         ; save this.  Note, we assume that file_reader~offset is 0, and will not reset y.
                                clc
                                adc <iReqAmount
                                putword [<pThis],#file_reader~offset        ; Update the offset
; Get the pointer
                                tya
                                clc
                                adc <pThis
                                sta <result
                                lda #0
                                adc <pThis+2
                                sta <result+2
                                clc                                         ; No error!
exit                            retkc 4:result
request_too_large               anop
                                debugger_msg #file_manager_msg_read_underflow
                                lda #file_manager_error_buffer_too_small
                                bra error_exit
not_enough                      anop
                                debugger_msg #file_manager_msg_read_underflow
                                lda #file_manager_error_read_underflow
error_exit                      sta >file_manager_last_error
                                sec
                                bra exit
                                end

; --------------------------------------------------------------------------------------------
; Put the requested amount of data into a user buffer.
; If there is any data in the internal reader buffer, that will be used first, and if
; there is more to be read, it will come directly from the file.
;
; Parameters:
; pThis         - the file reader
; pBuffer       - the user buffer to fill
; dwReqAmount   - the amount of data requested.  Note, this is a long value.
;
; Returns:
; 0 or error code, will also set the carry if there is an error
file_reader_put_in_buffer       start seg_flib
                                using file_manager_data
                                using file_manager_errors
; Define our work area data
                                begin_locals
result                          decl word
wRemaining                      decl word
work_area_size                  end_locals
                                debugtag 'put_in_buffer'
                                debugtag 'file_reader'
                                sub (4:pThis,4:pBuffer,4:dwReqAmount),work_area_size
; Get the reamaining
                                getword [<pThis],#file_reader~size
                                sec
                                sbc [<pThis]
                                sta <wRemaining
                                beq empty_source
; Test request size
                                lda <dwReqAmount+2
                                bne get_remaining                               ; >64k, definititely getting the remaining
                                lda <dwReqAmount
                                cmp <wRemaining
                                bge get_remaining
; The request is for less that our remaining amount in the buffer, just copy that
                                getword [<pThis],#file_reader~offset
                                clc
                                adc <pThis
                                tay
                                lda #0
                                adc <pThis+2
                                pha
                                phy
                                pushptr <pBuffer
                                pushsword <dwReqAmount
                                jsl copy_memory
; Update our offset
                                getword [<pThis],#file_reader~offset
                                clc
                                adc <dwReqAmount
                                putword [<pThis],#file_reader~offset
                                lda #0                                      ; no error
                                bra exit
get_remaining                   anop
; Get the pointer to the remaining buffer
                                getword [<pThis],#file_reader~offset
                                clc
                                adc <pThis
                                tay
                                lda #0
                                adc <pThis+2
                                pha
                                phy
                                pushptr <pBuffer
                                pushsword <wRemaining
                                jsl copy_memory
; Reset the buffer
                                lda #file_reader~buffer
                                putword [<pThis],#file_reader~offset
                                putword [<pThis],#file_reader~size
; Advance the input buffer pointer
                                lda <pBuffer
                                clc
                                adc <wRemaining
                                sta <pBuffer
                                lda <pBuffer+2
                                adc #0
                                sta <pBuffer+2
; How much more do we need to load?
                                lda <dwReqAmount
                                sec
                                sbc <wRemaining
                                sta <dwReqAmount
                                lda <dwReqAmount+2
                                sbc #0
                                sta <dwReqAmount+2
                                ora <dwReqAmount
                                beq exit
empty_source                    anop
; Need to load more
                                pushptr <pThis
                                pushptr <pBuffer
                                pushptr <dwReqAmount                            ; pushdword
                                jsl _file_reader_fill_user_buffer
                                bcs read_error
exit                            clc
read_error                      sta <result
                                retkc 2:result                                  ; being consistent and returning carry-on-error for the file operations
                                end

; --------------------------------------------------------------------------------------------
; Fills the file readers buffer to the maximum amount
; This will retain any valid data that is already in the buffer, though it will
; move downward in the buffer.
_file_reader_fill_internal_buffer private seg_flib
                                using file_manager_data
                                using file_manager_errors
                                using system_error_data
; Define our work area data
                                begin_locals
result                          decl word                                           ; result value inside our local work area
iRemaining                      decl word
pSrc                            decl ptr
pDest                           decl ptr
work_area_size                  end_locals

                                debugtag 'fill_internal_buffer'
                                debugtag 'file_reader'
                                sub (4:pThis),work_area_size

; Slide down anything remaining in the buffer.
                                getword [<pThis],#file_reader~size
                                sec
                                sbc [<pThis]
                                sta <iRemaining
                                beq empty
; Well, patch the code and use sta patched,x? Just make and adjusted address and have y line up?  MVN?  It is such a pain to setup and you have to patch the code too.
                                getword [<pThis],#file_reader~offset
                                clc
                                adc <pThis
                                sta <pSrc
                                lda #0
                                adc <pThis+2
                                sta <pSrc+2
; Need to make another pointer, as we have a built-in offset that we have to remove to use Y as a 0 based index
                                clc
                                lda <pThis
                                adc #file_reader~buffer
                                sta <pDest
                                lda <pThis+2
                                adc #0
                                sta <pDest+2
                                ldy <iRemaining
                                dey
                                shortm
move_loop                       lda [<pSrc],y
                                sta [<pDest],y
                                dey
                                bpl move_loop
                                longm
                                lda <iRemaining

empty                           anop
; Put the remaiming, plus the fixed offset, into file_reader~size
                                clc
                                adc #file_reader~buffer
                                putword [<pThis],#file_reader~size
                                lda #file_reader~buffer
                                putword [<pThis],#file_reader~offset
; Setup the parameter block to read
                                lda #file_reader~default_buffer_size
                                sec
                                sbc <iRemaining
                                sta >read_pb_read_req_size
; refnum
                                getword [<pThis],#file_reader~file_desc+file_descriptor~refnum
                                sta >read_pb_refnum
; buffer
                                clc
                                getword [<pThis],#file_reader~size
                                adc <pThis
                                sta >read_pb_dest_ptr
                                lda #0
                                adc <pThis+2
                                sta >read_pb_dest_ptr+2

                                _ReadGS read_pb
                                bcs read_error
; Adjust the size by the returned read amount
no_error                        clc
                                getword [<pThis],#file_reader~size
                                adc >read_pb_read_ret_size
                                sta [<pThis],y
                                stz <result
                                clc
error_exit                      retkc 2:result

read_error                      anop
                                cmp #eofEncountered                 ; EOF is not an error for me
                                beq no_error
                                sta >system_error~last_toolbox_code
                                sta <result
                                debugger_msg #file_manager_msg_read_error
                                sec
                                bra error_exit

read_pb                         dc i2'4'
read_pb_refnum                  dc i2'0'
read_pb_dest_ptr                dc a4'0'
read_pb_read_req_size           dc i4'0'
read_pb_read_ret_size           dc i4'0'

                                end

; --------------------------------------------------------------------------------------------
; Read to a target (usually user) buffer
; Returns 0 or error code, as well as carry set on error
_file_reader_fill_user_buffer   private seg_flib
                                using file_manager_data
                                using file_manager_errors
                                using system_error_data
; Define our work area data
                                begin_locals
result                          decl word                                           ; result value inside our local work area
work_area_size                  end_locals

                                debugtag 'fill_user_buffer'
                                debugtag 'file_reader'
                                sub (4:pThis,4:pBuffer,4:dwReqAmount),work_area_size

; req amount
                                lda <dwReqAmount
                                sta >read_pb_read_req_size
                                lda <dwReqAmount+2
                                sta >read_pb_read_req_size+2
; refnum
                                getword [<pThis],#file_reader~file_desc+file_descriptor~refnum
                                sta >read_pb_refnum
; buffer
                                lda <pBuffer
                                sta >read_pb_dest_ptr
                                lda <pBuffer+2
                                sta >read_pb_dest_ptr+2

                                _ReadGS read_pb
                                bcs read_error
                                stz <result
error_exit                      retkc 2:result

read_error                      cmp #eofEncountered                 ; EOF is not an error for me
                                beq read_underflow
                                sta >system_error~last_toolbox_code
set_error                       sta <result
                                debugger_msg #file_manager_msg_read_error
                                sec
                                bra error_exit
read_underflow                  lda #file_manager_error_read_underflow
                                sec
                                bra set_error

read_pb                         dc i2'4'
read_pb_refnum                  dc i2'0'
read_pb_dest_ptr                dc a4'0'
read_pb_read_req_size           dc i4'0'
read_pb_read_ret_size           dc i4'0'

                                end

; ===========================================================================================
; file_writer
;
; This is similar to the reader, except that the buffer is allocated and the system is designed
; to allow for growth, and the resulting buffer in memory is then flushed to the disk.
; This can do intermediate flushes as well.
; ===========================================================================================

; --------------------------------------------------------------------------------------------
; Construct an empty writer.
;
; Parameters:
; pThis         - pointer to a file_writer object
; Returns:
; carry clear if successful
file_writer_construct           start seg_flib
                                using file_manager_data
                                using file_manager_errors
; Define our work area data
                                begin_locals
work_area_size                  end_locals

                                debugtag 'construct'
                                debugtag 'file_writer'
                                sub (4:pThis),work_area_size

                                lda #0
                                putword [<pThis],#file_writer~offset
                                putword [<pThis],#file_writer~capacity
                                putptr [<pThis],#file_writer~buffer_ptr
; Make an empty descriptor.  We will not 'own' the descriptor, at least not now.  Perhaps add a bit flag saying if we own it or are just sharing it?
                                pushptr <pThis,#file_writer~file_desc
                                jsl file_descriptor_construct

                                clc
                                retkc
                                end

; --------------------------------------------------------------------------------------------
; Destruct a writer.
; The writer does not currently own its file_descriptor, so it is left alone.
;
; Parameters:
; pThis         - pointer to a file_writer object
; Returns:
; carry clear if successful
file_writer_destruct            start seg_flib
                                using file_manager_data
                                using file_manager_errors
; Define our work area data
                                begin_locals
work_area_size                  end_locals

                                debugtag 'destruct'
                                debugtag 'file_writer'
                                sub (4:pThis),work_area_size

                                pushptr <pThis
                                jsl file_writer_flush

                                getword [<pThis],#file_writer~buffer_ptr+2
                                beq no_buffer
                                pha
                                lda #0
                                putword [<pThis],#same
                                getword [<pThis],#file_writer~buffer_ptr
                                pha
                                lda #0
                                putword [<pThis],#same
                                jsl sba_free

no_buffer                       clc
                                retkc
                                end

; --------------------------------------------------------------------------------------------
; Construct a new pointer to an empty writer.
;
; Parameters:
; pThis         - pointer to a file_writer object
; Returns:
; if carry is clear, the pointer.
; if carry is set, null
file_writer_new                 start seg_flib
                                using file_manager_data
                                using file_manager_errors
; Define our work area data
                                begin_locals
result                          decl ptr                                    ; result value inside our local work area
work_area_size                  end_locals

                                debugtag 'new'
                                debugtag 'file_writer'
                                sub ,work_area_size

                                pushsword #sizeof~file_writer
                                jsl sba_alloc
                                bcs allocation_error
                                sta <result
                                stx <result+2

                                phx
                                pha
                                jsl file_writer_construct
                                clc
exit                            retkc 4:result
allocation_error                anop
                                clearptr <result
                                sec
                                bra exit
                                end

; --------------------------------------------------------------------------------------------
; Construct a new pointer to an empty writer, and *copy* in the file_descriptor
; The file_writer will *not* own the file_descriptor
;
; Parameters:
; pThis         - pointer to a file_writer object
; Returns:
; if carry is clear, the pointer.
; if carry is set, null
file_writer_new_with_desc       start seg_flib
                                using file_manager_data
                                using file_manager_errors
; Define our work area data
                                begin_locals
result                          decl ptr                                    ; result value inside our local work area
work_area_size                  end_locals
                                debugtag 'new_with_desc'
                                debugtag 'file_writer'
                                sub (4:pFileDesc),work_area_size

                                pushsword #sizeof~file_writer
                                jsl sba_alloc
                                bcs allocation_error
                                sta <result
                                stx <result+2

                                phx
                                pha
                                jsl file_writer_construct

                                testptr <pFileDesc
                                beq exit
                                pushptr <result
                                pushptr <pFileDesc
                                jsl file_writer_set_file_descriptor
                                clc
exit                            retkc 4:result
allocation_error                anop
                                clearptr <result
                                sec
                                bra exit
                                end

; --------------------------------------------------------------------------------------------
; Deallocate a file_writer object.
;
; Parameters:
; pThis     - pointer to a file_writer
; Returns: nothing
file_writer_delete              start seg_flib
; Define our work area data
                                begin_locals
work_area_size                  end_locals

                                debugtag 'delete'
                                debugtag 'file_writer'
                                sub (4:pThis),work_area_size

                                testptr <pThis
                                beq exit

                                pushptr <pThis
                                jsl file_writer_destruct

                                pushptr <pThis
                                jsl sba_free

exit                            ret
                                end

; --------------------------------------------------------------------------------------------
; Set the descriptor reference for the writer.
; The writer does not own the descriptor
file_writer_set_file_descriptor start seg_flib
                                using file_manager_data
                                using file_manager_errors
; Define our work area data
                                begin_locals
result                          decl word                                           ; result value inside our local work area
work_area_size                  end_locals
                                debugtag 'set_file_descriptor'
                                debugtag 'file_writer'
                                sub (4:pThis,4:pFileDesc),work_area_size

; Note, the file_writer will not own the file_descriptor
                                static_assert_equal sizeof~file_descriptor,6
                                getword [<pFileDesc],#file_descriptor~refnum
                                putword [<pThis],#file_writer~file_desc+file_descriptor~refnum
                                getword [<pFileDesc],#file_descriptor~length
                                putword [<pThis],#file_writer~file_desc+file_descriptor~length
                                getword [<pFileDesc],#file_descriptor~length+2
                                putword [<pThis],#file_writer~file_desc+file_descriptor~length+2
                                stz <result
                                ret 2:result
                                end

; --------------------------------------------------------------------------------------------
; Set the capcity of the buffer for the writer
; Note, if the writer currently has a buffer, and the offset into the buffer is not 0,
; the contents of the previous buffer will be copied to the new buffer, and the offset
; will be left alone or truncated.
; Parameters:
;   pThis   - the file_writer
;   wCapacity - the new capacity, can be 0
file_writer_set_capacity        start seg_flib
                                using file_manager_data
                                using file_manager_errors

                                begin_locals
wSourceSize                     decl word
pSource                         decl ptr
pDest                           decl ptr
work_area_size                  end_locals

                                debugtag 'set_capacity'
                                debugtag 'file_writer'
                                sub (4:pThis,2:wCapacity),work_area_size

                                getword [<pThis],#file_writer~capacity
                                cmp <wCapacity
                                beq same

                                lda <wCapacity
                                jeq set_to_0

                                pha

                                stz <wSourceSize

                                getword [<pThis],#file_writer~buffer_ptr+2
                                beq no_prev
                                sta <pSource+2
                                getword [<pThis],#file_writer~buffer_ptr
                                sta <pSource

                                getword [<pThis],#file_writer~offset
                                sta <wSourceSize
                                bne prev_copy
; We can free the source first
                                lda #0
                                putptr [<pThis],#file_writer~buffer_ptr             ; clear, in case we get an error allocating the new buffer
                                pushptr <pSource
                                jsl sba_free

prev_copy                       anop
no_prev                         jsl sba_alloc
                                bcs allocation_error
                                putretptr <pDest

                                lda <wCapacity
                                cmp <wSourceSize
                                bge ok_source_size
                                sta <wSourceSize

ok_source_size                  lda <wSourceSize
                                beq no_copy

                                pushptr <pSource
                                pushptr <pDest
                                pushsword <wSourceSize
                                jsl copy_memory

                                pushptr <pSource
                                jsl sba_free

no_copy                         lda <wSourceSize
                                putword [<pThis],#file_writer~offset
                                lda <wCapacity
                                putword [<pThis],#file_writer~capacity
                                lda <pDest
                                putptrlow [<pThis],#file_writer~buffer_ptr
                                lda <pDest+2
                                putptrhigh [<pThis],#file_writer~buffer_ptr

same                            clc
exit                            retkc

set_to_0                        anop
                                jsr clear
                                bra same

allocation_error                jsr clear
                                sec
                                bra exit

;
clear                           getword [<pThis],#file_writer~buffer_ptr+2
                                beq no_prev_clear
                                pha
                                lda #0
                                putword [<pThis],#same
                                getword [<pThis],#file_writer~buffer_ptr
                                pha
                                lda #0
                                putword [<pThis],#same
                                jsl sba_free

no_prev_clear                   lda #0
                                putword [<pThis],#file_writer~offset
                                putword [<pThis],#file_writer~capacity
                                rts

                                end

; --------------------------------------------------------------------------------------------
; Append to the buffer.  If the buffer capacity is too small, it will grow, if allowed to
; or it will flush to disk, if the buffer is backed by a valid file descriptor.
;
; Parameters:
;   pThis   - the file_writer
;   pSource - the source data
;   wSourceLength - the source length
file_writer_append              start seg_flib
                                using file_manager_data
                                using file_manager_errors

                                begin_locals
wWantCapacity                   decl word
wOffset                         decl word
work_area_size                  end_locals

                                debugtag 'append'
                                debugtag 'file_writer'

                                sub (4:pThis,4:pSource,2:wSourceLength),work_area_size

                                getword [<pThis],#file_writer~offset
                                sta <wOffset
                                clc
                                adc <wSourceLength
                                bcs over_64k
                                cmpword [<pThis],#file_writer~capacity
                                beq ok_copy
                                blt ok_copy
; round up to the next 256 byte page
                                bit #$00FF
                                beq ok_page
                                and #$FF00
                                clc
                                adc #$0100
                                bcs over_64k
ok_page                         sta <wWantCapacity
                                pushptr <pThis
                                pushsword <wWantCapacity
                                jsl file_writer_set_capacity
                                bcs resize_error

ok_copy                         anop
                                pushptr <pSource
                                lda <wOffset
                                clc
                                adcword [<pThis],#file_writer~buffer_ptr
                                tax
                                lda #0
                                adcword [<pThis],#file_writer~buffer_ptr+2
                                pha
                                phx
                                pushsword <wSourceLength
                                jsl copy_memory

                                lda <wSourceLength
                                clc
                                adc <wOffset
                                putword [<pThis],#file_writer~offset

                                clc
resize_error                    anop
exit                            retkc
over_64k                        sec
                                bra exit

                                end

; --------------------------------------------------------------------------------------------
; Convenience function to append a zero-terminated string.  The 0 is NOT written to the buffer.
;
; Parameters:
;   pThis   - the file_writer
;   pStr    - the source string
file_writer_append_zt           start seg_flib
                                using file_manager_data
                                using file_manager_errors

                                begin_locals
wSourceSize                     decl word
pSource                         decl ptr
pDest                           decl ptr
work_area_size                  end_locals

                                debugtag 'append_zt'
                                debugtag 'file_writer'

                                sub (4:pThis,4:pStr),work_area_size

                                pushptr <pStr
                                jsl string_zt_length
                                cmp #0
                                bne has_chars
                                clc
                                bra exit
has_chars                       tax
                                pushptr <pThis
                                pushptr <pStr
                                phx
                                jsl file_writer_append
exit                            retkc
                                end

; --------------------------------------------------------------------------------------------
; Flush the buffer to the destination and reset the offset to 0
; Parameters:
;   pThis   - the file_writer
file_writer_flush               start seg_flib
                                using file_manager_data
                                using file_manager_errors
                                using system_error_data

                                begin_locals
wLength                         decl word
work_area_size                  end_locals

                                debugtag 'flush'
                                debugtag 'file_writer'
                                sub (4:pThis),work_area_size

                                getword [<pThis],#file_writer~offset
                                beq none

                                sta <wLength

                                clc
                                getword [<pThis],#file_writer~file_desc+file_descriptor~refnum
                                beq no_file

                                sta >write_pb_refnum
                                getword [<pThis],#file_writer~buffer_ptr
                                sta >write_pb_buffer
                                getword [<pThis],#file_writer~buffer_ptr+2
                                beq no_buffer
                                sta >write_pb_buffer+2
                                lda <wLength
                                sta >write_pb_length
                                _WriteGS write_pb
                                bcc ok
                                sta >system_error~last_toolbox_code
ok                              anop

no_file                         anop
no_buffer                       anop
                                lda #0
                                putword [<pThis],#file_writer~offset

none                            anop
                                retkc


write_pb                        dc i'4'
write_pb_refnum                 dc i'0'
write_pb_buffer                 dc i4'0'
write_pb_length                 dc i4'0'
write_pb_writted_length         dc i4'0'
                                end

