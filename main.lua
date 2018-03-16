local ow_simple = require 'ow_simple'

function readJSON( filename )
    local json = require "cjson"
    file.open( filename ,"r")
    local content = file.read()
    local data = json.decode( content )
    file.close()    
    return data
end

OW_PIN = 4
ow.setup( OW_PIN )

local jsonrpc_conf = readJSON( 'jsonrpc.conf.json' )

local function fetch_data()    
    ow_simple.fetch( function( result )
        local request = '{'
        request = request .. '"jsonrpc":"2.0","id":' .. tmr.now() .. ',"method":"' .. jsonrpc_conf.method .. '","params":{'
        request = request .. '"vdd":' .. adc.readvdd33()/1000 .. ',"timestamp":' .. rtctime.get() .. ','
        request = request .. '"ipaddr":"' .. wifi.sta.getip() .. '","rssi":' .. wifi.sta.getrssi() .. ','
        request = request .. '"sensors":['

        if table.getn( result ) > 0 then
            for idx, sensor in ipairs( result ) do
                if idx > 1 then request = request .. ',' end
                local t = sensor.temp
                if t == nil then
                    t = 'null'
                end
                request = request .. '{"romcode":"' .. sensor.romcode .. '","temp":'.. t .. '}'
            end
        end
        request = request .. ']}}'    
        print( request )
        http.post( jsonrpc_conf.url, jsonrpc_conf.headers, request, function( code, data )
            print(code, data)
        end)
    end)
end

wifi.setmode(wifi.STATION)

wifi.eventmon.register(wifi.eventmon.STA_CONNECTED, function( T )
    print( "connected: " .. T.SSID )
    if not tmr.state(2) == nil then
        tmr.start(2)
    end
end)

wifi.eventmon.register( wifi.eventmon.STA_DISCONNECTED, function( T )
    tmr.stop(0)
    tmr.stop(2)
    print( "disconnected: " .. T.SSID )
end)

wifi.eventmon.register( wifi.eventmon.STA_DHCP_TIMEOUT, function()
    print("dhcp timeout")
    node.restart()
end)

wifi.eventmon.register( wifi.eventmon.STA_GOT_IP, function( T ) 
    print("ipaddr: " .. T.IP)
    print("get ntp ...")
    sntp.sync( 'tempus1.gum.gov.pl', function( sec, usec, server )
        print("ntp ok: " .. sec )
        tmr.start(2)
        fetch_data()
        tmr.alarm(0, 60*1000, 1, function()
            fetch_data()
        end)
    end,
    function()
        print("ntp failed ...")
        node.restart()
    end)
end)

local wifi_conf = readJSON( 'wifi.conf.json' )
wifi.sta.config( wifi_conf.ssid, wifi_conf.password, 1 )
