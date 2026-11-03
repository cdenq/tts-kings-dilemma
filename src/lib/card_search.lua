-- Takes the deck/card whose name matches the typed text out of this bag.
posY = -4
function CardSearch(player, value)
  self.UI.setAttribute("Input", "text", value)
  if value == "" then return end

  for _, data in ipairs(self.getObjects()) do
    if string.lower(data.name) == string.lower(value) then
      return self.takeObject({
        position = addVec(self.getPosition(), {0, 3, posY}),
        rotation = {0.00, 180.00, 0.00},
        index    = data.index,
      })
    end
  end

  printToAll("Card named " .. value .. " is not found. Check letters and cases.", {1,0,0})
end

function addVec(v1,v2)
  return {v1[1]+v2[1],v1[2]+v2[2],v1[3]+v2[3]}
end
