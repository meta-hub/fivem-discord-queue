-- Don't change code in here.
-- If errors occur, contact support (https://modit.store -> contact us)
-- All values you need to modify are in the config.lua file provided.

Queue         = {}
Queue.Current = {}

Queue.GetDiscordIdentifier = function(source)
  local identifiers = GetPlayerIdentifiers(source)
  for i=1,5 do
    for _,id in next,identifiers,nil do
      if id:find("discord") then
        return id
      end
    end
    Wait(1000)
  end
  return false
end

Queue.GetDiscordMember = function(identifier)
  local res,ret = false,false
  PerformHttpRequest(string.format('https://discordapp.com/api/guilds/%s/members/%s',Config.Tokens.Discord,identifier),function(err,data)
    if data then
      ret = json.decode(data)
    else
      ret = false
    end
    res = true
  end,'GET','',{['Content-Type'] = 'application/json', ['Authorization'] = Config.Tokens.Bot})
  while not res do Wait(0); end
  return ret
end

Queue.CheckDiscordRole = function(member,id)
  for _,role in ipairs(member.roles) do
    if role == id then
      return true
    end
  end
  return false
end

Queue.CheckInfront = function(source)
  local staff,priority,members = 0,0,0
  for k,v in ipairs(Queue.Current) do
    if v.source == source then
      return staff,priority,members
    else
      if v.queue == 1 then
        staff = staff + 1
      elseif v.queue == 2 then
        priority = priority + 1
      else
        members = members + 1
      end
    end
  end
  return staff,priority,members
end

Queue.Add = function(source,queue)
  if queue == 1 then
    for k,v in ipairs(Queue.Current) do
      if v.queue == 1 then
        last = k
      end

      if v.queue > 1 then
        table.insert(Queue.Current,k,{source = source, queue = queue})
        return
      end
    end
    table.insert(Queue.Current,1,{source = source, queue = queue})
  elseif queue == 2 then
    local last = 0
    for k,v in ipairs(Queue.Current) do
      if v.queue == 1 or v.queue == 2 then 
        last = k
      end

      if v.queue > 2 then
        table.insert(Queue.Current,k,{source = source, queue = queue})
        return
      end
    end
    table.insert(Queue.Current,last+1,{source = source, queue = queue})
  elseif queue == 3 then
    local last = 0
    for k,v in ipairs(Queue.Current) do
      if v.queue == 1 or v.queue == 2 or v.queue == 3 then 
        last = k
      end

      if v.queue > 3 then
        table.insert(Queue.Current,k,{source = source, queue = queue})
        return
      end
    end
    table.insert(Queue.Current,last+1,{source = source, queue = queue})
  elseif queue == 4 then
    table.insert(Queue.Current,{source = source, queue = queue})    
  end
end

Queue.Remove = function(source)
  for k,v in ipairs(Queue.Current) do
    if v.source == source then
      table.remove(Queue.Current,k)
      return
    end
  end
end

Queue.Ready = function(source)
  for k,v in ipairs(Queue.Current) do
    if v.source == source then
      if not GetPlayerName(source) then
        return false,false
      else
        return true,k
      end
    end
  end
end

Queue.Connect = function(name,setKickReason,deferrals)
  local _source = source

  deferrals.defer()
  Wait(0)  
  
  local identifier = Queue.GetDiscordIdentifier(_source)

  if identifier then
    deferrals.update("Checking discord identifier.")

    local id = identifier:gsub("discord:","")
    local member = Queue.GetDiscordMember(id)
    if member then
      if Config.Tokens.StaffRole and Queue.CheckDiscordRole(member,Config.Tokens.StaffRole) then
        deferrals.update("Connecting to server as staff.")
        Queue.Add(_source,1)
      elseif Config.Tokens.PriorityRole and Queue.CheckDiscordRole(member,Config.Tokens.PriorityRole) then
        deferrals.update("Connecting to server as priority.")
        Queue.Add(_source,2)
      elseif Config.Tokens.WhitelistRole and Queue.CheckDiscordRole(member,Config.Tokens.WhitelistRole) then
        deferrals.update("Connecting to server as whitelisted.")
        Queue.Add(_source,3)
      else
        if Config.Whitelisted then
          deferrals.done("You are not whitelisted.")
          return
        else
          deferrals.update("Connecting to server as unlisted.")
          Queue.Add(_source,4)
        end
      end

      local tick = 0
      while GetNumPlayerIndices() >= (Config.MaxPlayers-Config.ReserveSlots) do
        local connected,queue = Queue.Ready(_source)
        if not connected then
          Queue.Remove(_source)
          return
        else
          tick = tick + 1
          if tick > 3 then
            tick = 1
          end

          if GetNumPlayerIndices() < (Config.MaxPlayers) then
            if Config.Tokens.StaffRole and Queue.CheckDiscordRole(member,Config.Tokens.StaffRole) then
              break
            elseif Config.Tokens.PriorityRole and Queue.CheckDiscordRole(member,Config.Tokens.PriorityRole) then
              break
            else
              deferrals.update(string.format("Server full. Please wait%s",string.rep(".",tick)))
            end
          else
            deferrals.update(string.format("Server full. Please wait%s",string.rep(".",tick)))
          end
          Wait(1000)
        end
      end

      tick = 0

      local connected,queue = Queue.Ready(_source)
      while queue ~= 1 do
        if not connected then
          Queue.Remove(_source)
          return
        else
          local staff,priority,members = Queue.CheckInfront(_source)

          tick = tick + 1
          if tick > 3 then
            tick = 1
          end

          if Config.ShowStaffQueue and Config.ShowPriorityQueue then
            deferrals.update(string.format("%i staff, %i priority, %i member%s ahead of you in the queue%s",staff,priority,members,(members == 1 and "" or "s"),string.rep(".",tick)))
          elseif Config.ShowStaffQueue then
            deferrals.update(string.format("%i staff, %i member%s ahead of you in the queue%s",staff,members,(members == 1 and "" or "s"),string.rep(".",tick)))
          elseif Config.ShowPriorityQueue then
            deferrals.update(string.format("%i priority, %i member%s ahead of you in the queue%s",priority,members,(members == 1 and "" or "s"),string.rep(".",tick)))
          else
            deferrals.update(string.format("%i member%s ahead of you in the queue",queue-1,(queue-1 == 1 and "" or "s"),string.rep(".",tick)))
          end
          Wait(1000)
        end
      end

      Queue.Remove(_source)
      deferrals.done()
    else
      deferrals.done("You are not apart of the discord.")
    end
  else
    deferrals.done("You are not connected to discord.")
  end
end

RegisterNetEvent("playerConnecting")
AddEventHandler("playerConnecting",Queue.Connect)