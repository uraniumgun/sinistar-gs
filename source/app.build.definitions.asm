; App compile time configuration values.
; These are NON-DEBUG definitions, put debug related ones in app.debug.definitions.asm

; These control whether or not the merged vs. non-merged update rects are in use
; At the library level, both could be on, but the app side can also use these
; to pick one or the other.
app~use_merged_update_rects             gequ 0
app~use_non_merged_update_rects         gequ 1

