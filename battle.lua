Battle = {}
Battle.mt =  {__index = Battle}
local lg = love.graphics
local lfs = love.filesystem
local nfs = require("lib/nativefs")
local spring = require "spring"

Battle.s = {}

Battle.count = 0

local shader = lg.newShader[[
  vec4 effect(vec4 vcolor, Image tex, vec2 texcoord, vec2 pixcoord)
{
  vec4 texcolor = Texel(tex, texcoord);
  texcolor.rgb = texcolor.grb;
  return texcolor * vcolor;
}
]]

function Battle.initialize()
    Battle.buttons = {
    ["autolaunch"] = Checkbox:new()
    :resetPosition(function() return lobby.fixturePoint[2].x - 90, lobby.fixturePoint[2].y - 65 end)
    :setDimensions(20,20)
    :setText("Auto-start"):setFont(fonts.latobolditalicmedium)
    :setToggleVariable(function() return lobby.launchOnGameStart end)
    :onClick(function() if User.s[lobby.username].spectator then lobby.launchOnGameStart = not lobby.launchOnGameStart end end),
    ["exit"] = BattleButton:new()
    :resetPosition(function() return lobby.fixturePoint[2].x - 255, lobby.fixturePoint[2].y - 35 end)
    :setDimensions(100, 35)
    :setText("Exit Battle")
    :onClick(function() Battle:getActive():leave() end),
    ["ready"] = Checkbox:new()
    :resetPosition(function() return lobby.fixturePoint[2].x - 165 , lobby.fixturePoint[2].y - 65 end)
    :setDimensions(20, 20)
    :setText("Ready"):setFont(fonts.latobolditalicmedium)
    :setToggleVariable(function() return User.s[lobby.username].ready end)
    :onClick(function() if not User.s[lobby.username].spectator then lobby.setReady(not User.s[lobby.username].ready) end end),
    ["spectate"] = Checkbox:new()
    :resetPosition(function() return lobby.fixturePoint[2].x - 255, lobby.fixturePoint[2].y - 65 end)
    :setDimensions(20, 20)
    :setText("Spectate"):setFont(fonts.latobolditalicmedium)
    :setToggleVariable(function() return User.s[lobby.username].spectator end)
    :onClick(function() lobby.setSpectator(not User.s[lobby.username].spectator) end),
    ["launch"] = BattleButton:new()
    :resetPosition(function() return lobby.fixturePoint[2].x - 65, lobby.fixturePoint[2].y - 35 end)
    :setDimensions(70, 35)
    :setText("Start")
    :onClick(function()
      if Battle:getActive().founder.ingame then
        lobby.launchSpring()
      else
        love.window.showMessageBox("For your information", "Game has not yet started.", "info")
      end
    end)
  }
  for _, button in pairs(Battle.buttons) do
    lobby.clickables[button] = false
  end
  
  Battle.showMapScroll = 1
  
  Battle.mapScrollBar = ScrollBar:new():setOffset(0)
  :setRenderFunction(function(y)
        if y > 0 then
          Battle.showMapScroll = math.min(2, Battle.showMapScroll + 1)
        elseif y < 0 then
          Battle.showMapScroll = math.max(0, Battle.showMapScroll - 1)
        end
      end)
  
  Battle.spectatorsScrollBar = ScrollBar:new()
  :setLength(40)
  :setScrollBarLength(10)
  :setOffset(0)
  :setScrollSpeed(fonts.latosmall:getHeight() + 2)
  
  Battle.modoptionsScrollBar = ScrollBar:new()
  :setPosition(lobby.fixturePoint[2].x - 5, (lobby.height-lobby.fixturePoint[2].y)/2 - 20)
  :setLength(40)
  :setScrollBarLength(10)
  :setOffset(0)
  :setScrollSpeed(fonts.latosmall:getHeight())
  
  Battle.showMap = "minimap"
end

function Battle:joined(id)
  if self:mapHandler() and self:modHandler() then
    lobby.user.synced = true
  end

  Channel.active = Channel.s["Battle_" .. id]
  self.display = true
  
  self:getChannel().infoBoxScrollBar:setOffset(0)
end

function Battle:resetButtons()
  for _, button in pairs(self.buttons) do
    button:resetPosition()
  end
end

