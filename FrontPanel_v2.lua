-- Luau | FrontPanel_v2.lua | Roblox client | Pixel Front
local VERSION="4.0-breakout-strategy"
local RAW_URL="https://raw.githubusercontent.com/ICTtrying/pixelfront-script/main/FrontPanel_v2.lua"
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local UIS=game:GetService("UserInputService")
local Http=game:GetService("HttpService")
local player=Players.LocalPlayer
local pg=player:WaitForChild("PlayerGui")
for _,name in ipairs({"FrontPanelV2","FrontUITest"}) do
 local old=pg:FindFirstChild(name)
 if old then old:Destroy() end
end
local alive=true
local connections={}
local options={queue=false,spawn=false,expand=false,attack=false,defend=false,leave=false,
 dry=false,reserve=45,strength=2,interval=3,reload=true,skipHistorical=false,
 protect=true,cities=true,posts=true,nukes=false,upgradeCities=true,
 goldReserve=100000,minCluster=3,nukeDelay=60,maxCities=10,maxCityLevel=3,buildDelay=8,
 rivers=true,sams=true,maxFronts=3,riverRange=24,maxSams=4,botCities=true,preserveBotCities=true,
 growthAware=true,buyReinforcements=true,reinforce=true,growthFloor=25,reinforceDelay=6,maxBoosts=2}
local settings_path="frontpanel_"..tostring(player.UserId).."_settings.json"
local env={}
if type(getgenv)=="function" then
 local ok,value=pcall(getgenv)
 if ok and type(value)=="table" then env=value end
end
local storage_status="alleen deze uitvoering"
local storage_error=nil
local function valid_settings(value)
 if type(value)~="table" then return end
 for key,default in pairs(options) do
  if type(default)=="boolean" and type(value[key])=="boolean" then options[key]=value[key] end
 end
 for key,range in pairs({reserve={10,90},strength={1.2,10},interval={2,30},
  goldReserve={0,10000000},minCluster={2,12},nukeDelay={30,300},maxCities={1,40},
  maxCityLevel={1,10},buildDelay={5,60},maxFronts={1,4},riverRange={4,48},maxSams={1,12},
  growthFloor={15,60},reinforceDelay={4,30},maxBoosts={1,5}}) do
  local n=value[key]
  if type(n)=="number" and n==n and n>=range[1] and n<=range[2] then options[key]=n end
 end
end
valid_settings(env.FrontPanelSettings)
if type(readfile)=="function" then
 local exists=nil
 if type(isfile)=="function" then
  local ok,result=pcall(isfile,settings_path)
  if ok then exists=result end
 end
 if exists~=false then
  local ok,text=pcall(readfile,settings_path)
  if ok then
   local decoded,data=pcall(function() return Http:JSONDecode(text) end)
   if decoded then valid_settings(data) else storage_error="Instellingenbestand ongeldig; standaardwaarden gebruikt." end
  elseif exists then storage_error="Instellingen niet leesbaar: "..tostring(text) end
 end
end
local function save_settings()
 env.FrontPanelSettings=table.clone(options)
 if type(writefile)=="function" and type(readfile)=="function" then
  local ok,err=pcall(function() writefile(settings_path,Http:JSONEncode(options)) end)
  storage_status=ok and "op apparaat opgeslagen" or "alleen deze sessie"
  if not ok then storage_error=tostring(err) end
 else storage_status="alleen deze sessie; executor biedt geen bestandsopslag" end
end
local state={phase="waiting",players={},allies={},teams={},board={},incoming={},outgoing={},
 ready=false,frontier={},representatives={},pending={},generation=0,lastPlayers=0,
 lastFronts=0,lastAction=-100,spawnAt=-100,spawned=false,errorCount=0}
local history,toggles,tabs={},{},{}
local status,logbox,startup
local ui_loaded=false
local gui=Instance.new("ScreenGui")
gui.Name="FrontPanelV2"
gui.ResetOnSpawn=false
gui.DisplayOrder=100000
gui.Parent=pg
local panel=Instance.new("Frame")
panel.Size=UDim2.new(0,460,0,300)
panel.Position=UDim2.new(0.5,-230,0.5,-150)
panel.BackgroundColor3=Color3.fromRGB(20,25,35)
panel.BorderSizePixel=0
panel.Parent=gui
local title=Instance.new("TextLabel")
title.Size=UDim2.new(1,-100,0,38)
title.BackgroundTransparency=1
title.TextColor3=Color3.new(1,1,1)
title.TextSize=17
title.Text="FRONT PANEL "..VERSION
title.Parent=panel
local function simple_button(text,x,y,w,h,parent)
 local b=Instance.new("TextButton")
 b.Size=UDim2.new(0,w,0,h)
 b.Position=UDim2.new(0,x,0,y)
 b.BackgroundColor3=Color3.fromRGB(35,80,145)
 b.TextColor3=Color3.new(1,1,1)
 b.TextSize=15
 b.TextWrapped=true
 b.Text=text
 b.Parent=parent
 return b
end
local minimize=simple_button("-",366,2,42,34,panel)
local close=simple_button("X",412,2,42,34,panel)
local collapsed=false
local expanded=panel.Size
local function cleanup()
 if not alive then return end
 alive=false
 state.generation=state.generation+1
 for _,c in ipairs(connections) do c:Disconnect() end
end
close.Activated:Connect(function() cleanup(); gui:Destroy() end)
minimize.Activated:Connect(function()
 collapsed=not collapsed
 panel.Size=collapsed and UDim2.new(0,460,0,38) or expanded
 for _,tab in pairs(tabs) do tab.page.Visible=not collapsed and tab.selected end
 for _,child in ipairs(panel:GetChildren()) do
  if child~=title and child~=minimize and child~=close then
   if child:IsA("GuiObject") and not child:IsA("ScrollingFrame") then
    child.Visible=not collapsed and (child~=startup or not ui_loaded)
   end
  end
 end
 minimize.Text=collapsed and "+" or "-"
end)
startup=Instance.new("TextLabel")
startup.Size=UDim2.new(1,-20,1,-50)
startup.Position=UDim2.new(0,10,0,42)
startup.Text="UI laden... Als dit blijft staan, is het bestand mogelijk onvolledig geplakt."
startup.TextColor3=Color3.new(1,1,1)
startup.TextWrapped=true
startup.TextSize=16
startup.BackgroundColor3=Color3.fromRGB(20,25,35)
startup.ZIndex=20
startup.Parent=panel
local function log(message)
 local line=os.date("%H:%M:%S").." "..tostring(message)
 table.insert(history,line)
 if #history>40 then table.remove(history,1) end
 if logbox then logbox.Text=table.concat(history,"\n") end
 print("[FrontPanel] "..line)
end
local function refresh_toggles()
 for key,item in pairs(toggles) do
  item.button.Text=item.name..": "..(options[key] and "AAN" or "UIT")
  item.button.BackgroundColor3=options[key] and Color3.fromRGB(30,125,80) or Color3.fromRGB(35,80,145)
 end
 title.Text="FRONT PANEL 3.6 | "..(options.dry and "OBSERVATIE" or "ACTIEF")
end
local function halt(reason)
 for _,key in ipairs({"queue","spawn","expand","attack","defend","leave","cities","posts","nukes","sams","reinforce","buyReinforcements"}) do options[key]=false end
 refresh_toggles()
 save_settings()
 state.reason=reason or "Gestopt"
 if reason then
  log(reason)
  if status then status.Text=tostring(reason) end
 end
end
local function guard(fn)
 return function(...)
  if not alive then return end
  local ok,err=xpcall(fn,debug.traceback,...)
  if not ok then
   local message=tostring(err)
   if state.engineFault~=message then log("FOUT (acties gepauzeerd, instellingen behouden): "..message) end
   state.engineFault=message;state.ready=false
   if status then status.Text="ACTIES GEPAUZEERD\n"..message.."\nInstellingen blijven aan. Gebruik Synchroniseer opnieuw." end
  end
 end
end
local function connect(signal,fn)
 table.insert(connections,signal:Connect(guard(fn)))
end
local function select_tab(name)
 for key,tab in pairs(tabs) do
  tab.selected=key==name
  tab.page.Visible=tab.selected and not collapsed
 end
end
local function row(tab,class,props)
 local t=tabs[tab]
 local object=Instance.new(class)
 for k,v in pairs(props) do object[k]=v end
 object.Position=UDim2.new(0,0,0,t.y)
 object.Parent=t.page
 t.y=t.y+object.Size.Y.Offset+8
 t.page.CanvasSize=UDim2.new(0,0,0,t.y)
 return object
end
local function label(tab,text,height)
 return row(tab,"TextLabel",{Size=UDim2.new(1,-10,0,height or 45),BackgroundTransparency=1,
  Text=text,TextWrapped=true,TextColor3=Color3.new(1,1,1),TextSize=14,
  TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top})
end
local function button(tab,text,callback)
 local b=row(tab,"TextButton",{Size=UDim2.new(1,-10,0,38),Text=text,
  BackgroundColor3=Color3.fromRGB(35,80,145),TextColor3=Color3.new(1,1,1),TextSize=15,TextWrapped=true})
 b.Activated:Connect(guard(callback))
 return b
end
local function toggle(tab,name,key)
 toggles[key]={name=name,button=button(tab,name,function()
  options[key]=not options[key];state.reason=nil;refresh_toggles();save_settings()
  log(name..": "..tostring(options[key]))
  if key=="dry" then log(options.dry and "Observatie: geen spelorders." or "Actieve modus: ingeschakelde functies versturen orders.") end
 end)}
end
local function number_input(tab,name,key,lo,hi)
 label(tab,name,25)
 local box=row(tab,"TextBox",{Size=UDim2.new(1,-10,0,35),Text=tostring(options[key]),
  BackgroundColor3=Color3.fromRGB(40,45,60),TextColor3=Color3.new(1,1,1),TextSize=16,ClearTextOnFocus=false})
 box.FocusLost:Connect(function()
  local value=tonumber(box.Text)
  if value and value==value and value>=lo and value<=hi then options[key]=value;save_settings() end
  box.Text=tostring(options[key])
 end)
