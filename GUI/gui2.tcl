source gui-param-config.tcl

wm title . "BLE-Mesh Simulator v0.5"

set network_entries {}
set network_labels {}

puts "start"

foreach param $param_network {
  # Unpack the param info. (Constructed in gui-param-config.tcl)
  set name [lindex $param 0]
  set label [lindex $param 1]
  set type [lindex $param 2]
  set values [lindex $param 3]
  set trace [lindex $param 4]
  set state [lindex $param 5]

  puts "$name $label $type $values $trace $state"
  set param($name) 0

  # Make the label
  label .${name}_label -text $label
  $type .${name}_entry -textvariable ${param(${name})}

  # Add the trace
  if {!($trace eq "")} {
    trace add variable param($name) write $trace
  }

  # Add the label and the entry to the list
  lappend network_entries .network.${name}_entry
  lappend network_labels .network.${name}_label
}

puts "ye"
puts [lindex network_entries 0]





# Pack the objects and display on screen

set i 0
foreach label $network_labels entry $network_entries {
  puts $label
  puts $entry
  grid $label -row $i -column 0
  grid $entry -row $i -column 1
  incr i
}
