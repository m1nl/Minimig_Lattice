#
# IceSugarPro demo JTAG script
#

init
scan_chain


# {hdd1_ena,hdd0_ena,hdd_cmd_req,hdd_dat_req,hdd_status_wr,hdd_data_wr,hdd_data_rd,hdd_wr,irq};

set capture_fields {
	{ ide_irq 1 }
	{ hdd_wr 1 }
	{ hdd_data_rd 1 }
	{ hdd_data_wr 1 }
	{ hdd_status_wr 1 }
	{ hdd_dat_req 1 }
	{ hdd_cmd_req 1 }
	{ hdd0_ena 2 }
	{ hdd1_ena 2 }
	{ nrdy 1 }
	{ sel_ide 1 }
	{ id1 19 }
	{ id2 32 }
}

source jcapture.tcl

set capture_length [::jcapture::setup ecp5.tap $capture_fields]
puts "Capture length is $capture_length"

proc led {v} {
	::jcapture::virscan ecp5.tap write
	::jcapture::vdrscan ecp5.tap $::jcapture::capture_width $v
}

# FIXME - add a momentary sample option

::jcapture::sample
::jcapture::wait_fifohasdata
::jcapture::dump_fifo
# exit


puts "Setting capture parameters..."

# Mask on bit 0 of ide_irq and trigger on rising edge
::jcapture::settrigger mask ide_irq 0x1
::jcapture::settrigger edge ide_irq 0x1
::jcapture::settrigger value ide_irq 0x1

::jcapture::settrigger mask hdd_wr 0x0
::jcapture::settrigger edge hdd_wr 0x0
::jcapture::settrigger value hdd_wr 0x0

# capture with 50% lead-in
::jcapture::setleadin 2

# Send capture parameters and start capturing...
::jcapture::capture

puts "Waiting for the FIFO"
::jcapture::wait_fifofull

puts "Collecting the FIFO contents"
::jcapture::dump_fifo

puts "Done."
exit