end
local ui_ok,ui_error=xpcall(function()
 panel.ClipsDescendants=true
 for i,name in ipairs({"Overzicht","Match","Oorlog","Instellen","Foutlog"}) do
  local page=Instance.new("ScrollingFrame")
  page.Position=UDim2.new(0,112,0,44)
  page.Size=UDim2.new(1,-120,1,-90)
  page.CanvasSize=UDim2.new(0,0,0,0)
  page.BackgroundTransparency=1
  page.BorderSizePixel=0
  page.ScrollBarThickness=4
  page.Visible=false
  page.Parent=panel
  tabs[name]={page=page,y=0,selected=false}
  local name_copy=name
  simple_button(name,5,44+(i-1)*40,100,35,panel).Activated:Connect(function() select_tab(name_copy) end)
 end
 status=label("Overzicht","Spelverbinding wordt geladen...",400)
 label("Overzicht","Zet de gewenste functies aan. ACTIEF voert orders uit. OBSERVATIE toont alleen plannen. Instellingen worden automatisch opgeslagen wanneer je executor dit ondersteunt.",100)
 toggle("Match","Auto join","queue"); toggle("Match","Auto spawn","spawn"); toggle("Match","Verlaat na einde","leave")
 toggle("Match","Herladen na teleport","reload")
 toggle("Match","Historisch overslaan","skipHistorical")
 label("Match","Auto spawn kiest op historische kaarten een groot beschikbaar land; op andere kaarten een vrije plek. Herladen wordt aangevraagd bij je executor en is afhankelijk van diens ondersteuning.",120)
 toggle("Oorlog","Uitbreiden","expand"); toggle("Oorlog","Zwakke buren aanvallen","attack"); toggle("Oorlog","Verdedigen","defend")
 toggle("Oorlog","Bescherm tegen buren","protect")
 toggle("Oorlog","Steden bouwen","cities")
 toggle("Oorlog","Grensposten bouwen","posts")
 toggle("Oorlog","Nuke op vijandelijk cluster","nukes")
 toggle("Oorlog","Rivieren oversteken","rivers")
 toggle("Oorlog","Anti-nuke bij steden","sams")
 toggle("Oorlog","Botlanden met steden eerst","botCities")
 toggle("Oorlog","Zwakke botsteden heel houden","preserveBotCities")
 toggle("Oorlog","Groeicurve benutten","growthAware")
 toggle("Oorlog","Lopende fronten versterken","reinforce")
 toggle("Oorlog","Reinforcement met goud kopen","buyReinforcements")
 label("Oorlog","Nukes: alleen atoomwapens, alleen tegen een actief front, met meerdere steden binnen de zekere binnenradius. Geen eigen of geallieerde grond binnen de buitenradius. Beschikbare tokens en goud bepalen of een order mogelijk is.",160)
 toggle("Instellen","Observatiemodus","dry")
 button("Instellen","Echte acties aanzetten",function()
  options.dry=false;refresh_toggles();save_settings();log("ACTIEF: ingeschakelde functies voeren echte orders uit.")
 end)
 number_input("Instellen","Reserve % van troepencap","reserve",10,90)
 number_input("Instellen","Sterkteverhouding","strength",1.2,10)
 number_input("Instellen","Actievertraging in seconden","interval",2,30)
 toggle("Instellen","Veilige steden upgraden","upgradeCities")
 number_input("Instellen","Goud achterhouden","goldReserve",0,10000000)
 number_input("Instellen","Maximaal aantal steden","maxCities",1,40)
 number_input("Instellen","Maximaal stadsniveau","maxCityLevel",1,10)
 number_input("Instellen","Seconden tussen bouworders","buildDelay",5,60)
 number_input("Instellen","Minimale steden in nukecluster","minCluster",2,12)
 number_input("Instellen","Seconden tussen nukes","nukeDelay",30,300)
 number_input("Instellen","Maximale actieve fronten incl. transport","maxFronts",1,4)
 number_input("Instellen","Maximale waterzoekafstand in tegels","riverRange",4,48)
 number_input("Instellen","Maximale anti-nuketorens","maxSams",1,12)
 number_input("Instellen","Rustige uitbreiding: minimale reserve %","growthFloor",15,60)
 number_input("Instellen","Seconden tussen versterkingen per doel","reinforceDelay",4,30)
 number_input("Instellen","Extra orders zonder terreinwinst per doel","maxBoosts",1,5)
 button("Foutlog","Kopieer foutlog",function()
  if type(setclipboard)=="function" then setclipboard(table.concat(history,"\n"))
  else log("Geen klembordfunctie; maak een screenshot.") end
 end)
 logbox=row("Foutlog","TextBox",{Size=UDim2.new(1,-10,0,800),Text="",TextSize=13,
  TextColor3=Color3.new(1,1,1),BackgroundColor3=Color3.fromRGB(30,35,45),TextWrapped=true,
  TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,
  MultiLine=true,ClearTextOnFocus=false,TextEditable=false})
 local stop=simple_button("NOODSTOP",5,258,450,36,panel)
 stop.BackgroundColor3=Color3.fromRGB(160,45,65)
 stop.Activated:Connect(function() halt("Noodstop: geen nieuwe automatische orders.") end)
 select_tab("Overzicht")
 refresh_toggles()
 ui_loaded=true
 startup.Visible=false
 log("UI "..VERSION.." volledig geladen.")
 save_settings()
 log("Instellingen: "..storage_status)
 if storage_error then log(storage_error) end
end,debug.traceback)
if not ui_ok then
 startup.Visible=true
 startup.Text="UI-FOUT: "..tostring(ui_error)
 return
end
local drag=nil
title.Active=true
connect(title.InputBegan,function(input)
 if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then
  drag={input=input,start=input.Position,origin=panel.Position}
 end
end)
connect(UIS.InputChanged,function(input)
 if not drag then return end
 if input~=drag.input and input.UserInputType~=Enum.UserInputType.MouseMovement then return end
 local delta=input.Position-drag.start
 panel.Position=UDim2.new(drag.origin.X.Scale,drag.origin.X.Offset+delta.X,
  drag.origin.Y.Scale,drag.origin.Y.Offset+delta.Y)
end)
connect(UIS.InputEnded,function(input)
 if drag and (input==drag.input or input.UserInputType==Enum.UserInputType.MouseButton1) then drag=nil end
end)
gui.Destroying:Connect(cleanup)

local function setup_reload()
 local queue_function=env.queue_on_teleport or env.queueonteleport or queue_on_teleport or queueonteleport
 if type(queue_function)~="function" then
  for _,provider in ipairs({"syn","fluxus","delta"}) do
   local api=env[provider]
   if type(api)=="table" and type(api.queue_on_teleport)=="function" then queue_function=api.queue_on_teleport;break end
  end
 end
 if type(queue_function)~="function" then
  state.reloadStatus="executor biedt geen teleport-hook"
  log("Automatisch herladen niet beschikbaar: voer de loader na teleport opnieuw uit.")
  return
 end
 state.reloadStatus="beschikbaar via executor"
 connect(player.OnTeleport,function(teleport_state)
  if teleport_state==Enum.TeleportState.Failed then state.teleportQueued=false;return end
  if not options.reload or state.teleportQueued then return end
  if teleport_state~=Enum.TeleportState.Started and teleport_state~=Enum.TeleportState.InProgress then return end
  save_settings()
  local snapshot=Http:JSONEncode(options)
  local payload=string.format([=[
task.spawn(function()
 local ok,err=pcall(function()
  if not game:IsLoaded() then game.Loaded:Wait() end
  task.wait(2)
  if type(getgenv)=="function" then
   getgenv().FrontPanelSettings=game:GetService("HttpService"):JSONDecode(%q)
  end
  local source=game:HttpGet(%q)
  local run,compile_error=loadstring(source)
  assert(run,compile_error)
  run()
 end)
 if not ok then warn("[FrontPanel herladen] "..tostring(err)) end
end)
]=],snapshot,RAW_URL.."?v=4.0")
  local ok,err=pcall(queue_function,payload)
  if ok then
   state.teleportQueued=true
   log("Herladen na teleport aangevraagd; instellingen meegenomen.")
  else
   state.reloadStatus="fout: "..tostring(err)
   log("Herladen aanvragen mislukt: "..tostring(err))
  end
 end)
 log("Teleport-hook verbonden.")
end

local Config,Net,MapGen,Matchmaker,Scenarios,Nukes,folder,Maps
local W,H,N
local Strategy={}
local message_decoders={
    roster={"unpackRoster","decodeRoster"},
    structs={"unpackStructs","unpackStructures","unpackStructEvents","unpackStructureEvents","decodeStructures"},
    players={"unpackPlayers","decodePlayers"},
    vehicles={"unpackVehicles","decodeVehicles"},
    armies={"unpackArmies","decodeArmies"},
    allies={"unpackAllies","unpackIds","unpackIdList"},
    frontList={"unpackFrontList","unpackAttacks","unpackFronts"},
    fronts={"unpackFronts","decodeFronts"},
    diplomacy={"unpackDiplomacy","unpackDiplo"},
}
local function valid_list(kind,list)
    if type(list)~="table" then return false end
    local length=#list
    local keys=0
    for key in pairs(list) do
        if type(key)~="number" or key%1~=0 or key<1 or key>length then return false end
        keys=keys+1
    end
    if keys~=length then return false end
    for _,entry in ipairs(list) do
        if kind=="allies" then
            if type(entry)~="number" then return false end
        elseif type(entry)~="table" then return false
        elseif kind=="structs" then
            if type(entry.tile)~="number" or entry.tile<0 or entry.tile>=N
                or type(entry.ownerId)~="number" or type(entry.level)~="number" then return false end
        elseif kind=="roster" then
            if type(entry.i)~="number" then return false end
        elseif kind=="players" then
            if type(entry.id)~="number" or type(entry.troops)~="number" or type(entry.tiles)~="number" or type(entry.alive)~="boolean" then return false end
        elseif kind=="vehicles" then
            if type(entry.owner)~="number" or type(entry.kind)~="number" then return false end
        elseif kind=="armies" then
            if type(entry.id)~="number" or type(entry.t)~="number" or type(entry.troops)~="number"
                or type(entry.x)~="number" or type(entry.y)~="number" then return false end
        elseif kind=="frontList" then
            if type(entry.id)~="number" or type(entry.troops)~="number" then return false end
        end
    end
    return true
end
local function message_table(kind,payload)
    if type(payload)=="table" then return payload end
    for _,name in ipairs(message_decoders[kind] or {}) do
        if Net and type(Net[name])=="function" then
            local ok,result=pcall(Net[name],payload)
            if ok and type(result)=="table" then return result end
        end
    end
    return nil
