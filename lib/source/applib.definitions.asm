; Ranges in the shared_dp that are assigned to libs
; These ranges are for the use of the specified library and other
; libraries should not expect the variables to be a certain value
; or remain across calls to the owning library.
applib~shared_dp~start      gequ 0

mathlib~shared_dp~start     gequ $0080
mathlib~shared_dp~length    gequ 16
