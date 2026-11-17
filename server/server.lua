local API <const> = 'https://discord.com/api/v10'
local CDN <const> = 'https://cdn.discordapp.com'
local VERSION <const> = GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or '1.0.0'
local AGENT <const> = ('DiscordBot (https://github.com/macullendev, %s)'):format(VERSION)

local convar = GetConvar('azurite_discord_token', '')
local token = ((convar ~= '' and convar or tostring(Config.Token or '')):gsub('^%s*[Bb]ot%s+', ''):gsub('%s+', ''))
local guild = (tostring(Config.Guild or ''):gsub('%D', ''))
local ttl = math.max(1, tonumber(Config.CacheMinutes) or 5) * 60000
local size = math.tointeger(tonumber(Config.Size)) or 128

local people, waiting = {}, {}
local roleIds, rolesExpire = {}, 0
local blockedUntil = 0
local disabled = token == ''

local function say(level, color, text)
    print(('^5[azurite_discord]^7 [%s%s^7] %s^7'):format(color, level, text))
end

local function call(path, tries)
    if disabled then return nil, 0 end
    tries = tries or 0
    local pause = blockedUntil - GetGameTimer()
    if pause > 0 then Wait(pause) end

    local p, settled = promise.new(), false
    local function settle(result)
        if settled then return end
        settled = true
        p:resolve(result)
    end
    PerformHttpRequest(API .. path, function(status, body)
        settle({ status = status, body = body })
    end, 'GET', '', { ['Authorization'] = 'Bot ' .. token, ['User-Agent'] = AGENT, ['Accept'] = 'application/json' })
    SetTimeout(8000, function() settle({ status = 0 }) end)

    local result = Citizen.Await(p)
    local ok, data = pcall(json.decode, result.body or '')
    if not ok then data = nil end

    if result.status == 429 and tries < 2 then
        blockedUntil = GetGameTimer() + math.ceil((type(data) == 'table' and tonumber(data.retry_after) or 1) * 1000)
        return call(path, tries + 1)
    end
    if result.status == 401 then
        disabled = true
        say('ERROR', '^1', 'Discord rejected the bot token. Copy it again from the Discord Developer Portal and restart.')
    end
    if result.status == 200 and type(data) == 'table' then return data, 200 end
    return nil, result.status
end

local function fileType(hash)
    return (Config.Animated and hash:sub(1, 2) == 'a_') and 'gif' or 'png'
end

local function stockPicture(seed)
    local n = math.tointeger(tonumber(seed))
    local index = n and n > 1000000 and ((n >> 22) % 6) or ((n or 0) % 6)
    return ('%s/embed/avatars/%d.png'):format(CDN, index)
end

local function pictureOf(id, hash, serverHash)
    if Config.ServerAvatars and serverHash and guild ~= '' then
        return ('%s/guilds/%s/users/%s/avatars/%s.%s?size=%d'):format(CDN, guild, id, serverHash, fileType(serverHash), size)
    end
    if hash then
        return ('%s/avatars/%s/%s.%s?size=%d'):format(CDN, id, hash, fileType(hash), size)
    end
    return stockPicture(id)
end

local function download(id)
    local now = GetGameTimer()
    if guild ~= '' then
        local member, status = call(('/guilds/%s/members/%s'):format(guild, id))
        if member then
            local user = member.user or {}
            return {
                id = id,
                inServer = true,
                name = member.nick or user.global_name or user.username,
                username = user.username,
                avatar = pictureOf(id, user.avatar, member.avatar),
                roles = member.roles or {},
                expires = now + ttl,
            }
        end
        if status ~= 404 and status ~= 403 and status ~= 0 then return nil end
    end
    local user = call(('/users/%s'):format(id))
    if user then
        return {
            id = id,
            inServer = false,
            name = user.global_name or user.username,
            username = user.username,
            avatar = pictureOf(id, user.avatar),
            roles = {},
            expires = now + ttl,
        }
    end
