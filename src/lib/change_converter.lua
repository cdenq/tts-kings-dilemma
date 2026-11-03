--[[ Change Converter: makes change and consolidates coins and Power.
Shared by the four bags nicknamed "Change Converter" (305b4a, 7e0944, c0a478,
6eafd0); each one's file in src/change_converter/ includes this.

  [   +1 Coin  ]            [ +1 Power ]      row 0, above the bag
  [ Break-down ]            [ Cash-up ]       row 1, either side of the bag
  [    Gold: 0   ][   Power: 0   ]             row 2, one total per kind

The totals are recounted from what's in the bag on every change (recount()),
so they always match its contents. A piece counts if it's tagged "Gold" or
"Power" and its GM Notes are a positive number, the same reading zoneTotal()
in player_board.lua uses. Gold and Power never convert into each other.

  Cash-up     the fewest pieces for the same value: 7 Nibs -> 1 Shard + 2 Nibs.
              Greedy largest-first, which is exact for both denomination sets.
  Break-down  each piece becomes its entry in `breakdown`, e.g. a Dragon (25)
              -> 10, 5, 5 and 5x 1. 1s stay as they are.

Both empty the bag and lay the result out in front of it.

  +1 Coin     one 1-Gold coin into the clicking player's coins zone.
  +1 Power    one 1-Power into the clicking player's power zone.
              The player's board is the Player Board whose GM Notes are their
              seat colour; the zone comes from its zoneGuids.
]]

--[[ Panel geometry. Positions are object-local {x, y, z}, which TTS multiplies
by the bag's scale; a bag is about 1 unit across. +z is the bag's front, so the
panel sits below it on the table.

TTS rasterises button text at font_size and then shrinks it by scale, so a big
font at a small scale looks sharper than the reverse. SHARPNESS is that
multiplier. Horizontal measurements here are in visible local units and get
converted by unitsToPx().
]]
PANEL = {
  SHARPNESS = 4,
  BTN_SCALE = 0.75,

  LIFT = 0.25,              -- just above the table surface

  GRANT_Z = -2.1,           -- row 0: above the bag, one either side
  ACTION_Z = 0,             -- row 1: level with the bag, one either side
  ACTION_X = 3.4,
  WIDE_Z = 2.1,             -- row 2: one total per kind, side by side

  -- How wide row 2 is, in object-local units; the bars share it evenly.
  SPAN_X = 6.8,
  WIDE_GAP = 0.2,           -- gap between total bars, local units

  -- Button pixels per local unit at BTN_SCALE, before shrinking. createButton's
  -- width isn't in local units and the API doesn't say how they relate, so this
  -- was measured.
  PX_PER_UNIT = 650,

  ACTION_W = 1500,
  ACTION_H = 420,
  ACTION_FONT = 170,

  WIDE_H = 420,
  WIDE_FONT = 170,

  BREAKDOWN_COLOR = {0.62, 0.18, 0.18},
  CASHUP_COLOR = {0.18, 0.5, 0.24},
  TEXT_COLOR = {1, 1, 1},
}

--[[ The kinds of currency, each with its own conversion tree.

`denoms` are the face values that exist, ascending. `breakdown` is what one
piece becomes when broken down: a {denomination -> count} mix that has to add
up to the piece's value (checkBreakdowns() checks at load). A value with no
entry can't be broken.

The mixes are picked by hand rather than computed. A greedy split would turn
a Dragon into 2 Taols and a Shard, where a spread of smaller pieces is more useful for
making payments.

  Gold   Harbor Moon(100) -> 50, 25, 10, 10, 5
         Sun(50)          -> 25, 10, 5, 5, 5x 1
         Dragon(25)       -> 10, 5, 5, 5x 1
         Taol(10)         -> 5, 5x 1
         Shard(5)         -> 5x 1
  Power  10               -> 5, 5x 1
         5                -> 5x 1
]]
KINDS = {
  {
    tag = "Gold", label = "Gold", color = {0.70, 0.55, 0.18},
    denoms = {1, 5, 10, 25, 50, 100},
    breakdown = {
      [100] = {[50] = 1, [25] = 1, [10] = 2, [5] = 1},
      [50] = {[25] = 1, [10] = 1, [5] = 2, [1] = 5},
      [25] = {[10] = 1, [5] = 2, [1] = 5},
      [10] = {[5] = 1, [1] = 5},
      [5] = {[1] = 5},
    },
  },
  {
    tag = "Power", label = "Power", color = {0.36, 0.22, 0.52},
    denoms = {1, 5, 10},
    breakdown = {
      [10] = {[5] = 1, [1] = 5},
      [5] = {[1] = 5},
    },
  },
}

