-- Title   : DHT11 Webserver
-- Author  : Claus Kuehnel
-- Date    : 2015-06-06
-- Id      : dht11_webserver.lua
-- Firmware: nodemcu_float_0.9.6-dev_20150406
-- Copyright © 2015 Claus Kuehnel info[at]ckuehnel.ch

PIN = 4 -- data pin of DHT11
LED = 8 -- D8

gpio.mode(LED, gpio.OUTPUT)

function readDHT()
  DHT = require("dht")
  status, temp, humi, temp_dec, humi_dec = dht.read(PIN)
  if status == dht.OK then
    gpio.write(LED,gpio.LOW)
    error = 0
    print("Temperature: "..temp.." deg C\tHumidity: "..humi.."%")
  elseif status == dht.ERROR_CHECKSUM then
    print( "DHT Checksum error." )
  elseif status == dht.ERROR_TIMEOUT then
    print( "DHT timed out." )
  else
    error = 1
    print("Error reading from DHT")
  end
  gpio.write(LED,gpio.HIGH)
  DHT = nil
end

-- LUA Webserver --
srv = net.createServer(net.TCP)
srv:listen(80, function(conn)
  conn:on("receive",function(sck, req)
    local response = {}
    local status_code = ""

    print("\nGot query...")
    print("Heap = "..node.heap().." Bytes")
    print("Time since start = "..tmr.time().." sec")

    local reply_template = "Unable to find template.html"
    if file.open("template.html") then
      reply_template = file.read()
      file.close()
    end

    reply_template = string.gsub(reply_template, "%[!TITLE!%]", "ESP8266 Webserver")
    reply_template = string.gsub(reply_template, "%[!HEADER!%]", "ESP8266 Webserver")

    local reply_content = ""

    -- GET /DHT HTTP/1.1 --
    command = string.sub(req, 6,8) -- Get characters 6 to 8
    print("URL:"..command)
    if (command == "DHT") then
      readDHT()
      status_code = "200 OK"
      reply_content = "<p>Temperature: "..temp.." deg C<br />Humidity: "..humi.."%%</p>"
    else
      status_code = "404 Not Found"
      reply_content = "<p>Page not found</p>"
    end

    reply_template = string.gsub(reply_template, "%[!CONTENT!%]", reply_content)

    payload_len = string.len(reply_template)
    print("Response length:"..tostring(payload_len))

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
