#
# IceSugarPro demo JTAG script
#

init
scan_chain


# {_cpu_ipl,ext_int2,int2,gayle_irq};

set capture_fields {
	{ gayle_irq 1 }
	{ int2 1 }
	{ ext_int2 1 }
	{ cpu_ipl 3 }
	{ id1 26 }
	{ id2 32 }
}

source jcapture.tcl

set capture_length [::jcapture::setup ecp5.tap $capture_fields]
puts "Capture length is $capture_length"

proc led {v} {
	::jcapture::virscan ecp5.tap write
	::jcapture::vdrscan ecp5.tap $::jcapture::capture_width $v
}

#::jcapture::sample
#::jcapture::sample
#::jcapture::sample
#::jcapture::sample
#::jcapture::sample
#::jcapture::wait_fifohasdata
#::jcapture::dump_fifo
# exit

::jcapture::print_status

puts "Setting capture parameters..."

# Mask on bit 0 of ide_irq and trigger on rising edge
::jcapture::settrigger mask gayle_irq 0x1
::jcapture::settrigger edge gayle_irq 0x0
::jcapture::settrigger value gayle_irq 0x1
#::jcapture::settrigger mask cpu_ipl 0x7
#::jcapture::settrigger edge cpu_ipl 0x0
#::jcapture::settrigger value cpu_ipl 0x5
#::jcapture::settrigger mask int2 0x1
#::jcapture::settrigger edge int2 0x0
#::jcapture::settrigger value int2 0x0

# capture with 50% lead-in
::jcapture::setleadin 2

# Send capture parameters and start capturing...
::jcapture::capture

::jcapture::print_status

puts "Waiting for the FIFO"
::jcapture::wait_fifofull

::jcapture::print_status

puts "Collecting the FIFO contents"
::jcapture::dump_fifo
::jcapture::print_status

puts "Done."
exit


