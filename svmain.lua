isready = false
debugMode = false
settings = {}
OnlinePlayers = {}
-- FUNCTIONS
function has_value(tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end
    return false
end
function getSettings()
    local setters = MySQL.Sync.fetchAll('SELECT * FROM `_miav2Settings`')
    local whitelistenabled = "true"
    if setters[1].WL_Level == 0 then
        whitelistenabled = "false"
    end
    local setMenu = '| Whitelist: '..whitelistenabled..' | RequireSteam: '..tostring(setters[1].requireSteam)..' | RequireDiscord: '..tostring(setters[1].requireDiscord)..' |'
    ExecuteCommand(('sets MIAV2 "%s"'):format(setMenu))
    return setters[1]
end
function createUser(identifier, name, steam, discord, ip)
    MySQL.Sync.execute(
        'INSERT INTO `_miav2Users` (identifier, name, steam, discord, ip) VALUES (@identifier, @name, @steam, @discord, @ip)', {
            ['@identifier'] = identifier,
            ['@name']       = name,
            ['@steam']      = steam,
            ['@discord']    = discord,
            ['@ip']         = ip
        },
        function(rowsaffected)
            updateLog(rowsaffected.." User Created: ".. name .." ["..identifier.."]") 
        end)
end
function updateIdentifiers(identifier, name, steam, discord, ip)
    MySQL.Async.execute("UPDATE `_miav2Users` SET name=@name, steam=@steam, discord=@discord, ip=@ip WHERE identifier=@identifier", {
        ['@identifier'] = identifier,
        ['@name'] = name,
        ['@steam'] = steam,
        ['@discord'] = discord,
        ['@ip'] = ip
    })
end
function getUserFromID(license)
    local users = MySQL.Sync.fetchAll('SELECT * FROM `_miav2Users` WHERE `identifier` = @identifier', {
        ['@identifier'] = license,
    })
    return users[1]
end
function getUserFromSource(source)
    local license = nil
    for k,v in ipairs(GetPlayerIdentifiers(source))do
        if string.sub(v, 1, string.len("license:")) == "license:" then
            license = v
        end
    end
    if not license then
         print("Dafugg? no license? this shouldnt happen at this point.")
    end
    local users = MySQL.Sync.fetchAll('SELECT * FROM `_miav2Users` WHERE `identifier` = @identifier', {
        ['@identifier'] = license,
    })
    return users[1]
end
function checkPing()
    for k,player in #OnlinePlayers do
        currentPing = GetPlayerPing(k)
        if currentPing > settings.pingThreshold then
            kickPlayer(k, settings.kickMsgPing)            
        end
    end
end
function checkPlayer(player)
    local steam = nil
    local license = nil
    local ip = nil
    local discord = nil
    local name = GetPlayerName(player)
    for k,v in ipairs(GetPlayerIdentifiers(player))do
        if string.sub(v, 1, string.len("steam:")) == "steam:" then
            steam = v
        end
        if string.sub(v, 1, string.len("license:")) == "license:" then
            license = v
        end
        if string.sub(v, 1, string.len("ip:")) == "ip:" then
            ip = v
        end
        if string.sub(v, 1, string.len("discord:")) == "discord:" then
            discord = v
        end
    end
    if not license then
        return "Dafugg? no license, no come in. kthnxbye" -- why are you loggin in while not using license, get out.
    end
    if settings.requireSteam == true then
        if not steam then
            return settings.kickMsgSteam
        end
    end
    if settings.requireDiscord == true then
        if not discord then
            return settings.kickMsgDiscord
        end
    end
    local SecCheck = getUserFromID(license)
    if SecCheck == nil then
        createUser(license, name, steam, discord, ip)
        SecCheck = getUserFromID(license)
    else
        updateIdentifiers(license, name, steam, discord, ip)         
        SecCheck = getUserFromID(license)       
    end
    if settings.requireWhitelist == true then
        if (tonumber(SecCheck.wl) < tonumber(settings.WL_Level)) then
            return settings.kickMsgWhitelist
        end
    end
    if settings.requireBanCheck == true then
        if SecCheck.banned ~= nil then
            return settings.kickMsgBanned
        end
    end
    OnlinePlayers[player] = SecCheck
    return true
end
function kickPlayer(target, banBy)
    DropPlayer(target, '[MIAV2]: '.. banBy.. '')
end
function updateLog(text)
    text = '[MIAV2]: '..text
    print(text)
    return MySQL.Async.execute('INSERT INTO `_miav2Log` (`logmsg`) VALUES (@text)', {
        ['@text'] = text
    })
end
function setBan(identifier, banBy, banReason)
    return MySQL.Async.execute('UPDATE `_miav2Users` SET `banned` = 1, `banBy` = @banBy, `banReason` = @banReason where `identifier` = @identifier', {
        ['@identifier'] = identifier,
        ['@banBy'] = banBy,
        ['@banReason'] = banReason
    })
end
function wlUserUpdate(identifier, state)
    return MySQL.Async.execute('UPDATE `_miav2Users` set `wl` = @wl where `identifier` = @identifier', {
        ['@identifier'] = identifier,
        ['@wl'] = state
    })
end
function wlSettingUpdate(state)
    return MySQL.Async.execute('UPDATE `_miav2Settings` set `WL_Level` = @wl', {
        ['@wl'] = state
    })
end
function stringsplit(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t={} ; i=1
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        t[i] = str
        i = i + 1
    end
    return t
end
function updateCheck()
    local CurrentVersion = LoadResourceFile(GetCurrentResourceName(), "VERSION")
    PerformHttpRequest('https://raw.githubusercontent.com/mikethemadkiwi/MIAV/MIAV2/VERSION', function(Error, NewestVersion, Header)
            if tonumber(CurrentVersion) ~= tonumber(NewestVersion) then
                updateLog('MIAV2 HAS UPDATED!!!! Get the newest updates!! NAO!!!')
                updateLog('https://github.com/mikethemadkiwi/MIAV/blob/MIAV2/')
            else
                updateLog('MIAV2 is at Latest Version.')
            end
            CurrentVersion = nil
    end)
end
-- EVENT HANDLERS
AddEventHandler('onMySQLReady', function ()
    settings = getSettings()
    if settings ~= nil then
        isready = true
    end
    updateCheck() -- MOFO IS MY HAPPY
    updateLog("CORE LOADED")
end)
AddEventHandler("playerConnecting", function(name, setKickReason, deferrals)  
    if debugMode == true then
        setKickReason("[MIAV2: Testing Completed. Get out.]")
    end
    if isready == false then
        setKickReason("[MIAV2: SQL Connection NOT Ready]")
        CancelEvent()
    end 
    if #OnlinePlayers >= GetConvarInt('sv_maxclients', 64) then
        setReason('This server is full ')
        CancelEvent()
    end
    settings = getSettings()
    if settings.acceptPlayers == false then
        setKickReason("[MIAV2: Connection Refused]")
        CancelEvent()
    else
        playercheck = checkPlayer(source)
        if playercheck ~= true then
            updateLog(name .. ": ".. playercheck)
            setKickReason("[MIAV2]: ".. playercheck)
            CancelEvent()
        else
            updateLog("User Online: ".. OnlinePlayers[source].name.." ["..OnlinePlayers[source].identifier.."]") 
        end
    end
    if debugMode == true then
        CancelEvent()
    end
end)
AddEventHandler('chatMessage', function(source, name, msg)
    local chatmsg = chatMsgHandler(source, name, msg)
    CancelEvent() -- stop the event from being shown to the clients.
end)
AddEventHandler('playerDropped', function()
    updateLog('Player Drop: '.. GetPlayerName(source))
    OnlinePlayers[source] = nil
end)
-------------------------- CODE NOT ADDED YET --------------------------
-------------------------- CODE NOT ADDED YET --------------------------
------------------------------------------------------------------------

function setSetting(setting, value)
    local s = {
        'acceptPlayers',
        'requireSteam',
        'requireDiscord',
        'requireWhitelist',
        'requireBanCheck',
        'pingThreshold',
        'WL_Level'
    }
    if has_value(s, setting) then
        return MySQL.Sync.execute('UPDATE `_miav2Settings` SET @setting = @value', {
            ['@setting'] = tostring(setting),
            ['@value'] = value
        })
    end
    settings = getSettings()
end

function chatMsgHandler(source,name,msg)
    local user = getUserFromSource(source)
    sm = stringsplit(msg, " ")
        if user.wl >= settings.modLevel then            
            if sm[1] ~= nil then
                -- WL userlevel 
                if sm[1] == "/wluser" then
                    if sm[2] ~= nil then 
                        if sm[3] ~= nil then
                            local target = getUserFromSource(tonumber(sm[2]))
                            local newwlstate = tonumber(sm[3])
                            if newwlstate >= user.wl then newwlstate = user.wl end
                            if newwlstate < 0 then newwlstate = 0 end
                            wlUserUpdate(target.identifier, newwlstate)
                            updateLog("Whitelist Lvl of ".. target.name .."Updated to: ".. newwlstate .. " by ".. user.name)
                        end
                    end
                end
                -- WL Toggle 
                if sm[1] == "/wltoggle" then
                    if sm[2] ~= nil then 
                        local newwlstate = tonumber(sm[2])
                        if newwlstate > user.wl then newwlstate = user.wl end
                        if newwlstate < 0 then newwlstate = 0 end
                        wlSettingUpdate(newwlstate)
                        updateLog("Global Whitelist Lvl Updated to: ".. newwlstate .. " by ".. user.name)
                    end
                end 
                -- Ban All Cmmand
                if sm[1] == "/banall" then
                    if sm[2] ~= nil then
                        if sm[3] ~= nil then                            
                            local target = getUserFromSource(tonumber(sm[2]))
                            local kicktarget = sm[2]
                            local reason = string.sub(msg,9)                        
                            if target.wl < user.wl then                                
                                setBan(target.identifier, user.name, reason)
                                kickPlayer(kicktarget, settings.kickMsgBanned)
                            else                                
                                updateLog("Ban aborted, "..target.name.." [".. target.steam .."] is >= "..user.name.." ["..user.steam.."]")
                            end
                        else                                                   
                            updateLog( user.name .. " Attempted a ban without a reason, please try again")
                        end                    
                    end
                end
            end
        end
        if user.wl >= settings.AdminLevel then        
            if sm[1] ~= nil then  
                -- miav2 settings toggle
                -- if sm[1] == "/miav2set" then
                --     local key
                --     local value
                --     if sm[2] ~= nil then                    
                --         key = sm[2]
                --         if sm[3] ~= nil then                    
                --             value = tonumber(sm[3])
                --             setSetting(key, value)
                --         ---
                --         end
                --     end
                -- end
            end
        end
    return
end
-------------------------- CODE NOT ADDED YET --------------------------
-------------------------- CODE NOT ADDED YET --------------------------