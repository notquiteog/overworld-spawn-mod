-- AI dialogue configuration + private secret storage.
-- Public options never hold API keys. Secrets live in private user data.
local V = ...
local Config = V.require("config")

local AiConfig = {}

AiConfig.DEFAULT_ENDPOINT = "http://127.0.0.1:1234/v1"
AiConfig.DEFAULT_MODEL = "local"
AiConfig.SECRETS_REL = "wilds_ai/provider_secrets.json"
AiConfig.SECRETS_NOTE = "plaintext local storage (not Pokémon save data)"

local function opt(mod, key, default)
  if Config and type(Config.get) == "function" then
    local v = Config.get(mod, key)
    if v ~= nil then return v end
  end
  if mod and mod.options and type(mod.options.get) == "function" then
    local v = mod.options:get(key)
    if v ~= nil then return v end
  end
  return default
end

function AiConfig.enabled(mod)
  return opt(mod, "ai_dialogues", false) == true
end

function AiConfig.providerId(mod)
  local p = tostring(opt(mod, "ai_provider", "local") or "local")
  if p ~= "local" and p ~= "openai" and p ~= "custom" then
    return "local"
  end
  return p
end

function AiConfig.model(mod)
  local m = opt(mod, "ai_model", AiConfig.DEFAULT_MODEL)
  if type(m) ~= "string" or m == "" then return AiConfig.DEFAULT_MODEL end
  return m
end

function AiConfig.endpoint(mod)
  local e = opt(mod, "ai_endpoint", AiConfig.DEFAULT_ENDPOINT)
  if type(e) ~= "string" or e == "" then return AiConfig.DEFAULT_ENDPOINT end
  -- Strip trailing slash for joining /chat/completions
  return (e:gsub("/+$", ""))
end

function AiConfig.memoryEnabled(mod)
  return opt(mod, "ai_memory", false) == true
end

function AiConfig.chatUrl(mod)
  local base = AiConfig.endpoint(mod)
  if base:find("/chat/completions", 1, true) then return base end
  return base .. "/chat/completions"
end

-- Private installation cache is outside the mod installation and save fields.
-- No raw filesystem access or shell fallback in production.
local _secretsCache, _secretsPathOverride
function AiConfig.setSecretsPathForTests(path)
  _secretsPathOverride = path
  _secretsCache = nil
end
local function readFile()
  if _secretsPathOverride and io and io.open then
    local f = io.open(_secretsPathOverride, "rb")
    if not f then return end
    local body = f:read(65537); f:close()
    return body and #body <= 65536 and body or nil
  end
  local cache = V.mod and V.mod.cache
  if cache and cache.read then
    local ok, body = pcall(cache.read, cache, AiConfig.SECRETS_REL)
    if ok and type(body) == "string" and #body <= 65536 then return body end
  end
end
local function writeFile(body)
  if _secretsPathOverride and io and io.open then
    local f = io.open(_secretsPathOverride, "wb")
    if not f then return false end
    local ok = f:write(body); f:close(); return ok ~= nil
  end
  local cache = V.mod and V.mod.cache
  if cache and cache.write then
    local ok, saved = pcall(cache.write, cache, AiConfig.SECRETS_REL, body)
    return ok and saved ~= false and saved ~= nil
  end
  return false
end

local function decodeSecrets(raw)
  if type(raw) ~= "string" or raw == "" then return {} end
  local JsonDecode = V.require("json_decode")
  local obj = JsonDecode.decode(raw)
  if type(obj) ~= "table" then return {} end
  return {
    openai_api_key = type(obj.openai_api_key) == "string" and obj.openai_api_key or "",
    custom_api_key = type(obj.custom_api_key) == "string" and obj.custom_api_key or "",
  }
end

function AiConfig.loadSecrets()
  if _secretsCache then return _secretsCache end
  local raw = readFile()
  _secretsCache = decodeSecrets(raw)
  return _secretsCache
end

function AiConfig.saveSecrets(secrets)
  secrets = secrets or {}
  local payload = {
    openai_api_key = tostring(secrets.openai_api_key or ""),
    custom_api_key = tostring(secrets.custom_api_key or ""),
    _note = AiConfig.SECRETS_NOTE,
  }
  local JsonEncode = V.require("ai/json_encode")
  local body = JsonEncode.encode(payload)
  local ok = writeFile(body)
  if ok then
    _secretsCache = {
      openai_api_key = payload.openai_api_key,
      custom_api_key = payload.custom_api_key,
    }
  end
  return ok == true
end

function AiConfig.apiKeyForProvider(mod, providerId)
  providerId = providerId or AiConfig.providerId(mod)
  local s = AiConfig.loadSecrets()
  if providerId == "openai" then
    return s.openai_api_key or ""
  end
  if providerId == "custom" then
    return s.custom_api_key or ""
  end
  -- Local: optional key (some local proxies want one)
  return s.custom_api_key or ""
end

function AiConfig.redact(value)
  if type(value) ~= "string" then return value end
  if #value < 8 then return "***" end
  return value:sub(1, 2) .. string.rep("*", math.min(12, #value - 4)) .. value:sub(-2)
end

--- Safe snapshot for diagnostics (no secrets).
function AiConfig.diagnostics(mod)
  return {
    enabled = AiConfig.enabled(mod),
    provider = AiConfig.providerId(mod),
    model = AiConfig.model(mod),
    endpoint = AiConfig.endpoint(mod),
    memory = AiConfig.memoryEnabled(mod),
    hasOpenAiKey = (AiConfig.loadSecrets().openai_api_key or "") ~= "",
    hasCustomKey = (AiConfig.loadSecrets().custom_api_key or "") ~= "",
    secretsStorage = AiConfig.SECRETS_NOTE,
  }
end

function AiConfig.resetCache()
  _secretsCache = nil
end

return AiConfig