function Battle:leave()
  for _, button in pairs(Battle.buttons) do
    lobby.clickables[button] = false
  end
  Channel.active = Channel.s[next(Channel.s, self:getChannel().title)]
  self.display = false
  self:getChannel().display = false
  lobby.enter()
  --Battle.modoptionsScrollBar = nil
  --lobby.clickables[Battle.sideButton] = nil
  --Battle.sideButton = nil
  --[[Battle.modoptionsScrollBar = nil
  Battle.spectatorsScrollBar = nil
  Battle.mapScrollBar = nil]]
  lobby.send("LEAVEBATTLE")
  Battle.active = nil
  lobby.resize(lobby.width, lobby.height)
end

function Battle.enter(fromJoined)
  lobby.clickables[lobby.backbutton] = true
  lobby.clickables[lobby.options.button] = false
  lobby.events[lobby.battlelist] = nil
  if fromJoined then
    lobby.state = "battle"
    lobby.resize(lobby.width, lobby.height)
  else
    lobby.battleMiniWindow:initialize("maximize")
  end
  for _, button in pairs(Battle.buttons) do
    lobby.clickables[button] = true
  end
  lobby.scrollBars[Battle.mapScrollBar] = true
  lobby.scrollBars[Battle.spectatorsScrollBar] = true
  lobby.scrollBars[Battle.modoptionsScrollBar] = true
  --Battle.sideButton = Button:new():setPosition(1, lobby.height/2 - 20):setDimensions(20-2, 40):onClick(function() Battle.enterWithList() end)
  
  --[[function Battle.sideButton:draw()
    lg.rectangle("line", self.x, self.y, self.w, self.h)
    lg.polygon("line",
              5, self.y + self.h/2 - 8,
              5, self.y + self.h/2 + 8,
              15, self.y + self.h/2)
  end]]
  --lobby.clickables[Battle.sideButton] = true
end

function Battle:new(battle)
  setmetatable(battle, Battle.mt)
  
  battle.playersByTeam = {}
  
  battle.spectatorCount = 0
  battle.locked = false
  battle.users = {}
  battle.userCount = 0
  
  battle.teamCount = 0
  battle.userListScrollOffset = 0
  
  battle.game = {}
  battle.game.modoptions = {}
  battle.game.players = {}
  battle.startrect = {}
  
  --battle.ffa = false
  
  self.s[battle.id] = battle
  self.count = self.count + 1
  self.tab = BattleTab:new(battle.id)
end

function Battle:getChannel()
  return self.channel
end

-- lol
function Battle:getActiveBattle()
  return self.active
end
function Battle:getActive()
  return self.active
end
function Battle.getActive()
  return Battle.active
end
--

function Battle:getPlayers()
  return self.players
end

function Battle:getUsers()
  return self.users
end

function lobby.setSynced(b)
  if User.s[lobby.username].syncStatus then return end
  User.s[lobby.username].synced = b
  lobby.sendMyBattleStatus()
end

function lobby.setSpectator(b)
  User.s[lobby.username].spectator = b
  User.s[lobby.username].ready = false
  lobby.launchOnGameStart = lobby.launchOnGameStart or not b
  lobby.sendMyBattleStatus()
end

function lobby.setReady(b)
  User.s[lobby.username].ready = settings.autoready or b
  lobby.sendMyBattleStatus()
end

function lobby.setColor(r, g, b, a) --needs completing
  if type(r) == "table" then r = r[1] g = r[2] b = r[3] a = r[4] end
  --User.s[lobby.username].color = r * 255
  lobby.sendMyBattleStatus()
end

function lobby.sendMyBattleStatus()
  local user = User.s[lobby.username]
  --local status = user.battleStatus
  local b = {
    user.ready and 1 or 0,
    user.spectator and 0 or 1,
    user.synced and 1 or 0
  }
  local newstatus = b[1] * 2 + b[2] * 2 ^ 10 + 2 ^ (23 - b[3])
  local color = user.color
  lobby.send("MYBATTLESTATUS " .. newstatus .. " " .. color)
end

