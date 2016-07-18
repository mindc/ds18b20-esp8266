function init_OLED(sda,scl) --Set up the u8glib lib
    sla = 0x3c
    i2c.setup(0, sda, scl, i2c.SLOW)
    disp = u8g.ssd1306_128x64_i2c(sla)
    disp:setFont(u8g.font_6x10)
    disp:setFontRefHeightExtendedText()
    disp:setDefaultForegroundColor()
    disp:setFontPosTop()
end

function drawClean( T )
    disp:firstPage()
    repeat
        T()
    until disp:nextPage() == false
end    

init_OLED(5,6)

drawClean( function()
    disp:drawStr(50,22,"READY")
end)

print("startup delay: 10 sec")
tmr.alarm(0, 10000, 0, function() 
    dofile("ow.lua") 
end)
