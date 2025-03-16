# ================================================================================
#
# Build ID Verilog Module Script
#
# Generates a Verilog module with version information from the timestamp of the
# current build.
# These values are available from the BETA_FLAG, MAJOR_VER, MINOR_VER, MINION_VER
# localparams of the generated build_id module rtl/minimig/minimig_version.vh
# Verilog source file.
#
# ================================================================================

# Message using quartus's post_message if available, and puts if not
# (Allows script to run under other Tcl hosts)
proc msg {text} {
	if {"post_message" in [info commands "post_message"]} {
		post_message $text
	} else {
		puts $text
	}
}

proc generateBuildID_Verilog {} {

	# Beta flag
	set buildBeta 1

	# Get the timestamp (see: https://www.intel.com/content/www/us/en/programmable/support/support-resources/design-examples/design-software/tcl/tcl-date-time-stamp.html)
	set buildYear  [ clock format [ clock seconds ] -format %y ]
	set buildMonth [ clock format [ clock seconds ] -format %m ]
	set buildDay   [ clock format [ clock seconds ] -format %d ]

	# Create a Verilog file for output
	set outputFileName "../../rtl/minimig/minimig_version.vh"
	set outputFile [open $outputFileName "w"]

	# Output the Verilog source
	puts $outputFile "// minimig version constants"
	puts $outputFile ""
	puts $outputFile "localparam \[7:0\] BETA_FLAG  = 8'd$buildBeta;  // BETA / RELEASE flag"
	puts $outputFile "localparam \[7:0\] MAJOR_VER  = 8'd$buildYear;  // major version number (Year)"
	puts $outputFile "localparam \[7:0\] MINOR_VER  = 8'd$buildMonth;  // minor version number (Month)"
	puts $outputFile "localparam \[7:0\] MINION_VER = 8'd$buildDay;  // least version number (Day)"
	close $outputFile

	# Send confirmation message to the Messages window
	msg "Generated build identification Verilog module: [pwd]/$outputFileName"
	msg "Beta:             $buildBeta"
	msg "Year:             $buildYear"
	msg "Month:            $buildMonth"
	msg "Day:              $buildDay"
}

# Comment out this line to prevent the process from automatically executing when the file is sourced:
generateBuildID_Verilog

