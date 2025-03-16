#
# JCapture utility functions.
#

set ::jcapture::tap ""
set ::jcapture::fields ""
set ::jcapture::capture_width 0
set ::jcapture::capture_depth 0
set ::jcapture::trigger_width 0

set ::jcapture::membernames {
	"name" "width" "mask" "edge" "value"
}

# Setup function, makes a copy of the fields to be captured, and sets the tap to be used hereafter

proc ::jcapture::setup { newtap capture_fields} {
	set ::jcapture::tap $newtap
	set ::jcapture::fields ""
	set cw 0
	for {set i 0} {$i< [llength $capture_fields]} {incr i} {
		set record [lindex $capture_fields $i]
		set cw [expr {$cw + [lindex $record 1]}]
		# Add mask, edge and invert fields to capture list
		lappend record 0
		lappend record 0
		lappend record 0
		lappend ::jcapture::fields $record
	}

	# Fetch capture width, depth and trigger width from design
	flush_fifo

	virscan $newtap capturewidth
	wait_fifobusy
	set t [vdrscan $newtap 16 0]
	set ::jcapture::capture_width [expr 0x$t]

	virscan $newtap capturedepth
	wait_fifobusy
	set t [vdrscan $newtap 16 0]
	set ::jcapture::capture_depth [expr "2**0x$t"]

	virscan $newtap triggerwidth
	wait_fifobusy
	set t [vdrscan $newtap 16 0]
	set ::jcapture::trigger_width [expr 0x$t]
	
	if {$cw != $::jcapture::capture_width} {
		puts "Warning: field mismatch - $cw bits defined but design contains $::jcapture::capture_width bits"
	}
	return $::jcapture::capture_width
}


# Virtual IR scan - shifts a value into a register attached to ER1.
# The index of these commands must match their assigned command codes in the the jcapture package.
set ::jcapture::commands {
	"status" "abort" "read" "write"  "setleadin" "setmask" "setinvert" "setedge"  "capture" "capturewidth" "capturedepth" "triggerwidth"  "sample" "spare" "reset" "bypass"
}

proc ::jcapture::virscan {tap {cmd status}} {
	set v -1
	for {set i 0} {$i < [llength $::jcapture::commands]} {incr i} {
		if {[lindex $::jcapture::commands $i] == $cmd} {
			set v $i
			set i [llength $::jcapture::commands]
		}
	}
	if {$v>=0} {
		irscan $tap 0x32
		return [drscan $tap 4 $v]
	} else {
		error "Unknown command $cmd";
	}
}


# Virtual DR scan - shifts a value into a register attached to ER2
proc ::jcapture::vdrscan {tap c v {sp -full}} {
	if {$sp == "-full" || $sp == "-start"} {
		irscan $tap 0x38
	}
	if {$sp == "-full" || $sp == "-end"} {
		return [drscan $tap $c $v]
	}
	return [drscan $tap $c $v -endstate DRPAUSE]	
}

# Command definitions for the jcapture module
set ::jcapture::cmd_status 0x0
set ::jcapture::cmd_abort 0x01
set ::jcapture::cmd_read 0x02
set ::jcapture::cmd_write 0x3
set ::jcapture::cmd_setleadin 0x4
set ::jcapture::cmd_setmask 0x5
set ::jcapture::cmd_setinvert 0x6
set ::jcapture::cmd_setedge 0x7
set ::jcapture::cmd_capture 0x8
set ::jcapture::cmd_capturewidth 0x9
set ::jcapture::cmd_capturedepth 0xa
set ::jcapture::cmd_triggerwidth 0xb
set ::jcapture::cmd_sample 0xc

# Flag definitions
set ::jcapture::flag_busy 0x1
set ::jcapture::flag_full 0x2
set ::jcapture::flag_empty 0x4


# Wait for the busy flag to fall 
proc ::jcapture::wait_fifobusy { } {
	puts -nonewline "Waiting on busy flag..."
	set status [virscan $::jcapture::tap status]
	while {[expr "0x$status & $::jcapture::flag_busy"] != 0 } {
		after 10
		set status [virscan $::jcapture::tap status]
	}
	puts "done"
}

