; Constants for the datalib system
; These should not define any constants/structures that require other headers

datalib_type_TILE                       gequ 'ELIT'
datalib_type_CTIL                       gequ 'LITC'
datalib_type_PALT                       gequ 'TLAP'
datalib_type_FRMC                       gequ 'CMRF'
datalib_type_FONT                       gequ 'TNOF'
datalib_type_WAVE                       gequ 'EVAW'             ; Audio sample

datalib_load_options~none               gequ $0000
datalib_load_options~reference          gequ $8000                                                ; Adds a reference to the data.

datalib_preload_options~none            gequ 0

datalib_unload_options~none             gequ $0000
