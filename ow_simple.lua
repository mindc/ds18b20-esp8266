local ow_simple = {
    fetch = function ( callback )
        ow.reset_search( OW_PIN )    
        local addrs = {}
        repeat
            local addr = ow.search( OW_PIN )
            if addr then
                table.insert( addrs, addr)
            end
        until addr == nil

        ow.reset( OW_PIN )
        ow.skip( OW_PIN )
        ow.write( OW_PIN, 0x44, 1)

        tmr.alarm( 3, 750, 0, function()
            result = {}
            for i,addr in ipairs(addrs) do
                ow.reset( OW_PIN )
                ow.select( OW_PIN, addr )
                ow.write( OW_PIN, 0xBE, 1 )
                local data = nil
                data = string.char(ow.read( OW_PIN ))
                for i = 1, 8 do
                    data = data .. string.char(ow.read( OW_PIN ))
                end 
                local romcode = string.format("%02X%02X%02X%02X%02X%02X%02X%02X",addr:byte(1,9))
                crc = ow.crc8(string.sub(data,1,8))
                if crc == data:byte(9) then
    			    t = (data:byte(1) + data:byte(2) * 256) * 625
                    t1 = t / 10000
                    if t1 > 4032 then t1 = t1 - 4096 end
                    table.insert( result, { romcode = romcode, temp = t1 } )
                else
                    table.insert( result, { romcode = romcode, temp = nil } )
                end
            end
            callback( result )
        end)
    end
}

return ow_simple
