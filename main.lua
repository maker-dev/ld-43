json = require('libs.json')
inspect = require('libs.inspect')

DEBUG = true
LANG = "fr"

function love.load(arg)
  -- Load decks
  game_load()

  love.graphics.setDefaultFilter("nearest", "nearest", 0)

  print("Loading fonts...")

  assets_font_romulus_big = love.graphics.newFont("assets/romulus.ttf", 32)
  assets_font_romulus = love.graphics.newFont("assets/romulus.ttf", 26)

  print("Loading images...")
  assets_card = love.graphics.newImage("assets/card.png")

  icons = {}
  local files = love.filesystem.getDirectoryItems("assets/icons")
  for k, file in ipairs(files) do
    icons[file] = love.graphics.newImage("assets/icons/" .. file)
  	print(k .. ". " .. file)
  end
end

function love.update(dt)
  mouse_update()
  game_update(dt)
end

function love.draw()
  game_draw()
end

-- Deck Managments -------------------------------------------------------------

function deck_unlock(name)
  if decks[name] == nil then
    if love.filesystem.exists("decks/" .. name .. ".json") then
      local deck_json = love.filesystem.read("decks/" .. name .. ".json")
      local deck_data = json.decode(deck_json)

      decks[name] = deck_data

      print("Deck unlocked '" .. name .. "' !")
      print(inspect(deck_data))
    else
      error("No deck named '" .. name .. "' !")
    end
  end

end

function deck_lock(name)
  print("Deck locked '" .. name .. "' !")
  decks[name] = nil
end

function card_valid_equal(card)
  local requirements = card.requirement.equal

  if (requirements == nil) then return true end

  local r = true

  for k,v in pairs(requirements) do
    r = r and game_states[k] == v
  end

  return r
end

function card_valid_morethan(card)
  local requirements = card.requirement.morethan

  if (requirements == nil) then return true end

  local r = true

  for k,v in pairs(requirements) do
    if game_states[k] == nil then return false end
    r = r and game_states[k] > v
  end

  return r
end

function card_valid_lessthan(card)
  local requirements = card.requirement.lessthan

  if (requirements == nil) then return true end

  local r = true

  for k,v in pairs(requirements) do
    if game_states[k] == nil then return false end
    r = r and game_states[k] < v
  end

  return r
end

function card_valid_morethanorequal(card)
  local requirements = card.requirement.morethanorequal

  if (requirements == nil) then return true end

  local r = true

  for k,v in pairs(requirements) do
    if game_states[k] == nil then return false end
    r = r and game_states[k] >= v
  end

  return r
end

function card_valid_lessthanorequal(card)
  local requirements = card.requirement.lessthanorequal

  if (requirements == nil) then return true end

  local r = true

  for k,v in pairs(requirements) do
    if game_states[k] == nil then return false end
    r = r and game_states[k] <= v
  end

  return r
end

function deck_get_nextcard()
  local valid_card = {}
  local sum_weight = 0

  for _, deck in pairs(decks) do
    for _, card in ipairs(deck) do
      print(inspect(card))
      if card.weight ~= nil and card.weight > 0 then
        if card.requirement == nil or
           card_valid_equal(card) and
           card_valid_lessthan(card) and
           card_valid_morethan(card) and
           card_valid_lessthanorequal(card) and
           card_valid_morethanorequal(card) then

           table.insert(valid_card, card)
           sum_weight = sum_weight + card.weight
        end
      end
    end
  end

  local rnd_weight = math.random(0, sum_weight)

  for _,card in ipairs(valid_card) do
    rnd_weight = rnd_weight - card.weight
    if rnd_weight <= 0 then
      return card
    end
  end

  error("Out of card")
end

function deck_get_nextcard_by_nick(nick)
  for _, deck in pairs(decks) do
    for _, card in ipairs(deck) do
      if card.nick == nick then
        return card
      end
    end
  end

  error("No card named " .. nick .. "!")
end

-- GAME ------------------------------------------------------------------------

