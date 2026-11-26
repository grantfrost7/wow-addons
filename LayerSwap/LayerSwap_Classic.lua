-- LayerSwap on Classic Era and TBC Anniversary: what only these two clients do.
-- The game loads this file from LayerSwap_Classic.toc, which Classic Era (vanilla) and TBC Anniversary (tbc) read
-- before LayerSwap.toc; WoW Forever reads its own and never sees it. It runs after LayerSwap.lua and builds on what
-- that file shares in the addon's table. Should it ever run anywhere else, it stops at once.
local _, NS = ...
if type(NS) ~= "table" or NS.FOREVER ~= false or type(NS.Send) ~= "table" then return end
local Send, log = NS.Send, NS.log

NS.classic = true

-- the session's log says this file ran: a frame after LayerSwap.lua's own login handler has opened the session
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
  C_Timer.After(0, function()
    if type(LayerSwapDB) == "table" and type(LayerSwapDB.session) == "table" then LayerSwapDB.session.classic = true end
    log("classic", "loaded")
  end)
end)

-- A click that asks for a swap joins the layer channel first. The game may refuse the join - a character can be in
-- only so many chat channels, General, Trade and the like counted - and it says so nowhere an addon is told. Before,
-- the panel said "Joined the layer channel. Click again to ask." at once, joined or not, at every click. Now it says
-- Joining, looks whether the player is in the channel, and says Joined only then; if not after the last look, it says
-- so. No number of channels is assumed, and no channel is ever left. A host's own join (any click, Host on) says nothing.
Send.JOINING = "Joining the layer channel..."
Send.JOINED = "Joined the layer channel. Click again to ask."
Send.NOT_JOINED = "Could not join the layer channel. If your chat channels are full, leave one."
Send.JOIN_LOOKS = { 0.5, 1, 2, 3 }   -- seconds after the click
-- the channels the character is in (GetChannelList: id, name, disabled for each), for the log; nil when not told
function Send.channelCount()
  if type(GetChannelList) ~= "function" then return nil end
  local ok, n = pcall(function() return select("#", GetChannelList()) end)
  if not ok or type(n) ~= "number" then return nil end
  return math.floor(n / 3)
end
local join = Send.joinLayer
function Send.joinLayer(why)
  join(why)
  if why ~= "ask" then return true end
  Send.joinRun = (Send.joinRun or 0) + 1   -- a later click starts its own looks; these stop
  local run = Send.joinRun
  NS.setNotice(Send.JOINING, 15, "Joining")
  for i, after in ipairs(Send.JOIN_LOOKS) do
    C_Timer.After(after, function()
      if run ~= Send.joinRun or run == Send.joinDone then return end
      local id = GetChannelName(NS.LAYER_CHANNEL)
      local inside = type(id) == "number" and id > 0
      if not inside and i < #Send.JOIN_LOOKS then return end
      Send.joinDone = run
      if not inside then
        local n = Send.channelCount()
        log("layer", "not joined", n and (n .. " channels") or "channels unknown", after .. " s")
      end
      if NS.notice() ~= Send.JOINING then return end   -- another line has taken the panel since: it stays
      if inside then NS.setNotice(Send.JOINED, 15, "Click to ask") else NS.setNotice(Send.NOT_JOINED, 15, "Not joined") end
      NS.refresh()
    end)
  end
  return false
end
