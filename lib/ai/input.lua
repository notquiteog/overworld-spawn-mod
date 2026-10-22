-- Free-text input for AI dialogues (keyboard preferred; NamingScreen fallback).
local V = ...
local AiLog = V.require("ai/log")
local GameCompat = V.require("game_compat")

local Input = {}
Input.MAX_LEN = 80

local function tryRequire(name)
  local ok, mod = pcall(require, name)
  if ok then return mod end
  return nil
end

function Input.supportsKeyboard()
  if love and love.keyboard then return true end
  return false
end

--- Push a free-text prompt. onDone(text|nil) — nil means cancelled.
-- path: "keyboard" | "naming" | "none"
function Input.prompt(mod, game, opts, onDone)
  opts = opts or {}
  local title = opts.title or "ASK WHAT?"
  local maxLen = tonumber(opts.maxLen) or Input.MAX_LEN
  onDone = onDone or function() end

  -- Unit-test / headless injection
  if Input._testPrompt then
    return Input._testPrompt(mod, game, opts, onDone)
  end

  -- Prefer engine NamingScreen with elevated maxLen (works on controller/mobile).
  -- On desktop with keyboard, still use NamingScreen unless a keyboard screen exists;
  -- M9 documents glyph-grid limits. Desktop builds may also feed love.textinput
  -- into a thin wrapper when available.
  if Input.supportsKeyboard() and Input._useKeyboardScreen ~= false then
    local screen = Input._makeKeyboardScreen(game, title, maxLen, onDone)
    if screen and game and game.stack and game.stack.push then
      screen.wildsAiInput = mod and mod.id
      local ok = pcall(game.stack.push, game.stack, screen)
      if ok then
        if opts.onScreen then opts.onScreen(screen) end
        return "keyboard"
      end
    end
  end

  local gen2 = GameCompat.generation(mod, game) == 2
  local NamingScreen = (mod and mod.ui and mod.ui.NamingScreen)
    or tryRequire(gen2 and "src.ui.gen2.NamingScreen" or "src.ui.NamingScreen")
  if NamingScreen and NamingScreen.new and game and game.stack then
    local ok, screen = pcall(NamingScreen.new, game, {
      title = title, prompt = title,
      maxLen = math.min(maxLen, 16), maxLength = math.min(maxLen, 12),
      onCancel = function() onDone(nil) end,
      onDone = function(name)
        onDone(type(name) == "string" and name ~= "" and name or nil)
      end,
    })
    if ok and screen then
      local pushed = pcall(game.stack.push, game.stack, screen)
      if pushed then return "naming" end
    end
  end

  AiLog.warn(mod, "no free-text input available")
  onDone(nil)
  return "none"
end

function Input._makeKeyboardScreen(game, title, maxLen, onDone)
  local screen = {
    isOpaque = true,
    game = game,
    title = title,
    maxLen = maxLen,
    text = "",
    _done = false,
  }
  function screen:enter()
    if self.game and self.game.input and self.game.input.reset then self.game.input:reset() end
  end
  function screen:exit()
    if not self._done then self._done = true; onDone(nil) end
  end
  function screen:textinput(t)
    if self._done then return end
    if type(t) ~= "string" then return end
    if #self.text < self.maxLen then
      self.text = (self.text .. t):sub(1, self.maxLen)
    end
  end
  function screen:keypressed(key)
    if self._done then return end
    if key == "backspace" then
      self.text = self.text:sub(1, math.max(0, #self.text - 1))
    elseif key == "return" or key == "kpenter" then
      self:_finish(self.text)
    elseif key == "escape" then
      self:_finish(nil)
    elseif key == "space" then
      self:textinput(" ")
    elseif type(key) == "string" and #key == 1 and key:match("[%w%p]") then
      local shift = love and love.keyboard and love.keyboard.isDown
        and (love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift"))
      self:textinput(shift and key:upper() or key)
    end
  end
  screen.onKeyPressed = screen.keypressed
  function screen:update()
    if self._done then
      if self.game.stack:top() == self then self.game.stack:pop() end
      return
    end
    self:handleInput(self.game and self.game.input)
  end
  function screen:handleInput(input)
    -- Gen1Recomp-style logical buttons when love keyboard events are absent.
    if not input then return end
    if input.wasPressed and input:wasPressed("b") then
      self:_finish(nil)
      return
    end
    if input.wasPressed and (input:wasPressed("a") or input:wasPressed("start")) then
      self:_finish(self.text)
      return
    end
  end
  function screen:_finish(value)
    if self._done then return end
    self._done = true
    if self.game and self.game.stack and self.game.stack.pop
      and (not self.game.stack.top or self.game.stack:top() == self) then
      pcall(self.game.stack.pop, self.game.stack)
    end
    if type(value) == "string" then
      value = value:match("^%s*(.-)%s*$") or ""
      if value == "" then value = nil end
    end
    onDone(value)
  end
  function screen:draw()
    local Font = tryRequire("src.render.Font")
    if not Font then return end
    -- Same active generation font/frame as native menus, no global UI override.
    if Font.drawBox then Font.drawBox(0, 0, 20, 18) end
    Font.draw(tostring(self.title), 8, 8)
    local text = self.text or ""
    for row = 0, 7 do Font.draw(text:sub(row*18+1, row*18+18), 8, 32+row*8) end
    Font.draw("ENTER/START: OK", 8, 112)
    Font.draw("ESC/B: CANCEL", 8, 128)
  end
  return screen
end

function Input.setTestPrompt(fn)
  Input._testPrompt = fn
end

return Input
