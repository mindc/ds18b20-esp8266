--[[
    Please create config.lua file with following parameters:
    WIFI_SSID = "ap-ssid"
    WIFI_PASS = "ap-password"
    PUSH_URL = "http://example.com/push.php"
]]
dofile("config.lua")

OW_PIN = 7
ow.setup( OW_PIN )

local function ow_search()
    ow.reset_search( OW_PIN )    
    local addrs = {}
    repeat
        local addr = ow.search( OW_PIN )
        if addr then
            table.insert( addrs, addr)
        end
    until addr == nil
    return addrs
end
  
local function fetch_data()    
    local addrs = ow_search()

    ow.reset( OW_PIN )
    ow.skip( OW_PIN )
    ow.write( OW_PIN, 0x44, 1)

    tmr.alarm( 3, 750, 0, function()
        result = {}
        for i,addr in ipairs(addrs) do
            ow.reset( OW_PIN )
            ow.select( OW_PIN, addr )
            ow.write( OW_PIN, 0xBE, 1 )
            data = nil
            data = string.char(ow.read( OW_PIN ))
            for i = 1, 8 do
                data = data .. string.char(ow.read( OW_PIN ))
            end 
            local romcode = string.format("%02X%02X%02X%02X%02X%02X%02X%02X",addr:byte(1,9))
            crc = ow.crc8(string.sub(data,1,8))
            if crc == data:byte(9) then
    			t = (data:byte(1) + data:byte(2) * 256) * 625
                t1 = t / 10000
                if t1 > 4032 then
                    t1 = t1 - 4096
                end
                print(string.format("%s => %4.1f", romcode, t1))
                table.insert( result, { romcode = romcode, temp = t1 } )
            else
                table.insert( result, { romcode = romcode, temp = nil } )
            end
        end

        local response = '{"jsonrpc":"2.0","id":' .. node.flashid() .. ',"method":"ESP8266.push","params":{"vbatt":' .. adc.readvdd33()/1000 .. ',"timestamp":' .. rtctime.get() .. ',"sensors":['
        if table.getn( result ) > 0 then
            for idx, sensor in ipairs( result ) do
                if idx > 1 then response = response .. ',' end
                local t = sensor.temp
                if t == nil then
                    t = 'null'
                end
                response = response .. '{"romcode":"' .. sensor.romcode .. '","temp":'.. t .. '}'
            end
        end
        response = response .. ']}}'    
        print( response )
        http.post( PUSH_URL, 'Origin: zeus.mindc.net\r\nContent-Type: application/json\r\n', response, function( code, data )
            print(code, data)
        end)
        print("heap: " .. node.heap() )
    
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
--[[
    if T.reason == wifi.eventmon.reason.NO_AP_FOUND then
        tmr.alarm(1, 5*1000, 0, function()
            print ( "reconnecting ..." )
            -- wifi.sta.connect()
        end)
    end
]]--        
    
end)

wifi.eventmon.register( wifi.eventmon.STA_DHCP_TIMEOUT, function()
    print("dhcp timeout")
    drawClean(function()
        disp:drawStr( 20, 22, "DHCP TIMEOUT" )
    end)
end)

wifi.eventmon.register( wifi.eventmon.STA_GOT_IP, function( T ) 
    print("ipaddr: " .. T.IP)
    drawClean(function()
        disp:drawStr( 20, 22, "NET CONNECTED" )
        disp:drawStr( 20, 33, wifi.sta.getip() )
        disp:drawStr( 20, 44, wifi.sta.getrssi() .. " dbi" )        
    end)
    print("get ntp ...")
    sntp.sync('tempus1.gum.gov.pl', function(sec,usec,server)
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

wifi.sta.config( WIFI_SSID, WIFI_PASS, 1 )