function game_load()
  decks = {}
  game_states = {}

  deck_unlock("intro")
  deck_unlock("endings/money")
  deck_unlock("endings/health")
  current_card = deck_get_nextcard_by_nick("game_start")
end

function game_update(dt)
  -- body...
end

function game_draw()
  love.graphics.clear(0.094, 0.078, 0.145)


  love.graphics.setColor(1,1,1)
  local text = love.graphics.newText( assets_font_romulus_big, current_card.question[LANG] )
  love.graphics.draw(text, love.graphics.getWidth()  / 2 - text:getWidth() / 2,
                           love.graphics.getHeight() / 2 - text:getHeight() / 2 - 76)

  for i, respond in ipairs(current_card.respond) do
    if button(love.graphics.getWidth() / 2 - 480/2, love.graphics.getHeight() / 2 + 48 * (i + 1), 480, 32, respond[LANG]) then
      print(inspect(respond))

      -- Set game states
      if respond.set ~= nil then
        for k,v in pairs(respond.set) do
          print("set ".. k .. ":" .. v)
          game_states[k] = v
        end
      end

      -- Add game states
      if respond.add ~= nil then
        for k,v in pairs(respond.add) do
          print("add ".. k .. ":" .. v)
          if game_states[k] == nil then
            game_states[k] = v
          else
            game_states[k] = game_states[k] + v
          end
        end
      end

      -- Substract game states
      if respond.sub ~= nil then
        for k,v in pairs(respond.sub) do
          print("sub ".. k .. ":" .. v)
          if game_states[k] == nil then
            game_states[k] = -v
          else
            game_states[k] = game_states[k] - v
          end
        end
      end

      -- Unlock decks
      if respond.unlock ~= nil then
        for i,v in ipairs(respond.unlock) do
          deck_unlock(v)
        end
      end

      -- lock decks
      if respond.lock ~= nil then
        for i,v in ipairs(respond.lock) do
          deck_lock(v)
        end
      end

      -- get the next card
      if respond.nextcard ~= nil then
        current_card = deck_get_nextcard_by_nick(respond.nextcard)
      else
        current_card = deck_get_nextcard()
      end

      print(inspect(game_states))
    end
  end
end

-- UI --------------------------------------------------------------------------

function button(x, y, w, h, text)

  -- local dist = distance(x + w / 2, y + h / 2, love.mouse.getX(), love.mouse.getY())

  love.graphics.setLineWidth(2)
  if check_collision(x, y, w, h, love.mouse.getX(), love.mouse.getY(), 1, 1) then
    love.graphics.setColor(0.996, 0.682, 0.012, 0.75)
    love.graphics.rectangle("fill", x, y, w, h)
    love.graphics.setColor(0.996, 0.906, 0.38, 0.75)
    love.graphics.rectangle("line", x, y, w, h)
  else
    love.graphics.setColor(0.227, 0.267, 0.4)
    love.graphics.rectangle("fill", x, y, w, h)
    love.graphics.setColor(0.353, 0.412, 0.533)
    love.graphics.rectangle("line", x, y, w, h)
  end

  love.graphics.setColor(1, 1, 1)
  local text = love.graphics.newText( assets_font_romulus, text )
  love.graphics.draw(text, x + w / 2 - text:getWidth() / 2,
                           y + h / 2 - text:getHeight() / 2 + 2)

   return check_collision(x, y, w, h, love.mouse.getX(), love.mouse.getY(), 1, 1) and mouse_click()
end

-- Utils -----------------------------------------------------------------------

function distance ( x1, y1, x2, y2 )
  local dx = x1 - x2
  local dy = y1 - y2
  return math.sqrt ( dx * dx + dy * dy )
end

function check_collision(x1,y1,w1,h1, x2,y2,w2,h2)
  return x1 < x2+w2 and
         x2 < x1+w1 and
         y1 < y2+h2 and
         y2 < y1+h1
end

function mouse_update()
  old_mouse_lclick = mouse_lclick
  mouse_lclick = love.mouse.isDown(1)
end

function mouse_click()
  return mouse_lclick and not old_mouse_lclick
end
