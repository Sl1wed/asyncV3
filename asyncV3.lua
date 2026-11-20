local GITHUB_USER     = "Sl1wed"
local GITHUB_REPO     = "asynccc-keys"  -- FILL: your private repo name
local GITHUB_PAT      = "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"
local SCRIPT_URL      = "https://raw.githubusercontent.com/Sl1wed/asyncV4/refs/heads/main/asyncV4.lua"

local RAW_BASE = "https://raw.githubusercontent.com/" .. GITHUB_USER .. "/" .. GITHUB_REPO .. "/main/keys/"

local httpRequest = (syn and syn.request) or http_request or request or fluxus_request
if not httpRequest then error("[KeyGate] unsupported executor") end
local httpSvc = game:GetService("HttpService")

local function safeHTTP(opts)
    local ok, res = pcall(httpRequest, opts)
    return (ok and res) or nil
end

local function getHWID()
    for _, name in ipairs({ "hwid", "get_hwid", "gethwid" }) do
        local ok, v = pcall(function()
            local fn = getfenv(0)[name] or getfenv()[name]
            return fn and fn()
        end)
        if ok and type(v) == "string" and #v > 4 then return v end
    end
    local ok, v = pcall(function()
        return tostring(game:GetService("RbxAnalyticsService"):GetClientId())
    end)
    return (ok and v) or "UNKNOWN_HWID"
end

local function getIP()
    local res = safeHTTP({ Url = "https://api64.ipify.org?format=json", Method = "GET" })
    if res and res.StatusCode == 200 then
        local ok, t = pcall(function() return httpSvc:JSONDecode(res.Body) end)
        if ok and t and t.ip then return t.ip end
    end
    local res2 = safeHTTP({ Url = "https://api4.my-ip.io/ip", Method = "GET" })
    if res2 and res2.StatusCode == 200 then
        return res2.Body:match("^%s*(.-)%s*$")
    end
    return "UNKNOWN_IP"
end

local function trim(s) return s and s:match("^%s*(.-)%s*$") or "" end

local function fetchEntry(key)
    local res = safeHTTP({
        Url    = RAW_BASE .. key .. ".txt",
        Method = "GET",
    })
    warn("[KeyGate] fetch status: " .. tostring(res and res.StatusCode))
    if not res or res.StatusCode ~= 200 then return nil end
    local lines = {}
    for line in res.Body:gmatch("[^\r\n]+") do
        lines[#lines + 1] = trim(line)
    end
    warn("[KeyGate] file line1: " .. tostring(lines[1]))
    warn("[KeyGate] file line2: " .. tostring(lines[2]))
    warn("[KeyGate] file line3: " .. tostring(lines[3]))
    return lines
end

local function kick(reason)
    warn("[KeyGate] " .. reason)
    game:GetService("Players").LocalPlayer:Kick("[AsyncCC] " .. reason)
end

local function getKey()
    local gk = getgenv and getgenv().script_key
    if type(gk) == "string" and #trim(gk) > 0 then return trim(gk) end
    for _, name in ipairs({ "inputbox", "input_box", "prompt" }) do
        local fn = getfenv(0)[name] or getfenv()[name]
        if type(fn) == "function" then
            local ok, v = pcall(fn, "AsyncCC Key Gate", "Enter your key:", "")
            if ok and type(v) == "string" and #trim(v) > 0 then return trim(v) end
        end
    end
    if syn and syn.input_box then
        local ok, v = pcall(syn.input_box, { title = "AsyncCC Key Gate", text = "Enter your key:" })
        if ok and v then return trim(v) end
    end
    local readfile = getfenv(0)["readfile"] or getfenv()["readfile"]
    if type(readfile) == "function" then
        local ok, v = pcall(readfile, "asynccc/key.txt")
        if ok and v and #trim(v) > 0 then return trim(v) end
    end
    return nil
end

local key = getKey()
if not key or #key < 4 then
    kick("No key provided.")
    return
end

warn("[KeyGate] validating key: " .. key)

local hwid = getHWID()
local ip   = getIP()

warn("[KeyGate] HWID: " .. hwid)
warn("[KeyGate] IP: " .. ip)

local entry = fetchEntry(key)

if not entry then
    kick("Invalid key.")
    return
end

local storedKey  = entry[1] or ""
local storedIP   = entry[2] or ""
local storedHWID = entry[3] or ""

warn("[KeyGate] storedKey: " .. storedKey)
warn("[KeyGate] storedIP: " .. storedIP)
warn("[KeyGate] storedHWID: " .. storedHWID)

if storedKey ~= key then
    kick("Invalid key.")
    return
end
if storedHWID ~= hwid then
    kick("HWID mismatch. DM Sl1wed to reset.")
    return
end
if storedIP ~= ip then
    kick("IP mismatch. DM Sl1wed to reset.")
    return
end

warn("[KeyGate] authorised.")

local res = safeHTTP({ Url = SCRIPT_URL, Method = "GET" })
if not res or res.StatusCode ~= 200 or not res.Body or #res.Body < 10 then
    kick("Failed to fetch script.")
    return
end

local fn, err = loadstring(res.Body)
if not fn then
    kick("Script error: " .. tostring(err))
    return
end

warn("[KeyGate] loaded.")
fn()
