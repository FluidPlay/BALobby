Replay = {}

local lg = love.graphics
  
local replayMirror = "http://replays.springfightclub.com/"

local nfs = require "nativefs"

function Replay.fetchLocalReplays()
  Replay.local_demos = {
    filename = {},
    date = {},
    time = {},
    mapName = {},
    version = {},
    ext = {}
  }
  for i, file in pairs(nfs.getDirectoryItems(lobby.replayFolder)) do
    if file:find("103.sdfz") then
      local date, time, map, version, ext = file:match("(%d+)_(%d+)_(.+)_(%d+).(.+)")
      table.insert(Replay.local_demos.filename, file)
      table.insert(Replay.local_demos.date, date)
      table.insert(Replay.local_demos.time, time)
      table.insert(Replay.local_demos.mapName, map)
      table.insert(Replay.local_demos.version, version)
      table.insert(Replay.local_demos.ext, ext)
    end
  end
  print("local replays:", #Replay.local_demos.date)
  Replay.initialize()
end

function Replay.initialize()
  lobby.replayTabs = {}
  local i = #Replay.local_demos.date
  local y = 90
  local x = 0
  local xmin = 0
  local ymin = - 10
  local ymax = lobby.fixturePoint[1].y
  local xmax = lobby.fixturePoint[2].x
  local cols = math.floor((xmax - xmin) / 610)
  local w = (xmax - xmin) / cols
  local c = 1
  while y < ymax do
    ReplayTab:new(
    Replay.local_demos.filename[i],
    Replay.local_demos.date[i],
    Replay.local_demos.time[i],
    Replay.local_demos.mapName[i],
    Replay.local_demos.version[i])
        :setDimensions(w - 16, 25)
        :setPosition(x+8, y+5)
    i = i - 1
    x = x + w
    c = c + 1
    if c > cols then
      c = 1
      x = xmin
      y = y + 35
    end
  end
end

function Replay.fetchOnlineReplays()
  Replay.uploaded_list = {
    link = {},
    name = {},
    map = {}
  }
  local http = require "socket.http"

  local data, err = http.request(replayMirror)
  
  print("fetchReplayList", err)
  
  for line in data:gmatch("[^\n]+") do
    local link, name = line:match("alt=\"%[   %]\"> <a href=\"(.+)\">(.+)</a>")
    if link and name then
      table.insert(Replay.uploaded_list.link, link)
      table.insert(Replay.uploaded_list.name, name)
      if map then
        table.insert(Replay.uploaded_list.map, map)
      else
        table.insert(Replay.uploaded_list.map, false)
      end
    end
  end
  print("replays:", #Replay.uploaded_list.link)
  Replay.init()
end

--[[function Replay.init()
  lobby.replayTabs = {}
  local i = 1
  local y = 90
  local x = 0
  local xmin = 0
  local ymin = - 10
  local ymax = lobby.fixturePoint[1].y
  local xmax = lobby.fixturePoint[2].x
  local cols = math.floor((xmax - xmin) / 610)
  local w = (xmax - xmin) / cols
  local c = 1
  while y < ymax do
    
  --lobby.replayTabs[ReplayTab:new(Replay.uploaded_list.link[i], Replay.uploaded_list.name[i], Replay.uploaded_list.map[i])
    ReplayTab:new(Replay.uploaded_list.name[i], Replay.uploaded_list.map[i])
    :setDimensions(w - 16, 100)
    :setPosition(x+8, y+5)
    i = i + 1
    x = x + w
    c = c + 1
    if c > cols then
      c = 1
      x = xmin
      y = y + 110
    end
   end
end]]

local month = {
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec'
}

local launchCode = [[
  local exec = ...
  io.popen(exec)
  love.window.restore( )
]]

ReplayTab = Button:new()
ReplayTab.mt = {__index = ReplayTab}
ReplayTab.s = {}
function ReplayTab:new(filename, date, time, mapName, version)
  local new = Button:new()
  setmetatable(new, ReplayTab.mt)
  
  new.colors = {
    background = {
      default = colors.bb,
      highlight = colors.bd
    }   
  }

  new.filename = filename
  
  new.date = date
  new.time = time
  new.mapName = mapName
  new.version = version
  
  new.year = date:match("(%d%d%d%d)%d%d%d%d")
  new.month = date:match("%d%d%d%d(%d%d)%d%d")
  new.day = date:match("%d%d%d%d%d%d(%d%d)")
  
  new.dateStr = new.day .. " " .. month[tonumber(new.month)] .. ", " .. new.year
  
  new.highlighted = false
  
  new.func = function()
    --new:startDownload()
    local exec = "\"" .. lobby.exeFilePath .. " " .. lobby.replayFolder .. filename .. "\""
    print(exec)
    if not lobby.springThread then
      lobby.springThread = love.thread.newThread( launchCode )
    end
    love.window.minimize( )
    lobby.springThread:start( exec )
  end
 
  self.s[new] = true
  lobby.clickables[new] = true
  return new
end

function ReplayTab:clean()
  for RT in pairs(self.s) do
    lobby.clickables[RT] = nil
    self.s[RT] = nil
  end
end

function ReplayTab:isOver(x,y)
  if x > self.x and x < self.x + self.w and y > self.y and y < self.y + self.h then
    lobby.ReplayTabHover = self
    lobby.ReplayTabHoverTimer = 0.5
    self.highlighted = true
    return true
  end
  self.highlighted = false
  return false
end

function ReplayTab:draw()
  local y = self.y
  local x = self.x
  local w = self.w
  local h = self.h
  lg.setFont(fonts.latosmall) 
  local fontHeight = fonts.latosmall:getHeight()
  if self.highlighted then
    lg.setColor(self.colors.background.highlight)
  else
    lg.setColor(self.colors.background.default) 
  end
  lg.rectangle("fill", x, y, w, h)
  
  -- BATTLE TITLE
  lg.setColor(colors.text)
  lg.printf(self.mapName, x + h + 10, y+5, w, "left")
  lg.printf(self.dateStr, x + h + 10, y+5, w-40, "right")
  
  -- IMAGES
  lg.setColor(colors.bd)
  lg.rectangle("fill", x, y, h, h)
  lg.setFont(fonts.latosmall)
  lg.setColor(1,1,1)
  if self.minimap then
    local modx = math.min(1, battle.mapWidthHeightRatio)
    local mody = math.min(1, 1/battle.mapWidthHeightRatio)
    lg.draw(self.minimap, x - (modx-1)*h/2, y - (mody-1)*h/2, 0,modx*h/(2*1024), mody*h/(2*1024))
  else
    lg.draw(img["nomap"], x, y, 0, 1/2, 1/2)
  end 
end

function ReplayTab:startDownload()
  if self.download then return end
  self.download = Download:new()
  self.download:push(replayMirror .. self.link, self.title, love.filesystem.getSaveDirectory() .. "/replays")
end

function ReplayTab:updateDownload(dt)
  local progress_update = self.progress_channel:pop()
  while progress_update do
    if progress_update.finished then
      
    end
    if progress_update.file_size then
      
      login.dl_status.file_size = progress_update.file_size
      
    end
    if progress_update.chunk then
      
      login.dl_status.downloaded = login.dl_status.downloaded + progress_update.chunk
      
    end
    if progress_update.error then
      
      login.dl_status.err = progress_update.error
      
    end
    progress_update = progress_channel:pop()
  end
end