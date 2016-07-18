SSID = "SSID"
PASS = "PASS"
DST_URL = "http://example.com/fetch.php"

OW_PIN = 7
ow.setup( OW_PIN )

function search_device()
   addr = ow.search( OW_PIN )
   if addr then
     print(string.format("found: %02X%02X%02X%02X%02X%02X%02X%02X",addr:byte(1,9))) 
     return addr
   else
    return nil
   end    
end

time = 0
   
function get_temp()    
    ow.reset_search( OW_PIN )
    print("searching for sensors ...")

    addrs = {}
    repeat
        addr = search_device()
        if addr then
            table.insert(addrs, addr)
        end
    until addr == nil
    
    for i,addr in ipairs(addrs) do
        ow.reset( OW_PIN )
        ow.select( OW_PIN, addr)
        ow.write( OW_PIN, 0x44, 1)
    end

    tmr.alarm( 3, 750, 0, function()
   
        params = "?"
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
            -- print(string.format("%02X%02X%02X%02X%02X%02X%02X%02X",data:byte(1,9)))
            crc = ow.crc8(string.sub(data,1,8))
            if crc == data:byte(9) then
    			t = (data:byte(1) + data:byte(2) * 256) * 625
                t1 = t / 10000
                params = params .. string.format("serial"..i.."=%02X%02X%02X%02X%02X%02X%02X%02X&temperature"..i.."="..t1.."&",addr:byte(1,9))
                print(string.format("%02X%02X%02X%02X%02X%02X%02X%02X => "..t1,addr:byte(1,9)))
                print(string.format("%4.1f",t1))
                table.insert( result, { name = "T"..i, temp = string.format("%4.1f",t1) } )
            else
                table.insert( result, { name = "T"..i, temp = "ERROR" } )
            end
        end
    
    
    
        if params ~= "?" then
           http.get( DST_URL .. params, nil, function(code, data)
                if code == 200 then
                    time = tonumber( data )
                    print("SEND OK (" .. data .. ")")
                else
                    time = "ERROR"
                    print("SEND ERROR " .. code)
                end
           end)
        end
    
        print("heap: " .. node.heap() )
    
    end)
end

tmr.alarm(2, 1000, 1, function()
    --if not tmr.state(3) then
    drawClean(function()
        lines = 0
        disp:setScale2x2()
        for key,value in ipairs(result) do
            disp:drawStr(0, 11 * lines, string.format("%2s %5s%sC",value.name, value.temp, string.char(176) ) )
            lines = lines + 1
        end
        disp:drawStr( 0, 22, time )
        disp:undoScale()        
        
    end)
    time = time + 1
    --end
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

wifi.eventmon.register(wifi.eventmon.STA_DISCONNECTED, function( T )
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

wifi.eventmon.register(wifi.eventmon.STA_GOT_IP, function( T ) 
    print("ipaddr: " .. T.IP)
    drawClean(function()
        disp:drawStr( 20, 22, "NET CONNECTED" )
        disp:drawStr( 20, 33, wifi.sta.getip() )
        disp:drawStr( 20, 44, wifi.sta.getrssi() .. " dbi" )        
    end)
    tmr.start(2)
    get_temp()
    tmr.alarm(0, 60*1000, 1, function()
        get_temp()
    end)

end)

wifi.sta.config( SSID, PASS, 1 )
