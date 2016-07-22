local ow_simple = require 'ow_simple'

function readJSON( filename )
    local json = require "cjson"
    file.open( filename ,"r")
    local content = file.read()
    local data = json.decode( content )
    file.close()    
    return data
end

OW_PIN = 7
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

tmr.alarm(2, 1000, 1, function()
    local sec, usec = rtctime.get()
    drawClean(function()
        local lines = 0
        disp:setScale2x2()
        for idx,value in ipairs(result) do
            disp:drawStr(0, 11 * lines, string.format("T%d %5.1f%sC", idx, value.temp, string.char(176) ) )
            lines = lines + 1
        end
        disp:undoScale()
        disp:drawStr( 0, 11 * 2*lines, 'TIMESTAMP: ' .. sec )
        disp:drawStr( 0, 11 * 2*lines + 11, 'VBATT: ' .. adc.readvdd33() / 1000 .. 'V' )        
    end)
end)

tmr.stop(2)

wifi.setmode(wifi.STATION)

wifi.eventmon.register(wifi.eventmon.STA_CONNECTED, function( T )
    print( "connected: " .. T.SSID )

    drawClean(function()
        disp:drawStr( 20, 22, "WIFI CONNECTED" )
        disp:drawStr( 20, 33, T.SSID )
    end)

    if not tmr.state(2) == nil then
        tmr.start(2)
    end
end)

wifi.eventmon.register( wifi.eventmon.STA_DISCONNECTED, function( T )
    tmr.stop(0)
    tmr.stop(2)
    print( "disconnected: " .. T.SSID )
    drawClean(function()
        disp:drawStr( 20, 22, "WIFI DISCONNECTED" )
        disp:drawStr( 20, 33, T.reason )
    end)
end)

wifi.eventmon.register( wifi.eventmon.STA_DHCP_TIMEOUT, function()
    print("dhcp timeout")
    drawClean(function()
        disp:drawStr( 20, 22, "DHCP TIMEOUT" )
    end)
    node.restart()
end)

wifi.eventmon.register( wifi.eventmon.STA_GOT_IP, function( T ) 
    print("ipaddr: " .. T.IP)
    drawClean(function()
        disp:drawStr( 20, 22, "NET CONNECTED" )
        disp:drawStr( 20, 33, wifi.sta.getip() )
        disp:drawStr( 20, 44, wifi.sta.getrssi() .. " dbi" )        
    end)
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