# Wait for the empty flag to fall 
proc ::jcapture::wait_fifohasdata { } {
	set status [virscan $::jcapture::tap status]
	while {[expr "0x$status & $::jcapture::flag_empty"] != 0 } {
		puts $status
		after 10
		set status [virscan $::jcapture::tap status]
	}
}

# Wait for the FIFO to fill 
proc ::jcapture::wait_fifofull { } {
	set status [virscan $::jcapture::tap status]
	while {[expr "0x$status & $::jcapture::flag_full"] == 0 } {
		set status [virscan $::jcapture::tap status]
	}
	wait_fifobusy
}

# Dump the FIFO contents to the shell window
proc ::jcapture::dump_fifo { } {
	set fields [llength $::jcapture::fields]
	set status [virscan $::jcapture::tap status]
	while {[expr "0x$status & $::jcapture::flag_empty"] == 0 } {
		set captures ""

		for {set i 0 } {$i < $fields} {incr i} {
			set record [lindex $::jcapture::fields $i]
			set w [lindex $record 1]
			if {$i==0} {
				set d [vdrscan $::jcapture::tap $w 0 -start]
			} else {
				set d [vdrscan $::jcapture::tap $w 0 -cont]
			}			
			lappend captures $d
		}
				
		for {set i 0} {$i < $fields} {incr i} {
			puts -nonewline "[lindex $captures [expr {$fields - $i -1 }]] "
		}
		puts ""
		set status [virscan $::jcapture::tap status]
	}
}


# Convert decimal number to the required binary code
proc ::jcapture::dec2bin {i {width {}}} {

    set res {}
    if {$i<0} {
        set sign -
        set i [expr {abs($i)}]
    } else {
        set sign {}
    }
    while {$i>0} {
        set res [expr {$i%2}]$res
        set i [expr {$i/2}]
    }
    if {$res == {}} {set res 0}

    if {$width != {}} {
        append d [string repeat 0 $width] $res
        set res [string range $d [string length $res] end]
    }
    return $sign$res
}


# Helper function for creating VCD files - creates a unique signal name from an index.

proc ::jcapture::vcdid { c } {
	set result [format %c [expr {97 + $c % 26}]]
	set c [expr {$c / 26}]
	while { $c > 0 } {
		append result [format %c [expr {97 + $c % 26}]]
		set c [expr {$c / 26}]
	}
	return $result
}


# Create a VCD file from the capture_fields array, and write a header.

proc ::jcapture::create_vcd {filename {timezero 0}} {	
	set chan [open $filename w]
	
	puts $chan "\$version Generated by jcapture \$end"
	puts -nonewline $chan "\$date "
	puts $chan [clock format [clock seconds]]
	puts $chan " \$end"
	puts $chan "\$timescale 10ns \$end"
	puts $chan "\$timezero $timezero \$end"

	puts $chan "\$scope module TOP \$end"

	for {set i 0 } {$i < [llength $::jcapture::fields]} {incr i} {
		set record [lindex $::jcapture::fields $i]
		set w [lindex $record 1]
		if {$w > 1} {
			set wfmt "\[[expr {$w - 1}]:0\]"
		} else {
			set wfmt ""
		}
		set id [vcdid $i]
		puts $chan "\$var wire [lindex $record 1] $id [lindex $record 0] $wfmt \$end"
	}
	puts $chan {$enddefinitions $end}
	return $chan
}

# Dump the FIFO contents to a previously-created VCD file
proc ::jcapture::fifo_to_vcd { chan } {
	set fields [llength $::jcapture::fields]

	set vcdi 0

	set status [virscan $::jcapture::tap status]
	while {[expr "0x$status & $::jcapture::flag_empty"] == 0 } {
		set captures ""

		puts $chan "#$vcdi"

		for {set i 0 } {$i < $fields} {incr i} {
			set record [lindex $::jcapture::fields $i]
			set w [lindex $record 1]
			if {$i==0} {
				set d [vdrscan $::jcapture::tap $w 0 -start]
			} else {
				set d [vdrscan $::jcapture::tap $w 0 -cont]
			}			
			lappend captures $d
			set id [vcdid $i]
			puts $chan "b[dec2bin [expr 0x$d] $w] $id"
		}

		set status [virscan $::jcapture::tap status]

		incr vcdi
	}
	puts $chan "#$vcdi"
	close $chan
}

