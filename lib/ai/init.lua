-- Optional AI NPC dialogue subsystem entry.
-- Zero overhead when AI Dialogues are disabled (no context build, no polls).
local V = ...
local now = V.require("ai/time")
local AiConfig = V.require("ai/config")
local AiLog = V.require("ai/log")
local Transport = V.require("ai/transport")
local Dialogue = V.require("ai/dialogue")
local Providers = V.require("ai/providers/init")
local Prompt = V.require("ai/prompt")

local Ai = {}
Ai.__index = Ai

function Ai.new(mod, opts)
  local self = setmetatable({}, Ai)
  self.mod = mod
  self.follower = opts and opts.follower
  self.dialogue = Dialogue.new(mod, opts)
  self._installed = false
  self._devProbePending = nil
  if self.follower then
    mod._wildsAiFollower = self.follower
  end
  return self
end

function Ai:install()
  if self._installed then return true end
  -- Always install wrap; eligible() no-ops when disabled.
  self.dialogue._disposed = false
  if not self.dialogue:installTalkWrap() then return false end
  self._installed = true
  AiLog.info(self.mod, "subsystem ready transport=%s", Transport.describe(self.mod))
  return true
end

function Ai:enabled()
  return AiConfig.enabled(self.mod)
end

function Ai:tick()
  -- Cheap gate: only work when enabled or an in-flight request exists.
  if not AiConfig.enabled(self.mod) and self._devProbePending and self._devProbePending.real then
    local p = self._devProbePending
    pcall(p.provider.cancel, self.mod, p.handle)
    self._devProbePending = nil
  end
  if not AiConfig.enabled(self.mod) and self.dialogue._inputScreen then
    self.dialogue._inputScreen:_finish(nil)
    self.dialogue._inputScreen = nil
  end
  local hasActive = self.dialogue:hasActiveRequest()
  local pendingOffer = self.dialogue._pendingOffer ~= nil
  if not (AiConfig.enabled(self.mod) or hasActive or pendingOffer or self._devProbePending) then
    return
  end
  if pendingOffer then
    self.dialogue:processPendingOffer()
  end
  if hasActive then
    self.dialogue:tick()
  end
  if self._devProbePending then
    self:_tickDevProbe()
  end
end

--- DEV helper: prove async OpenAI-compatible round-trip without NPC wiring.
-- Uses mock provider by default in tests; with real transport sends the
-- "Wilds AI OK" probe when forceReal is true.
function Ai:devProbe(opts)
  opts = opts or {}
  local mod = self.mod
  if opts.useMock == false and not AiConfig.enabled(mod) then return false, "disabled" end
  local provider
  if opts.useMock ~= false then
    provider = Providers.resolve(mod, "mock")
  else
    provider = Providers.resolve(mod)
  end
  local context = {
    npcName = "Probe",
    role = "test",
    generation = 1,
    _devProbe = true,
    _testExact = "Wilds AI OK",
  }
  -- Ensure system prompt includes the exact-reply instruction for mock/real.
  -- Real probe: put instruction in context localKnowledge so providers include it.
  context.localKnowledge = "Reply with exactly: Wilds AI OK"
  local handle, err = provider.startRequest(mod, context, opts.message or "test")
  if not handle then
    return false, err or "start failed"
  end
  self._devProbePending = {
    provider = provider,
    handle = handle,
    onDone = opts.onDone,
    started = now(),
    real = opts.useMock == false,
  }
  AiLog.info(mod, "dev probe started")
  return true
end

function Ai:_tickDevProbe()
  local p = self._devProbePending
  if not p then return end
  local st = p.provider.poll(self.mod, p.handle)
  if st.status == "pending" then
    if now() - p.started > 30 then
      p.provider.cancel(self.mod, p.handle)
      self._devProbePending = nil
      if p.onDone then p.onDone(false, "timeout") end
    end
    return
  end
  self._devProbePending = nil
  if st.status == "success" and st.text == "Wilds AI OK" then
    AiLog.info(self.mod, "dev probe ok")
    if p.onDone then p.onDone(true, st.text) end
  else
    AiLog.warn(self.mod, "dev probe failed: %s", tostring(st.err or st.text))
    if p.onDone then p.onDone(false, st.err or st.text) end
  end
end

function Ai:handleKey(game, event)
  local top = game and game.stack and game.stack:top()
  if not (top and top.wildsAiInput == self.mod.id and top.onKeyPressed) then return false end
  if event and event.phase == "pressed" then top:onKeyPressed(event.key) end
  return true
end

function Ai:diagnostics()
  local d = AiConfig.diagnostics(self.mod)
  d.transport = Transport.describe(self.mod)
  d.providerReady = Providers.isReady(self.mod)
  d.activeRequest = self.dialogue:hasActiveRequest()
  return d
end

function Ai:uninstall()
  if self._devProbePending then
    local p = self._devProbePending
    pcall(p.provider.cancel, self.mod, p.handle)
    self._devProbePending = nil
  end
  self.dialogue:uninstall()
  self._installed = false
end

return Ai
