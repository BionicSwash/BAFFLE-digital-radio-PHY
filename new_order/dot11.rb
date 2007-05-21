$: << "."
require 'packet'

class Dot11 < Packet
  name        "802.11" # For pretty printing
  
  unsigned    :subtype,   4,  'Subtype'
  enum        :type,      2,  'Type',       :spec => ['Management', 'Control', 'Data', 'Reserved']
  unsigned    :proto,     2,  'Protocol'
  flags       :fc,        8,  'Frame Control', :spec => ['to-DS', 'from-DS', 'MF', 'retry', 'pw-mgt', 'MD', 'wep', 'order']
  unsigned    :id,        16, 'ID'
  hex_octets  :addr1,     48, 'Address 1'
  hex_octets  :addr2,     48, 'Address 2',  :applicable => proc {|instance| if instance.type == 1 then [0x0B, 0x0A, 0x0E, 0x0F].include?(instance.subtype) else true end}
  hex_octets  :addr3,     48, 'Address 3',  :applicable => proc {|instance| [0, 2].include?(instance.type)}
  unsigned    :sc,        16, 'SC',         :endian => :little, :applicable => proc {|instance| instance.type != 1}
  hex_octets  :addr4,     48, 'Address 4',  :applicable => proc {|instance| instance.type == 2 && (instance.fc & 0x3 == 0x3)}
  nest        :frame,    nil, 'Payload',    :nested_class => proc {|instance|
    #puts "instance.fc = #{instance.fc.inspect}"
    if instance.fc & 0x40 == 0x40
      Dot11WEP
    elsif instance.type == 0
      [Dot11AssoReq, Dot11AssoResp, Dot11ReassoReq, Dot11ReassoResp, Dot11ProbeReq, Dot11ProbeResp, nil, nil,
       Dot11Beacon, Dot11ATIM, Dot11Disas, Dot11Auth, Dot11Deauth, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil][instance.subtype]
    end
  }
end

$capability_list = [ "res8", "res9", "short-slot", "res11",
                     "res12", "DSSS-OFDM", "res14", "res15",
                     "ESS", "IBSS", "CFP", "CFP-req",
                     "privacy", "short-preamble", "PBCC", "agility"]

$reason_code = {0 => "reserved",1 => "unspec", 2 => "auth-expired",
                3 => "deauth-ST-leaving",
                4 => "inactivity", 5 => "AP-full", 6 => "class2-from-nonauth",
                7 => "class3-from-nonass", 8 => "disas-ST-leaving",
                9 => "ST-not-auth"}

$status_code = {0 => "success", 1 => "failure", 10 => "cannot-support-all-cap",
                11 => "inexist-asso", 12 => "asso-denied", 13 => "algo-unsupported",
                14 => "bad-seq-num", 15 => "challenge-failure",
                16 => "timeout", 17 => "AP-full",18 => "rate-unsupported" }

class Dot11Elt < Packet
  name        "802.11 Information Element"
  
  enum        :id,          8, "ID", :spec => {0 => "SSID", 1 => "Rates", 2 =>  "FHset", 3 => "DSset", 4 => "CFset", 5 => "TIM", 6 => "IBSSset", 16 => "challenge", 42 => "ERPinfo", 47 => "ERPinfo", 48 => "RSNinfo", 50 => "ESRates",221 => "vendor",68 => "reserved"}
  unsigned    :info_length, 8, "Information Length", :default => 0
  char        :info,        proc { |instance| instance.info_length * 8 }, "Information"
  nest        :elt,       nil, "Nested", :nested_class => Dot11Elt
end

class Dot11Beacon < Packet
  name        "802.11 Beacon"
  
  unsigned    :timestamp,         64,   "Timestamp", :endian => :little
  unsigned    :beacon_interval,   16,   "Beacon Interval", :endian => :little, :default => 0x0064
  flags       :capabilities,      16,   "Capabilities", :spec => $capability_list
  nest        :elt,              nil,   "Nested ELT", :nested_class => Dot11Elt
end

class Dot11ATIM < Packet
  name        "802.11 ATIM"
end

class Dot11Disas < Packet
  name        "802.11 Disassociation"
  
  enum        :reason, 16, "Reason", :endian => :little, :spec => $reason_code
end

class Dot11AssoReq < Packet
  name        "802.11 Association Request"
  
  flags       :capabilities, 16, "Capabilities", :spec => $capability_list
  unsigned    :listen_interval, 16, "Listen Interval", :endian => :little, :default => 0x00C8
  nest        :elt,       nil, "Nested", :nested_class => Dot11Elt
