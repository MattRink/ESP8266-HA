
-- This file was originally based upon the below but it has been modified considerably since...
-- Title   : DHT11 Webserver
-- Author  : Claus Kuehnel
-- Date    : 2015-06-06
-- Id      : dht11_webserver.lua
-- Firmware: nodemcu_float_0.9.6-dev_20150406
-- Copyright © 2015 Claus Kuehnel info[at]ckuehnel.ch

-- TODO: Query string support, return JSON format results

PIN = 4 -- data pin of DHT11
LED = 8 -- D8

gpio.mode(LED, gpio.OUTPUT)

function readDHT()
  DHT = require("dht")
  local result = 0
  status, temp, humi, temp_dec, humi_dec = dht.read(PIN)
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

  return result
end

-- LUA Webserver --
srv = net.createServer(net.TCP)
srv:listen(80, function(conn)
  conn:on("receive",function(sck, req)
    local response = {}
    local status_code = ""
    local _, _, method, path, vars = string.find(req, "([A-Z]+) (.+)?(.+) HTTP")
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
    reply_template = string.gsub(reply_template, "%[!HEADER!%]", "ESP8266-HA")

    local reply_content = ""

    if method == "GET"and path == "/" then
      status_code = "200 OK"
      if readDHT() == 1 then -- Only return if the DHT is available
        reply_content = "<p>Temperature: "..temp.." deg C<br />Humidity: "..humi.."%%</p>"
      end
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
