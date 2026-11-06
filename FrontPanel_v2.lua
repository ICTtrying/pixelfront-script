-- Luau | FrontPanel_v2.lua | Roblox client | Pixel Front
local VERSION="2.4-persistent"
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
 dry=false,reserve=45,strength=2,interval=3,reload=true,skipHistorical=false}
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
 for key,range in pairs({reserve={10,90},strength={1.2,10},interval={2,30}}) do
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
 title.Text="FRONT PANEL 2.4 | "..(options.dry and "OBSERVATIE" or "ACTIEF")
end
local function halt(reason)
 for _,key in ipairs({"queue","spawn","expand","attack","defend","leave"}) do options[key]=false end
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
  if not ok then halt("FOUT: "..tostring(err)) end
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
 status=label("Overzicht","Spelverbinding wordt geladen...",255)
 label("Overzicht","Zet de gewenste functies aan. ACTIEF voert orders uit. OBSERVATIE toont alleen plannen. Instellingen worden automatisch opgeslagen wanneer je executor dit ondersteunt.",100)
 toggle("Match","Auto join","queue"); toggle("Match","Auto spawn","spawn"); toggle("Match","Verlaat na einde","leave")
 toggle("Match","Herladen na teleport","reload")
 toggle("Match","Historisch overslaan","skipHistorical")
 label("Match","Auto spawn kiest op historische kaarten een groot beschikbaar land; op andere kaarten een vrije plek. Herladen wordt aangevraagd bij je executor en is afhankelijk van diens ondersteuning.",120)
 toggle("Oorlog","Uitbreiden","expand"); toggle("Oorlog","Zwakke buren aanvallen","attack"); toggle("Oorlog","Verdedigen","defend")
 toggle("Instellen","Observatiemodus","dry")
 button("Instellen","Echte acties aanzetten",function()
  options.dry=false;refresh_toggles();save_settings();log("ACTIEF: ingeschakelde functies voeren echte orders uit.")
 end)
 number_input("Instellen","Reserve % van troepencap","reserve",10,90)
 number_input("Instellen","Sterkteverhouding","strength",1.2,10)
 number_input("Instellen","Actievertraging in seconden","interval",2,30)
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
]=],snapshot,RAW_URL.."?v=2.4")
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

local Config,Net,MapGen,Matchmaker,Scenarios,folder
local W,H,N
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
end
local function apply_delta(data)
    local touched={}
    Net.unpackDelta(data,function(tile,owner)
        assert(tile>=0 and tile<N,"Kaartdelta buiten bereik")
        buffer.writeu8(state.owners,tile,owner)
        touched[tile]=true
        if owner~=0 and owner~=state.id then state.representatives[owner]=tile end
    end)
    if state.terrain then
        for tile in pairs(touched) do
            refresh_tile(tile)
            neighbours(tile,refresh_tile)
        end
    end