end
local function structure_list(payload)
    if type(payload)~="table" then return nil,"verwacht gebouwtabel" end
    local root=payload
    if root.tile~=nil then root={root}
    else
        for _,key in ipairs({"structures","entries","events","list"}) do
            if type(root[key])=="table" then root=root[key];break end
        end
    end
    local result={}
    for key,entry in pairs(root) do
        if type(entry)~="table" then return nil,"record "..tostring(key).." is "..typeof(entry)..", geen gebouwrecord" end
        local tile=tonumber(entry.tile)
        local owner=tonumber(entry.ownerId)
        local level=tonumber(entry.level)
        if owner==0 and entry.level==nil then level=0 end
        local kind=entry.kind==nil and 1 or tonumber(entry.kind)
        local function integer(value) return type(value)=="number" and value==value and value%1==0 end
        if not integer(tile) or tile<0 or tile>=N then
            return nil,"record "..tostring(key)..": tile="..tostring(entry.tile).." ("..typeof(entry.tile).."), kaart N="..tostring(N)
        end
        if not integer(owner) or owner<0 or owner>255 then return nil,"record "..tostring(key)..": ownerId="..tostring(entry.ownerId).." ("..typeof(entry.ownerId)..")" end
        if not integer(level) or level<0 then return nil,"record "..tostring(key)..": level="..tostring(entry.level).." ("..typeof(entry.level)..")" end
        if not integer(kind) or kind<1 then return nil,"record "..tostring(key)..": kind="..tostring(entry.kind).." ("..typeof(entry.kind)..")" end
        local copy=table.clone(entry)
        copy.tile=tile;copy.ownerId=owner;copy.level=level;copy.kind=kind
        result[#result+1]=copy
    end
    return result
end
local function structure_shape(payload)
    if type(payload)~="table" then return "type="..typeof(payload) end
    local fields={}
    local record=nil
    if payload.tile~=nil then record=payload end
    for key,value in pairs(payload) do
        if #fields<8 then fields[#fields+1]=tostring(key)..":"..typeof(value) end
        if not record and type(value)=="table" then record=value end
    end
    local recordFields={}
    for key,value in pairs(record or {}) do
        if #recordFields>=10 then break end
        recordFields[#recordFields+1]=tostring(key)..":"..typeof(value)
    end
    return "root={"..table.concat(fields,",").."}; eerste record={"..table.concat(recordFields,",").."}"
end
local function message_issue(kind,payload,critical,detail)
    state.protocolWarnings=state.protocolWarnings or {}
    state.protocolBlocks=state.protocolBlocks or {}
    state.protocolWarningTypes=state.protocolWarningTypes or {}
    local size=typeof(payload)=="buffer" and (", "..buffer.len(payload).." bytes") or ""
    local message=kind..": ontvangen "..typeof(payload)..size.."; geen compatibele lijstdecoder"
    if detail then message=message.." | "..detail end
    local changed=state.protocolWarningTypes[kind]~=typeof(payload)
    if changed then
        state.protocolWarningTypes[kind]=typeof(payload)
        state.protocolWarnings[kind]=message
        log("BERICHTFORMAAT: "..message)
        if kind=="structs" then log("GEBOUWDETAILS: "..structure_shape(payload)) end
        if not state.decoderNamesLogged then
            local names={}
            for name,fn in pairs(Net or {}) do
                if type(name)=="string" and type(fn)=="function" and name:find("unpack",1,true) then names[#names+1]=name end
            end
            table.sort(names);log("Beschikbare decoders: "..table.concat(names,", "))
            state.decoderNamesLogged=true
        end
    end
    if critical then state.protocolBlocks[kind]=message end
    if kind=="structs" then
        state.structuresReady=false
        if changed then log("Gebouwafhankelijke orders wachten op betrouwbare gebouwgegevens.") end
    elseif kind=="vehicles" then state.transportKnown=false end
    if kind=="armies" then state.armies=nil end
end
local function message_list(kind,payload,critical)
    local list=message_table(kind,payload)
    if kind=="structs" then
        local normalized,reason=structure_list(list)
        if not normalized then message_issue(kind,payload,critical,reason);return nil end
        list=normalized
    end
    if not valid_list(kind,list) then message_issue(kind,payload,critical);return nil end
    if state.protocolWarnings then state.protocolWarnings[kind]=nil end
    if state.protocolWarningTypes then state.protocolWarningTypes[kind]=nil end
    if state.protocolBlocks then state.protocolBlocks[kind]=nil end
    return list
end
local function pause_map(reason)
    if not state.awaitingInit then
        state.generation=state.generation+1
        state.ready=false;state.snapshotReady=false;state.indexing=false
        state.pending={};state.awaitingInit=true
        state.mapFault=tostring(reason)
        log("KAART GEPAUZEERD: "..state.mapFault)
        log("Geen spelorders; schakelaars en opgeslagen instellingen blijven behouden.")
    end
    return false
end
local function decode_delta(data)
    assert(typeof(data)=="buffer","Delta is geen buffer maar "..typeof(data))
    local length=buffer.len(data)
    assert(length>=2,"Delta mist groepsheader")
    local offset=2
    local groups=buffer.readu16(data,0)
    assert(groups<=256,"Onverwacht aantal groepen: "..groups)
    local changes={}
    local pairCount=0
    local function read_byte()
        assert(offset<length,"Afgekapt deltapakket op byte "..offset)
        local value=buffer.readu8(data,offset);offset=offset+1
        return value
    end
    for _=1,groups do
        local owner=read_byte()
        local low,high=read_byte(),read_byte()
        local count=low+high*256
        pairCount=pairCount+count
        assert(pairCount<=math.min(N*2,65536),"Te veel deltaparen: "..pairCount)
        local tile=0
        for _=1,count do
            local value,factor,bytes=0,1,0
            while true do
                local byte=read_byte();bytes=bytes+1
                assert(bytes<=4,"Varint langer dan vier bytes")
                value=value+(byte%128)*factor
                if byte<128 then break end
                factor=factor*128
            end
            tile=tile+value
            assert(tile>=0 and tile<N,string.format("tegel=%s buiten kaart N=%s (%sx%s), pakket=%s bytes",tile,N,W,H,length))
            changes[#changes+1]=tile;changes[#changes+1]=owner
        end
    end
    assert(offset==length,"Ongelezen deltabytes: "..(length-offset))
    return changes
end
local function load_module(shared,name)
    local m=shared:FindFirstChild(name)
    assert(m and m:IsA("ModuleScript"),"Ontbrekende module: "..name)
    return require(m)
end
local function neighbours(tile,callback)
    local x=tile%W
    if tile>=W then callback(tile-W) end
    if tile<N-W then callback(tile+W) end
    if x>0 then callback(tile-1) end
    if x<W-1 then callback(tile+1) end
end
local function passable(tile)
    local b=buffer.readu8(state.terrain,tile)
    return bit32.btest(b,128) and bit32.band(b,63)<63
end
local function refresh_tile(tile)
    if not state.terrain or not state.owners then return end
    local candidate=false
    if buffer.readu8(state.owners,tile)~=state.id and passable(tile) then
        neighbours(tile,function(other)
            if buffer.readu8(state.owners,other)==state.id then candidate=true end
        end)
    end
    state.frontier[tile]=candidate or nil
    state.coast=state.coast or {}
    local coast=false
    if buffer.readu8(state.owners,tile)==state.id and passable(tile) then
        neighbours(tile,function(other)
            if not bit32.btest(buffer.readu8(state.terrain,other),128) then coast=true end
        end)
    end
    state.coast[tile]=coast or nil
end
local function apply_delta(data)
    if state.awaitingInit then return false end
    local ok,changes=pcall(decode_delta,data)
    if not ok then
        local prefix={}
        if typeof(data)=="buffer" then
            for i=0,math.min(buffer.len(data),16)-1 do prefix[#prefix+1]=string.format("%02x",buffer.readu8(data,i)) end
        end
        return pause_map(tostring(changes).." | header="..table.concat(prefix," "))
    end
    local touched={}
    for i=1,#changes,2 do
        local tile,owner=changes[i],changes[i+1]
        local previous=buffer.readu8(state.owners,tile)
        buffer.writeu8(state.owners,tile,owner)
        if owner==state.id and previous~=state.id then state.lastCaptureAt=os.clock() end
        if state.structures and state.structures[tile] then state.cityCache=nil end
        if owner==state.id then Strategy.sample_owned(tile) end
        touched[tile]=true
        if owner~=0 and owner~=state.id then state.representatives[owner]=tile end
    end
    if state.terrain then
        for tile in pairs(touched) do
            refresh_tile(tile)
            neighbours(tile,refresh_tile)
        end
    end
    state.lastGoodDelta=os.clock()
    return true
end
local function index_map(generation)
    task.spawn(guard(function()
        state.ready=false
        for tile=0,N-1 do
            if not alive or generation~=state.generation then return end
            refresh_tile(tile)
            local owner=buffer.readu8(state.owners,tile)
            if owner==state.id then Strategy.sample_owned(tile) end
            if owner~=0 and owner~=state.id and not state.representatives[owner] then
                state.representatives[owner]=tile
            end
            if tile%12000==0 then task.wait() end
        end
        if generation==state.generation then
            state.ready=true
            log("Kaart gereed: "..N.." tegels.")
        end
    end))
end
local function finish_map()
    if state.terrain and state.snapshotReady and not state.indexing then
        state.indexing=true
        index_map(state.generation)
    end
end
local function resolve_geometry(payload,terrain)
    local count=buffer.len(terrain)
    local candidates={}
    local function add(w,h,label)
        if type(w)=="number" and type(h)=="number" then candidates[#candidates+1]={w,h,label} end
    end
    add(payload.mapWidth,payload.mapHeight,"init.mapWidth")
    add(payload.width,payload.height,"init.width")
    if Maps and type(Maps.get)=="function" then
        local ok,data=pcall(Maps.get,payload.mapId or "us")
        if ok and type(data)=="table" then
            add(data.WIDTH,data.HEIGHT,"Maps.get")
            add(data.width,data.height,"Maps.get.width")
        end
    end
    add(Config.MAP_W,Config.MAP_H,"Config")
    local details={}
    for _,entry in ipairs(candidates) do
        local w,h=entry[1],entry[2]
        details[#details+1]=entry[3].."="..w.."x"..h
        if w>0 and h>0 and w%1==0 and h%1==0 and w<=8192 and h<=8192 and w*h==count and count<=16000000 then
            return w,h,count,entry[3]
        end
    end
    error("Kaartmetadata wijkt af: terrein="..count.." bytes; "..table.concat(details,", "))
end
local function finalize_snapshot()
    if state.waitingDimensions or not state.snapshotComplete then return end
    local input=state.snapshot
    local owners=buffer.create(N)
    if state.snapshotRaw then
        assert(buffer.len(input)==N,"Raw kaartlengte wijkt af van terrein")
        buffer.copy(owners,0,input)
    else
        local r,pos,total=0,0,buffer.len(input)
        while r<total do
            local owner=buffer.readu8(input,r);r+=1
            local run,scale=0,1
            for step=1,5 do
                assert(r<total,"Onvolledige kaartrun")
                local value=buffer.readu8(input,r);r+=1
                run+=(value%128)*scale
                if value<128 then break end
                assert(step<5,"Kaartvarint te lang")
                scale*=128
            end
            assert(run>0 and run<=N-pos,"Kaart-RLE buiten bereik")
            buffer.fill(owners,pos,owner,run);pos+=run
        end
        assert(pos==N,"Onvolledige kaartdekking")
    end
    state.owners=owners;state.snapshotReady=true
    state.snapshot=nil;state.snapshotComplete=false
    for _,data in ipairs(state.pending) do if not apply_delta(data) then return end end
    state.pending={};finish_map()
end
local function fresh()
    return state.ready and os.clock()-state.lastPlayers<5 and os.clock()-state.lastFronts<5
end
local function friendly(id)
    if id==state.id or state.allies[id] then return true end
    local me=state.players[state.id]
    local other=state.players[id]
    return me and other and me.team~=nil and me.team==other.team
end
function Strategy.distance(a,b)
    local dx=a%W-b%W
    local dy=math.floor(a/W)-math.floor(b/W)
    return math.sqrt(dx*dx+dy*dy)
end
function Strategy.city_value(id)
    if not state.cityCache or state.cityCacheOwners~=state.owners or state.cityCacheStructs~=state.structures
        or os.clock()-(state.cityCacheAt or -100)>1 then
        state.cityCache={};state.cityCacheAt=os.clock()
        state.cityCacheOwners=state.owners;state.cityCacheStructs=state.structures
        for _,s in pairs(state.structures or {}) do
            if s.kind==1 and buffer.readu8(state.owners,s.tile)==s.ownerId then
                local value=state.cityCache[s.ownerId] or {0,0,0}
                value[1]=value[1]+1;value[2]=value[2]+(s.level or 1)*(s.uc and 0.5 or 1)
                if not s.uc then value[3]=value[3]+1 end
                state.cityCache[s.ownerId]=value
            end
        end
    end
    local value=state.cityCache[id]
    if not value then return 0,0,0 end
    return value[1],value[2],value[3]
end
function Strategy.threat_factor(id)
    local other=state.players[id]
    if not other or other.isBot~=true then return 1 end
    local cities=Strategy.city_value(id)
    return cities>0 and 0.45 or 0.20
end
function Strategy.opportunity_ratio(id,covered)
    local me,enemy=state.players[state.id],state.players[id]
    if not me or not enemy or not enemy.alive or friendly(id) or me.troops<=0 then return nil end
    if me.troops<enemy.troops*options.strength then return nil end
    local capacity=Strategy.capacity(me)
    local required=math.min(capacity*options.reserve/100,me.troops*(enemy.isBot==true and 0.30 or 0.40))
    if enemy.isBot~=true and enemy.troops>me.troops*0.12 then
        for _,front in ipairs(state.outgoing) do
            local other=state.players[front.id]
            if front.id~=id and other and other.isBot~=true and other.alive then return nil end
        end
    end
    if options.protect then required=math.max(required,Strategy.risk_reserve()) end
    local multiplier=covered and 2 or (enemy.isBot==true and 0.9 or 1.4)
    local needed=math.max(Config.MIN_ATTACK_TROOPS or 250,enemy.troops*multiplier)
    local best=nil
    for _,ratio in ipairs(Config.attackPresets(state.mode)) do
        local committed=math.floor(me.troops*ratio)
        if committed>=needed and me.troops-committed>=required and (not best or ratio<best) then best=ratio end
    end
    return best,required
end
function Strategy.breakout_ratio(id,covered,support)
    local me,enemy=state.players[state.id],state.players[id]
    if not options.attack or not me or not enemy or not enemy.alive or friendly(id) or #state.incoming>0 then return nil end
    local deployed=0
    for _,front in ipairs(state.outgoing) do
        if front.id~=id and front.id~=0 then return nil end
        if front.id==id then deployed+=front.troops end
    end
    if me.troops+deployed*0.60<enemy.troops*1.15 then return nil end
    local strongest,total=0,0
    for other,c in pairs(Strategy.contacts()) do
        if other~=id then
            local strength=c.troops*Strategy.threat_factor(other)
            strongest=math.max(strongest,strength);total+=strength
        end
    end
    local reserve=math.max(me.troops*0.25,strongest*0.55+total*0.10+enemy.troops*0.10)
    local needed=math.max(Config.MIN_ATTACK_TROOPS or 250,enemy.troops*(covered and 0.50 or 0.25))
    if support then needed=math.max(Config.MIN_ATTACK_TROOPS or 250,enemy.troops*(covered and 0.24 or 0.12)) end
    local best=nil
    for _,ratio in ipairs(Config.attackPresets(state.mode)) do
        local sent=math.floor(me.troops*ratio)
        if ratio<=0.50 and sent>=needed and me.troops-sent>=reserve and (not best or ratio<best) then best=ratio end
    end
    return best,reserve
end
function Strategy.breakout_plan(targets)
    local me=state.players[state.id]
    if not options.attack or not me or #state.incoming>0 or #state.outgoing>0 then state.boxedSince=nil;return nil end
    if targets[0] then state.boxedSince=nil;return nil end
    for id in pairs(state.waterTargets or {}) do if id==0 and options.rivers then state.boxedSince=nil;return nil end end
    local now=os.clock()
    state.boxedSince=state.boxedSince or now
    local progress=math.max(state.boxedSince,state.lastCaptureAt or 0,state.playingAt or 0)
    if now-progress<30 or now-(state.lastBreakoutAt or -10000)<60 then return nil end
    local best,bestRatio,bestReserve,bestScore=nil,nil,nil,-math.huge
    for id,tile in pairs(targets) do
        if id~=0 then
            local ratio,reserve=Strategy.breakout_ratio(id,state.targetProtected[id],false)
            local enemy=state.players[id]
            if ratio and enemy then
                local cities=Strategy.city_value(id)
                local score=-enemy.troops/math.max(1,me.troops)*1000+math.min(cities,5)*20
                if score>bestScore then best,bestRatio,bestReserve,bestScore=id,ratio,reserve,score end
            end
        end
    end
    return best,bestRatio,bestReserve
end
function Strategy.target_score(id,tile,distance)
    local me,enemy=state.players[state.id],state.players[id]
    if not me or not enemy or not enemy.alive or friendly(id) then return nil end
    if not options.attack and not (options.expand and enemy.isBot==true) then return nil end
    if me.troops<enemy.troops*options.strength then return nil end
    local cities,value,complete=Strategy.city_value(id)
    local priority=enemy.isBot==true and 2 or 1
    if enemy.isBot==true and options.botCities and cities>0 then priority=4 end
    local exposed=enemy.isBot~=true and enemy.troops<=me.troops*0.12
    if exposed then priority=3.5 end
    return priority*100000+math.min(value,100)*100+math.min(complete,30)*50
        -enemy.troops/math.max(1,me.troops)*200-Strategy.nearby_danger(tile)*50-(distance or 0)*4,
        cities,enemy.isBot==true
end
function Strategy.contacts()
    local contacts={}
    for tile in pairs(state.frontier) do
        local id=buffer.readu8(state.owners,tile)
        local other=state.players[id]
        if id~=0 and other and other.alive and not friendly(id) then
            local c=contacts[id]
            if not c then c={id=id,tile=tile,border=0,troops=other.troops,points={}};contacts[id]=c end
            c.border=c.border+1
            if #c.points<24 then table.insert(c.points,tile)
            else local k=math.random(1,c.border);if k<=24 then c.points[k]=tile end end
        end
    end
    for id,entry in pairs(state.waterTargets or {}) do
        local other=state.players[id]
        if id~=0 and other and other.alive and not friendly(id) and not contacts[id] then
            contacts[id]={id=id,tile=entry.tile,border=1,troops=other.troops,points={entry.tile}}
        end
    end
    return contacts
end
function Strategy.water_targets()
    if not options.rivers then state.waterTargets={};return state.waterTargets end
    if os.clock()-(state.lastWaterScan or -10000)<6 then return state.waterTargets or {} end
    state.lastWaterScan=os.clock()
    local queue,depth,seen,targets={},{},{},{}
    local function push(tile,d)
        if not seen[tile] and #queue<12000 then
            seen[tile]=true;queue[#queue+1]=tile;depth[#queue]=d
        end
    end
    local origins=0
    local shores={}
    for tile in pairs(state.coast or {}) do
        origins=origins+1
        if #shores<256 then shores[#shores+1]=tile
        else local k=math.random(1,origins);if k<=256 then shores[k]=tile end end
    end
    for _,tile in ipairs(shores) do
        neighbours(tile,function(other)
            if not bit32.btest(buffer.readu8(state.terrain,other),128) then push(other,1) end
        end)
    end
    local head=1
    while head<=#queue do
        local tile,d=queue[head],depth[head];head=head+1
        neighbours(tile,function(other)
            if passable(other) then
                local id=buffer.readu8(state.owners,other)
                if id~=state.id and (id==0 or not friendly(id)) and (state.blockedLanding[other] or 0)<os.clock() then
                    if not targets[id] or d<targets[id].distance then targets[id]={tile=other,distance=d} end
                end
            elseif d<options.riverRange and not bit32.btest(buffer.readu8(state.terrain,other),128) then
                push(other,d+1)
            end
        end)
    end
    state.waterTargets=targets
    return targets
end
function Strategy.active_orders()
    local afloat=state.transportCount or 0
    local pending=0
    for id,entry in pairs(state.riverOrders or {}) do
        if entry.untilTime<=os.clock() then state.riverOrders[id]=nil
        elseif not entry.failed then pending=pending+1 end
    end
    return #state.outgoing+math.max(afloat,pending)
end
function Strategy.sam_spot()
    local cities,sams,candidates={},{},{}
    local coverage=Nukes and Nukes.samRange and Nukes.samRange(1) or 70
    for _,s in pairs(state.structures) do
        if s.ownerId==state.id then
            if s.kind==1 then table.insert(cities,s)
            elseif s.kind==5 then table.insert(sams,s) end
        end
    end
    if #sams>=options.maxSams then return nil end
    local important={}
    for _,city in ipairs(cities) do
        local covered=false
        for _,sam in ipairs(sams) do
            local r=Nukes and Nukes.samRange and Nukes.samRange(sam.level or 1) or coverage
            if Strategy.distance(city.tile,sam.tile)<=r then covered=true;break end
        end
        if not covered then
            table.insert(important,city)
            local x,y=city.tile%W,math.floor(city.tile/W)
            for _,offset in ipairs({{20,0},{-20,0},{0,20},{0,-20},{20,20},{-20,20},{20,-20},{-20,-20}}) do
                local px,py=x+offset[1],y+offset[2]
                if px>=0 and px<W and py>=0 and py<H then candidates[#candidates+1]=py*W+px end
            end
        end
    end
    for _,tile in pairs(state.ownedSamples or {}) do candidates[#candidates+1]=tile end
    local best,bestScore=nil,0
    for _,tile in ipairs(candidates) do
        if buffer.readu8(state.owners,tile)==state.id and passable(tile) and (state.blockedBuild[tile] or 0)<os.clock() then
            local clear=true
            for _,s in pairs(state.structures) do
                if Strategy.distance(tile,s.tile)<(Config.STRUCTURE_MIN_DIST or 15)+2 then clear=false;break end
            end
            if clear then
                local value=0
                for _,city in ipairs(important) do
                    if Strategy.distance(tile,city.tile)<=coverage*0.85 then value=value+(city.level or 1)+2 end
                end
                local score=value-Strategy.nearby_danger(tile)*2
                if value>0 and score>bestScore then best,bestScore=tile,score end
            end
        end
    end
    return best
end
function Strategy.risk_reserve()
    local top,second,count,total,rawTop=0,0,0,0,0
    for id,c in pairs(Strategy.contacts()) do
        local troops=c.troops*Strategy.threat_factor(id)
        rawTop=math.max(rawTop,c.troops)
        count=count+1
        total=total+troops
        if troops>top then second,top=top,troops
        elseif troops>second then second=troops end
    end
    local incoming=0
    for _,a in ipairs(state.incoming) do incoming=incoming+a.troops end
    state.strongestNeighbour=rawTop;state.weightedThreat=top;state.neighbourCount=count
    return math.ceil(top*0.65+second*0.20+total*0.20+incoming*1.20)
end
function Strategy.sample_owned(tile)
    if not state.ownedSamples then state.ownedSamples={} end
    state.ownedSamples[math.random(1,512)]=tile
end
function Strategy.nearby_danger(tile)
    local me=state.players[state.id]
    if not me then return math.huge end
    local x,y=tile%W,math.floor(tile/W)
    local risk=0
    for _,r in ipairs({8,18,30}) do
        for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1},{1,1},{-1,1},{1,-1},{-1,-1}}) do
            local px,py=x+d[1]*r,y+d[2]*r
            if px>=0 and px<W and py>=0 and py<H then
                local id=buffer.readu8(state.owners,py*W+px)
                if id~=0 and not friendly(id) then
                    local enemy=state.players[id]
                    risk=risk+(enemy and math.min(5,enemy.troops/math.max(1,me.troops))*Strategy.threat_factor(id) or 1)*(32-r)/16
                end
            end
        end
    end
    return risk
end
function Strategy.open_tile()
    local best,bestScore=nil,-math.huge
    local seen=0
    for tile in pairs(state.frontier) do
        if buffer.readu8(state.owners,tile)==0 then
            seen=seen+1
            if seen<=120 or math.random(1,seen)<=120 then
                local free=0
                neighbours(tile,function(other)
                    if passable(other) and buffer.readu8(state.owners,other)==0 then free=free+1 end
                end)
                local score=free*3-Strategy.nearby_danger(tile)*8-bit32.band(buffer.readu8(state.terrain,tile),63)*0.1
                if score>bestScore then best,bestScore=tile,score end
            end
        end
    end
    return best
end
function Strategy.build_spot(kind)
    local best,bestScore=nil,-math.huge
    local spacing=(Config.STRUCTURE_MIN_DIST or 15)+2
    local contacts=Strategy.contacts()
    for _,tile in pairs(state.ownedSamples or {}) do
        if buffer.readu8(state.owners,tile)==state.id and passable(tile)
            and (state.blockedBuild[tile] or 0)<os.clock() then
            local closest=math.huge
            local same=math.huge
            for _,s in pairs(state.structures) do
                local d=Strategy.distance(tile,s.tile)
                closest=math.min(closest,d)
                if s.ownerId==state.id and s.kind==kind then same=math.min(same,d) end
            end
            if closest>=spacing then
                local danger=Strategy.nearby_danger(tile)
                local score=nil
                local blast=Nukes and Nukes.magnitude(13)
                local ownCities=Strategy.city_value(state.id)
                local citySpacing=ownCities<3 and spacing or (blast and blast.outer or 30)*2+8
                if kind==1 and danger<1 and same>=citySpacing then
                    local own=0
                    local x,y=tile%W,math.floor(tile/W)
                    for _,d in ipairs({{12,0},{-12,0},{0,12},{0,-12},{18,18},{-18,-18},{18,-18},{-18,18}}) do
                        local px,py=x+d[1],y+d[2]
                        if px>=0 and px<W and py>=0 and py<H and buffer.readu8(state.owners,py*W+px)==state.id then own=own+1 end
                    end
                    if own>=(ownCities<3 and 2 or 4) then score=own*10+math.min(same,70)-danger*80 end
                elseif kind==3 then
                    local border=math.huge
                    for _,c in pairs(contacts) do
                        local attacking=false
                        for _,a in ipairs(state.incoming) do if a.id==c.id then attacking=true;break end end
                        if attacking or (state.players[c.id] and state.players[c.id].isBot~=true)
                            or c.troops*Strategy.threat_factor(c.id)>=(state.weightedThreat or 0)*0.7 then
                            for _,point in ipairs(c.points) do border=math.min(border,Strategy.distance(tile,point)) end
                        end
                    end
                    if border<= (Config.DEFENSE_POST_RANGE or 30) and same>=(Config.DEFENSE_POST_RANGE or 30)*1.2 then
                        score=80-border+danger*12
                    end
                end
                if score and score>bestScore then best,bestScore=tile,score end
            end
        end
    end
    return best
end
function Strategy.cluster_candidate()
    if not state.structuresReady or not Nukes then return nil end
    local mag=Nukes.magnitude(13)
    if not mag then return nil end
    local atWar={}
    for _,a in ipairs(state.incoming) do if a.id~=0 then atWar[a.id]=true end end
    for _,a in ipairs(state.outgoing) do if a.id~=0 then atWar[a.id]=true end end
    local cities={}
    local me=state.players[state.id]
    local attackers={}
    for _,a in ipairs(state.incoming) do attackers[a.id]=true end
    for _,s in pairs(state.structures) do
        local enemy=state.players[s.ownerId]
        local captureInstead=options.preserveBotCities and enemy and enemy.isBot==true and me
            and me.troops>=enemy.troops*options.strength and not attackers[s.ownerId]
        if s.kind==1 and not s.uc and atWar[s.ownerId] and not friendly(s.ownerId) and not captureInstead then
            if buffer.readu8(state.owners,s.tile)==s.ownerId then table.insert(cities,s) end
            if #cities>=48 then break end
        end
    end
    local candidates={}
    for _,s in ipairs(cities) do table.insert(candidates,s.tile) end
    for i=1,#cities do
        for j=i+1,#cities do
            if #candidates>=144 then break end
            local a,b=cities[i],cities[j]
            if a.ownerId==b.ownerId and Strategy.distance(a.tile,b.tile)<=mag.inner*2 then
                local x=math.floor((a.tile%W+b.tile%W)/2)
                local y=math.floor((math.floor(a.tile/W)+math.floor(b.tile/W))/2)
                table.insert(candidates,y*W+x)
            end
        end
    end
    local ranked={}
    for _,tile in ipairs(candidates) do
        local owner=buffer.readu8(state.owners,tile)
        if atWar[owner] and not friendly(owner) and passable(tile) then
            local count,score=0,0
            for _,s in ipairs(cities) do
                if s.ownerId==owner then
                    local d=Strategy.distance(tile,s.tile)
                    if d<=mag.inner then count=count+1;score=score+3*(s.level or 1)
                    elseif d<=mag.outer then score=score+0.5*(s.level or 1) end
                end
            end
            if count>=options.minCluster then table.insert(ranked,{tile=tile,count=count,score=score}) end
        end
    end
    table.sort(ranked,function(a,b) return a.score>b.score end)
    for i=1,math.min(12,#ranked) do
        local candidate=ranked[i]
        local tile=candidate.tile
        local clear=true
        local x,y=tile%W,math.floor(tile/W)
        local radius=math.ceil(mag.outer)+2
        for dy=-radius,radius do
            for dx=-radius,radius do
                if dx*dx+dy*dy<=radius*radius then
                    local px,py=x+dx,y+dy
                    if px>=0 and px<W and py>=0 and py<H then
                        local owner=buffer.readu8(state.owners,py*W+px)
                        if owner~=0 and friendly(owner) then clear=false;break end
                    end
                end
            end
            if not clear then break end
        end
        for _,s in pairs(state.structures) do
            if clear and s.kind==5 and not s.uc and not friendly(s.ownerId) then
                local samRange=Nukes.samRange and Nukes.samRange(s.level or 1) or 70
                if Strategy.distance(tile,s.tile)<=samRange then clear=false end
            end
        end
        for _,blast in ipairs(state.plannedBlasts or {}) do
            if blast.untilTime>os.clock() and Strategy.distance(tile,blast.tile)<mag.outer*2 then clear=false end
        end
        if clear then return candidate end
    end
    return nil
end
local function send(payload,description)
    if os.clock()-state.lastAction<options.interval then return false end
    state.lastAction=os.clock()
    if options.dry then state.reason="Observatie: "..description;log("PLAN: "..description); return false end
    folder.Intent:FireServer(payload)
    state.lastCommand=payload
    if payload.t=="attack" and state.owners and state.frontier[payload.tile] then
        state.landOrders=state.landOrders or {}
        state.landOrders[buffer.readu8(state.owners,payload.tile)]={tile=payload.tile,at=os.clock()}
    end
    state.reason="Order verstuurd: "..description
    log("ORDER: "..description)
    return true
end
function Strategy.try_nuke()
    if not options.nukes or os.clock()-(state.lastNuke or -10000)<options.nukeDelay then return false end
    if not state.structuresReady or not state.gold then return false end
    local free=(state.freeNukes or 0)>0
    if not free and state.gold-(Config.ATOM_BOMB_COST or 750000)<options.goldReserve then return false end
    if Config.NUKE_REQUIRES_SILO~=false then
        state.nukeReason="Nukeplanner wacht op ondersteunde siloregels";return false
    end
    if os.clock()-(state.lastNukeScan or -10000)<8 then return false end
    state.lastNukeScan=os.clock()
    local candidate=Strategy.cluster_candidate()
    if not candidate then state.nukeReason="Geen vrij cluster zonder geallieerde schade of SAM-dekking";return false end
    if send({t="nuke",tile=candidate.tile,kind=13},"atoomnuke op "..candidate.count.." geconcentreerde steden") then
        state.lastNuke=os.clock();state.lastSend=os.clock()
        table.insert(state.plannedBlasts,{tile=candidate.tile,untilTime=os.clock()+180})
    end
    return true
end
function Strategy.try_buy_reinforcements()
    if not options.buyReinforcements then return false end
    local me=state.players[state.id]
    if not me or not me.alive or not state.gold or state.reinforceDenied then return false end
    local access,held=pcall(function() return player:GetAttribute("ConquestPass_BARRACKS") end)
    if not access or held~=true then return false end
    if not state.reinforceQuoteAt or os.clock()-state.reinforceQuoteAt>5 then return false end
    if os.clock()<(state.reinforceCooldownUntil or 0) or os.clock()<(state.reinforceReadyAt or math.huge) or os.clock()<(state.reinforcePendingUntil or 0) then return false end
    local cost,troops=state.reinforceCost,state.reinforceTroops
    if type(cost)~="number" or cost<0 or type(troops)~="number" or troops<=0 or state.gold<cost then return false end
    local cap=Strategy.capacity(me)
    local room=math.max(0,cap-me.troops)
    local benefit=math.min(room,troops)
    local need=Strategy.risk_reserve()
    local emergency=#state.incoming>0 or me.troops<need*1.15
    local active=#state.outgoing>0
    local useful=benefit>=math.min(cap*0.10,troops*0.80)
    if benefit<=0 or not useful then return false end
    if not emergency and (not active or me.troops>=cap*0.65 or state.gold-cost<options.goldReserve) then return false end
    if send({t="reinforce"},"reinforcement kopen: +"..math.floor(benefit).." troepen voor "..math.floor(cost).." goud") then
        state.lastSend=os.clock();state.reinforcePendingUntil=os.clock()+8
        return true
    end
    return false
end
function Strategy.city_affordable(cost,free,count,defensive)
    if free then return true end
    if type(cost)~="number" or cost<0 or not state.gold or state.gold<cost then return false end
    local floor=options.goldReserve
    if count<3 and not defensive then floor=0 end
    return state.gold-cost>=floor
end
function Strategy.try_build(defensive)
    if not state.structuresReady or not state.gold or os.clock()-(state.lastBuild or -10000)<options.buildDelay then return false end
    local contacts=Strategy.contacts()
    local me=state.players[state.id]
    local highThreat=defensive
    for id,c in pairs(contacts) do
        local enemy=state.players[id]
        if enemy and enemy.isBot~=true and (c.troops>=me.troops*0.35 or (state.levels or 0)>=3) then highThreat=true end
        if c.troops*Strategy.threat_factor(id)>=me.troops*0.8 then highThreat=true end
    end
    local kind,tile,cost,free=nil,nil,nil,false
    if options.posts and highThreat then
        local posts=0
        for _,s in pairs(state.structures) do if s.ownerId==state.id and s.kind==3 then posts=posts+1 end end
        if posts<math.max(1,math.min(5,state.neighbourCount or 1)) then
            free=(state.freePosts or 0)>0;cost=state.postCost
            local cashFloor=defensive and 0 or math.min(options.goldReserve,state.gold*0.20)
            if free or (cost and state.gold-cost>=cashFloor) then tile=Strategy.build_spot(3);kind=3 end
        end
    end
    if not tile and options.sams and (defensive or Strategy.city_value(state.id)>=3 or not options.cities) then
        free=(state.freeSams or 0)>0;cost=state.samCost;kind=5
        if free or (cost and state.gold-cost>=options.goldReserve) then tile=Strategy.sam_spot() end
    end
    if not tile and options.cities and not defensive then
        local cities={}
        for _,s in pairs(state.structures) do if s.ownerId==state.id and s.kind==1 then table.insert(cities,s) end end
        cost=state.cityCost;free=(state.freeCities or 0)>0;kind=1
        if #cities<options.maxCities and Strategy.city_affordable(cost,free,#cities,defensive) then tile=Strategy.build_spot(1) end
        if not tile and options.upgradeCities and cost and state.gold-cost>=options.goldReserve then
            local lowest=math.huge
            for _,s in ipairs(cities) do
                if not s.uc and s.level<math.min(options.maxCityLevel,Config.STRUCTURE_MAX_LEVEL or 10)
                    and s.level<lowest and Strategy.nearby_danger(s.tile)<1
                    and (state.blockedBuild[s.tile] or 0)<os.clock() then tile=s.tile;lowest=s.level end
            end
        end
    end
    if not tile then return false end
    state.lastBuild=os.clock()
    local description=kind==1 and "stad op veilige, verspreide locatie bouwen/upgraden"
        or kind==5 and "anti-nuketoren voor ongedekte belangrijke steden bouwen"
        or "verdedigingspost bij bedreigde grens bouwen"
    if send({t="build",tile=tile,kind=kind},description) then
        state.lastSend=os.clock();state.blockedBuild[tile]=os.clock()+30
    end
    return true
end
function Strategy.capacity(me)
    return math.max(1,(Config.MAX_TROOPS_MULT or 1)*(
        me.tiles^Config.TROOPS_TILE_EXPONENT*Config.TROOPS_PER_TILE_COEF+Config.BASE_MAX_TROOPS
    )+(state.levels or 0)*Config.CITY_TROOP_INCREASE+(state.capBonus or 0))
end
function Strategy.growth_model(troops,cap)
    return ((Config.GROWTH_BASE or 10)+math.max(0,troops)^(Config.GROWTH_EXPONENT or 0.73)/(Config.GROWTH_DIVISOR or 4))
        *math.max(0,1-troops/cap)
end
function Strategy.growth_peak(cap)
    if state.growthProfile and math.abs(state.growthProfile.cap-cap)/cap<0.01 then return state.growthProfile.fraction end
    local best,bestGain=0.4,-1
    for step=5,95 do
        local fraction=step/100
        local gain=Strategy.growth_model(cap*fraction,cap)
        if gain>bestGain then best,bestGain=fraction,gain end
    end
    state.growthProfile={cap=cap,fraction=best}
    return best
end
function Strategy.growth_ready(ratio)
    if not ratio then return false end
    if not options.growthAware then return true end
    local me=state.players[state.id]
    if not me then return false end
    local cap=Strategy.capacity(me)
    local peak=Strategy.growth_peak(cap)
    local trigger=math.clamp(peak/math.max(0.01,1-ratio)-0.04,0.45,0.75)
    state.economicStatus=string.format("%.0f%% gevuld; groeipiekmodel %.0f%%; ordervenster vanaf %.0f%%",me.troops/cap*100,peak*100,trigger*100)
    return me.troops/cap>=trigger
end
function Strategy.observe_growth(previous,current)
    if not previous or not current then return end
    local dt=os.clock()-(state.lastPlayers or 0)
    local delta=current.troops-previous.troops
    if dt<0.1 or dt>3 or delta<0 or os.clock()-(state.lastSend or -100)<math.max(1,options.interval) then return end
    if #state.incoming>0 then return end
    local oldCap,newCap=Strategy.capacity(previous),Strategy.capacity(current)
    if math.abs(newCap-oldCap)/oldCap>0.01 then return end
    local rate=delta/dt
    local estimate=Strategy.growth_model(current.troops,newCap)*(Config.TICK_RATE or 10)
    if rate>math.max(50,estimate*5) then return end
    state.measuredGrowth=state.measuredGrowth and state.measuredGrowth*0.7+rate*0.3 or rate
end
local function choose_ratio(defending,economic)
    local me=state.players[state.id]
    if not me or not me.alive or me.troops<=0 then return nil end
    local cap=Strategy.capacity(me)
    local reserve=options.reserve
    if economic and options.growthAware and not defending then reserve=math.min(reserve,options.growthFloor) end
    local required=cap*reserve/100
    state.baseReserve=required
    local risk=Strategy.risk_reserve()
    if options.protect and not defending then required=math.max(required,risk) end
    state.requiredReserve=math.ceil(required)
    local best,bestGain=nil,-math.huge
    for _,ratio in ipairs(Config.attackPresets(state.mode)) do
        local committed=math.floor(me.troops*ratio)
        if committed>=(Config.MIN_ATTACK_TROOPS or 250) and me.troops-committed>=required then
            if economic and options.growthAware then
                local gain=Strategy.growth_model(me.troops-committed,cap)
                if gain>bestGain then best,bestGain=ratio,gain end
            elseif not best or ratio<best then best=ratio end
        end
    end
    return best
end
local function enemy_targets()
    local result,scores,seen={},{},{}
    state.targetProtected={}
    for tile in pairs(state.frontier) do
        local id=buffer.readu8(state.owners,tile)
        if id~=state.id and (id==0 or not friendly(id)) then
            seen[id]=(seen[id] or 0)+1
            if seen[id]<=32 then
                local covered=false
                for _,s in pairs(state.structures or {}) do
                    if s.ownerId==id and s.kind==3 and not s.uc
                        and Strategy.distance(tile,s.tile)<=(Config.DEFENSE_POST_RANGE or 30) then covered=true;break end
                end
                local score=-bit32.band(buffer.readu8(state.terrain,tile),63)-(covered and 100 or 0)
                if not scores[id] or score>scores[id] then
                    result[id]=tile;scores[id]=score;state.targetProtected[id]=covered
                end
            end
        end
    end
    return result
end
function Strategy.try_reinforce(targets,normalRatio,economicRatio,economicReady)
    if not options.reinforce or #state.outgoing==0 then return false end
    local me=state.players[state.id]
    local now=os.clock()
    local busy={}
    for _,front in ipairs(state.outgoing) do busy[front.id]=true end
    local slots=math.min(options.maxFronts,Config.MAX_FRONTS_PER_PLAYER or 4)
    if Strategy.active_orders()<slots then
        for id,tile in pairs(targets) do
            local other=state.players[id]
            if not busy[id] and other and other.isBot==true and Strategy.city_value(id)>0
                and economicRatio and economicReady and Strategy.target_score(id,tile,0) then return false end
        end
    end
    state.boosts=state.boosts or {}
    local best=nil
    for _,front in ipairs(state.outgoing) do
        local id=front.id
        local enemy=state.players[id]
        local economic=id==0 or (enemy and enemy.isBot==true)
        local enabled=(id==0 and options.expand) or (id~=0 and (options.attack or (economic and options.expand)))
        local ratio=economic and economicRatio or normalRatio
        local tile=targets[id]
        local breakout=state.breakout and state.breakout.id==id and now<state.breakout.untilTime
        if breakout then ratio=Strategy.breakout_ratio(id,state.targetProtected[id],true) end
        if id==0 then
            tile=nil
            local anchor=nil
            for _,army in ipairs(state.armies or {}) do
                if army.id==state.id and army.t==0 then
                    local x,y=math.floor(army.x),math.floor(army.y)
                    if x>=0 and x<W and y>=0 and y<H then anchor=y*W+x;break end
                end
            end
            local last=state.landOrders and state.landOrders[0]
            if not anchor and last and now-last.at<30 then anchor=last.tile end
            if anchor then
                local closest=65
                for candidate in pairs(state.frontier) do
                    if buffer.readu8(state.owners,candidate)==0 then
                        local d=Strategy.distance(anchor,candidate)
                        if d<closest then closest=d;tile=candidate end
                    end
                end
            end
        end
        local record=state.boosts[id] or {at=-10000,bursts=0,captureAt=-10000}
        if (state.lastCaptureAt or -10000)>record.captureAt then record.bursts=0 end
        local eligible=id==0 or breakout or Strategy.target_score(id,tile or 0,0)~=nil
        if enabled and ratio and tile and eligible and not friendly(id)
            and (not options.protect or not state.targetProtected[id] or breakout)
            and now-record.at>=options.reinforceDelay and record.bursts<options.maxBoosts then
            local committed=math.floor(me.troops*ratio)
            local depleted=front.troops<committed*0.5
            local ready=not economic or economicReady or depleted
            local oversupplied=front.troops>committed*2 and me.troops/Strategy.capacity(me)<0.9
            if ready and not oversupplied then
                local score=(depleted and 1000 or 0)+(id~=0 and 100 or 0)-front.troops/math.max(1,committed)
                if not best or score>best.score then best={id=id,tile=tile,ratio=ratio,record=record,score=score} end
            end
        end
    end
    if not best then return false end
    if send({t="attack",tile=best.tile,ratio=best.ratio},"bestaand front "..best.id.." gericht versterken") then
        best.record.at=now;best.record.bursts=best.record.bursts+1
        best.record.captureAt=state.lastCaptureAt or -10000
        state.boosts[best.id]=best.record;state.lastSend=now
    end
    return true
end
local function choose_spawn()
    if state.historical then
        if not Scenarios then state.reason="Historische module niet beschikbaar";return nil end
        local scenario=Scenarios.forMap(state.mapId,state.mode)
        if not scenario then state.reason="Onbekend historisch scenario";return nil end
        local best,bestSize=nil,-1
        for _,nation in ipairs(scenario.NATIONS) do
            local tile=nation.capital
            if nation.playable and tile and tile>=0 and tile<N and passable(tile) and not state.rejectedSpawn[tile] then
                local owner=buffer.readu8(state.owners,tile)
                local user=state.rosterUsers[owner]
                if owner~=0 and (not user or user==player.UserId) and nation.tiles>bestSize then
                    best,bestSize=tile,nation.tiles
                end
            end
        end
        return best
    end
    local best,bestScore=nil,-math.huge
    local rng=Random.new()
    for attempt=1,400 do
        local tile=rng:NextInteger(0,N-1)
        if buffer.readu8(state.owners,tile)==0 and passable(tile) then
            local x,y=tile%W,math.floor(tile/W)
            local nearest=W+H
            for id,other in pairs(state.representatives) do
                if buffer.readu8(state.owners,other)==id then
                    nearest=math.min(nearest,math.abs(x-other%W)+math.abs(y-math.floor(other/W)))
                end
            end
            if nearest>=(Config.MIN_SPAWN_DISTANCE or 30)+10 then
                local free=0
                for dy=-24,24,8 do
                    for dx=-24,24,8 do
                        local px,py=x+dx,y+dy
                        if px>=0 and px<W and py>=0 and py<H then
                            local t=py*W+px
                            if passable(t) and buffer.readu8(state.owners,t)==0 then free=free+1 end
                        end
                    end
                end
                local height=bit32.band(buffer.readu8(state.terrain,tile),63)
                local score=free*12+math.min(nearest,300)-height*2
                if free>=30 and score>bestScore then best,bestScore=tile,score end
            end
        end
        if attempt%80==0 then task.wait() end
    end
    return best
end
local function state_event(kind,payload,extra)
    if kind=="structs" and state.waitingDimensions then
        assert(#state.deferredStructures<128,"Te veel gebouwupdates tijdens kaartladen")
        state.deferredStructures[#state.deferredStructures+1]=payload
        return
    end
    if kind=="roster" or kind=="structs" or kind=="players" or kind=="vehicles" or kind=="armies" then
        local list=message_list(kind,payload,kind=="players")
        if not list then return end
        payload=list
    elseif kind=="fronts" then
        local object=message_table("fronts",payload)
        if not object then message_issue("fronts",payload,true);return end
        local outgoing=message_table("frontList",object.out)
        local incoming=message_table("frontList",object.inc)
        if not valid_list("frontList",outgoing) or not valid_list("frontList",incoming) then
            message_issue("fronts",payload,true);return
        end
        local diplo=object.diplo and message_table("diplomacy",object.diplo) or nil
        if object.diplo~=nil and not diplo then message_issue("diplomacy",object.diplo,true);return end
        local allies=message_list("allies",diplo and diplo.allies or {},true)
        if not allies then return end
        payload=table.clone(object);payload.out=outgoing;payload.inc=incoming
        payload.diplo={allies=allies}
        if state.protocolBlocks then state.protocolBlocks.fronts=nil;state.protocolBlocks.diplomacy=nil end
        if state.protocolWarnings then state.protocolWarnings.fronts=nil;state.protocolWarnings.diplomacy=nil end
        if state.protocolWarningTypes then state.protocolWarningTypes.fronts=nil;state.protocolWarningTypes.diplomacy=nil end
    end
    if kind=="init" then
        assert(type(payload)=="table" and type(payload.yourId)=="number","Onbekend init-formaat")
        if state.round~=payload.round then state.resyncAttempts=0 end
        state.awaitingInit=false;state.mapFault=nil;state.engineFault=nil
        state.generation=state.generation+1
        local generation=state.generation
        state.round=payload.round; state.id=payload.yourId; state.phase=payload.phase
        state.mode=payload.modeId; state.historical=payload.historical; state.mapId=payload.mapId or "us"
        state.rosterUsers={};state.rejectedSpawn={};state.pendingSpawn=nil
        state.ownedSamples={};state.structures={};state.structuresReady=false
        state.armies=nil;state.boosts={};state.landOrders={};state.growthProfile=nil;state.measuredGrowth=nil;state.economicStatus=nil;state.lastCaptureAt=-10000
        state.coast={};state.waterTargets={};state.riverOrders={};state.blockedLanding={};state.transportCount=0;state.lastWaterScan=-10000
        state.blockedBuild={};state.plannedBlasts={};state.gold=nil;state.cityCost=nil;state.postCost=nil
        state.freeCities=0;state.freePosts=0;state.freeNukes=0;state.freeSams=0;state.samCost=nil
        state.reinforceCost=nil;state.reinforceTroops=nil;state.reinforceQuoteAt=nil
        state.boxedSince=nil;state.lastBreakoutAt=nil;state.breakout=nil
        state.reinforceReadyAt=nil;state.reinforceCooldownUntil=0;state.reinforcePendingUntil=0;state.reinforceDenied=false
        state.lastBuild=-10000;state.lastNuke=-10000;state.lastNukeScan=-10000
        state.requiredReserve=nil;state.neighbourCount=0;state.strongestNeighbour=0
        local roster=message_list("roster",payload.roster or {},false)
        for _,entry in ipairs(roster or {}) do state.rosterUsers[entry.i]=entry.u end
        state.capBonus=payload.troopCapBonus or 0
        state.players={}; state.allies={}; state.incoming={}; state.outgoing={}
        state.frontier={}; state.representatives={}; state.pending={}
        state.owners=buffer.create(N); state.terrain=nil; state.ready=false
        state.waitingDimensions=true;state.deferredStructures={};state.snapshotComplete=false;state.snapshotCovered=0
        state.snapshotReady=false; state.snapshot=nil; state.chunks={}; state.seen=0
        state.indexing=false; state.spawned=false; state.spawnAt=-100
        state.lastPlayers=0; state.lastFronts=0; state.lastSend=-100;state.playingAt=os.clock()
        state.lastAction=os.clock(); state.levels=0; state.errorCount=0; state.left=false
        log("Ronde "..tostring(payload.round).." | "..tostring(payload.mapId).." | "..state.phase)
        task.spawn(guard(function()
            local terrain=MapGen.generate(payload.mapId or "us",payload.seed)
            if alive and generation==state.generation then
                local width,height,count,source=resolve_geometry(payload,terrain)
                W,H,N=width,height,count
                state.owners=buffer.create(N);state.terrain=terrain;state.waitingDimensions=false
                log("Kaartafmetingen: "..W.."x"..H.." | "..source)
                local deferred=state.deferredStructures;state.deferredStructures={}
                for _,message in ipairs(deferred) do state_event("structs",message) end
                finalize_snapshot()
            end
        end))
    elseif kind=="snapshot" and payload.round==state.round then
        local function integer(v) return type(v)=="number" and v%1==0 end
        assert(integer(payload.bytes) and payload.bytes>0 and payload.bytes<=128000000,"Onverwachte snapshotgrootte")
        assert(integer(payload.count) and payload.count>0 and payload.count<=65536,"Ongeldig aantal kaartdelen")
        assert(integer(payload.index) and payload.index>=0 and payload.index<=payload.count,"Ongeldig kaartdeel")
        assert(typeof(payload.data)=="buffer" and integer(payload.offset) and payload.offset>=0 and payload.offset+buffer.len(payload.data)<=payload.bytes,"Kaartdeel buiten bereik")
        if not state.snapshot then
            state.snapshot=buffer.create(payload.bytes)
            state.snapshotCount=payload.count;state.snapshotRaw=payload.raw==true
        end
        assert(buffer.len(state.snapshot)==payload.bytes and state.snapshotCount==payload.count and state.snapshotRaw==(payload.raw==true),"Verschillende kaartdeelmetadata")
        if not state.chunks[payload.index] then
            local ending=payload.offset+buffer.len(payload.data)
            for _,range in pairs(state.chunks) do assert(ending<=range[1] or payload.offset>=range[2],"Overlappende kaartdelen") end
            buffer.copy(state.snapshot,payload.offset,payload.data)
            state.chunks[payload.index]={payload.offset,ending};state.seen+=1
            state.snapshotCovered+=buffer.len(payload.data)
            if state.seen==payload.count then
                assert(state.snapshotCovered==payload.bytes,"Ontbrekende kaartbytes")
                state.snapshotComplete=true;finalize_snapshot()
            end
        end
    elseif kind=="roster" then
        state.rosterUsers=state.rosterUsers or {}
        for _,entry in ipairs(payload) do state.rosterUsers[entry.i]=entry.u end
    elseif kind=="players" and state.id then
        local players={}
        for _,entry in ipairs(payload) do players[entry.id]=entry end
        Strategy.observe_growth(state.players[state.id],players[state.id])
        state.players=players; state.lastPlayers=os.clock()
    elseif kind=="fronts" and state.id then
        assert(type(payload.out)=="table" and type(payload.inc)=="table","Onbekend fronts-formaat")
        state.incoming=payload.inc; state.outgoing=payload.out
        for _,front in ipairs(state.outgoing) do
            if state.riverOrders then state.riverOrders[front.id]=nil end
        end
        state.levels=payload.levels or 0; state.lastFronts=os.clock()
        state.gold=payload.gold or state.gold;state.cityCost=payload.cost or state.cityCost
        if type(payload.reinforceCost)=="number" and type(payload.reinforceTroops)=="number" and type(payload.reinforceLeft)=="number"
            and payload.reinforceCost>=0 and payload.reinforceTroops>=0 and payload.reinforceLeft>=0 then
            state.reinforceCost=payload.reinforceCost;state.reinforceTroops=payload.reinforceTroops
            state.reinforceQuoteAt=os.clock()
            state.reinforceReadyAt=os.clock()+payload.reinforceLeft/(Config.TICK_RATE or 10)
        end
        state.postCost=payload.postCost or state.postCost
        state.samCost=payload.samCost or state.samCost;state.freeSams=payload.freeSams or 0
        state.freeCities=payload.freeCities or 0;state.freePosts=payload.freePosts or 0;state.freeNukes=payload.freeNukes or 0
        state.allies={}
        for _,id in ipairs(payload.diplo and payload.diplo.allies or {}) do state.allies[id]=true end
    elseif kind=="armies" and state.id then
        state.armies=payload
    elseif kind=="vehicles" and state.id then
        state.transportCount=0
        state.transportKnown=true
        for _,v in ipairs(payload) do
            if v.owner==state.id and v.kind==3 then state.transportCount=state.transportCount+1 end
        end
    elseif kind=="structs" and state.id then
        if extra then state.structures={} end
        state.structures=state.structures or {}
        for _,s in ipairs(payload) do
            if s.ownerId==0 or (s.level or 0)<=0 then state.structures[s.tile]=nil
            else local copy=table.clone(s);copy.kind=copy.kind or 1;state.structures[s.tile]=copy end
        end
        if extra then state.structuresReady=true end
        state.cityCache=nil
    elseif kind=="built" then
        state.errorCount=0;state.gold=payload.gold or state.gold
        if payload.kind==1 then state.cityCost=payload.cost or state.cityCost
        elseif payload.kind==3 then state.postCost=payload.cost or state.postCost
        elseif payload.kind==5 then state.samCost=payload.cost or state.samCost end
        log("Bouw bevestigd op tegel "..tostring(payload.tile))
    elseif kind=="reinforced" then
        state.gold=payload.gold or state.gold
        state.reinforcePendingUntil=0
        state.reinforceReadyAt=os.clock()+(Config.REINFORCE_COOLDOWN or 300)/(Config.TICK_RATE or 10)
        state.reinforceCooldownUntil=state.reinforceReadyAt
        state.reinforceQuoteAt=nil
        state.errorCount=0
        log("Reinforcement bevestigd: +"..tostring(payload.troops or "?").." troepen; wachten op actuele legerstand.")
    elseif kind=="phase" then
        if state.phase~=payload.phase and payload.phase=="playing" then state.playingAt=os.clock() end
        state.phase=payload.phase
    elseif kind=="spawned" then state.spawned=true;state.errorCount=0; log("Spawn bevestigd.")
    elseif kind=="denied" then
        log("Server weigert: "..tostring(payload.reason))
        if state.phase=="spawn" and state.pendingSpawn then
            state.rejectedSpawn[state.pendingSpawn]=true
            state.pendingSpawn=nil
            state.spawnAt=-100
        end
        local command=state.lastCommand
        if command and command.t=="attack" and state.riverOrders then
            for id,entry in pairs(state.riverOrders) do
                if entry.tile==command.tile then
                    local route=payload.reason=="nobeach" or payload.reason=="nocoast" or payload.reason=="nosearoute"
                    entry.untilTime=os.clock()+(route and 30 or options.interval);entry.failed=true
                    if route then state.blockedLanding[command.tile]=os.clock()+60;state.lastWaterScan=-10000 end
                end
            end
        end
        if command and command.t=="reinforce" then
            state.reinforcePendingUntil=os.clock()+10
            if payload.reason=="pass" then state.reinforceDenied=true;log("Reinforcement niet beschikbaar voor dit account.") end
            state.reinforceQuoteAt=nil
        end
        if command and command.t=="build" and state.blockedBuild then state.blockedBuild[command.tile]=os.clock()+45 end
        local expected={pass=true,gold=true,crowded=true,maxlevel=true,immunity=true,toonear=true,taken=true,notadjacent=true,troops=true,full=true,cooldown=true,
            busy=true,nobeach=true,nocoast=true,nosearoute=true,toomanytransportboats=true,toomanyfronts=true}
        if not expected[payload.reason] then state.errorCount=state.errorCount+1 end
        state.lastAction=os.clock()+5
        if state.errorCount>=4 then
            state.engineFault="Vier onverwachte serverweigeringen; stuur Foutlog. Instellingen behouden."
            log(state.engineFault)
        end
    end
end
local function run_step()
    local role=RS:GetAttribute(Matchmaker.ROLE_ATTR)
    if role=="match" and (not state.id or state.id==0) and os.clock()-(state.helloAt or -100)>8 then
        if (state.helloAttempts or 0)<3 then
            state.helloAttempts=(state.helloAttempts or 0)+1
            state.helloAt=os.clock()
            folder.Intent:FireServer({t="hello",tile=0})
            log("Wedstrijdgegevens opnieuw opvragen ("..state.helloAttempts.."/3).")
        elseif not state.initTimeout then
            state.initTimeout=true
            state.engineFault="Geen init ontvangen. Stuur Foutlog; instellingen behouden."
            log(state.engineFault)
        end
    end
    local me=state.players[state.id]
    local warnings={}
    for kind in pairs(state.protocolWarnings or {}) do warnings[#warnings+1]=kind end
    table.sort(warnings)
    status.Text=string.format("Server: %s | %s\nKaart: %s | Troepen: %s\nInkomend: %d | Uitgaand: %d\nModus: %s\nOpslag: %s\nHerladen: %s\nSterkste buur: %s | Buren: %s\nReserve strijd/economie: %s | Goud: %s\nGroeimodel: %s\nGemeten groei: %s troepen/s\nBerichtwaarschuwingen: %s\nStatus: %s",
        tostring(role),tostring(state.phase),state.ready and "gereed" or "wachten",
        me and tostring(me.troops) or "onbekend",#state.incoming,#state.outgoing,
        options.dry and "OBSERVATIE: GEEN ORDERS" or "ACTIEF",storage_status,
        options.reload and (state.reloadStatus or "controleren") or "UIT",
        tostring(state.strongestNeighbour or "?"),tostring(state.neighbourCount or "?"),
        (tostring(state.requiredReserve or "?").." / "..tostring(state.economicReserve or "?")),tostring(state.gold or "?"),
        state.economicStatus or "nog geen betrouwbare beoordeling",
        state.measuredGrowth and string.format("%.1f",state.measuredGrowth) or "meten",
        #warnings>0 and table.concat(warnings,", ") or "geen",state.reason or "Initialiseren")
    if state.engineFault then
        state.reason="Gepauzeerd na fout; instellingen behouden. Gebruik Synchroniseer opnieuw."
        status.Text=state.engineFault
        return
    end
    if state.protocolBlocks and next(state.protocolBlocks) then
        local _,warning=next(state.protocolBlocks)
        state.reason="Wachten op kritiek berichtformaat: "..warning
        return
    end
    if state.awaitingInit then
        state.reason="Kaartupdate ongeldig; wachten op nieuwe volledige kaart"
        if os.clock()-(state.helloAt or -100)>8 then
            if (state.resyncAttempts or 0)<3 then
                state.resyncAttempts=(state.resyncAttempts or 0)+1;state.helloAt=os.clock()
                folder.Intent:FireServer({t="hello",tile=0})
                log("Kaart opnieuw aanvragen "..state.resyncAttempts.."/3; functies blijven ingesteld.")
            else
                state.reason="Kaart niet hersteld na 3 pogingen; stuur Foutlog. Functies blijven ingesteld."
            end
        end
        return
    end
    if os.clock()-state.lastAction<options.interval then state.reason="Actievertraging";return end
    if role=="lobby" then
        if not options.queue then state.reason="Auto join staat uit";return end
        if os.clock()-(state.boardAt or 0)>10 then state.reason="Wachten op actuele lobbylijst";return end
        local chosen=nil
        for _,card in pairs(state.board) do
            if card.mine then state.reason="In wachtrij: "..card.name;return end
            if card.state=="open" and card.count<card.cap and (not options.skipHistorical or not card.historical) and not card.special then
                if not chosen or card.remaining<chosen.remaining then chosen=card end
            end
        end
        if chosen and os.clock()-(state.queueAt or -100)>15 then
            state.lastAction=os.clock(); state.queueAt=os.clock()
            local slot=Matchmaker.SLOTS[chosen.slot]
            if options.dry then state.reason="Observatie: join wordt niet uitgevoerd";log("PLAN: join "..chosen.name)
            else folder.LobbyIntent:FireServer("join",slot.key); state.reason="Join verstuurd: "..chosen.name;log("Join gevraagd: "..chosen.name) end
        elseif not chosen then state.reason="Geen passende open match"
        end
        return
    end
    if role~="match" then state.reason="Serverrol nog onbekend";return end
    if state.phase=="ended" and options.leave and not state.left then
        if send({t="leave"},"terug naar lobby") then state.left=true end
        return
    end
    if not state.id or state.id==0 then state.reason="Wachten op eigen identiteit van server";return end
    if not state.ready then state.reason="Kaart en eigenaars laden";return end
    if state.phase=="spawn" and options.spawn and not state.spawned then
        if os.clock()-state.spawnAt<8 then state.reason="Wachten op spawnbevestiging";return end
        state.spawnAt=os.clock()
        local generation=state.generation
        local tile=choose_spawn()
        if alive and state.generation==generation and state.phase=="spawn" and options.spawn and tile then
            if send({t="spawn",tile=tile},state.historical and "groot beschikbaar land kiezen" or "spawn op tegel "..tile) then state.pendingSpawn=tile end
        elseif not tile then state.reason="Geen geschikte beschikbare spawn gevonden"
        end
        return
    end
    if state.phase~="playing" then state.reason="Wachten op start wedstrijd";return end
    if not me or not me.alive or me.tiles<=0 then state.reason="Geen levend eigen rijk gevonden";return end
    if not fresh() then state.reason="Wachten op actuele troepen/fronten";return end
    if state.lastPlayers< (state.lastSend or -100) or state.lastFronts<(state.lastSend or -100) then state.reason="Wachten op server na order";return end
    Strategy.water_targets()
    if Strategy.try_buy_reinforcements() then return end
    local ratio=choose_ratio(#state.incoming>0)
    local targets=enemy_targets()
    if #state.incoming>0 then
        if options.defend then
            local worst=nil
            for _,attack in ipairs(state.incoming) do
                if targets[attack.id] and (not worst or attack.troops>worst.troops) then worst=attack end
            end
            if worst and ratio then
                if send({t="attack",tile=targets[worst.id],ratio=ratio},"tegenaanval op "..worst.id) then state.lastSend=os.clock() end
                return
            else state.reason="Aanval binnenkomend; geen veilige tegenaanval beschikbaar" end
        else state.reason="Aanval binnenkomend; offensief gepauzeerd" 
        end
        if Strategy.try_build(true) then return end
        if Strategy.try_nuke() then return end
        return
    end
    if Strategy.try_nuke() then return end
    if Strategy.try_build(false) then return end
    local normalReserve=state.requiredReserve
    local economicRatio=choose_ratio(false,true)
    local economicReserve=state.requiredReserve
    state.economicReserve=economicReserve
    state.requiredReserve=normalReserve
    local economicReady=Strategy.growth_ready(economicRatio)
    local active=Strategy.active_orders()
    local allowedFronts=state.transportKnown==false and 1 or options.maxFronts
    if active>=math.min(allowedFronts,Config.MAX_FRONTS_PER_PLAYER or 4) then
        if Strategy.try_reinforce(targets,ratio,economicRatio,economicReady) then return end
        state.reason="Frontenlimiet bereikt ("..active.."); bestaande legers/transporten afwachten";return
    end
    local busy={}
    for _,front in ipairs(state.outgoing) do busy[front.id]=true end
    if options.attack or options.expand then
        local truce=state.historical and (state.historical.grace or 0) or (Config.SPAWN_IMMUNITY_SECONDS or 0)
        local attacksAllowed=os.clock()-(state.playingAt or 0)>=truce
        local weakest,bestScore,bestRatio,bestReserve=nil,-math.huge,nil,nil
        for id,tile in pairs(targets) do
            if attacksAllowed and id~=0 and not busy[id] then
                local enemy=state.players[id]
                local economic=enemy and enemy.isBot==true
                local orderRatio,orderReserve=Strategy.opportunity_ratio(id,state.targetProtected[id])
                local score=Strategy.target_score(id,tile,0)
                if orderRatio and score and score>bestScore then weakest,bestScore,bestRatio,bestReserve=id,score,orderRatio,orderReserve end
            end
        end
        if not weakest and attacksAllowed then
            local escape,escapeRatio,escapeReserve=Strategy.breakout_plan(targets)
            if escape then
                if send({t="attack",tile=targets[escape],ratio=escapeRatio},"UITBRAAK via "..escape.." na stilstand | inzet "..math.floor(me.troops*escapeRatio).." | thuis "..math.floor(me.troops*(1-escapeRatio))) then
                    state.lastSend=os.clock();state.lastBreakoutAt=os.clock()
                    state.breakout={id=escape,untilTime=os.clock()+90};state.requiredReserve=math.ceil(escapeReserve)
                end
                return
            end
        else state.boxedSince=nil end
        if not weakest then state.reason="Geen nieuw veilig landfront; wateroversteek onderzoeken" end
        if options.rivers and state.transportKnown~=false and (state.transportCount or 0)<(Config.TRANSPORT_BOAT_MAX_PER_PLAYER or 3) then
            local targetId,target,waterScore,waterRatio,waterReserve=nil,nil,-math.huge,nil,nil
            for id,entry in pairs(state.waterTargets or {}) do
                local enemy=state.players[id]
                local economic=id==0 or (enemy and enemy.isBot==true)
                local orderRatio=economic and economicRatio or ratio
                local score=id==0 and options.expand and 0 or Strategy.target_score(id,entry.tile,entry.distance)
                local pending=state.riverOrders[id]
                if (id==0 or attacksAllowed) and orderRatio and (not economic or economicReady) and score and not targets[id] and not busy[id] and not friendly(id)
                    and (not pending or pending.untilTime<=os.clock()) then
                    if score>waterScore then targetId,target,waterScore,waterRatio,waterReserve=id,entry,score,orderRatio,economic and economicReserve or normalReserve end
                end
            end
            local boatTroops=math.floor(me.troops/(Config.TRANSPORT_BOAT_TROOP_DIVISOR or 5))
            if target and waterScore>bestScore and boatTroops>=(Config.TRANSPORT_BOAT_MIN_TROOPS or 250)
                and me.troops-boatTroops>=(waterReserve or 0) then
                if send({t="attack",tile=target.tile,ratio=waterRatio},"rivier/korte waterroute naar "..targetId.."; server kiest landbrug of transport") then
                    state.lastSend=os.clock()
                    state.riverOrders[targetId]={tile=target.tile,untilTime=os.clock()+60}
                end
                return
            end
            state.reason="Geen veilige beschikbare wateroversteek binnen zoekafstand"
        end
        if weakest then
            local cityCount=Strategy.city_value(weakest)
            local bot=state.players[weakest].isBot==true
            local description=bot and ("botland "..weakest.." veroveren; "..cityCount.." zichtbare steden") or "voorzichtige aanval op speler/onbekend land "..weakest
            state.requiredReserve=math.ceil(bestReserve or normalReserve or 0)
            description=description.." | inzet "..math.floor(me.troops*bestRatio).." | thuis "..math.floor(me.troops*(1-bestRatio))
            if send({t="attack",tile=targets[weakest],ratio=bestRatio},description) then state.lastSend=os.clock() end
            return
        end
        if Strategy.try_reinforce(targets,ratio,economicRatio,economicReady) then return end
        if options.expand and targets[0] and not busy[0] and economicRatio and economicReady then
            local tile=Strategy.open_tile()
            if tile and send({t="attack",tile=tile,ratio=economicRatio},"groeivenster benutten: uitbreiden via minder bedreigde grens") then state.lastSend=os.clock() end
            return
        end
        state.reason="Geen betaalbaar veilig doel; wachten op troepen of beschikbare grens"
    else state.reason="Uitbreiden en aanvallen staan uit"
    end
end

task.spawn(guard(function()
    log("Start "..VERSION.." | place "..game.PlaceId)
    assert(game.PlaceId==138110382920220 or game.GameId==10764297006,"Dit is niet de verwachte Pixel Front-game.")
    local shared=RS:WaitForChild("Conquest",15)
    assert(shared,"ReplicatedStorage.Conquest ontbreekt")
    Config=load_module(shared,"Config"); Net=load_module(shared,"Net")
    MapGen=load_module(shared,"MapGen"); Matchmaker=load_module(shared,"Matchmaker")
    if shared:FindFirstChild("Scenarios") then
        local ok,value=pcall(load_module,shared,"Scenarios")
        if ok and type(value)=="table" and type(value.forMap)=="function" then Scenarios=value
        else log("Historische spawnmodule niet beschikbaar: "..tostring(value)) end
    end
    if shared:FindFirstChild("Nukes") then
        local ok,value=pcall(load_module,shared,"Nukes")
        if ok and type(value)=="table" and type(value.magnitude)=="function" then Nukes=value
        else log("Nukeplanner niet beschikbaar: "..tostring(value)) end
    end
    if shared:FindFirstChild("Maps") then
        local ok,value=pcall(load_module,shared,"Maps")
        if ok then Maps=value end
    end
    W,H,N=Config.MAP_W,Config.MAP_H,Config.NUM_TILES
    assert(type(W)=="number" and type(H)=="number" and N==W*H and N<=16000000,"Onbekende kaartconfiguratie")
    assert(type(Config.attackPresets)=="function" and type(Net.unpackPlayers)=="function","Spelversie wijkt af")
    folder=RS:WaitForChild("ConquestNet",15)
    assert(folder,"ConquestNet ontbreekt")
    for _,name in ipairs({"State","Delta","Intent","Lobby","LobbyIntent"}) do
        local obj=folder:WaitForChild(name,10)
        assert(obj and obj:IsA("RemoteEvent"),"Remote ontbreekt: "..name)
    end
    connect(folder.State.OnClientEvent,function(kind,payload,extra)
        local ok,err=xpcall(state_event,debug.traceback,kind,payload,extra)
        if not ok then
            state.engineFault="BERICHT="..tostring(kind).." | TYPE="..typeof(payload).."\n"..tostring(err)
            state.ready=false;log(state.engineFault);status.Text=state.engineFault
        end
    end)
    connect(folder.Delta.OnClientEvent,function(data)
        if not state.id or state.awaitingInit then return end
        if state.snapshotReady then apply_delta(data)
        else
            if #state.pending>=100 then pause_map("Snapshot blijft uit; delta-wachtrij vol");return end
            table.insert(state.pending,data)
        end
    end)
    connect(folder.Lobby.OnClientEvent,function(kind,payload)
        if kind=="board" then
            state.board=Matchmaker.readWire(payload,player.UserId)
            state.boardAt=os.clock()
        elseif kind=="toast" then log("Lobby: "..tostring(payload)) end
    end)
    button("Overzicht","Synchroniseer opnieuw",function()
        if os.clock()-(state.helloAt or -100)<10 then return end
        if RS:GetAttribute(Matchmaker.ROLE_ATTR)=="match" then
            state.engineFault=nil;state.resyncAttempts=0
            pause_map("Handmatige synchronisatie aangevraagd")
            state.helloAt=os.clock()
            folder.Intent:FireServer({t="hello",tile=0})
        end
    end)
    if RS:GetAttribute(Matchmaker.ROLE_ATTR)=="match" then
        state.helloAt=os.clock()
        state.helloAttempts=1
        folder.Intent:FireServer({t="hello",tile=0})
    end
    setup_reload()
    log("Verbinding gereed. Modus: "..(options.dry and "OBSERVATIE" or "ACTIEF"))
    while alive do guard(run_step)(); task.wait(0.5) end
end))
