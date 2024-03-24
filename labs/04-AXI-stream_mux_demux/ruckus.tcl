# Load RUCKUS environment and library
source $::env(RUCKUS_PROC_TCL)

# Load ruckus files
loadRuckusTcl "$::env(MODULES)/surf"

# Load local source Code
loadSource -dir "$::DIR_PATH/rtl"