end
local function index_map(generation)
    task.spawn(guard(function()
        state.ready=false
        for tile=0,N-1 do
            if not alive or generation~=state.generation then return end
            refresh_tile(tile)
            local owner=buffer.readu8(state.owners,tile)
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
local function fresh()
    return state.ready and os.clock()-state.lastPlayers<5 and os.clock()-state.lastFronts<5
end
local function friendly(id)
    if id==state.id or state.allies[id] then return true end
    local me=state.players[state.id]
    local other=state.players[id]
    return me and other and me.team~=nil and me.team==other.team
end
local function send(payload,description)
    if os.clock()-state.lastAction<options.interval then return false end
    state.lastAction=os.clock()
    if options.dry then state.reason="Observatie: "..description;log("PLAN: "..description); return false end
    folder.Intent:FireServer(payload)
    state.reason="Order verstuurd: "..description
    log("ORDER: "..description)
    return true
end
local function choose_ratio()
    local me=state.players[state.id]
    if not me or not me.alive or me.troops<=0 then return nil end
    local cap=(Config.MAX_TROOPS_MULT or 1)*(
        me.tiles^Config.TROOPS_TILE_EXPONENT*Config.TROOPS_PER_TILE_COEF+Config.BASE_MAX_TROOPS
    )+(state.levels or 0)*Config.CITY_TROOP_INCREASE+(state.capBonus or 0)
    local required=cap*options.reserve/100
    local best=nil
    for _,ratio in ipairs(Config.attackPresets(state.mode)) do
        local committed=math.floor(me.troops*ratio)
        if committed>=(Config.MIN_ATTACK_TROOPS or 250) and me.troops-committed>=required then
            if not best or ratio<best then best=ratio end
        end
    end
    return best
end
local function enemy_targets()
    local result={}
    for tile in pairs(state.frontier) do
        local id=buffer.readu8(state.owners,tile)
        if not result[id] and id~=state.id and (id==0 or not friendly(id)) then result[id]=tile end
    end
    return result
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
local function state_event(kind,payload)
    if kind=="init" then
        assert(type(payload)=="table" and type(payload.yourId)=="number","Onbekend init-formaat")
        state.generation=state.generation+1
        local generation=state.generation
        state.round=payload.round; state.id=payload.yourId; state.phase=payload.phase
        state.mode=payload.modeId; state.historical=payload.historical; state.mapId=payload.mapId or "us"
        state.rosterUsers={};state.rejectedSpawn={};state.pendingSpawn=nil
        for _,entry in ipairs(payload.roster or {}) do state.rosterUsers[entry.i]=entry.u end
        state.capBonus=payload.troopCapBonus or 0
        state.players={}; state.allies={}; state.incoming={}; state.outgoing={}
        state.frontier={}; state.representatives={}; state.pending={}
        state.owners=buffer.create(N); state.terrain=nil; state.ready=false
        state.snapshotReady=false; state.snapshot=nil; state.chunks={}; state.seen=0
        state.indexing=false; state.spawned=false; state.spawnAt=-100
        state.lastPlayers=0; state.lastFronts=0; state.lastSend=-100;state.playingAt=os.clock()
        state.lastAction=os.clock(); state.levels=0; state.errorCount=0; state.left=false
        log("Ronde "..tostring(payload.round).." | "..tostring(payload.mapId).." | "..state.phase)
        task.spawn(guard(function()
            local terrain=MapGen.generate(payload.mapId or "us",payload.seed)
            if alive and generation==state.generation then
                assert(buffer.len(terrain)==N,"Afwijkende kaartgrootte")
                state.terrain=terrain
                finish_map()
            end
        end))
    elseif kind=="snapshot" and payload.round==state.round then
        assert(payload.bytes>0 and payload.bytes<=N*8,"Onverwachte snapshotgrootte")
        if not state.snapshot then state.snapshot=buffer.create(payload.bytes) end
        if not state.chunks[payload.index] then
            buffer.copy(state.snapshot,payload.offset,payload.data)
            state.chunks[payload.index]=true; state.seen=state.seen+1
            if state.seen==payload.count then
                if payload.raw then
                    assert(buffer.len(state.snapshot)==N,"Onverwachte raw snapshot")
                    buffer.copy(state.owners,0,state.snapshot)
                else Net.unpackOwners(state.snapshot,state.owners) end
                state.snapshotReady=true
                for _,data in ipairs(state.pending) do apply_delta(data) end
                state.pending={}; state.snapshot=nil
                finish_map()
            end
        end
    elseif kind=="roster" then
        state.rosterUsers=state.rosterUsers or {}
        for _,entry in ipairs(payload) do state.rosterUsers[entry.i]=entry.u end
    elseif kind=="players" and state.id then
        local players={}
        for _,entry in ipairs(Net.unpackPlayers(payload)) do players[entry.id]=entry end
        state.players=players; state.lastPlayers=os.clock()
    elseif kind=="fronts" and state.id then
        assert(type(payload.out)=="table" and type(payload.inc)=="table","Onbekend fronts-formaat")
        state.incoming=payload.inc; state.outgoing=payload.out
        state.levels=payload.levels or 0; state.lastFronts=os.clock()
        state.allies={}
        for _,id in ipairs(payload.diplo and payload.diplo.allies or {}) do state.allies[id]=true end
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
        state.errorCount=state.errorCount+1
        state.lastAction=os.clock()+5
        if state.errorCount>=4 then halt("Vier weigeringen: automatisering gestopt. Stuur foutlog.") end
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
            halt("Geen init ontvangen. Stuur dit foutlog; geen automatische spelorders gestart.")
        end
    end
    local me=state.players[state.id]
    status.Text=string.format("Server: %s | %s\nKaart: %s | Troepen: %s\nInkomend: %d | Uitgaand: %d\nModus: %s\nOpslag: %s\nHerladen: %s\nStatus: %s",
        tostring(role),tostring(state.phase),state.ready and "gereed" or "wachten",
        me and tostring(me.troops) or "onbekend",#state.incoming,#state.outgoing,
        options.dry and "OBSERVATIE: GEEN ORDERS" or "ACTIEF",storage_status,
        options.reload and (state.reloadStatus or "controleren") or "UIT",state.reason or "Initialiseren")
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
    local ratio=choose_ratio()
    if not ratio then state.reason="Troepen groeien tot reserve + aanvalsbudget beschikbaar zijn";return end
    local targets=enemy_targets()
    if #state.incoming>0 then
        if options.defend then
            local worst=nil
            for _,attack in ipairs(state.incoming) do
                if targets[attack.id] and (not worst or attack.troops>worst.troops) then worst=attack end
            end
            if worst then
                if send({t="attack",tile=targets[worst.id],ratio=ratio},"tegenaanval op "..worst.id) then state.lastSend=os.clock() end
            else state.reason="Aanval binnenkomend; aanvaller niet langs land bereikbaar" end
        else state.reason="Aanval binnenkomend; offensief gepauzeerd" 
        end
        return
    end
    if #state.outgoing>0 then state.reason="Bestaande veldleger afwachten";return end
    if options.expand and targets[0] then
        if send({t="attack",tile=targets[0],ratio=ratio},"uitbreiden naar vrij terrein") then state.lastSend=os.clock() end
        return
    end
    if options.attack or options.expand then
        local truce=state.historical and (state.historical.grace or 0) or (Config.SPAWN_IMMUNITY_SECONDS or 0)
        if os.clock()-(state.playingAt or 0)<truce then state.reason="Beginbescherming afwachten";return end
        local weakest=nil
        for id in pairs(targets) do
            local enemy=state.players[id]
            if id~=0 and enemy and enemy.alive and (options.attack or enemy.isBot) and me.troops>=enemy.troops*options.strength then
                if not weakest or enemy.troops<state.players[weakest].troops then weakest=id end
            end
        end
        if weakest then
            if send({t="attack",tile=targets[weakest],ratio=ratio},"aanval op zwakkere buur "..weakest) then state.lastSend=os.clock() end
        else state.reason="Geen zwakke aangrenzende vijand; bondgenoten overgeslagen" end
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
    W,H,N=Config.MAP_W,Config.MAP_H,Config.NUM_TILES
    assert(type(W)=="number" and type(H)=="number" and N==W*H and N<=4000000,"Onbekende kaartconfiguratie")
    assert(type(Config.attackPresets)=="function" and type(Net.unpackPlayers)=="function","Spelversie wijkt af")
    folder=RS:WaitForChild("ConquestNet",15)
    assert(folder,"ConquestNet ontbreekt")
    for _,name in ipairs({"State","Delta","Intent","Lobby","LobbyIntent"}) do
        local obj=folder:WaitForChild(name,10)
        assert(obj and obj:IsA("RemoteEvent"),"Remote ontbreekt: "..name)
    end
    connect(folder.State.OnClientEvent,state_event)
    connect(folder.Delta.OnClientEvent,function(data)
        if not state.id then return end
        if state.snapshotReady then apply_delta(data)
        else
            assert(#state.pending<100,"Snapshot blijft uit; delta-wachtrij vol")
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
            halt("Opnieuw synchroniseren; schakel functies daarna weer aan.")
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
