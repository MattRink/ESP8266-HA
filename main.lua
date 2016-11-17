
-- TODO: Return JSON format results

DHT_PIN = 4 -- data pin of DHT11
LED = 8 -- D8
APS = {}

gpio.mode(LED, gpio.OUTPUT)

function updateAPs()
  print("Getting list of APs")

  wifi.sta.getap({["show_hidden"] = 1}, 1, function (t) 
    for k, v in pairs(APS) do
      APS[k] = nil
    end

    for k, v in pairs(t) do
      APS[k] = v
    end
  end)
end

function readDHT()
  DHT = require("dht")
  local result = 0
  local status, temp, humi, temp_dec, humi_dec = dht.read(DHT_PIN)
  if status == dht.OK then
    gpio.write(LED, gpio.LOW)
    result = 1
    print("Temperature: "..temp.." deg C\tHumidity: "..humi.."%")
  elseif status == dht.ERROR_CHECKSUM then
    print( "DHT Checksum error." )
    result = -1
  elseif status == dht.ERROR_TIMEOUT then
    print( "DHT timed out." )
    result = -2
  else
    print("Error reading from DHT")
    result = -3
  end
  gpio.write(LED, gpio.HIGH)
  DHT = nil

  return result, temp, humi
end

srv = net.createServer(net.TCP, 60)
srv:listen(80, function(conn)
  conn:on("receive", function(sck, req)
    local response = {}
    local status_code = ""

    if req == nil then
      print("No request")
      return
    end

    local _, method, path, vars 
    _, _, method, path, vars = string.find(req, "([A-Z]+) (.+)?(.+) HTTP")

    if method == nil then
      _, _, method, path = string.find(req, "([A-Z]+) (.+) HTTP")
    end

    local _GET = {}
    if vars ~= nil then
      for k, v in string.gmatch(vars, "(%w+)=(%w+)&*") do
        _GET[k] = v
      end
    end

    print("\nMethod:"..method..";path:"..path..";vars:"..(vars or ""))
    print("Heap = "..node.heap().." Bytes")
    print("Time since start = "..tmr.time().." sec")

    local reply_template = "Unable to find template.html"
    if file.open("template.html") then
      reply_template = file.read()
      file.close()
    end

    reply_template = string.gsub(reply_template, "%[!TITLE!%]", "ESP8266-HA")

    local reply_content = ""

    if method == "GET"and path == "/" then
      status_code = "200 OK"
      local dht_content = ""
      local config_content = ""
      local result, temp, humi = readDHT()
      if result == 1 then -- Only return if the DHT is available
        if file.open("dht.inc") then
          dht_content = file.read()
          file.close()
        end
        dht_content = string.gsub(dht_content, "%[!TEMP!%]", tostring(temp))
        dht_content = string.gsub(dht_content, "%[!HUMI!%]", tostring(humi))
        reply_content = reply_content..dht_content
      end
    elseif method == "GET" and path == "/config" then
      local wifi_rows = ""
      if file.open("config.inc") then
        config_content = file.read()
        file.close()
      end
      for bssid,v in pairs(APS) do
        print(bssid..": "..v)
        local ssid, rssi, authmode, channel
        ssid, rssi, authmode, channel = string.match(v, "([^,]+),([^,]+),([^,]+),([^,]*)")

        if (ssid == nil) then
          ssid = "&lt;Unknown SSID&gt;"
          rssi, authmode, channel = string.match(v, ",([^,]+),([^,]+),([^,]*)")
        end

        local auth_string = ""
        if authmode == "0" then auth_string = "Open"
        elseif authmode == "1" then auth_string = "WEP"
        elseif authmode == "2" then auth_string = "WPA PSK"
        elseif authmode == "3" then auth_string = "WPA2 PSK"
        elseif authmode == "4" then auth_string = "WPA+WPA2 PSK"
        else auth_string = "Unknown" end

        wifi_rows = wifi_rows.."<tr><td><input type=\"radio\" name=\"bssid\" value=\""..bssid.."\"></td><td>"..string.format("%32s",bssid).."</td><td>"..ssid.."</td><td>"..rssi.."</td><td>"..auth_string.."</td><td>"..channel.."</td></tr>"
      end
      config_content = string.gsub(config_content, "%[!APS!%]", wifi_rows)
      reply_content = reply_content..config_content
    else
      status_code = "404 Not Found"
      reply_content = "<p>Page not found</p>"
    end

    reply_template = string.gsub(reply_template, "%[!INCLUDE!%]", reply_content)

    payload_len = string.len(reply_template)
    print("Response length: "..tostring(payload_len))

    response[#response]     = "HTTP/1.1 "..status_code.."\r\nContent-Length: "..tostring(payload_len).."\r\nContent-Type: text/html\r\n\r\n"
    response[#response + 1] = reply_template;

    local function send(sk)
      if #response > 0 then
        sk:send(table.remove(response, 1))
      else
        sk:close()
        response = nil
      end
    end
    
    sck:on("sent", send)
    send(sck)

    collectgarbage()
  end)
  
end)

tmr.alarm(0, 60000, tmr.ALARM_AUTO, function() updateAPs() end)
updateAPs()