--[[ The canonical bag that replacement pieces are cloned from. It holds both
gold and Power, which share face values (1, 5, 10), so lookups in it must
match the tag as well as the value. ]]
SOURCE_BAG_GUID = "f0d3ab"

-- tag -> {value -> how many of that piece are in the bag}. Rebuilt by recount().
COUNTS = {}

-- Guards the convert/respawn cycle: putObject and takeObject are async, and a
-- second click mid-run would double-count.
busy = false


-- ------------------------------------------------------------------ setup ---

function onLoad()
  checkBreakdowns()
  buildPanel()
  recount()
end

-- Visible sizes -> the supersampled font, width, height and scale vector that
-- createButton wants. `extra` shrinks further on top of SHARPNESS (normally
-- BTN_SCALE).
function sharp(font, width, height, extra)
  local k = PANEL.SHARPNESS
  local s = (extra or 1) / k
  return font * k, width * k, height * k, {s, s, s}
end

-- Local units -> the pixel figure createButton wants, at BTN_SCALE.
function unitsToPx(units)
  return units * PANEL.PX_PER_UNIT
end

function addButton(p)
  self.createButton({
    click_function = p.fn, function_owner = self,
    label = p.label, tooltip = p.tooltip,
    position = {p.x, PANEL.LIFT, p.z},
    rotation = {0, 0, 0}, scale = p.scale,
    width = p.width, height = p.height, font_size = p.font,
    color = p.color, font_color = p.text
  })
end

