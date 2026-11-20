local GITHUB_USER = "Sl1wed"
local GITHUB_REPO = "asynccc-keys"
local GITHUB_PAT  = "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"
local SCRIPT_URL  = "https://raw.githubusercontent.com/Sl1wed/asyncV4/refs/heads/main/asyncV4.lua"

local RAW_BASE = "https://raw.githubusercontent.com/" .. GITHUB_USER .. "/" .. GITHUB_REPO .. "/main/keys/"
local API_BASE = "https://api.github.com/repos/" .. GITHUB_USER .. "/" .. GITHUB_REPO .. "/contents/keys/"

local httpRequest = (syn and syn.request) or http_request or request or fluxus_request
if not httpRequest then error("[KeyGate] unsupported executor") end
local httpSvc = game:GetService("HttpService")

local function safeHTTP(opts)
    local ok, res = pcall(httpRequest, opts)
    return (ok and res) or nil
end

local function b64enc(data)
    local b = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    return ((data:gsub(".", function(x)
        local r, byte = "", x:byte()
        for i = 8, 1, -1 do
            r = r .. (byte % 2^i - byte % 2^(i-1) > 0 and "1" or "0")
        end
        return r
    end) .. "0000"):gsub("%d%d%d?%d?%d?%d?", function(x)
        if #x < 6 then return "" end
        local c = 0
        for i = 1, 6 do c = c + (x:sub(i,i) == "1" and 2^(6-i) or 0) end
        return b:sub(c+1, c+1)
    end) .. ({"", "==", "="})[#data % 3 + 1])
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
    if not res or res.StatusCode ~= 200 then return nil end
    local lines = {}
    for line in res.Body:gmatch("[^\r\n]+") do
        lines[#lines + 1] = trim(line)
    end
    return lines
end

local function fillEntry(key, hwid, ip)
    local apiUrl  = API_BASE .. key .. ".txt"
    local content = key .. "\n" .. ip .. "\n" .. hwid
    local b64     = b64enc(content)

    local existing = safeHTTP({
        Url     = apiUrl,
        Method  = "GET",
        Headers = {
            Authorization  = "token " .. GITHUB_PAT,
            ["User-Agent"] = "AsyncCC-KeyGate",
        },
    })

    warn("[KeyGate] SHA fetch status: " .. tostring(existing and existing.StatusCode))
    warn("[KeyGate] SHA fetch body: " .. tostring(existing and existing.Body))

    local sha = nil
    if existing and existing.StatusCode == 200 then
        local ok, t = pcall(function() return httpSvc:JSONDecode(existing.Body) end)
        if ok and t then sha = t.sha end
    end

    warn("[KeyGate] SHA: " .. tostring(sha))

    if not sha then return false end

    local payload = { message = "fill: " .. key, content = b64, sha = sha }

    local res = safeHTTP({
        Url     = apiUrl,
        Method  = "PUT",
        Headers = {
            Authorization    = "token " .. GITHUB_PAT,
            ["User-Agent"]   = "AsyncCC-KeyGate",
            ["Content-Type"] = "application/json",
        },
        Body = httpSvc:JSONEncode(payload),
    })

    warn("[KeyGate] PUT status: " .. tostring(res and res.StatusCode))
    warn("[KeyGate] PUT body: " .. tostring(res and res.Body))

    return res and (res.StatusCode == 200 or res.StatusCode == 201)
end

local function kick(reason)
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
    kick("Invalid key.")
    return
end

local hwid = getHWID()
local ip   = getIP()

local entry = fetchEntry(key)

if not entry then
    kick("Invalid key.")
    return
end

local storedKey  = entry[1] or ""
local storedIP   = entry[2] or ""
local storedHWID = entry[3] or ""

if storedIP == "" and storedHWID == "" then
    local ok = fillEntry(key, hwid, ip)
    if not ok then
        kick("Failed to activate key. DM Sl1wed.")
        return
    end
else
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
end

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

fn()