end


class Dot11AssoResp < Packet
  name        "802.11 Association Response"
  
  flags       :capabilities, 16, "Capabilities", :spec => $capability_list
  unsigned    :status, 16, "Status", :endian => :little
  unsigned    :aid, 16, :endian => :little
  nest        :elt,       nil, "Nested", :nested_class => Dot11Elt
end

class Dot11ReassoReq < Packet
  name        "802.11 Reassociation Request"

  flags       :capabilities, 16, "Capabilities", :spec => $capability_list
  hex_octets  :current_ap, 48, "Current AP" # ETHER_ANY?? check scapy.py
  unsigned    :listen_interval, 16, "Listen Interval", :endian => :little, :default => 0x00C8
  nest        :elt,       nil, "Nested", :nested_class => Dot11Elt
end


class Dot11ReassoResp < Dot11AssoResp
  name        "802.11 Reassociation Response"
  nest        :elt,       nil, "Nested", :nested_class => Dot11Elt
end

class Dot11ProbeReq < Packet
  name        "802.11 Probe Request"
  nest        :elt,       nil, "Nested", :nested_class => Dot11Elt
end
    
class Dot11ProbeResp < Packet
  name        "802.11 Probe Response"
  
  unsigned    :timestamp, 64, "Timestamp", :endian => :little
  unsigned    :beacon_interval, 16, "Beacon Interval", :endian => :little, :default => 0x0064 # I think that default is what scapy means... should check it, but not really important
  flags       :capabilities, 16, "Capabilities", :spec => $capability_list # Defined above
  nest        :elt,       nil, "Nested", :nested_class => Dot11Elt
end
    
class Dot11Auth < Packet
  name        "802.11 Authentication"
  
  enum        :algo, 16, "Algorithm", :endian => :little, :spec => ["open", "sharedkey"]
  unsigned    :seqnum, 16, "Sequence Number", :endian => :little
  enum        :status, 16, "Status Code", :endian => :little, :spec => $status_code
  nest        :elt,       nil, "Nested", :nested_class => Dot11Elt
end

class Dot11Deauth < Packet
  name        "802.11 Deauthentication"
  
  enum        :reason, 16, "Reason", :endian => :little, :spec => $reason_code
end

class Dot11WEP < Packet
  name        "802.11 WEP packet"
    
  char        :iv, 24, "Initialization Vector"
  unsigned    :keyid, 8, "Key ID"
  text        :wepdata, "WEP Data" # Check scapy.py
  unsigned    :icv, 32, "ICV"
  
  # Do WEP-specific magic here
end

class PrismHeader < Packet
  name        "Prism header"
  
=begin 
  ugh convert me
  
  LEIntField("msgcode",68),
                    LEIntField("len",144),
                    StrFixedLenField("dev","",16),
                    LEIntField("hosttime_did",0),
                  LEShortField("hosttime_status",0),
                  LEShortField("hosttime_len",0),
                    LEIntField("hosttime",0),
                    LEIntField("mactime_did",0),
                  LEShortField("mactime_status",0),
                  LEShortField("mactime_len",0),
                    LEIntField("mactime",0),
                    LEIntField("channel_did",0),
                  LEShortField("channel_status",0),
                  LEShortField("channel_len",0),
                    LEIntField("channel",0),
                    LEIntField("rssi_did",0),
                  LEShortField("rssi_status",0),
                  LEShortField("rssi_len",0),
                    LEIntField("rssi",0),
                    LEIntField("sq_did",0),
                  LEShortField("sq_status",0),
                  LEShortField("sq_len",0),
                    LEIntField("sq",0),
                    LEIntField("signal_did",0),
                  LEShortField("signal_status",0),
                  LEShortField("signal_len",0),
              LESignedIntField("signal",0),
                    LEIntField("noise_did",0),
                  LEShortField("noise_status",0),
                  LEShortField("noise_len",0),
                    LEIntField("noise",0),
                    LEIntField("rate_did",0),
                  LEShortField("rate_status",0),
                  LEShortField("rate_len",0),
                    LEIntField("rate",0),
                    LEIntField("istx_did",0),
                  LEShortField("istx_status",0),
                  LEShortField("istx_len",0),
                    LEIntField("istx",0),
                    LEIntField("frmlen_did",0),
                  LEShortField("frmlen_status",0),
                  LEShortField("frmlen_len",0),
                    LEIntField("frmlen",0),
                    ]
=end                    
end