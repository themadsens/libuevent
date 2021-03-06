#!/usr/bin/env lua
--/usr/bin/env luajit
---
-- @file
-- Micro event library libuevent.
-- Test & showcase of libuevent
--
-- (C) Copyright 2012 flemming.madsen at madsensoft.dk. See libuevent.h
---
require "socket"
require "luevent"

local ADDR = "127.0.0.1"
local PORT = 42555
local timer
local period
local appTimer, readHdl, writeTimer

local function timeOut()
   print("Timeout is exceeded")
   appTimer:clear()
   readHdl:clear()
   writeTimer:clear()
   luevent.terminate()
end

local function writeThread(sck, cnt)
   sck:send(("TESTING"):sub(1, cnt))
   period = cnt + 5
   writeTimer = luevent.addTimer(100 * period, function() writeThread(sck, cnt + 1) end)
end

local function main()
   appTimer = luevent.addTimer(5000, function()
      print("Lifetime is exceeded")
      os.exit(1);
   end)

   local isrv = assert(socket.bind(ADDR, PORT))
   luevent.addFileIO(isrv:getfd(), function(self)
      local isock = isrv:accept()
      isock:settimeout(0)
      readHdl = luevent.addFileIO(isock:getfd(), function(self)
         -- Pipe readable
         if timer then
            timer:clear()
            timer = luevent.addTimer(950, timeOut)
         end
         local str, err, prt = isock:receive(50)
         if not str and err == "timeout" then str = prt end
         io.write(str.."."..#str.." ") io.flush()
      end)

      self:clear() -- This is a oneshot
   end)
   timer = luevent.addTimer(950, timeOut)

   local osck = socket.tcp() osck:settimeout(0) osck:connect(ADDR, PORT)
   luevent.addFileIO(osck:getfd(), function(self)
      writeThread(osck, 1) 
      self:clear() -- This is a oneshot
   end, "w")

   luevent.run()
   print "DONE"
   -- Only index '1' should be there now
   for k,v in pairs(luevent._lue_objects) do print(k,v) end

   package.loaded.luevent = nil
   collectgarbage("collect")
   print(("Period is %d must be 10: %s"):format(period, 10 == period and "OK" or "ERROR!"))
   os.exit(period == 10 and 0 or 1)
end

main()
-- vim: set sw=3 sts=3 et nu:
