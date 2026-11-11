# Record every signal made visible by xelab's debug setting.
log_wave -recursive /*

if {![info exists ::env(SIM_TIME)] || $::env(SIM_TIME) eq "" || $::env(SIM_TIME) eq "all"} {
    run all
} else {
    run $::env(SIM_TIME)
}

quit