function Battle:update(dt)
  --Mod
  if self.modDownload then
    local err = self.modDownload.error
    local finished = self.modDownload.finished
    if finished then
      self.hasMod = true
      if self.hasMap then lobby.events[self] = nil lobby.setSynced(true) end
      self.modDownload = nil
      lobby.refreshBattleTabs()
      return
    elseif err then
      self.modMirrorID = self.modMirrorID + 1
      if self.modMirrorID > #self.modMirrors then
        table.insert(self:getChannel().lines, {time = os.date("%X"), msg = "Error auto-downloading game\n" .. self.modDownload.error .. "\nYou Could try installing manually"})
        self.modDownload:release()
        self.modDownload = nil
        if self.hasMap or (not self.mapDownload) then lobby.events[self] = nil end
        return
      end
      local filename = string.match(self.modMirrors[self.modMirrorID], ".*/(.*)")
      self.modDownload:push(self.modMirrors[self.modMirrorID], filename, lobby.modFolder)
    end
  end
  -- Map
  if self.mapDownload then
    local err = self.mapDownload.error
    local finished = self.mapDownload.finished
    if finished then
      self.hasMap = true
      self:getMinimap()
      self.mapDownload = nil
      if self.hasMod then lobby.events[self] = nil lobby.setSynced(true) end
      lobby.refreshBattleTabs()
      return
    elseif err then
      self.mapMirrorID = self.mapMirrorID + 1
      if self.mapMirrorID > #self.mapMirrors then
        table.insert(self:getChannel().lines, {time = os.date("%X"), msg = "Failed to find URL for map " .. self.mapName .. "\n".. self.mapDownload.error .. "\nTry downloading manually\n(Type !maplink, click on the hyperlink and place the file in your spring/maps/ directory)"})
        --love.window.showMessageBox("Auto Map Downloader", "\nFailed to find URL for map\nTry installing manually\n(Type !maplink, click on the hyperlink and place the file in your spring/maps/ directory)", "error" )
        self.mapDownload:release()
        self.mapDownload = nil
        if self.hasMod or (not self.modDownload) then lobby.events[self] = nil end
        return
      end
      local filename = string.match(self.mapMirrors[self.mapMirrorID], ".*/(.*)")
      self.mapDownload:push(self.mapMirrors[self.mapMirrorID], filename, lobby.mapFolder)
    end
  end
end

local draw = {
  readyButton = {
    [true] = function(x, y) lg.setColor(colors.bargreen) lg.circle("fill", x, y, 6) end,
    [false] = function(x, y) lg.setColor(colors.orange) lg.circle("fill", x, y, 6) end
  },
  specButton = function(x, y) lg.setColor(colors.bt) lg.circle("fill", x, y, 4) end
}

local rectColors = {
  {0, 200/255, 0, 0.2},
  {200/255, 0, 0, 0.2}
}
    