# Print current status
proc ::jcapture::print_status { } {
	set status [virscan $::jcapture::tap status]
	puts -nonewline "Status :" 
	if {[expr "0x$status & $::jcapture::flag_empty"] == $::jcapture::flag_empty } { puts -nonewline " FIFO_empty" }
	if {[expr "0x$status & $::jcapture::flag_full"] == $::jcapture::flag_full } { puts -nonewline " FIFO_full" }
	if {[expr "0x$status & $::jcapture::flag_busy"] == $::jcapture::flag_busy } { puts -nonewline " BUSY" }
	puts ""
	return $status
}

# Silently empty the FIFO.
proc ::jcapture::flush_fifo { } {
	::jcapture::setleadin 0
	virscan $::jcapture::tap abort
	set status [::jcapture::print_status]
	puts -nonewline "Flushing FIFO... "
	while {[expr "0x$status & $::jcapture::flag_empty"] == 0 } {
		vdrscan $::jcapture::tap 1 0 -full
		set status [virscan $::jcapture::tap status]
	}
	puts "done"
}

proc ::jcapture::triggerconf {idx} {
	for {set i 0} {$i < [llength $::jcapture::fields]} {incr i } {
		set record [lindex $::jcapture::fields $i]
		if {$i==0} {
			vdrscan $::jcapture::tap [lindex $record 1] [lindex $record $idx] -start
		} else {
			vdrscan $::jcapture::tap [lindex $record 1] [lindex $record $idx] -cont		
		}
	}
}

proc ::jcapture::checktrigger { } {
	set twidth 0
	for {set i 0} {$i < [llength $::jcapture::fields]} {incr i } {
		set record [lindex $::jcapture::fields $i]
		set mask [lindex $record 2]
		set twidth [expr {$twidth + [lindex $record 1]}]
		if {$mask > 0 } {
			if {$twidth > $::jcapture::trigger_width } {
				puts "Warning: trigger fields are $twidth bits wide, the design only supports $::jcapture::trigger_width"
			}
		}
	}
}

proc ::jcapture::capture { } {
	checktrigger
	virscan $::jcapture::tap setmask
	triggerconf 2
	virscan $::jcapture::tap setedge
	triggerconf 3
	virscan $::jcapture::tap setinvert
	triggerconf 4
	virscan $::jcapture::tap capture
}

proc ::jcapture::sample { } {
	::jcapture::virscan $::jcapture::tap sample
}

proc ::jcapture::setleadin { leadin } {
	::jcapture::virscan $::jcapture::tap setleadin
	::jcapture::vdrscan $::jcapture::tap $::jcapture::capture_width $leadin
}

proc ::jcapture::settrigger {triggerparam field value} {
	set v 0
	for {set i 0} {$i < [llength $::jcapture::membernames]} {incr i} {
		if {[lindex $::jcapture::membernames $i] == $triggerparam} {
			set v $i
			set i [llength $::jcapture::membernames]
		}
	}
	if {$v > 1} {
		for {set i 0} {$i < [llength $::jcapture::fields]} {incr i } {
			set record [lindex $::jcapture::fields $i]
			if {$field == [lindex $record 0]} {
				puts "Setting $triggerparam for $field to $value"
				lset record $v $value
				lset ::jcapture::fields $i $record
				set i [llength $::jcapture::fields]
			}
		}	
	} else {
		puts "Unknown trigger parameter $triggerparam"
	}
}


# Make the script interruptable with ctrl-c
signal handle SIGINT SIGTERM
catch -signal {
	exit
}