function buildPanel()
  self.clearButtons()

  -- Row 1: the two actions, flanking the bag.
  local f, w, h, sc = sharp(PANEL.ACTION_FONT, PANEL.ACTION_W, PANEL.ACTION_H,
                            PANEL.BTN_SCALE)
  addButton({fn = "breakDownClick", label = "Break-down",
             tooltip = "Break every piece down one tier.",
             x = -PANEL.ACTION_X, z = PANEL.ACTION_Z,
             width = w, height = h, font = f, scale = sc,
             color = PANEL.BREAKDOWN_COLOR, text = PANEL.TEXT_COLOR})
  addButton({fn = "cashUpClick", label = "Cash-up",
             tooltip = "Consolidate into the fewest pieces.",
             x = PANEL.ACTION_X, z = PANEL.ACTION_Z,
             width = w, height = h, font = f, scale = sc,
             color = PANEL.CASHUP_COLOR, text = PANEL.TEXT_COLOR})

  -- Row 2: one total bar per kind, side by side across the span.
  local span = PANEL.SPAN_X
  local each = (span - PANEL.WIDE_GAP * (#KINDS - 1)) / #KINDS
  f, w, h, sc = sharp(PANEL.WIDE_FONT, unitsToPx(each), PANEL.WIDE_H,
                      PANEL.BTN_SCALE)
  for i, kind in ipairs(KINDS) do
    addButton({fn = "noop", label = "",
               tooltip = "Total " .. kind.label .. " in the bag.",
               x = -span / 2 + each / 2 + (i - 1) * (each + PANEL.WIDE_GAP),
               z = PANEL.WIDE_Z,
               width = w, height = h, font = f, scale = sc,
               color = kind.color, text = PANEL.TEXT_COLOR})
  end

  -- Row 0: the grants, above the bag. Created last so the total bars keep
  -- indices 2, 3, ... for refreshPanel.
  f, w, h, sc = sharp(PANEL.ACTION_FONT, PANEL.ACTION_W, PANEL.ACTION_H,
                      PANEL.BTN_SCALE)
  for i, g in ipairs(GRANTS) do
    addButton({fn = g.fn, label = g.label, tooltip = g.tooltip,
               x = (i == 1 and -1 or 1) * PANEL.ACTION_X, z = PANEL.GRANT_Z,
               width = w, height = h, font = f, scale = sc,
               color = kindByTag(g.tag).color, text = PANEL.TEXT_COLOR})
  end
end

function noop() end


-- ----------------------------------------------------------------- counting ---

-- The kind and face value of a bag entry (a plain table, not an Object), or nil
-- if it isn't currency. The tag gives the kind and the GM Notes the value.
function entryKind(entry)
  local tags = {}
  for _, t in ipairs(entry.tags or {}) do tags[t] = true end
  for _, kind in ipairs(KINDS) do
    if tags[kind.tag] then
      local raw = entry.gm_notes or entry.gmNotes or entry.description or ""
      local v = tonumber(raw)
      if v == nil or v <= 0 then return nil end
      return kind, math.floor(v)
    end
  end
  return nil
end

--[[ Rebuilds COUNTS from what's in the bag and redraws. A full recount rather
than a running tally, since pieces can also leave the bag, get deleted by another
script, or arrive mid-conversion.

Returns tag -> total value, and the number of pieces across all kinds. ]]
function recount()
  COUNTS = {}
  local totals, pieces = {}, 0
  for _, kind in ipairs(KINDS) do
    COUNTS[kind.tag] = {}
    totals[kind.tag] = 0
  end
  for _, entry in ipairs(self.getObjects()) do
    local kind, v = entryKind(entry)
    if kind then
      local c = COUNTS[kind.tag]
      c[v] = (c[v] or 0) + 1
      totals[kind.tag] = totals[kind.tag] + v
      pieces = pieces + 1
    end
  end
  refreshPanel(totals)
  return totals, pieces
end

-- Buttons are indexed in creation order: 0 and 1 are the actions, then one
-- total per kind, then the grants.
function refreshPanel(totals)
  for i, kind in ipairs(KINDS) do
    self.editButton({index = 1 + i, label = string.format("%s: %d",
                     kind.label, totals[kind.tag])})
  end
end

function onObjectEnterContainer(container, obj)
  if container == self then recount() end
end

function onObjectLeaveContainer(container, obj)
  if container == self then recount() end
end


-- --------------------------------------------------------------- conversion ---

--[[ The fewest pieces of `kind` adding up to `amount`. Greedy largest-first,
which is only optimal for "canonical" denomination sets; both 1, 5, 10, 25, 50,
100 and 1, 5, 10 are, like real coinage. ]]
function fewestPieces(kind, amount)
  local counts, left = {}, amount
  for i = #kind.denoms, 1, -1 do
    local d = kind.denoms[i]
    local n = math.floor(left / d)
    if n > 0 then
      counts[d] = n
      left = left - n * d
    end
  end
  return counts, left
end

-- Warns at load if a breakdown doesn't add up to its piece's value, since the
-- table is hand-edited and a typo would quietly mint or burn money on every click.
function checkBreakdowns()
  for _, kind in ipairs(KINDS) do
    for value, mix in pairs(kind.breakdown) do
      local sum = 0
      for d, n in pairs(mix) do sum = sum + d * n end
      if sum ~= value then
        broadcastToAll(string.format(
          "Change Converter: %s breakdown[%d] sums to %d, not %d. "
          .. "Break-down would alter the money supply.",
          kind.label, value, sum, value), {1, 0.4, 0.4})
      end
    end
  end
end

--[[ Where converted change is laid out: in front of the bag (+z, the panel's
side), past the panel's far edge. Pieces run along +x and wrap onto new rows
further from the bag. ]]
PAYOUT = {
  START_X = -3.0,
  START_Z = 4.7,
  STEP_X = 0.9,
  STEP_Z = 0.9,
  PER_ROW = 8,
  DROP_HEIGHT = 1.5,
}

function payoutPosition(n)
  local col = (n - 1) % PAYOUT.PER_ROW
  local row = math.floor((n - 1) / PAYOUT.PER_ROW)
  return self.positionToWorld({
    PAYOUT.START_X + col * PAYOUT.STEP_X,
    PAYOUT.DROP_HEIGHT,
    PAYOUT.START_Z + row * PAYOUT.STEP_Z
  })
end

--[[ Converts everything in the bag and lays the change out in front of it.
`plan` maps tag -> {value -> how many to hand back}. The currency inside is
destroyed first, so the plan is the whole result, and the bag ends up empty. ]]
function applyPlan(plan, summary, before)
  local bag = getObjectFromGUID(SOURCE_BAG_GUID)
  if bag == nil then
    broadcastToAll("Source bag " .. SOURCE_BAG_GUID .. " not found.",
                   {1, 0.5, 0.5})
    busy = false
    return
  end

  -- Destroy the currency already inside. getObjects() is a snapshot, so
  -- taking from it while iterating is safe.
  for _, entry in ipairs(self.getObjects()) do
    if entryKind(entry) then
      self.takeObject({guid = entry.guid, smooth = false,
                       callback_function = function(o) destroyObject(o) end})
    end
  end

  -- Then mint the replacements from the source bag.
  local queue = {}
  for _, kind in ipairs(KINDS) do
    local p = plan[kind.tag] or {}
    for _, d in ipairs(kind.denoms) do
      for _ = 1, (p[d] or 0) do
        table.insert(queue, {kind = kind, value = d})
      end
    end
  end
  mintStep(bag, queue, 1, summary, before, 0)
end

--[[ Clones one piece out of the source bag per step and lays it in front.
Pieces are cloned and the original put back (see cloneFromBag), so the source
bag keeps its stock. One per step because takeObject is async, and many at
once against one bag drops pieces. ]]
function mintStep(bag, queue, index, summary, before, placed)
  if index > #queue then
    Wait.frames(function()
      recount()
      -- "Converted 37 Gold, 6 Power: 12 -> 6 pieces". The value doesn't
      -- change, so the piece count is what's reported.
      broadcastToAll(string.format("Converted %s: %d -> %d piece%s",
                                   summary, before, placed,
                                   placed == 1 and "" or "s"),
                     {0.9, 0.85, 0.6})
      busy = false
      pumpGrants()
    end, 2)
    return
  end

  local want = queue[index]
  local found = findPiece(bag, want.kind, want.value)
  if found == nil then
    broadcastToAll(string.format("No %d-%s piece in the source bag.",
                                 want.value, want.kind.label), {1, 0.8, 0.3})
    mintStep(bag, queue, index + 1, summary, before, placed)
    return
  end

  cloneFromBag(bag, found, payoutPosition(placed + 1), function()
    mintStep(bag, queue, index + 1, summary, before, placed + 1)
  end)
end

-- GUID of a `value` piece of `kind` in `bag`, or nil.
function findPiece(bag, kind, value)
  for _, entry in ipairs(bag.getObjects()) do
    local k, v = entryKind(entry)
    if k == kind and v == value then return entry.guid end
  end
  return nil
end

--[[ Clone the piece `guid` out of `bag` to `target`, put the original back,
then call `done`. ]]
function cloneFromBag(bag, guid, target, done)
  local original = bag.takeObject({
    guid = guid, smooth = false,
    position = bag.getPosition() + Vector(0, 3, 0)
  })
  Wait.condition(
    function()
      original.clone({position = target, snap_to_grid = false})
      -- Put the original straight back so the bag keeps its stock.
      Wait.frames(function()
        bag.putObject(original)
        if done then done() end
      end, 2)
    end,
    function() return original ~= nil and not original.spawning end
  )
end


-- ------------------------------------------------------------------ actions ---

-- "37 Gold, 6 Power", skipping kinds that are absent; nil when the bag is empty.
function describeTotals(totals)
  local parts = {}
  for _, kind in ipairs(KINDS) do
    if totals[kind.tag] > 0 then
      table.insert(parts, string.format("%d %s", totals[kind.tag], kind.label))
    end
  end
  if #parts == 0 then return nil end
  return table.concat(parts, ", ")
end

function cashUpClick(obj, playerColor, altClick)
  if busy then return end
  local totals, pieces = recount()
  local summary = describeTotals(totals)
  if summary == nil then
    broadcastToColor("Nothing in the converter.", playerColor, {1, 0.8, 0.3})
    return
  end

  local plan = {}
  for _, kind in ipairs(KINDS) do
    plan[kind.tag] = fewestPieces(kind, totals[kind.tag])
  end
  busy = true
  applyPlan(plan, summary, pieces)
end

function breakDownClick(obj, playerColor, altClick)
  if busy then return end
  local totals, pieces = recount()
  local summary = describeTotals(totals)
  if summary == nil then
    broadcastToColor("Nothing in the converter.", playerColor, {1, 0.8, 0.3})
    return
  end

  -- One tier down per piece, within its own kind; a 1 has nowhere to go and
  -- stays as it is.
  local plan, moved = {}, false
  for _, kind in ipairs(KINDS) do
    local p = {}
    plan[kind.tag] = p
    for value, n in pairs(COUNTS[kind.tag]) do
      local mix = kind.breakdown[value]
      if mix then
        for d, per in pairs(mix) do
          p[d] = (p[d] or 0) + n * per
        end
        moved = true
      else
        p[value] = (p[value] or 0) + n
      end
    end
  end

  if not moved then
    broadcastToColor("Nothing left to break down.", playerColor, {1, 0.8, 0.3})
    return
  end
  busy = true
  applyPlan(plan, summary, pieces)
end


-- ------------------------------------------------------------------ grants ---

--[[ The +1 buttons above the bag. `zone` is the Player Board zone role the
piece lands in (ZONE_ROLES in player_board.lua). ]]
GRANTS = {
  {fn = "grantCoinClick", label = "+1 Coin", tag = "Gold", zone = "coins",
   tooltip = "Put 1 Gold in your player board's coins zone."},
  {fn = "grantPowerClick", label = "+1 Power", tag = "Power", zone = "power",
   tooltip = "Put 1 Power in your player board's power zone."},
}
GRANT_VALUE = 1

--[[ Grants waiting their turn. Each takes from the source bag, as a
conversion does, so they run one at a time and never alongside a conversion;
a click while busy is queued rather than dropped. ]]
grantQueue = {}

function kindByTag(tag)
  for _, kind in ipairs(KINDS) do
    if kind.tag == tag then return kind end
  end
end

--[[ The scripting zone `role` on the Player Board seated at `color`.

Returns the zone (or nil) and whether a board was found at all. A Player
Board is anything carrying player_board.lua's zoneGuids table; its seat colour
is its GM Notes, the same field getVote() reports. ]]
function playerZone(color, role)
  for _, obj in ipairs(getObjects()) do
    local guids = obj.getTable("zoneGuids")
    if guids and obj.getGMNotes():match("^%s*(.-)%s*$") == color then
      local guid = guids[role]
      return guid and getObjectFromGUID(guid) or nil, true
    end
  end
  return nil, false
end

function grantCoinClick(obj, playerColor) queueGrant(GRANTS[1], playerColor) end
function grantPowerClick(obj, playerColor) queueGrant(GRANTS[2], playerColor) end

function queueGrant(grant, color)
  table.insert(grantQueue, {grant = grant, color = color})
  pumpGrants()
end

function pumpGrants()
  if busy or #grantQueue == 0 then return end
  local job = table.remove(grantQueue, 1)
  local grant, color = job.grant, job.color
  local kind = kindByTag(grant.tag)
  local warn = {1, 0.8, 0.3}

  local zone, hasBoard = playerZone(color, grant.zone)
  if zone == nil then
    broadcastToColor(hasBoard
      and ("Your player board has no " .. grant.zone .. " zone.")
      or ("No player board for " .. color .. ". Set its GM Notes to '"
          .. color .. "'."), color, warn)
    return pumpGrants()
  end

  local bag = getObjectFromGUID(SOURCE_BAG_GUID)
  local guid = bag and findPiece(bag, kind, GRANT_VALUE)
  if guid == nil then
    broadcastToColor(bag == nil
      and ("Source bag " .. SOURCE_BAG_GUID .. " not found.")
      or string.format("No %d-%s piece in the source bag.", GRANT_VALUE,
                       kind.label), color, warn)
    return pumpGrants()
  end

  busy = true
  cloneFromBag(bag, guid, zone.getPosition() + Vector(0, 1, 0), function()
    busy = false
    pumpGrants()
  end)
end