end

local function profile(id)
    local known = people[id]
    if known and known.expires > GetGameTimer() then return known end
    if waiting[id] then return Citizen.Await(waiting[id]) or nil end

    local p = promise.new()
    waiting[id] = p
    local entry = download(id)
    if not entry then
        if known then
            known.expires = GetGameTimer() + 60000
            entry = known
        else
            entry = { id = id, inServer = false, avatar = stockPicture(id), roles = {}, expires = GetGameTimer() + 60000 }
        end
    end
    people[id] = entry
    waiting[id] = nil
    p:resolve(entry)
    return entry
end

local function discordOf(src)
    local identifier = GetPlayerIdentifierByType(tostring(src), 'discord')
    if not identifier then return nil end
    return (identifier:gsub('^discord:', ''))
end

local function forPlayer(src)
    local id = discordOf(src)
    return id and profile(id) or nil
end

local function refreshRoles()
    if guild == '' or rolesExpire > GetGameTimer() then return end
    rolesExpire = GetGameTimer() + ttl
    local list = call(('/guilds/%s/roles'):format(guild))
    if not list then return end
    roleIds = {}
    for _, role in ipairs(list) do roleIds[tostring(role.name):lower()] = role.id end
end

local function resolveRole(role)
    role = (tostring(role or ''):gsub('^%s+', ''):gsub('%s+$', ''))
    if role:match('^%d+$') then return role end
    refreshRoles()
    return roleIds[role:lower()]
end

local function clone(list)
    local out = {}
    for i = 1, #list do out[i] = list[i] end
    return out
end

exports('GetDiscordId', discordOf)

exports('GetAvatar', function(src)
    local p = forPlayer(src)
    if p and p.avatar then return p.avatar end
    return Config.Fallback and stockPicture(src) or nil
end)

exports('GetName', function(src)
    local p = forPlayer(src)
    return p and p.name or nil
end)

exports('GetRoles', function(src)
    local p = forPlayer(src)
    return p and clone(p.roles) or {}
end)

exports('HasRole', function(src, roles)
    local p = forPlayer(src)
    if not p or #p.roles == 0 then return false end
    for _, role in ipairs(type(roles) == 'table' and roles or { roles }) do
        local id = resolveRole(role)
        if id then
            for _, mine in ipairs(p.roles) do
                if mine == id then return true end
            end
        end
    end
    return false
end)

exports('GetProfile', function(src)
    local p = forPlayer(src)
    if not p then return nil end
    return { id = p.id, name = p.name, username = p.username, avatar = p.avatar, roles = clone(p.roles), inServer = p.inServer }
end)

exports('Refresh', function(src)
    local id = discordOf(src)
    if not id then return nil end
    people[id] = nil
    return profile(id).avatar
end)

RegisterNetEvent('azurite_discord:spawned', function()
    local src = source
    if disabled then return end
    local id = discordOf(src)
    if id and not people[id] and not waiting[id] then profile(id) end
end)

CreateThread(function()
    if disabled then
        say('WARN', '^3', 'No bot token set. Add ^3set azurite_discord_token "your token"^7 to server.cfg. Until then players get the default Discord picture.')
        return
    end

    local me, status = call('/users/@me')
    if not me then
        if status ~= 401 then say('WARN', '^3', ('Could not reach Discord right now (status %s)'):format(status)) end
        return
    end
    say('INFO', '^2', ('Connected to Discord as ^3%s^7'):format(me.username))

    if guild == '' then
        say('WARN', '^3', 'Config.Guild is empty, so roles and server profile pictures are off.')
    elseif call(('/guilds/%s'):format(guild)) then
        refreshRoles()
    else
        say('WARN', '^3', 'The bot is not in the server set in Config.Guild. Invite it, or roles will not work.')
    end

    for _, src in ipairs(GetPlayers()) do forPlayer(src) end
end)
