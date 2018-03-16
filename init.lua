adc.force_init_mode(adc.INIT_VDD33)

print("startup delay: 10 sec")
tmr.alarm(0, 10000, 0, function() 
    dofile("main.lua") 
end)
