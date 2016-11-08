--load credentials
--SID and PassWord should be saved according wireless router in use
dofile("credentials.lua")

function startup()
    if file.open("init.lua") == nil then
      print("init.lua deleted")
    else
      print("Running")
      file.close("init.lua")
      dofile("main.lua")
    end
end

wifi.sta.disconnect()

print("Set up wifi mode")
wifi.setmode(wifi.STATION)
wifi.sta.config(SSID,PASSWORD,0)
wifi.sta.connect()
tmr.alarm(1, 1000, 1, function() 
    if wifi.sta.getip()== nil then 
        print("IP unavailable, Waiting...") 
    else 
        tmr.stop(1)
        print("Config done, IP is "..wifi.sta.getip())
        print("You have 5 seconds to abort startup")
        print("Waiting...")
        tmr.alarm(0, 5000, 0, startup)
    end 
 end)