function Battle:draw()
  self.midpoint = math.max(lobby.fixturePoint[1].x + 280, lobby.width * 0.45)
  --Buttons
  
  for _, button in pairs(self.buttons) do
    button:draw()
  end
  
  --Room Name, Title
  lg.setFont(fonts.roboto)
  lg.setColor(colors.bargreen)
  local i = 0
  local text = self.title
  repeat
    text = text:sub(1, #text - i)
    local width = fonts.roboto:getWidth(text)
    i = i + 1
  until width < lobby.fixturePoint[2].x - 50 - lobby.fixturePoint[1].x or text == ""
  if i > 1 then text = text:sub(1, #text - 2) .. ".." end
  lg.print(text, lobby.fixturePoint[1].x + 50, 15)
  local fontHeight = fonts.roboto:getHeight()
  
  --Game Name, subtitle
  lg.setFont(fonts.latoitalic)
  lg.setColor(colors.bt)
  lg.print(self.gameName, lobby.fixturePoint[1].x + 50, 15 + fontHeight)
  
    --[[if self.modDownload then
    lg.printf(self.modDownload.filename, lobby.fixturePoint[2].x - 10 - 1024/8, 1024/8 + 20 + 3*fontHeight, 1024/8, "left")
    lg.printf(tostring(math.ceil(100*self.modDownload.downloaded/self.modDownload.file_size)) .. "%", lobby.fixturePoint[2].x - 10 - 1024/8, 1024/8 + 20 + 4*fontHeight, 1024/8, "left")
  end]]
  
  local h = self:drawMap()
  self:drawModOptions(h)
  local y = self:drawPlayers()
  self:drawSpectators(y)

  lg.origin()
  --Battle.sideButton:draw()
end

function Battle:drawMap()
  local fontHeight = fonts.roboto:getHeight()
  lg.setFont(fonts.robotoitalic)
  lg.setColor(colors.text)
  
  lg.setColor(1,1,1)
  local w, h
  local xmin = self.midpoint + 20
  local xmax = lobby.fixturePoint[2].x - 50
  local ymin = 25 + 2*fontHeight
  local ymax = lobby.fixturePoint[2].y - 60 - (math.floor(lobby.height/100))*fonts.latoitalic:getHeight() - 10
  -- couldnt find a better way to do this
  local aw, ah = xmax - xmin, ymax - ymin
  lg.printf(self.mapName, self.midpoint + 5, 15 + fontHeight, aw, "center")
  if self.minimap then
    if self.mapW > self.mapH then
      w = aw
      h = w / self.mapWidthHeightRatio
      if ah < h then
        h = ah
        w = self.mapWidthHeightRatio * h
      end
    elseif self.mapW < self.mapH then
      h = ah
      w = self.mapWidthHeightRatio * h
      if aw < w then
        w = aw
        h = w / self.mapWidthHeightRatio
      end
    else
      h = math.min(aw, ah)
      w = h
    end
    local x = xmin + aw/2 - w/2
    --local y = ymin + ah/2 - h/2
    if self.showMapScroll == 0 then
      lg.setColor(1,1,1)
      lg.draw(self.heightmap,
      x, -- (modx-1)*w,
      ymin, -- (mody-1)*h,
      0, w/self.mapW, h/self.mapH)
    elseif self.showMapScroll == 1 then
      lg.draw(self.minimap,
      x, -- (modx-1)*w,
      ymin, -- (mody-1)*h,
      0, w/1024, h/1024)
    elseif self.showMapScroll == 2 then
      lg.draw(self.minimap,
      x, -- (modx-1)*w,
      ymin, -- (mody-1)*h,
      0, w/1024, h/1024)
      lg.setColor(1,1,1,0.7)
      lg.setShader(shader)
      lg.draw(self.metalmap,
      x, -- (modx-1)*w,
      ymin, -- (mody-1)*h,
      0, 2*w/self.mapW, 2*h/self.mapH)
      lg.setShader( )
    end
    lg.setColor(colors.text)
    --
    self.mapScrollBar:getZone():setPosition(x, ymin):setDimensions(w, h)
    local myAllyTeam = 0
    for _, user in pairs(self.playersByTeam) do
      if user.name == lobby.username then
        myAllyTeam = user.allyTeamNo
      end
    end
    for ally, box in pairs(self.startrect) do
      if ally == myAllyTeam then
        lg.setColor(rectColors[1])
      else
        lg.setColor(rectColors[2])
      end
      lg.rectangle("fill",
                    x + w*box[1],
                    ymin + h*box[2],
                    w*(box[3] - box[1]),
                    h*(box[4] - box[2]))
      lg.setFont(fonts.roboto)
      lg.setColor(0,0,0)
      lg.print(ally, x + w*(box[1] + box[3])/2 - fonts.roboto:getWidth(ally)/2, ymin + h*(box[2] + box[4])/2 - fonts.roboto:getHeight()/2 )
    end
  elseif self.mapDownload and self.mapDownload.error then
    lg.setColor(colors.text)
    lg.print(self.mapDownload.filename, lobby.fixturePoint[2].x - 10 - 1024/8, 20 + 2*fontHeight)
    lg.print("Error downloading Map", lobby.fixturePoint[2].x - 10 - 1024/8, 20 + 3*fontHeight)
  elseif self.mapDownload and not self.mapDownload.finished then
    lg.setColor(colors.text)
    lg.print(self.mapDownload.filename, lobby.fixturePoint[2].x - 10 - 1024/8, 20 + 2*fontHeight)
    lg.print(tostring(math.ceil(100*self.mapDownload.downloaded/self.mapDownload.file_size)) .. "%", lobby.fixturePoint[2].x - 10 - 1024/8, 20 + 3*fontHeight)
  else
    lg.draw(img["nomap"], lobby.fixturePoint[2].x - 10 - 1024/8, 20 + 2*fontHeight, 0, 1024/(8*50))
  end
  return h
end

function Battle:drawModOptions(h)
  local fontHeight = fonts.roboto:getHeight()
  local x = self.midpoint + 20
  local ymin = 20 + 3*fontHeight + (h or 1024/8)
  local ymax = lobby.fixturePoint[2].y - fontHeight - 60
  local y = ymin - self.modoptionsScrollBar:getOffset()
  local font = fonts.latobold
  if love.graphics:getWidth() > 1200 then
    font = fonts.latobig
  elseif love.graphics:getWidth() > 800 then
    font = fonts.latoboldmedium
  end
  lg.setFont(font)
  fontHeight = font:getHeight()
  self.modoptionsScrollBar:getZone():setPosition(x, ymin)
  self.modoptionsScrollBar:setPosition(lobby.fixturePoint[2].x - 5, ymin):setLength(ymax - ymin + 10):setScrollBarLength((ymax - ymin + 10 )/ 10):setScrollSpeed(fontHeight)
  lg.setColor(colors.mo)
  local c = 0
  local t = 0
  for k, v in pairs(self.game.modoptions) do
    if y < ymax and y >= ymin then
      local _, wt = font:getWrap(k, lobby.fixturePoint[2].x - x - font:getWidth(v .. "  "))
      if #wt > 1 then
        for _, l in ipairs(wt) do
          lg.print(l, x, y)
          y = y + fontHeight
          c = c + 1
          t = t + 1
        end
        y = y - fontHeight
      else
        lg.print(k, x, y)
      end
      lg.print(v, lobby.fixturePoint[2].x - font:getWidth(v) - 10, y)
      c = c + 1
    end
    y = y + fontHeight
    t = t + 1
  end
  self.modoptionsScrollBar:getZone():setDimensions(lobby.fixturePoint[2].x - x, ymax - ymin)
  self.modoptionsScrollBar:setOffsetMax(math.max(0, t - c) * fontHeight):draw()
end

function Battle:drawPlayers()
  local y = 20 --+ self.userListScrollOffset
  lg.translate(lobby.fixturePoint[1].x + 25, 40 )
  local xmax = self.midpoint - (lobby.fixturePoint[1].x + 25) - fonts.latomedium:getWidth("Team 00")
  local teamNo = 0
  local drawBackRect = true
  local cy = y
  local myAllyTeam = 0
  local teamBool = (self.teamCount > 2) and not self.ffa
  local font = fonts.latosmall
  local padding = 0
  if love.graphics:getWidth() > 1200 then
    padding = 4
    font = fonts.latomedium
  elseif love.graphics:getWidth() > 800 then
    padding = 2
    font = fonts.latobig
  end
  local fontHeight = font:getHeight() + 2
  lg.setFont(fonts.latomedium)
  lg.setColor(colors.bt)
  if (self.teamCount < 3) then lg.print("Duel", xmax, y) elseif self.ffa then lg.print("FFA", xmax, y) end
  lg.setFont(font)
  for _, user in pairs(self.playersByTeam) do
    local username = user.name
    if username == lobby.username then
      myAllyTeam = user.allyTeamNo
    end
    if user.allyTeamNo > teamNo then
      if teamNo > 0 then
        lg.line(0, y + fontHeight/4, xmax - 40, y + fontHeight/4)
        y = y + fontHeight/2
      end
      lg.setFont(fonts.latomedium)
      lg.setColor(colors.bt)
      teamNo = user.allyTeamNo
      if teamBool then lg.print("Team " .. teamNo, xmax, y) end
      cy = y
      lg.setFont(font)
    end
    if user.battleStatus then
      if drawBackRect then
        lg.setColor(colors.bb)
        lg.rectangle("fill", 0, y - padding + 1, xmax - 40, fontHeight - 2 + 2*padding)
      end
      drawBackRect = not drawBackRect
      draw.readyButton[user.ready](xmax - 50, y + 7 + padding)
      lg.setColor(1,1,1)
      lg.draw(user.flag, 23, 3 + y)
      lg.draw(user.insignia, 41, y, 0, 1/4)
      lg.setColor(user.teamColorUnpacked[1]/255, user.teamColorUnpacked[2]/255, user.teamColorUnpacked[3]/255, 0.4)
      lg.rectangle("fill", 60, y, 120, fontHeight, 5, 5)
      lg.setColor(colors.text)
      if user.icon then
        lg.draw(img[user.icon], 5, y, 0, 1/4)
      end
      lg.print(username, 64, y)
      if self.game.players[username:lower()] and self.game.players[username:lower()].skill then
        lg.print(string.match(self.game.players[username:lower()].skill, "%d+"), 190, y)
      end
      y = y + fontHeight + padding
    end
  end
  return y
end

function Battle:drawSpectators(y)
  local xmax = self.midpoint - (lobby.fixturePoint[1].x + 25) - fonts.latomedium:getWidth("Team 00")
  local font = fonts.latosmall
  local padding = 0
  if love.graphics:getWidth() > 1200 then
    padding = 4
    font = fonts.latomedium
  elseif love.graphics:getWidth() > 800 then
    padding = 2
    font = fonts.latobig
  end
  local fontHeight = font:getHeight() + 2
  local drawBackRect = true
  self.spectatorsScrollBar:getZone():setPosition(lobby.fixturePoint[1].x + 25, y)
  self.spectatorsScrollBar:getZone():setDimensions(self.midpoint - lobby.fixturePoint[1].x + 25, lobby.fixturePoint[2].y - y)
  local ymin = math.max(8*fontHeight, y + fontHeight)
  self.spectatorsScrollBar:setPosition(xmax - 20, ymin + 3*fontHeight/2)
  local ymax = lobby.fixturePoint[1].y
  y = ymin - self.spectatorsScrollBar:getOffset()
  lg.setColor(colors.text)
  lg.print("Spectators", 60, ymin)
  y = y + 3*fontHeight/2
  drawBackRect = true
  local c = 0
  local t = 0
  for username, user in pairs(self.users) do
    if user.isSpectator and user.battleStatus then
      t = t + 1
      if y >= ymin + fontHeight and y <= ymax - 60 then
        c = c + 1
        if drawBackRect then
          lg.setColor(colors.bb)
          lg.rectangle("fill", 0, y, xmax - 40, fontHeight)
        end
        drawBackRect = not drawBackRect
        draw.specButton(xmax - 50, 7 + y + padding)
        lg.setColor(1,1,1)
        lg.draw(user.flag, 23, 3 + y)
        lg.draw(user.insignia, 41, y, 0, 1/4)
        --local w = fonts.latosmall:getWidth(username)
        lg.setColor(colors.text)
        if user.icon then
          lg.draw(img[user.icon], 5, y, 0, 1/4)
        end
        lg.print(username, 60, y)
      end
      y = y + fontHeight
    end
  end
  self.spectatorsScrollBar:setLength(ymax - ymin - 70):setOffsetMax(math.max(0, t - c) * fontHeight):setScrollSpeed(fontHeight):draw()
end

function Battle:modHandler()
  local gameName = string.gsub(self.gameName:lower(), " ", "_", 1)
  gameName = string.gsub(gameName, " ", "-", 1)
  gameName = string.gsub(gameName, " ", "_")
  if spring.hasMod(gameName) then self.hasMod = true return true end
  self.modMirrors = {
    "https://www.balancedannihilation.com/data/" .. gameName .. ".sdz"
  }
  self.modMirrorID = 1
  self.modDownload = Download:new()
  local filename = string.match(self.modMirrors[self.modMirrorID], ".*/(.*)")
  self.modDownload:push(self.modMirrors[self.modMirrorID], filename, lobby.gameFolder)
  lobby.events[self] = true
  return false
end

function Battle:mapHandler()
  local mapName = string.gsub(self.mapName:lower(), " ", "_")
  if spring.hasMap(mapName) then self.hasMap = true return true end
  self.mapMirrors = {
    "https://api.springfiles.com/files/maps/" .. mapName .. ".sd7",
    "https://api.springfiles.com/files/maps/" .. mapName .. ".sdz",
    --"https://www.springfightclub.com/data/maps/" .. mapName .. ".sd7",
    --"https://www.springfightclub.com/data/maps/" .. mapName .. ".sdz"
    "http://files.balancedannihilation.com/data/maps/" .. mapName .. ".sdz",
    "http://files.balancedannihilation.com/data/maps/" .. mapName .. ".sd7"
  }
  self.mapDownload = Download:new()
  self.mapMirrorID = 1
  local filename = string.match(self.mapMirrors[self.mapMirrorID], ".*/(.*)")
  self.mapDownload:push(self.mapMirrors[self.mapMirrorID], filename, lobby.mapFolder)
  lobby.events[self] = true
  return false
end

function Battle:getMinimap()
  local data = spring.getMapData(self.mapName)
  if data then
    self.minimap = data.minimap
    self.metalmap = data.metalmap
    self.heightmap = data.heightmap
    self.mapWidthHeightRatio = data.widthHeightRatio
    self.mapW = data.mapwidth
    self.mapH = data.mapheight
  end
end
  