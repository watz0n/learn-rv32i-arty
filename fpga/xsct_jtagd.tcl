###################################################################
#      JTAG Deamon (jtagd) for dtmxsdb interface
#      Author: Watson Huang
#      Description:
#           JTAG deamon API for dtmxsdb_t::do_command function in dtmxsdb.cc
# 			Configure FPGA by ./fpgabs/fpga_rv32i_arty.bit and setup JTAG service deamon
#      Change Log:
#      02/13, 2018: Setup JTAG deamon by xsdbserver, 
# 					jtagd_dmi_req/jtagd_dmi_resp for do_command function
# 	   02/15, 2018: Add reset function via BSCANE2 USER3 interface
###################################################################

# Xilinx JTAG hex data reorder function
proc jtagd_reorder { data } {
    set l [string length $data]
    if {$l > 2} {
        set i [expr $l - 1]
        set s ""
        while {$i > -1} {
            if {$i > 0} {
                set s [concat $s[string range $data [expr {$i - 1}] $i]]
                set i [expr {$i - 2}]
            } else {
                set s [concat $s[expr 0][string index $data $i]]
                set i [expr {$i - 1}]
            }
        }
        return $s
    } else {
        return $data
    }
}

# Xilinx JTAG connect to FPGA board, Digilent Arty Board
proc jtagd_conn {} {
    connect
    jtag targets -set -filter {jtag_cable_name =~ "Digilent*" && name =~ "xc7a35t"} ; #Multiple Filter in Xilinx UG835
    puts "JTAG Frequency [jtag frequency] Hz"
    variable jseq
    set jseq [jtag sequence]
    $jseq state RESET
    $jseq irshift -state IDLE -hex 6 09
    $jseq drshift -state IDLE -tdi 0 -capture 32
    set result [jtagd_reorder [$jseq run]] ; $jseq clear

    if { $result == "0362d093" } {
        puts "Read JTAG IDCODE: $result (XC7A35T)"

        $jseq irshift -state IDLE -hex 6 0B
        $jseq irshift -state IDLE -capture -hex 6 3F
        set result [jtagd_reorder [$jseq run]] ; $jseq clear

        if { $result == "01" } {
            puts "Reset FPGA done, configure FPGA"
            fpga -file ./fpgabs/fpga_rv32i_arty.bit
            $jseq irshift -state IDLE -capture -hex 6 3F
            set result [jtagd_reorder [$jseq run]] ; $jseq clear
            if { $result == "35" } {
                puts "JTAG connect to FPGA done."
                return 0
            } else {
                puts "FPGA state: $result, should be 35 after configure."
            }
        } else {
            puts "FPGA state: $result, should be 01 after reset."
        }

    } else {
        puts "Read JTAG IDCODE: $result, but expect Arty IDCODE:0362d093"
    }   

    puts "JTAG connect to FPGA fail."
    return -1

}

proc jtagd_stop {} {
    xsdbserver stop
    disconnect
}

proc jtagd_start {} {
    puts "Start JTAG connect to FPGA board."
    set result [jtagd_conn]
    if { $result == 0 } {
        puts "Start JTAG deamon @localhost:3333"
        xsdbserver start -host localhost -port 3333
    } else {
        jtagd_stop
        puts "JTAG deamon not start."
        return -1
    }
}

proc jtagd_tx { data } {
    variable jseq
    $jseq irshift -state IDLE -hex 6 23 ; #USER4
    $jseq drshift -state IDLE -capture -hex 41 [jtagd_reorder $data]
    set result [jtagd_reorder [$jseq run]]
    $jseq clear
    return $result
}

proc jtagd_rx { } {
    variable jseq
    $jseq irshift -state IDLE -hex 6 23 ; #USER4
    $jseq drshift -state IDLE -capture -tdi 0 41
    set result [jtagd_reorder [$jseq run]]
    $jseq clear
    return $result
}

# DMI cmd => Hex string 
proc dmi_cmd {addr data opcode} {
    scan "$addr $data $opcode" "%x %x %x" ad da op
    set hxl [format %08x [expr (($da<<2)&0xFFFFFFFC)|($op&0x03)]]
    set hxh [format %03x [expr (($da>>30)&0x03)|(($ad&0x7F)<<2)]]
    return [concat $hxh$hxl]
}

# DMI cmd <= Hex string 
proc dmi_cmd_analyze { data } {
    set l [string length $data]
    if {$l > 8} {
        scan [string range $data [expr {$l-8}] [expr {$l-1}]] %x dl
        scan [string range $data 0 [expr {$l-9}]] %x dh
    } else {
        scan $data %x dl
        set dh 0
    }
    set op [format %02X [expr $dl & 0x03]]
    set d [format %08X [expr ($dh << 30) | ($dl >> 2)]]
    set a [format %02X [expr ($dh >> 2)]]
    return "0x$a 0x$d 0x$op"
}

proc jtagd_reset_board {} {
    variable jseq
    set done 0
    while { $done == 0 } {
        $jseq irshift -state IDLE -hex 6 22
        $jseq drshift -state IDLE -capture -hex 32 01000000
        set result [jtagd_reorder [$jseq run]]
        $jseq clear

        if { $result == "00000001" } {
            set done 1
            #puts "Reset Board."
        }
    }

    set done 0
    while { $done == 0 } {
        $jseq irshift -state IDLE -hex 6 22
        $jseq drshift -state IDLE -capture -tdi 0 32
        set result [jtagd_reorder [$jseq run]]
        $jseq clear

        if { $result == "00000002" } {
            set done 1
            #puts "Reset Done."
        }
    }
}

#Initialize JTAG connection before dtmxsdb.cc start htif server
proc jtagd_dmi_init {} {
    variable jseq
    jtagd_reset_board
    $jseq state RESET
    $jseq irshift -state IDLE -hex 6 23
    $jseq run
    $jseq clear
}


# For dtmxsdb.cc request interface
proc jtagd_dmi_req {addr data opcode} {
    set dmi_txd [ dmi_cmd $addr $data $opcode ]
    #puts "dmi-tx: [ dmi_cmd_analyze $dmi_txd ] " ; #uncomment puts command for debug req packet
    return [ dmi_cmd_analyze [ jtagd_tx $dmi_txd ] ]
}

# For dtmxsdb.cc responese interface
proc jtagd_dmi_resp {} {
    set dmi_rxd [ jtagd_rx ]
    #puts "dmi-rx: [ dmi_cmd_analyze $dmi_rxd ]" ; #uncomment puts command for debug resp packet
    return [ dmi_cmd_analyze $dmi_rxd ]
}
