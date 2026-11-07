-- Luau | FrontPanel_v2.lua | Roblox client | Pixel Front
local VERSION="6.16-repo-strategy"
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
 combatAware=true,preciseOrders=true,layeredSams=true,attritionAware=true,capRecovery=true,neighborReserve=true,growthDefense=true,adaptiveSams=true,activeDefense=true,protect=true,finishHumans=true,routeAwareTargets=true,adaptiveLandCampaign=true,cities=true,posts=true,nukes=false,adaptiveNukeSalvo=true,fastFrontReinforce=true,preemptNukes=true,upgradeCities=true,
 goldReserve=100000,minCluster=3,nukeDelay=60,maxCities=10,maxCityLevel=3,buildDelay=8,
 rivers=true,sams=true,maxFronts=3,riverRange=24,seaRange=192,maxSams=4,botCities=true,preserveBotCities=true,
 recordData=true,growthAware=true,catchUp=true,adaptiveTempo=true,parallelActions=true,buyReinforcements=true,reinforce=true,growthFloor=25,reinforceDelay=6,maxBoosts=2}
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
  maxCityLevel={1,10},buildDelay={5,60},maxFronts={1,4},riverRange={4,48},seaRange={48,512},maxSams={1,32},
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
local Recorder={schema=1,started=os.clock(),seq=0,roundStarted=os.clock(),round=nil,
 ring={},head=1,tail=0,bytes=0,pending={},pendingBytes=0,parts={},part=0,
 dropped=0,total=0,lastFlush=os.clock(),lastSample=-100,lastDecision=-100,systems={},rates={},lastByKind={}}
Recorder.session=os.date("%Y%m%d_%H%M%S").."_"..tostring(math.floor(os.clock()*1000)).."_"..tostring(math.random(100000,999999))
if type(Http.GenerateGUID)=="function" then
 local ok,guid=pcall(function() return Http:GenerateGUID(false) end)
 if ok then Recorder.session=Recorder.session.."_"..guid end
end
Recorder.prefix="frontpanel_data_"..Recorder.session
Recorder.disk=type(writefile)=="function"
Recorder.maxBytes=2*1024*1024
Recorder.maxPartBytes=512*1024
Recorder.maxParts=64
function Recorder.safe(value,depth,seen,budget)
 depth=depth or 0;seen=seen or {};budget=budget or {left=12000}
 local kind=typeof(value)
 if kind=="nil" or kind=="boolean" then return value end
 if kind=="number" then return value==value and math.abs(value)<math.huge and value or tostring(value) end
 if kind=="string" then return #value<=4096 and value or value:sub(1,4096).."[truncated]" end
 if kind=="buffer" then
  local header={}
  for i=0,math.min(16,buffer.len(value))-1 do header[#header+1]=string.format("%02x",buffer.readu8(value,i)) end
  return {type="buffer",bytes=buffer.len(value),header=table.concat(header," "),content="not recorded"}
 end
 if kind~="table" then return {type=kind} end
 if seen[value] then return "[cycle]" end
 if depth>=8 then return "[depth limit]" end
 seen[value]=true
 local result={};local count=0
 for key,item in pairs(value) do
  if budget.left<=0 or count>=2048 then result._truncated=true;break end
  budget.left-=1;count+=1
  result[tostring(key)]=Recorder.safe(item,depth+1,seen,budget)
 end
 seen[value]=nil
 return result
end
function Recorder.emit(kind,data)
 if not options.recordData then return false end
 Recorder.seq+=1
 local event={schema=Recorder.schema,session=Recorder.session,seq=Recorder.seq,
  utc=os.date("!%Y-%m-%dT%H:%M:%SZ"),elapsed=os.clock()-Recorder.started,
  round=state.round,roundElapsed=os.clock()-Recorder.roundStarted,generation=state.generation,
  kind=kind,data=Recorder.safe(data)}
 local ok,line=pcall(function() return Http:JSONEncode(event).."\n" end)
 if not ok then Recorder.error="JSON: "..tostring(line);return false end
 if #line>Recorder.maxPartBytes then Recorder.error="Gebeurtenis te groot";Recorder.dropped+=1;return false end
 Recorder.total+=1;Recorder.tail+=1;Recorder.ring[Recorder.tail]=line;Recorder.bytes+=#line
 while Recorder.bytes>Recorder.maxBytes and Recorder.head<=Recorder.tail do
  Recorder.bytes-=#Recorder.ring[Recorder.head];Recorder.ring[Recorder.head]=nil;Recorder.head+=1;Recorder.dropped+=1
 end
 if Recorder.head>4096 then
  local compact={}
  for i=Recorder.head,Recorder.tail do compact[#compact+1]=Recorder.ring[i] end
  Recorder.ring=compact;Recorder.head=1;Recorder.tail=#compact
 end
 if Recorder.disk and not Recorder.diskCapped then
  if Recorder.pendingBytes+#line>Recorder.maxPartBytes then Recorder.flush(true) end
  if Recorder.disk and not Recorder.diskCapped then
   Recorder.pending[#Recorder.pending+1]=line;Recorder.pendingBytes+=#line;Recorder.pendingLastSeq=Recorder.seq
  end
 end
 return true
end
function Recorder.flush(force)
 if not Recorder.disk or Recorder.pendingBytes==0 then return end
 if not force and os.clock()-Recorder.lastFlush<5 and Recorder.pendingBytes<128*1024 then return end
 local pending=table.concat(Recorder.pending)
 local current=Recorder.partText or ""
 local reuse=Recorder.part>0 and #current+#pending<=Recorder.maxPartBytes
 if not reuse and Recorder.part>=Recorder.maxParts then
  Recorder.error="Bestandslimiet bereikt; recent geheugen blijft beschikbaar"
  Recorder.diskCapped=true;Recorder.pending={};Recorder.pendingBytes=0;return
 end
 local part=reuse and Recorder.part or Recorder.part+1
 local text=reuse and (current..pending) or pending
 local path=Recorder.prefix..string.format("_part%03d.jsonl",part)
 local ok,err=pcall(writefile,path,text)
 Recorder.lastFlush=os.clock()
 if not ok then Recorder.error="Opslaan: "..tostring(err);Recorder.disk=false;return end
 if not reuse then Recorder.parts[#Recorder.parts+1]=path end
 Recorder.part=part;Recorder.partText=text;Recorder.diskSeq=Recorder.pendingLastSeq
 Recorder.pending={};Recorder.pendingBytes=0
 local manifest={schema=1,version=VERSION,session=Recorder.session,parts=Recorder.parts,
  latestSequence=Recorder.seq,memoryDropped=Recorder.dropped,partLimit=Recorder.maxParts,
  note="JSONL parts in sequence; client observations only; sampled players every 2 seconds; no full map buffers"}
 local saved,fault=pcall(function() writefile(Recorder.prefix.."_index.json",Http:JSONEncode(manifest)) end)
 if not saved then Recorder.error="Index: "..tostring(fault) end
end
function Recorder.memory_text()
 local lines={}
 for i=Recorder.head,Recorder.tail do lines[#lines+1]=Recorder.ring[i] end
 return table.concat(lines)
end
function Recorder.export()
 Recorder.emit("export",{lastSequence=Recorder.seq,memoryDropped=Recorder.dropped,diskParts=Recorder.part,error=Recorder.error})
 Recorder.flush(true)
 local chunks={};local complete=Recorder.disk and type(readfile)=="function" and Recorder.part>0
 if complete then
  for _,path in ipairs(Recorder.parts) do
   local ok,text=pcall(readfile,path)
   if not ok then complete=false;break end
   chunks[#chunks+1]=text
  end
 end
 local gap=nil
 if complete and Recorder.diskSeq and Recorder.seq>Recorder.diskSeq then
  local firstMemory=Recorder.seq-(Recorder.tail-Recorder.head)
  if firstMemory>Recorder.diskSeq+1 then gap={from=Recorder.diskSeq+1,to=firstMemory-1} end
  for i=Recorder.head,Recorder.tail do
   local sequence=firstMemory+i-Recorder.head
   if sequence>Recorder.diskSeq then chunks[#chunks+1]=Recorder.ring[i] end
  end
 end
 local body=complete and table.concat(chunks) or Recorder.memory_text()
 local metadata={schema=1,session=Recorder.session,kind="export_manifest",version=VERSION,
  durationSeconds=os.clock()-Recorder.started,matchObserved=Recorder.matchObserved==true,lastPhase=state.phase,
  lastSequence=Recorder.seq,lastDiskSequence=Recorder.diskSeq,missingSequenceRange=gap,parts=Recorder.part,partLimitReached=Recorder.diskCapped==true,
  memoryDropped=Recorder.dropped,source=complete and ((Recorder.diskSeq and Recorder.seq>Recorder.diskSeq) and "disk_parts_and_recent_memory" or "disk_parts") or "recent_memory",
  firstRetainedMemorySequence=Recorder.seq-(Recorder.tail-Recorder.head),
  error=Recorder.error,samplingSeconds=2,fullMapRecorded=false,
  note="Client-visible observations; unknown and sampled data are not a complete server replay. Numeric dictionary keys are strings."}
 local text=Http:JSONEncode(metadata).."\n"..body
 local path=Recorder.prefix..(complete and "_export.jsonl" or "_recent.jsonl")
 if type(writefile)=="function" then
  local ok,err=pcall(writefile,path,text)
  if ok and complete and Recorder.matchObserved then
   local saved,fault=pcall(writefile,"frontpanel_latest_match.jsonl",text)
   if not saved then Recorder.error="Laatste wedstrijdkopie: "..tostring(fault) end
  end
  if ok then return path,not Recorder.matchObserved and "Opgeslagen; deze opname bevat nog geen wedstrijd" or ((complete and not Recorder.diskCapped) and "Opgeslagen" or "Gedeeltelijke tijdlijn; zie exportmetadata") end
  Recorder.error=tostring(err)
 end
 if type(setclipboard)=="function" then
  local ok=pcall(setclipboard,text)
  if ok then return nil,"Recente tijdlijn naar klembord gekopieerd" end
 end
 return nil,"Geen bestand of klembord beschikbaar; gebruik Toon recente data"
end
function Recorder.system(name,status,detail)
 local old=Recorder.systems[name]
 local entry={status=status,detail=detail or "",at=os.clock()}
 Recorder.systems[name]=entry
 if not old or old.status~=status or old.detail~=entry.detail or entry.at-old.at>=10 then
  Recorder.emit("system",{name=name,status=status,detail=entry.detail})
 end
end
function Recorder.receive(kind,payload,extra)
 local rate=Recorder.rates[kind] or {count=0,bytes=0};Recorder.rates[kind]=rate
 rate.count+=1
 if typeof(payload)=="buffer" then rate.bytes+=buffer.len(payload) end
 local now=os.clock()
 if kind=="phase" and type(payload)=="table" then
  if Recorder.receivedPhase==payload.phase and now-(Recorder.lastByKind.phase or -100)<5 then return end
  Recorder.receivedPhase=payload.phase;Recorder.lastByKind.phase=now
 end
 if kind=="init" then
  if Recorder.round~=payload.round then Recorder.roundStarted=now;Recorder.round=payload.round end
 end
 if kind=="structs" then return end
 if kind=="portgold" or kind=="rails" or kind=="missiles" then
  if now-(Recorder.lastByKind[kind] or -100)<5 then return end
  Recorder.lastByKind[kind]=now
 end
 if kind=="players" or kind=="fronts" or kind=="armies" or kind=="vehicles" then
  if now-(Recorder.lastByKind[kind] or -100)<2 then return end
  Recorder.lastByKind[kind]=now
 end
 Recorder.emit("server."..tostring(kind),{payload=payload,extra=extra,lastSentSerial=state.orderSerial,lastSentOrder=state.lastCommand,correlation="context only; not a guaranteed acknowledgement match"})
end
Recorder.emit("session",{version=VERSION,placeId=game.PlaceId,gameId=game.GameId,settings=options,
 fileSupport=Recorder.disk,clipboardSupport=type(setclipboard)=="function",
 limits={memoryBytes=Recorder.maxBytes,partBytes=Recorder.maxPartBytes,parts=Recorder.maxParts,playerSampleSeconds=2},
 scope="Client-visible data only. Buffers summarized; normalized player/front/structure records stored separately. No inferred enemy gold or hidden orders."})

local UI={
 tween=game:GetService("TweenService"),
 bg=Color3.fromRGB(14,18,28),surface=Color3.fromRGB(23,30,44),
 hover=Color3.fromRGB(32,43,61),border=Color3.fromRGB(46,59,79),
 text=Color3.fromRGB(232,239,250),muted=Color3.fromRGB(155,173,196),
 accent=Color3.fromRGB(96,165,250),selected=Color3.fromRGB(30,57,91),
 enabled=Color3.fromRGB(26,63,57),green=Color3.fromRGB(74,222,157),
 danger=Color3.fromRGB(102,36,52),red=Color3.fromRGB(255,151,165),
}
function UI.corner(object,radius)
 local corner=Instance.new("UICorner")
 corner.CornerRadius=UDim.new(0,radius or 10)
 corner.Parent=object
end
function UI.stroke(object,color)
 local stroke=Instance.new("UIStroke")
 stroke.Color=color or UI.border
 stroke.Thickness=1
 stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
 stroke.Parent=object
 return stroke
end
function UI.padding(object,left,right,top,bottom)
 local padding=Instance.new("UIPadding")
 padding.PaddingLeft=UDim.new(0,left or 12)
 padding.PaddingRight=UDim.new(0,right or 12)
 padding.PaddingTop=UDim.new(0,top or 0)
 padding.PaddingBottom=UDim.new(0,bottom or 0)
 padding.Parent=object
end
function UI.animate(object,props)
 UI.tween:Create(object,TweenInfo.new(0.14,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),props):Play()
end
function UI.button(object)
 object.AutoButtonColor=false
 object.BorderSizePixel=0
 object.Font=Enum.Font.GothamMedium
 object.TextSize=14
 object.TextColor3=UI.text
 object.BackgroundColor3=UI.surface
 object:SetAttribute("RestColor",UI.surface)
 UI.corner(object,9)
 UI.stroke(object)
 UI.padding(object,12,12)
 table.insert(connections,object.MouseEnter:Connect(function()
  UI.animate(object,{BackgroundColor3=UI.hover})
 end))
 table.insert(connections,object.MouseLeave:Connect(function()
  UI.animate(object,{BackgroundColor3=object:GetAttribute("RestColor") or UI.surface})
 end))
end
function UI.button_color(object,color,textColor)
 object:SetAttribute("RestColor",color)
 UI.animate(object,{BackgroundColor3=color,TextColor3=textColor or UI.text})
end
local history,toggles,tabs={},{},{}
local status,logbox,startup
local ui_loaded=false
local gui=Instance.new("ScreenGui")
gui.Name="FrontPanelV2"
gui.ResetOnSpawn=false
gui.DisplayOrder=100000
gui.Parent=pg
local panel=Instance.new("Frame")
panel.Size=UDim2.new(0,640,0,500)
panel.AnchorPoint=Vector2.new(0.5,0.5)
panel.Position=UDim2.fromScale(0.5,0.5)
panel.BackgroundColor3=UI.bg
panel.BorderSizePixel=0
panel.Parent=gui
UI.corner(panel,14)
UI.stroke(panel)
UI.scale=Instance.new("UIScale")
UI.scale.Parent=panel
function UI.fit()
 local camera=workspace.CurrentCamera
 if not camera then return end
 local viewport=camera.ViewportSize
 UI.scale.Scale=math.min(1,math.max(1,viewport.X-24)/640,math.max(1,viewport.Y-72)/500)
end
function UI.watch_camera()
 if UI.cameraConnection then UI.cameraConnection:Disconnect() end
 local camera=workspace.CurrentCamera
 if camera then
  UI.cameraConnection=camera:GetPropertyChangedSignal("ViewportSize"):Connect(UI.fit)
  table.insert(connections,UI.cameraConnection)
 end
 UI.fit()
end
UI.watch_camera()
table.insert(connections,workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(UI.watch_camera))
local title=Instance.new("TextLabel")
title.Size=UDim2.new(1,-116,0,54)
title.Position=UDim2.fromOffset(18,0)
title.Font=Enum.Font.GothamBold
title.TextXAlignment=Enum.TextXAlignment.Left
title.BackgroundTransparency=1
title.TextColor3=UI.text
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
 UI.button(b)
 return b
end
local minimize=simple_button("−",542,10,38,34,panel)
local close=simple_button("×",588,10,38,34,panel)
UI.button_color(close,UI.danger,UI.red)
local collapsed=false
local expanded=panel.Size
local function cleanup()
 if not alive then return end
 Recorder.emit("stop",{reason="UI closed"})
 local path,message=Recorder.export()
 print("[FrontPanel] "..message..(path and (": "..path) or ""))
 alive=false
 state.generation=state.generation+1
 for _,c in ipairs(connections) do c:Disconnect() end
end
close.Activated:Connect(function() cleanup(); gui:Destroy() end)
minimize.Activated:Connect(function()
 collapsed=not collapsed
 panel.Size=collapsed and UDim2.new(0,640,0,54) or expanded
 for _,tab in pairs(tabs) do tab.page.Visible=not collapsed and tab.selected end
 for _,child in ipairs(panel:GetChildren()) do
  if child~=title and child~=minimize and child~=close then
   if child:IsA("GuiObject") and not child:IsA("ScrollingFrame") then
    child.Visible=not collapsed and (child~=startup or not ui_loaded)
   end
  end
 end
 minimize.Text=collapsed and "+" or "−"
end)
startup=Instance.new("TextLabel")
startup.Size=UDim2.new(1,-32,1,-72)
startup.Position=UDim2.new(0,16,0,60)
startup.Font=Enum.Font.GothamMedium
startup.Text="UI laden... Als dit blijft staan, is het bestand mogelijk onvolledig geplakt."
startup.TextColor3=Color3.new(1,1,1)
startup.TextWrapped=true
startup.TextSize=16
startup.BackgroundColor3=UI.bg
UI.corner(startup,10)
startup.ZIndex=20
startup.Parent=panel
local function log(message)
 Recorder.emit("log",{message=tostring(message)})
 local line=os.date("%H:%M:%S").." "..tostring(message)
 table.insert(history,line)
 if #history>40 then table.remove(history,1) end
 if logbox then logbox.Text=table.concat(history,"\n") end
 print("[FrontPanel] "..line)
end
local function refresh_toggles()
 for key,item in pairs(toggles) do
  item.button.Text=""
  if item.caption then item.caption.Text=item.name end
  UI.button_color(item.button,options[key] and UI.enabled or UI.surface)
  item.button:SetAttribute("Enabled",options[key])
  if item.switch then
   UI.animate(item.switch,{BackgroundColor3=options[key] and UI.green or UI.border})
   UI.animate(item.knob,{Position=UDim2.fromOffset(options[key] and 23 or 3,3)})
  end
 end
 title.Text="FRONT PANEL "..VERSION.." | "..(options.dry and "OBSERVATIE" or "ACTIEF")
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
  if tab.button then
   UI.button_color(tab.button,tab.selected and UI.selected or UI.surface,tab.selected and UI.accent or UI.muted)
   tab.indicator.Visible=tab.selected
  end
 end
end
local function row(tab,class,props)
 local t=tabs[tab]
 local object=Instance.new(class)
 for k,v in pairs(props) do object[k]=v end
 object.Position=UDim2.new(0,0,0,t.y)
 object.Parent=t.page
 object.BorderSizePixel=0
 object.Font=Enum.Font.Gotham
 if object:IsA("TextButton") then
  UI.button(object)
 elseif object:IsA("TextBox") then
  object.BackgroundColor3=UI.surface
  object.TextColor3=UI.text
  object.TextXAlignment=Enum.TextXAlignment.Left
  object.TextYAlignment=object.MultiLine and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center
  object.Font=object.MultiLine and Enum.Font.Code or Enum.Font.GothamMedium
  UI.corner(object,9)
  local outline=UI.stroke(object)
  UI.padding(object,12,12,object.MultiLine and 10 or 0,object.MultiLine and 10 or 0)
  table.insert(connections,object.Focused:Connect(function() UI.animate(outline,{Color=UI.accent}) end))
  table.insert(connections,object.FocusLost:Connect(function() UI.animate(outline,{Color=UI.border}) end))
 else
  object.TextColor3=UI.muted
  object.TextSize=13
  object.LineHeight=1.15
 end
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
 local b=row(tab,"TextButton",{Size=UDim2.new(1,-10,0,44),Text=text,
  BackgroundColor3=UI.surface,TextColor3=UI.text,TextSize=14,TextWrapped=true})
 b.Activated:Connect(guard(callback))
 return b
end
local function toggle(tab,name,key)
 toggles[key]={name=name,button=button(tab,name,function()
  Recorder.emit("settings",{key=key,value=not options[key]});options[key]=not options[key];state.reason=nil;refresh_toggles();save_settings()
  log(name..": "..tostring(options[key]))
  if key=="dry" then log(options.dry and "Observatie: geen spelorders." or "Actieve modus: ingeschakelde functies versturen orders.") end
 end)}
 local item=toggles[key]
 item.button.TextXAlignment=Enum.TextXAlignment.Left
 item.button.Text=""
 item.caption=Instance.new("TextLabel")
 item.caption.Size=UDim2.new(1,-66,1,0)
 item.caption.BackgroundTransparency=1
 item.caption.Font=Enum.Font.GothamMedium
 item.caption.TextSize=14
 item.caption.TextColor3=UI.text
 item.caption.TextWrapped=true
 item.caption.TextXAlignment=Enum.TextXAlignment.Left
 item.caption.Text=name
 item.caption.Parent=item.button
 item.switch=Instance.new("Frame")
 item.switch.Name="ToggleTrack"
 item.switch.Size=UDim2.fromOffset(44,24)
 item.switch.Position=UDim2.new(1,-54,0.5,-12)
 item.switch.BorderSizePixel=0
 item.switch.Parent=item.button
 UI.corner(item.switch,12)
 item.knob=Instance.new("Frame")
 item.knob.Name="ToggleKnob"
 item.knob.Size=UDim2.fromOffset(18,18)
 item.knob.Position=UDim2.fromOffset(3,3)
 item.knob.BackgroundColor3=UI.text
 item.knob.BorderSizePixel=0
 item.knob.Parent=item.switch
 UI.corner(item.knob,9)
end
local function number_input(tab,name,key,lo,hi)
 label(tab,name,25)
 local box=row(tab,"TextBox",{Size=UDim2.new(1,-10,0,35),Text=tostring(options[key]),
  BackgroundColor3=Color3.fromRGB(40,45,60),TextColor3=Color3.new(1,1,1),TextSize=16,ClearTextOnFocus=false})
 box.FocusLost:Connect(function()
  local value=tonumber(box.Text)
  if value and value==value and value>=lo and value<=hi then Recorder.emit("settings",{key=key,value=value});options[key]=value;save_settings() end
  box.Text=tostring(options[key])
 end)
end
local ui_ok,ui_error=xpcall(function()
 panel.ClipsDescendants=true
 for i,name in ipairs({"Overzicht","Match","Oorlog","Instellen","Foutlog","Data"}) do
  local page=Instance.new("ScrollingFrame")
  page.Position=UDim2.new(0,162,0,66)
  page.Size=UDim2.new(1,-176,1,-130)
  page.CanvasSize=UDim2.new(0,0,0,0)
  page.BackgroundTransparency=1
  page.BorderSizePixel=0
  page.ScrollBarThickness=3
  page.ScrollBarImageColor3=UI.accent
  page.VerticalScrollBarInset=Enum.ScrollBarInset.ScrollBar
  page.ScrollingDirection=Enum.ScrollingDirection.Y
  page.Visible=false
  page.Parent=panel
  tabs[name]={page=page,y=0,selected=false}
  local name_copy=name
  local nav=simple_button(name,14,66+(i-1)*46,132,38,panel)
  nav.TextXAlignment=Enum.TextXAlignment.Left
  tabs[name].button=nav
  local indicator=Instance.new("Frame")
  indicator.Size=UDim2.fromOffset(3,18)
  indicator.Position=UDim2.new(0,-8,0.5,-9)
  indicator.BackgroundColor3=UI.accent
  indicator.BorderSizePixel=0
  indicator.Parent=nav
  UI.corner(indicator,2)
  tabs[name].indicator=indicator
  nav.Activated:Connect(function() select_tab(name_copy) end)
 end
 status=label("Overzicht","Spelverbinding wordt geladen...",400)
 status.BackgroundTransparency=0
 status.BackgroundColor3=UI.surface
 status.TextColor3=UI.text
 status.Font=Enum.Font.Code
 UI.corner(status,10)
 UI.stroke(status)
 UI.padding(status,14,14,12,12)
 label("Overzicht","Zet de gewenste functies aan. ACTIEF voert orders uit. OBSERVATIE toont alleen plannen. Instellingen worden automatisch opgeslagen wanneer je executor dit ondersteunt.",100)
 toggle("Match","Auto join","queue"); toggle("Match","Auto spawn","spawn"); toggle("Match","Verlaat na einde","leave")
 toggle("Match","Herladen na teleport","reload")
 toggle("Match","Historisch overslaan","skipHistorical")
 label("Match","Auto spawn kiest op historische kaarten een groot beschikbaar land; op andere kaarten een vrije plek. Herladen wordt aangevraagd bij je executor en is afhankelijk van diens ondersteuning.",120)
 toggle("Oorlog","Uitbreiden","expand"); toggle("Oorlog","Zwakke buren aanvallen","attack"); toggle("Oorlog","Verdedigen","defend")
 toggle("Oorlog","Bescherm tegen buren","protect")
 toggle("Oorlog","Sparen bij sterke aangrenzende buren","neighborReserve")
 toggle("Oorlog","Kleine capaciteitsgroei bij onhaalbare reserve","capRecovery")
 toggle("Oorlog","Laatste zwakke menselijke tegenstanders eerst","finishHumans")
 toggle("Oorlog","Bereikbare hoofdmacht boven losse landstukjes","routeAwareTargets")
 toggle("Oorlog","Gecontroleerd aanvallen bij bruikbaar overwicht","adaptiveLandCampaign")
 toggle("Oorlog","Steden bouwen","cities")
 toggle("Oorlog","Grensposten bouwen","posts")
 toggle("Oorlog","Strategische atoomnukes","nukes")
 toggle("Oorlog","Nuke op sterkere huizeneconomie","preemptNukes")
 toggle("Oorlog","Rivieren en zee oversteken","rivers")
 toggle("Oorlog","Anti-nuke bij steden","sams")
 toggle("Oorlog","Antiraketdekking laten meegroeien","adaptiveSams")
 toggle("Oorlog","Snel inkomende legers opvangen","activeDefense")
 toggle("Oorlog","Groeireserve behouden bij verdedigen","growthDefense")
 toggle("Oorlog","Gevechtskosten meewegen bij doelkeuze","combatAware")
 toggle("Oorlog","Passende inzet tussen vaste percentages","preciseOrders")
 toggle("Oorlog","Extra antiraketlaag bij waargenomen salvo","layeredSams")
 toggle("Oorlog","Uitputtingsslag vermijden bij verdediging","attritionAware")
 toggle("Oorlog","Botlanden met steden eerst","botCities")
 toggle("Oorlog","Huizen van zwakke landen heel houden","preserveBotCities")
 toggle("Oorlog","Groeicurve benutten","growthAware")
 toggle("Oorlog","Adaptief uitbreidingstempo","adaptiveTempo")
 toggle("Oorlog","Inhaalstrategie bij dominante speler","catchUp")
 toggle("Oorlog","Bouwen naast militaire orders","parallelActions")
 toggle("Oorlog","Lopende fronten versterken","reinforce")
 toggle("Oorlog","Reinforcement met goud kopen","buyReinforcements")
 label("Oorlog","Atoomnukes: vijandelijke huizenclusters of een veilige vijandelijke zone achter een actieve aanval. Economische eerste aanval alleen tegen een nabije rivaal met betere huizeneconomie. Geen bekende SAM-dekking of eigen/geallieerde grond binnen de explosie. Goud, tokens en spelregels blijven bepalend.",160)
 toggle("Instellen","Observatiemodus","dry")
 button("Instellen","Echte acties aanzetten",function()
  options.dry=false;refresh_toggles();save_settings();log("ACTIEF: ingeschakelde functies voeren echte orders uit.")
 end)
 number_input("Instellen","Reserve % van troepencap","reserve",10,90)
 number_input("Instellen","Sterkteverhouding","strength",1.2,10)
 number_input("Instellen","Actievertraging in seconden","interval",2,30)
 toggle("Instellen","Veilige steden upgraden","upgradeCities")
 toggle("Instellen","Maximaal twee bevestigde silo-vrije nukes per salvo","adaptiveNukeSalvo")
 toggle("Instellen","Lopend front sneller aanvullen","fastFrontReinforce")
 label("Instellen","Nukes blijven afhankelijk van goud, reserve en veilige doelen. Een volgende bom wacht op lancering en nieuw goudsaldo. Reinforcement kopen houdt de serverwachttijd; frontaanvulling verplaatst bestaande troepen.",100)
 number_input("Instellen","Goud achterhouden","goldReserve",0,10000000)
 number_input("Instellen","Maximaal aantal steden","maxCities",1,40)
 number_input("Instellen","Maximaal stadsniveau","maxCityLevel",1,10)
 number_input("Instellen","Seconden tussen bouworders","buildDelay",5,60)
 number_input("Instellen","Minimale steden in nukecluster","minCluster",2,12)
 number_input("Instellen","Seconden tussen nukes","nukeDelay",30,300)
 number_input("Instellen","Maximale actieve fronten incl. transport","maxFronts",1,4)
 number_input("Instellen","Zoekafstand bij rivieren","riverRange",4,48)
 number_input("Instellen","Zoekafstand vanaf opgesloten eiland","seaRange",48,512)
 number_input("Instellen","Basislimiet anti-nuketorens (adaptief kan hoger)","maxSams",1,32)
 number_input("Instellen","Rustige uitbreiding: minimale reserve %","growthFloor",15,60)
 number_input("Instellen","Seconden tussen versterkingen per doel","reinforceDelay",4,30)
 number_input("Instellen","Extra orders zonder terreinwinst per doel","maxBoosts",1,5)
 toggle("Data","Wedstrijd opnemen","recordData")
 label("Data","Automatisch: alle zichtbare spelers elke 2 seconden, fronten, gebouwen, orders, fouten en plannerredenen. Buffers krijgen een samenvatting. Opnamedelen maximaal 32 MB per uitvoering; exports komen erbij. Geheugen bewaart de recentste 2 MB.",125)
 button("Data","Exporteer wedstrijddata",function()
  local path,message=Recorder.export()
  log(message..(path and (": "..path) or ""))
  Recorder.exportStatus.Text=message..(path and ("\n"..path) or "")
 end)
 button("Data","Markeer dit moment",function()
  Recorder.emit("manual_marker",{reason=state.reason,phase=state.phase})
  Recorder.flush(true);log("Moment gemarkeerd in de wedstrijddata.")
 end)
 Recorder.exportStatus=label("Data","Na de wedstrijd: Exporteer wedstrijddata. Stuur frontpanel_latest_match.jsonl uit de werkmap van je executor. Een lobby-export vervangt je laatste wedstrijd niet.",110)
 button("Data","Kopieer recente data",function()
  if type(setclipboard)=="function" then
   local ok=pcall(setclipboard,Recorder.memory_text())
   log(ok and "Recente data gekopieerd (maximaal 2 MB)." or "Kopiëren mislukt.")
  else log("Geen klembordfunctie; gebruik export of Toon recente data.") end
 end)
 button("Data","Toon recente data",function()
  Recorder.preview.Text=Recorder.memory_text():sub(-24000)
 end)
 Recorder.preview=row("Data","TextBox",{Size=UDim2.new(1,-10,0,400),Text="",TextSize=12,
  TextColor3=Color3.new(1,1,1),BackgroundColor3=Color3.fromRGB(30,35,45),TextWrapped=true,
  MultiLine=true,ClearTextOnFocus=false,TextEditable=true})
 button("Foutlog","Kopieer foutlog",function()
  if type(setclipboard)=="function" then setclipboard(table.concat(history,"\n"))
  else log("Geen klembordfunctie; maak een screenshot.") end
 end)
 logbox=row("Foutlog","TextBox",{Size=UDim2.new(1,-10,0,800),Text="",TextSize=13,
  TextColor3=Color3.new(1,1,1),BackgroundColor3=Color3.fromRGB(30,35,45),TextWrapped=true,
  TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,
  MultiLine=true,ClearTextOnFocus=false,TextEditable=false})
 local stop=simple_button("NOODSTOP · Automatische acties stoppen",14,446,612,40,panel)
 UI.button_color(stop,UI.danger,UI.red)
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
  Recorder.emit("teleport",{state=tostring(teleport_state)})
  Recorder.flush(true)
  if teleport_state==Enum.TeleportState.Started and not Recorder.teleportExported then
   Recorder.teleportExported=true
   local path,message=Recorder.export()
   log(message..(path and (": "..path) or ""))
  end
  if teleport_state==Enum.TeleportState.Failed then Recorder.teleportExported=false end
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
  local remote_version=source:match('local%%s+VERSION%%s*=%%s*"([^"\n]+)"')
  assert(remote_version==%q,"GitHub bevat versie "..tostring(remote_version).."; verwacht "..%q..". Voer het gedownloade bestand opnieuw uit.")
  local run,compile_error=loadstring(source)
  assert(run,compile_error)
  run()
 end)
 if not ok then warn("[FrontPanel herladen] "..tostring(err)) end
end)
]=],snapshot,RAW_URL.."?v=6.16",VERSION,VERSION)
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
    elseif kind=="vehicles" then
        state.transportKnown=false
        if changed then
            Recorder.emit("transport_degraded",{effect="vehicle count unavailable; serialize water orders with server validation",landLimit=Config and Strategy.land_front_limit()})
            for _,name in ipairs(message_decoders.vehicles) do
                if Net and type(Net[name])=="function" then
                    local ok,result=pcall(Net[name],payload)
                    Recorder.emit("decoder_probe",{kind=kind,name=name,success=ok,result=result})
                end
            end
        end
    end
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
function Strategy.quarantine_attack_tile(tile,own)
    if type(tile)~="number" or tile%1~=0 or tile<0 or tile>=N then return end
    state.quarantinedAttack=state.quarantinedAttack or {}
    state.blockedAttack=state.blockedAttack or {}
    state.quarantinedAttack[tile]={at=os.clock(),own=own==true}
    state.blockedAttack[tile]=math.huge
    state.frontier[tile]=nil
    if own and state.owners then
        buffer.writeu8(state.owners,tile,state.id)
        refresh_tile(tile);neighbours(tile,refresh_tile)
        state.cityCache=nil
    end
    for id,entry in pairs(state.waterTargets or {}) do if entry.tile==tile then state.waterTargets[id]=nil end end
    for id,point in pairs(state.representatives or {}) do if point==tile then state.representatives[id]=nil end end
    state.lastWaterScan=-10000
    state.mapRevision=(state.mapRevision or 0)+1
    state.mapRepairPending=true
    if own then state.mapRepairUrgent=true end
    Recorder.emit("attack_tile_quarantined",{tile=tile,own=own==true})
end
function Strategy.handle_own_denial(payload)
    if payload.reason~="own" then return end
    if type(payload.tile)=="number" then Strategy.quarantine_attack_tile(payload.tile,true);return end
    local candidates={}
    for _,order in ipairs(state.attackOrders or {}) do
        if not order.rejected and os.clock()-order.at<=4 then candidates[#candidates+1]=order end
    end
    for _,order in ipairs(candidates) do
        order.rejected=true
        Strategy.quarantine_attack_tile(order.tile,#candidates==1)
    end
    state.mapRepairPending=true;state.mapRepairUrgent=true
    Recorder.emit("target_race",{candidates=#candidates,reason="server reports own; quarantine until new ownership data"})
end
function Strategy.repair_map_if_needed()
    local delay=state.mapRepairUrgent and 15 or 45
    if not state.mapRepairPending or not folder or not state.id or state.awaitingInit or not state.ready or state.phase~="playing"
        or os.clock()-(state.lastMapRepairAt or -10000)<delay then return end
    state.lastMapRepairAt=os.clock();state.mapRepairPending=false;state.mapRepairUrgent=false
    folder.Intent:FireServer({t="hello",tile=0})
    Recorder.emit("map_repair_requested",{reason="ambiguous ownership or own rejection"})
    log("Kaart opnieuw aangevraagd; onbetrouwbare aanvalstegels worden overgeslagen.")
end
function Strategy.attack_tile_valid(tile,expectedOwner)
    if type(tile)~="number" or tile%1~=0 or tile<0 or tile>=N or not state.owners or not state.terrain then return false end
    if state.quarantinedAttack and state.quarantinedAttack[tile] then return false end
    if (state.blockedAttack and (state.blockedAttack[tile] or 0)>os.clock()) or not passable(tile) then return false end
    local owner=buffer.readu8(state.owners,tile)
    if owner==state.id or (expectedOwner~=nil and owner~=expectedOwner) then return false end
    if owner~=0 then
        if state.allies[owner] then return false end
        local me,other=state.players[state.id],state.players[owner]
        if me and other and me.team~=nil and me.team==other.team then return false end
        if other and not other.alive then return false end
    end
    return true
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
    local seen,ambiguous={},{}
    for i=1,#changes,2 do
        local tile,owner=changes[i],changes[i+1]
        if seen[tile]~=nil and seen[tile]~=owner then ambiguous[tile]=true end
        seen[tile]=owner
    end
    for tile in pairs(ambiguous) do Strategy.quarantine_attack_tile(tile,false) end
    local deltaStats=Recorder.deltaStats or {packets=0,changes=0,transfers={}}
    Recorder.deltaStats=deltaStats;deltaStats.packets+=1;deltaStats.changes+=#changes/2
    deltaStats.firstAt=deltaStats.firstAt or os.clock();deltaStats.lastAt=os.clock()
    local changed=false
    for i=1,#changes,2 do
        local tile,owner=changes[i],changes[i+1]
        if ambiguous[tile] then continue end
        local quarantined=state.quarantinedAttack and state.quarantinedAttack[tile]
        if quarantined and quarantined.own and owner~=state.id and os.clock()-quarantined.at<0.35 then continue end
        if quarantined then
            state.quarantinedAttack[tile]=nil
            state.blockedAttack[tile]=nil
            touched[tile]=true;neighbours(tile,function(other) touched[other]=true end)
        end
        local previous=buffer.readu8(state.owners,tile)
        buffer.writeu8(state.owners,tile,owner)
        if owner==state.id and previous~=state.id then state.lastCaptureAt=os.clock() end
        if state.structures and state.structures[tile] then state.cityCache=nil end
        if owner==state.id then Strategy.sample_owned(tile) end
        if previous~=owner then
            local key=tostring(previous)..">"..tostring(owner)
            deltaStats.transfers[key]=(deltaStats.transfers[key] or 0)+1
            changed=true;touched[tile]=true
            neighbours(tile,function(other) touched[other]=true end)
        end
        if owner~=0 and owner~=state.id then state.representatives[owner]=tile end
    end
    local refreshes=0
    if state.terrain then
        for tile in pairs(touched) do refresh_tile(tile);refreshes+=1 end
    end
    state.lastDeltaRefreshCount=refreshes
    if changed then state.mapRevision=(state.mapRevision or 0)+1 end
    state.lastGoodDelta=os.clock()
    return true
end
local function index_map(generation)
    task.spawn(guard(function()
        state.ready=false
        for tile=0,N-1 do
            if not alive or generation~=state.generation then return end
            local owner=buffer.readu8(state.owners,tile)
            if owner==state.id then
                refresh_tile(tile);Strategy.sample_owned(tile)
                neighbours(tile,function(other)
                    if buffer.readu8(state.owners,other)~=state.id and passable(other) then state.frontier[other]=true end
                end)
            end
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
    state.owners=owners;state.snapshotReady=true;state.mapRevision=(state.mapRevision or 0)+1
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
function Strategy.attack_choices(needed)
    local presets=Config.attackPresets(state.mode)
    if not options.preciseOrders then return presets end
    local me=state.players[state.id]
    if not me or me.troops<=0 then return presets end
    local choices=table.clone(presets)
    local ratio=math.max(Config.MIN_ATTACK_RATIO or 0.05,math.ceil(needed/me.troops*1000-1e-9)/1000)
    if math.floor(me.troops*ratio)<math.ceil(needed) then ratio+=0.001 end
    local limit=math.min(0.75,Config.MAX_ATTACK_RATIO or 1)
    if ratio<=limit then choices[#choices+1]=ratio end
    return choices
end
function Strategy.combat_estimate(id,tile,committed)
    local me,enemy=state.players[state.id],state.players[id]
    if not me or not enemy or not Strategy.attack_tile_valid(tile,id) or committed<=0 then return nil end
    local altitude=bit32.band(buffer.readu8(state.terrain,tile),63)
    local terrain=altitude<11 and 1 or altitude<21 and 2 or 3
    local mag=(Config.TERRAIN_MAG or {80,100,120})[terrain]
    local speed=(Config.TERRAIN_SPEED or {16.5,20,25})[terrain]
    local covered=false
    for _,post in pairs(state.structures or {}) do
        if post.ownerId==id and post.kind==3 and not post.uc and buffer.readu8(state.owners,post.tile)==id
            and Strategy.distance(tile,post.tile)<=(Config.DEFENSE_POST_RANGE or 30) then covered=true;break end
    end
    if covered then mag*=Config.DEFENSE_POST_DEFENSE_BONUS or 5;speed*=Config.DEFENSE_POST_SPEED_BONUS or 3 end
    if enemy.isBot==true then mag*=Config.BOT_DEFENDER_LOSS_MULT or 1 end
    local floor=Config.DEFENSE_DEBUFF_FLOOR or 0.7
    local exponent=math.clamp(-math.log(2)/math.max(1,Config.DEFENSE_DEBUFF_HALFLIFE or 50000)
        *((enemy.tiles or 0)-(Config.DEFENSE_DEBUFF_MIDPOINT or 150000)),-60,60)
    local size=floor+(1-floor)*(1-1/(1+math.exp(exponent)))
    local threshold=Config.LARGE_ATTACKER_TILES or 100000
    local lossBonus=(me.tiles or 0)>threshold and (threshold/me.tiles)^(Config.LARGE_ATTACKER_LOSS_EXP or 0.35) or 1
    local speedThreshold=Config.LARGE_ATTACKER_SPEED_TILES or threshold
    local speedBonus=(me.tiles or 0)>speedThreshold and (speedThreshold/me.tiles)^(Config.LARGE_ATTACKER_SPEED_EXP or 0.6) or 1
    local density=enemy.troops/math.max(1,enemy.tiles or 0)
    local ratio=math.clamp(enemy.troops/committed,Config.ATTACK_RATIO_MIN or 0.6,Config.ATTACK_RATIO_MAX or 2)
    local blend=Config.ATTACK_LOSS_BLEND or 0.6
    local loss=mag*(blend*ratio*(Config.ATTACK_MAG_SCALE or 0.8)*size*lossBonus
        +(1-blend)*(Config.ATTACK_ALT_COEF or 1.3)*density/100)
    local time=math.clamp(enemy.troops/((Config.SPEED_RATIO_DIV or 5)*committed),
        Config.SPEED_RATIO_MIN or 0.2,Config.SPEED_RATIO_MAX or 1.5)*speed*size*speedBonus
    return {lossPerTile=loss,defenderLossPerTile=density,timeIndex=time,
        initialLandBudget=committed/math.max(1,loss),covered=covered,terrain=terrain}
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
            if front.id~=id and other and other.isBot~=true and other.alive
                and other.troops+enemy.troops>me.troops*0.45 then return nil end
        end
    end
    if options.protect then required=math.max(required,Strategy.risk_reserve()) end
    local multiplier=covered and 2 or (enemy.isBot==true and 0.9 or 1.4)
    local needed=math.max(Config.MIN_ATTACK_TROOPS or 250,enemy.troops*multiplier)
    local best=nil
    for _,ratio in ipairs(Strategy.attack_choices(needed)) do
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
    local _,myCities=Strategy.city_value(state.id)
    local _,theirCities=Strategy.city_value(id)
    local advantage=enemy.isBot~=true and theirCities>myCities+1 and 1.35 or 1.15
    if state.catchupActive then advantage=theirCities>myCities+1 and 1.18 or 1.08 end
    if me.troops+deployed*0.60<enemy.troops*advantage then return nil end
    local strongest,total=0,0
    for other,c in pairs(Strategy.contacts()) do
        if other~=id then
            local strength=c.troops*Strategy.threat_factor(other)
            strongest=math.max(strongest,strength);total+=strength
        end
    end
    local reserve=math.max(me.troops*0.25,strongest*0.55+total*0.10+enemy.troops*0.10)
    if state.catchupActive then reserve=math.max(me.troops*0.30,strongest*0.35+total*0.08+enemy.troops*0.08) end
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
    if now-progress<(state.catchupActive and 10 or 30) or now-(state.lastBreakoutAt or -10000)<60 then return nil end
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
function Strategy.is_real_human(id,enemy)
    if not enemy or enemy.isBot~=false then return false end
    local userId=state.rosterUsers and state.rosterUsers[id]
    return userId==nil or (type(userId)=="number" and userId>0)
end
function Strategy.endgame_humans()
    local me=state.players[state.id]
    if not options.finishHumans or not options.attack or not me or not me.alive or me.troops<=0 then return {},0 end
    local context=state.planContext
    local cache=context and context.humanEndgame
    if cache and cache.players==state.players and cache.allies==state.allies and cache.troops==me.troops then
        return cache.targets,cache.count
    end
    local count,total=0,0
    for id,enemy in pairs(state.players) do
        if id~=state.id and enemy.alive and Strategy.is_real_human(id,enemy) and not friendly(id) then
            count+=1;total+=math.max(0,enemy.troops)
        end
    end
    local targets={}
    if count>=1 and count<=3 and me.troops>=math.max(Config.MIN_ATTACK_TROOPS or 250,total*4) then
        for id,enemy in pairs(state.players) do
            if id~=state.id and enemy.alive and Strategy.is_real_human(id,enemy) and not friendly(id)
                and me.troops>=math.max(Config.MIN_ATTACK_TROOPS or 250,enemy.troops*8) then
                targets[id]=true
            end
        end
    end
    if context then context.humanEndgame={players=state.players,allies=state.allies,troops=me.troops,targets=targets,count=count} end
    return targets,count
end
function Strategy.land_route(tile,id)
    if not options.routeAwareTargets or id==0 or not Strategy.attack_tile_valid(tile,id) then return nil end
    local cache=state.landRouteCache
    if not cache or cache.generation~=state.generation then
        cache={generation=state.generation,profiles={},byTile={}};state.landRouteCache=cache
    end
    for i=#cache.profiles,1,-1 do
        local profile=cache.profiles[i]
        if os.clock()-profile.at>4 then
            for _,point in ipairs(profile.tiles) do if cache.byTile[point]==profile then cache.byTile[point]=nil end end
            table.remove(cache.profiles,i)
        end
    end
    local old=cache.byTile[tile]
    if old and old.owner==id then return old end
    local context=state.planContext
    local spent=context and (context.routeBudget or 0) or 0
    local limit=math.min(4096,12288-spent)
    if limit<512 then return nil end
    local queue,seen={tile},{[tile]=true}
    local profile={owner=id,at=os.clock(),tiles=queue,area=0,capped=false,cities=0,levels=0,completed=0}
    local function visit(other)
        if not seen[other] and buffer.readu8(state.owners,other)==id and passable(other) then
            if #queue>=limit then profile.capped=true;return end
            seen[other]=true;queue[#queue+1]=other
        end
    end
    local head=1
    while head<=#queue do
        local point=queue[head];head+=1
        local structure=state.structures and state.structures[point]
        if structure and structure.kind==1 and structure.ownerId==id then
            profile.cities+=1;profile.levels+=structure.level or 1
            if not structure.uc then profile.completed+=1 end
        end
        neighbours(point,visit)
    end
    profile.area=#queue
    local enemy=state.players[id]
    profile.fragment=not profile.capped and enemy and profile.area<math.max(64,(enemy.tiles or 0)*0.15) or false
    if context then context.routeBudget=spent+#queue end
    cache.profiles[#cache.profiles+1]=profile
    for _,point in ipairs(queue) do cache.byTile[point]=profile end
    while #cache.profiles>6 do
        local stale=table.remove(cache.profiles,1)
        for _,point in ipairs(stale.tiles) do if cache.byTile[point]==stale then cache.byTile[point]=nil end end
    end
    return profile
end
function Strategy.route_score(profile)
    if not profile then return 0 end
    return (profile.fragment and -400 or 0)+(profile.capped and 60 or math.min(40,profile.area/64))
end
function Strategy.target_score(id,tile,distance,pressure)
    local me,enemy=state.players[state.id],state.players[id]
    if not me or not enemy or not enemy.alive or friendly(id) then return nil end
    if not options.attack and not (options.expand and enemy.isBot==true) then return nil end
    if not pressure and me.troops<enemy.troops*options.strength then return nil end
    local cities,value,complete=Strategy.city_value(id)
    local cityWeight=enemy.isBot==true and not options.botCities and 0.5 or 1
    local route=options.routeAwareTargets and Strategy.is_real_human(id,enemy) and Strategy.land_route(tile,id) or nil
    if route and not route.capped then cities=route.cities;value=route.levels;complete=route.completed end
    local assets=(value*2000+complete*3000+cities*1000)*cityWeight
    local land=math.sqrt(math.max(0,route and not route.capped and route.area or enemy.tiles or 0))*100
    local cost=1+enemy.troops/math.max(1,me.troops)*8
    local reward=(2000+assets+land)/cost
    if route and route.fragment then reward*=0.15 end
    if options.combatAware then
        local estimate=Strategy.combat_estimate(id,tile,math.max(Config.MIN_ATTACK_TROOPS or 250,me.troops*0.1))
        if estimate then reward/=(1+estimate.lossPerTile/80+estimate.timeIndex/50) end
    end
    local humanTargets=Strategy.endgame_humans()
    if humanTargets[id] and (not route or not route.fragment) then reward+=1000000 end
    return reward-Strategy.nearby_danger(tile)*50-(distance or 0)*4
        +math.min(200,(state.planBorders and state.planBorders[id]) or 0)*2,
        cities,enemy.isBot==true
end
function Strategy.update_catchup()
    local previous=state.catchupLeader
    local me=state.players[state.id]
    local best,bestScore=nil,0
    local total=0
    for _,entry in pairs(state.players) do if entry.alive then total+=entry.tiles or 0 end end
    if options.catchUp and me and me.alive and me.tiles>0 then
        for id,entry in pairs(state.players) do
            if id~=state.id and entry.alive and entry.isBot~=true and not friendly(id) then
                local land=(entry.tiles or 0)/math.max(1,me.tiles)
                local army=entry.troops/math.max(1,me.troops)
                local share=(entry.tiles or 0)/math.max(1,total)
                local remainsDominant=id==previous and ((land>=1.60 and share>=0.25) or army>=2.40)
                local fallingBehind=land>=1.20 and math.sqrt(land*army)>=1.45
                if remainsDominant or fallingBehind or (land>=2 and share>=0.30) or army>=3 then
                    local score=land+army*0.5
                    if score>bestScore then best,bestScore=id,score end
                end
            end
        end
    end
    state.catchupLeader=best;state.catchupActive=best~=nil
    if previous~=best then
        log(best and ("INHAALSTRATEGIE: dominante speler "..best.."; eerder haalbare veroveringen en economische investeringen") or "INHAALSTRATEGIE: gewone planning hervat")
    end
end
function Strategy.capacity_plan(targets)
    local me=state.players[state.id]
    state.pressureReason=nil
    if not me or not options.attack or #state.incoming>0 then return nil end
    local fill=me.troops/Strategy.capacity(me)
    local boxed=targets[0]==nil and not (options.rivers and state.waterTargets and state.waterTargets[0])
    if fill<(state.catchupActive and (boxed and 0.50 or 0.60) or 0.80) then return nil end
    local busy={}
    for _,front in ipairs(state.outgoing) do busy[front.id]=true end
    if options.expand and targets[0] and not busy[0] then state.pressureReason="Hoge vulling: vrije grond heeft een beschikbare route";return nil end
    local truce=state.historical and (state.historical.grace or 0) or (Config.SPAWN_IMMUNITY_SECONDS or 0)
    if os.clock()-(state.playingAt or 0)<truce then state.pressureReason="Beginbescherming afwachten";return nil end
    local limit=Strategy.land_front_limit()
    local contacts=Strategy.contacts()
    if options.protect and options.defend and (Config.MAX_FRONTS_PER_PLAYER or 4)>1 then
        for id,c in pairs(contacts) do
            if state.players[id] and state.players[id].isBot~=true and c.troops>=me.troops*0.60 then limit=math.min(limit,(Config.MAX_FRONTS_PER_PLAYER or 4)-1);break end
        end
    end
    if Strategy.active_orders()>=limit then state.pressureReason="Fronten actief; defensief serverslot behouden";return nil end
    local best,bestRatio,bestHold,bestScore=nil,nil,nil,-math.huge
    local requiredLead=state.catchupActive and (fill>=0.85 and 1.20 or 1.40) or (fill>=0.90 and 1.25 or 1.60)
    if state.catchupActive and boxed then requiredLead=1.08 end
    local considered=0
    for id,tile in pairs(targets) do
        local enemy=state.players[id]
        if id~=0 and enemy and enemy.alive and not friendly(id) and not busy[id] then
            considered+=1
            if me.troops>=enemy.troops*requiredLead then
                local top,total=0,0
                for other,c in pairs(contacts) do
                    if other~=id then local strength=c.troops*Strategy.threat_factor(other);top=math.max(top,strength);total+=strength end
                end
                local hold=math.max(me.troops*0.40,enemy.troops*0.50+top*0.45+total*0.10)
                local needed=math.max(Config.MIN_ATTACK_TROOPS or 250,enemy.troops*(state.targetProtected[id] and 1.1 or 0.60))
                local ratio=nil
                for _,preset in ipairs(Config.attackPresets(state.mode)) do
                    local sent=math.floor(me.troops*preset)
                    if preset<=0.50 and sent>=needed and me.troops-sent>=hold and (not ratio or preset<ratio) then ratio=preset end
                end
                if state.catchupActive and boxed then ratio,hold=Strategy.breakout_ratio(id,state.targetProtected[id],false) end
                local score=ratio and Strategy.target_score(id,tile,0,true)
                if score and score>bestScore then best,bestRatio,bestHold,bestScore=id,ratio,hold,score end
            end
        end
    end
    if best then state.pressureReason=string.format("%.0f%% gevuld: berekende verovering van %s",fill*100,tostring(best))
    else state.pressureReason="Hoge vulling: "..considered.." landdoelen beoordeeld; geen preset past bij overwicht en reserve voor andere buren" end
    return best,bestRatio,bestHold
end
function Strategy.contacts()
    local context=state.planContext
    if context and context.contacts and context.owners==state.owners and context.players==state.players
        and context.frontier==state.frontier and context.water==state.waterTargets and context.allies==state.allies
        and context.revision==state.mapRevision and context.generation==state.generation then return context.contacts end
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
    if context then
        context.contacts=contacts;context.owners=state.owners;context.players=state.players
        context.frontier=state.frontier;context.water=state.waterTargets;context.allies=state.allies
        context.revision=state.mapRevision;context.generation=state.generation
        context.scans=(context.scans or 0)+1
    end
    return contacts
end
function Strategy.water_failure(id,entry,reason)
    local now=os.clock()
    state.waterFailures=state.waterFailures or {}
    local count=1
    for i=#state.waterFailures,1,-1 do
        local old=state.waterFailures[i]
        if now-old.at>600 then table.remove(state.waterFailures,i)
        elseif old.id==id and Strategy.distance(old.tile,entry.tile)<96 then count=math.max(count,old.count+1);table.remove(state.waterFailures,i) end
    end
    local pause=math.min(240,45*count)
    state.waterFailures[#state.waterFailures+1]={id=id,tile=entry.tile,at=now,untilTime=now+pause,count=count}
    while #state.waterFailures>64 do table.remove(state.waterFailures,1) end
    state.waterOwnerRetry=state.waterOwnerRetry or {}
    if count>=3 then state.waterOwnerRetry[id]=now+60 end
    state.blockedLanding[entry.tile]=now+pause
    state.lastWaterScan=-10000
    Recorder.emit("water_route_failed",{id=id,tile=entry.tile,reason=reason,attempts=count,retryAfter=pause})
    log("WATER: route naar "..id.." niet geslaagd ("..reason.."); andere kust zoeken")
end
function Strategy.water_penalty(tile,id)
    local now=os.clock()
    if (state.waterOwnerRetry and (state.waterOwnerRetry[id] or 0)>now)
        or (state.blockedLanding[tile] or 0)>now then return nil end
    local penalty=0
    for _,old in ipairs(state.waterFailures or {}) do
        local distance=Strategy.distance(tile,old.tile)
        if old.id==id and distance<math.min(144,48*old.count) and old.untilTime>now then return nil end
        if old.id==id and distance<192 and now-old.at<600 then penalty+=math.max(0,192-distance)*old.count end
    end
    return penalty
end
function Strategy.poll_transports()
    if not state.ready or state.phase~="playing" then return end
    local now=os.clock()
    if now-(state.lastTransportPoll or -10000)<0.5 then return end
    state.lastTransportPoll=now
    local assigned={}
    for _,entry in pairs(state.riverOrders or {}) do if entry.vehicleId then assigned[entry.vehicleId]=entry end end
    for id,entry in pairs(state.riverOrders or {}) do
        if not entry.failed then
            local landed=state.ready and state.owners and buffer.readu8(state.owners,entry.tile)==state.id
            for _,front in ipairs(state.outgoing) do
                if front.id==id and entry.at and (state.lastFronts or 0)>entry.at
                    and not (entry.fronts or {})[front.aid or front.id] then landed=true end
            end
            if landed then
                state.riverOrders[id]=nil;state.lastWaterScan=-10000
                Recorder.emit("water_landed",{id=id,tile=entry.tile,elapsed=entry.at and now-entry.at})
            else
                local visible=false
                local reliable=state.transportKnown==true and now-(state.lastVehicles or -10000)<5
                if reliable then
                    for _,vehicle in ipairs(state.vehicles or {}) do
                        if vehicle.owner==state.id and vehicle.kind==3 and type(vehicle.id)=="number" and not (entry.existingBoats or {})[vehicle.id] then
                            if not entry.vehicleId and not assigned[vehicle.id] then entry.vehicleId=vehicle.id;assigned[vehicle.id]=entry end
                            if vehicle.id==entry.vehicleId then
                                visible=true;entry.seenAt=now
                                if vehicle.x~=entry.x or vehicle.y~=entry.y then entry.movedAt=now;entry.x=vehicle.x;entry.y=vehicle.y end
                            end
                        end
                    end
                end
                local gone=reliable and entry.seenAt and not visible and now-entry.seenAt>=5
                local expired=now>=entry.untilTime and not visible
                local stuck=visible and entry.movedAt and now-entry.movedAt>=30
                if gone or expired or stuck then
                    Strategy.water_failure(id,entry,gone and "boot verdwenen zonder landing" or stuck and "boot maakt geen voortgang" or "geen landing bevestigd binnen routevenster")
                    state.riverOrders[id]=nil
                end
            end
        elseif entry.untilTime<=now then state.riverOrders[id]=nil end
    end
end
function Strategy.water_threats()
    local threats={}
    if state.transportKnown==true and os.clock()-(state.lastVehicles or -10000)<5 then
        for _,v in ipairs(state.vehicles or {}) do
            if v.kind==4 and not friendly(v.owner) and type(v.x)=="number" and type(v.y)=="number" then
                threats[#threats+1]={x=v.x,y=v.y,radius=Config.GUNBOAT_TARGET_RANGE or 130}
                if #threats>=128 then break end
            end
        end
    end
    return threats
end
function Strategy.water_targets()
    if not options.rivers then state.waterTargets={};state.island=false;state.waterSearchInfo="Wateroversteken staat uit";return state.waterTargets end
    if os.clock()-(state.lastWaterScan or -10000)<6 then return state.waterTargets or {} end
    state.lastWaterScan=os.clock()
    local generation=state.generation
    local landExit=false
    for tile in pairs(state.frontier) do
        local id=buffer.readu8(state.owners,tile)
        if Strategy.attack_tile_valid(tile,id) then landExit=true;break end
    end
    local island=not landExit
    local opportunitySea=false
    local me=state.players[state.id]
    if me and options.attack then
        for id,enemy in pairs(state.players) do
            if id~=state.id and enemy.alive and enemy.isBot~=true and not friendly(id)
                and enemy.troops<=me.troops*0.10 and Strategy.city_value(id)>=3 then opportunitySea=true;break end
        end
    end
    if landExit then state.waterStalledAt=nil else state.waterStalledAt=state.waterStalledAt or os.clock() end
    local stalled=(state.waterStalledAt and os.clock()-state.waterStalledAt>=45)
        or os.clock()-(state.lastCaptureAt or os.clock())>=45
    local extended=island or opportunitySea or stalled
    local searchRange=extended and math.min(512,math.max(options.riverRange,options.seaRange)*(stalled and 2 or 1)) or options.riverRange
    local searchBudget=extended and math.min(N,stalled and 180000 or 100000) or 12000
    state.island=island
    local queue,depth,seen,targets={},{},{},{}
    local candidateScores={}
    local threats=Strategy.water_threats()
    local candidates={}
    local function landing_value(tile,id,distance)
        local x,y=tile%W,math.floor(tile/W)
        local space=0
        for _,offset in ipairs({{-8,0},{8,0},{0,8},{0,-8},{-16,0},{16,0},{0,16},{0,-16}}) do
            local px,py=x+offset[1],y+offset[2]
            if px>=0 and px<W and py>=0 and py<H then
                local other=py*W+px
                if passable(other) and buffer.readu8(state.owners,other)==id then space+=1 end
            end
        end
        local penalty=Strategy.water_penalty(tile,id)
        if not penalty then return nil end
        for _,threat in ipairs(threats) do
            local dx,dy=x-threat.x,y-threat.y
            if dx*dx+dy*dy<=threat.radius*threat.radius then penalty+=400 end
        end
        return space*8-distance-penalty
    end
    local function push(tile,d)
        if not seen[tile] and #queue<searchBudget then
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
                if Strategy.attack_tile_valid(other,id) then
                    local value=landing_value(other,id,d)
                    if value then
                        local list=candidates[id] or {};candidates[id]=list
                        local slot=nil
                        for i,entry in ipairs(list) do if Strategy.distance(other,entry.tile)<48 then slot=i;break end end
                        if not slot and #list<6 then slot=#list+1 end
                        if not slot then
                            for i,entry in ipairs(list) do if not slot or entry.value<list[slot].value then slot=i end end
                        end
                        if not list[slot] or value>list[slot].value then list[slot]={tile=other,distance=d,space=value+d,value=value} end
                        if not targets[id] or value>(candidateScores[id] or -math.huge) then
                            targets[id]={tile=other,distance=d,space=value+d};candidateScores[id]=value
                        end
                    end
                end
            elseif d<searchRange and not bit32.btest(buffer.readu8(state.terrain,other),128) then
                push(other,d+1)
            end
        end)
        if head%1024==0 then
            task.wait()
            if not alive or generation~=state.generation then return {} end
            if state.phase=="playing" and #state.incoming>0 and not Strategy.contained_attack() then
                state.waterSearchInfo="Waterzoektocht onderbroken: inkomende aanval"
                return state.waterTargets or {}
            end
        end
    end
    state.waterSearchInfo="Waterzoeker: "..(island and "eiland/zee" or "rivier").." | bereik "..searchRange.." | onderzocht "..#queue..(head<=#queue and " | afgebroken" or "")
    if #queue>=searchBudget then state.waterSearchInfo=state.waterSearchInfo.." | zoekbudget bereikt" end
    if island and os.clock()-(state.lastSeaLog or -10000)>20 then
        local count=0;for _ in pairs(targets) do count+=1 end
        log(state.waterSearchInfo.." | doelen "..count);state.lastSeaLog=os.clock()
    end
    state.waterCandidates=candidates;state.waterTargets=targets
    return targets
end
function Strategy.water_order(id,entry,attacksAllowed,targets,busy)
    local me,enemy=state.players[state.id],state.players[id]
    if not me or not Strategy.attack_tile_valid(entry.tile,id) or not Strategy.water_penalty(entry.tile,id) then return nil end
    local economic=id==0 or (enemy and enemy.isBot==true)
    local allowed=(id==0 and options.expand) or (id~=0 and enemy and (options.attack or (options.expand and economic)))
    if not allowed or (id~=0 and not attacksAllowed) or friendly(id) or busy[id]
        or (id~=0 and targets[id] and not state.island) then return nil end
    local pending=state.riverOrders[id]
    if pending and not pending.failed then return nil end
    local boat=math.floor(me.troops/(Config.TRANSPORT_BOAT_TROOP_DIVISOR or 5))
    if boat<(Config.TRANSPORT_BOAT_MIN_TROOPS or 250)
        or (id~=0 and (not enemy or not enemy.alive or boat<enemy.troops*(economic and 1.1 or 1.5))) then return nil end
    local hold=math.max(me.troops*0.35,options.protect and Strategy.risk_reserve() or 0)
    if me.troops-boat<hold then return nil end
    local score=id==0 and ((entry.space or 0)-entry.distance*0.25)
        or Strategy.target_score(id,entry.tile,entry.distance,true)
    if not score then return nil end
    score+=(entry.space or 0)*4
    return score,Config.attackPresets(state.mode)[1] or 0.1,hold
end
function Strategy.transport_available()
    Strategy.poll_transports()
    if not options.rivers then state.transportReason="Wateroversteken staat UIT";return false end
    if os.clock()<(state.transportRetryAt or 0) then state.transportReason="Serverlimiet boten: wachten op herpoging";return false end
    if Strategy.active_orders()>=Strategy.land_front_limit() then state.transportReason="Frontenlimiet: wachten op vrij front";return false end
    if state.transportKnown~=false then
        local available=(state.transportCount or 0)<(Config.TRANSPORT_BOAT_MAX_PER_PLAYER or 3)
        state.transportReason=available and "Voertuigdata beschikbaar" or "Bekende transportlimiet bereikt"
        return available
    end
    for _,entry in pairs(state.riverOrders or {}) do
        if not entry.failed and entry.untilTime>os.clock() then
            state.transportReason="Voertuigformaat onbekend: één oversteek loopt al";return false
        end
    end
    if os.clock()-(state.lastFallbackTransport or -10000)<10 then state.transportReason="Gecontroleerde oversteek: kort bevestigingsinterval";return false end
    state.transportReason="Voertuigformaat onbekend: één gecontroleerde oversteek, server controleert route en limieten"
    return true
end
function Strategy.track_transport(id,tile)
    state.riverOrders=state.riverOrders or {}
    local distance=state.waterTargets and state.waterTargets[id] and state.waterTargets[id].distance or 0
    local fronts,existing={ },{ }
    for _,front in ipairs(state.outgoing) do fronts[front.aid or front.id]=true end
    for _,vehicle in ipairs(state.vehicles or {}) do if vehicle.owner==state.id and vehicle.kind==3 then existing[vehicle.id]=true end end
    local seconds=math.max(24,math.min(120,distance/math.max(1,(Config.TRANSPORT_BOAT_SPEED or 1)*(Config.TICK_RATE or 10))*4+18))
    state.riverOrders[id]={tile=tile,at=os.clock(),distance=distance,untilTime=os.clock()+seconds,fronts=fronts,existingBoats=existing}
    if state.transportKnown==false then
        state.lastFallbackTransport=os.clock()
        Recorder.emit("fallback_transport",{id=id,tile=tile,distance=distance,deadline=seconds,reason=state.transportReason})
    end
end
function Strategy.active_orders()
    Strategy.poll_transports()
    local afloat=state.transportKnown==false and 0 or (state.transportCount or 0)
    local pending=0
    for id,entry in pairs(state.riverOrders or {}) do
        if not entry.failed then pending=pending+1 end
    end
    return #state.outgoing+math.max(afloat,pending)
end
function Strategy.shield_layers(tile)
    if not options.layeredSams or not options.adaptiveSams then return 1 end
    local count=0
    for _,shot in pairs(state.hostileWarheads or {}) do
        if os.clock()-shot.at<=20 and Strategy.distance(tile,shot.tile)<=140 then
            count+=1;if count>=2 then return 2 end
        end
    end
    return 1
end
function Strategy.shield_status()
    local cities,sams={},{}
    for _,structure in pairs(state.structures or {}) do
        if structure.ownerId==state.id and buffer.readu8(state.owners,structure.tile)==state.id then
            if structure.kind==1 then cities[#cities+1]=structure
            elseif structure.kind==5 then sams[#sams+1]=structure end
        end
    end
    local total,covered,planned,layered=0,0,0,false
    for _,city in ipairs(cities) do
        local layers=Strategy.shield_layers(city.tile);layered=layered or layers>1
        local weight=(city.level or 1)+2;total+=weight*layers
        local live,building=0,0
        for _,sam in ipairs(sams) do
            local radius=Nukes and Nukes.samRange and Nukes.samRange(sam.level or 1) or 70
            if Strategy.distance(city.tile,sam.tile)<=radius*0.85 then
                building+=1;if not sam.uc then live+=1 end
            end
        end
        covered+=weight*math.min(layers,live)
        planned+=weight*math.min(layers,building)
    end
    local limit=options.maxSams
    if options.adaptiveSams then
        limit=math.min(32,math.max(limit,math.ceil(#cities/4)))
        if layered then limit=math.min(32,limit+math.ceil(#cities/8)) end
    end
    local result={cities=#cities,sams=#sams,limit=limit,coverage=total>0 and covered/total or 1,
        plannedCoverage=total>0 and planned/total or 1}
    state.shieldStatus=result
    return result
end
function Strategy.sam_spot()
    local cities,sams,candidates={},{},{}
    local coverage=Nukes and Nukes.samRange and Nukes.samRange(1) or 70
    for _,s in pairs(state.structures) do
        if s.ownerId==state.id and buffer.readu8(state.owners,s.tile)==state.id then
            if s.kind==1 then table.insert(cities,s)
            elseif s.kind==5 then table.insert(sams,s) end
        end
    end
    if #sams>=Strategy.shield_status().limit then return nil end
    local important={}
    for _,city in ipairs(cities) do
        local count=0
        for _,sam in ipairs(sams) do
            local r=Nukes and Nukes.samRange and Nukes.samRange(sam.level or 1) or coverage
            if Strategy.distance(city.tile,sam.tile)<=r*0.85 then count+=1 end
        end
        if count<Strategy.shield_layers(city.tile) then
            table.insert(important,city)
            local x,y=city.tile%W,math.floor(city.tile/W)
            for _,offset in ipairs({{20,0},{-20,0},{0,20},{0,-20},{20,20},{-20,20},{20,-20},{-20,-20}}) do
                local px,py=x+offset[1],y+offset[2]
                if px>=0 and px<W and py>=0 and py<H then candidates[#candidates+1]=py*W+px end
            end
        end
    end
    for _,anchor in ipairs(important) do
        local sx,sy,count=0,0,0
        for _,city in ipairs(important) do
            if Strategy.distance(anchor.tile,city.tile)<=coverage*0.65 then sx+=city.tile%W;sy+=math.floor(city.tile/W);count+=1 end
        end
        if count>=2 then
            local cx,cy=math.floor(sx/count),math.floor(sy/count)
            local offset=(Config.STRUCTURE_MIN_DIST or 15)+13
            for _,delta in ipairs({{0,0},{offset,0},{-offset,0},{0,offset},{0,-offset}}) do
                local x,y=cx+delta[1],cy+delta[2]
                if x>=0 and x<W and y>=0 and y<H then candidates[#candidates+1]=y*W+x end
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
                    local distance=Strategy.distance(tile,city.tile)
                    if distance<=coverage*0.85 then
                        local outer=Nukes and Nukes.magnitude and Nukes.magnitude(13)
                        local margin=coverage-(outer and outer.outer or 30)-distance
                        value+=((city.level or 1)+2)*(1+math.max(0,margin)/coverage)
                    end
                end
                local score=value-Strategy.nearby_danger(tile)*2
                if value>0 and score>bestScore then best,bestScore=tile,score end
            end
        end
    end
    return best
end
function Strategy.contained_attack()
    if #state.incoming==0 then return true end
    local me=state.players[state.id]
    if not options.defend or not me or not me.alive or me.troops<=0 or not fresh() then return false end
    local incoming=0
    for _,front in ipairs(state.incoming) do incoming+=math.max(0,front.troops) end
    if incoming>me.troops*0.15 or (state.homeLossRate or 0)>math.max(20,(me.tiles or 0)*0.002) then return false end
    local strongest=0
    for id,contact in pairs(Strategy.contacts()) do
        if not friendly(id) then strongest=math.max(strongest,contact.troops*Strategy.threat_factor(id)) end
    end
    if strongest*4>me.troops or incoming*6>me.troops then return false end
    return Strategy.risk_reserve()<me.troops*0.60
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
    return math.ceil(top*0.35+second*0.10+total*0.07+incoming*1.20)
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
                local space=0
                local x,y=tile%W,math.floor(tile/W)
                for _,offset in ipairs({{8,0},{-8,0},{0,8},{0,-8},{16,0},{-16,0},{0,16},{0,-16}}) do
                    local px,py=x+offset[1],y+offset[2]
                    if px>=0 and px<W and py>=0 and py<H then
                        local probe=py*W+px
                        if passable(probe) and buffer.readu8(state.owners,probe)==0 then space+=1 end
                    end
                end
                local score=free*3+space*2-Strategy.nearby_danger(tile)*8-bit32.band(buffer.readu8(state.terrain,tile),63)*0.1
                if score>bestScore then best,bestScore=tile,score end
            end
        end
    end
    return best
end
function Strategy.build_spot(kind)
    local best,bestScore=nil,-math.huge
    local spacing=(Config.STRUCTURE_MIN_DIST or 15)+2
    local contacts=kind==3 and Strategy.contacts() or {}
    local blast=Nukes and Nukes.magnitude(13)
    local ownCities=Strategy.city_value(state.id)
    local cover=Nukes and Nukes.samRange and Nukes.samRange(1) or 70
    local anchors={}
    if kind==1 then
        for _,city in pairs(state.structures) do
            if city.ownerId==state.id and buffer.readu8(state.owners,city.tile)==state.id and city.kind==1 then
                local group=nil
                for _,anchor in ipairs(anchors) do if Strategy.distance(city.tile,anchor.tile)<=cover*0.55 then group=anchor;break end end
                if group then group.count+=1 else anchors[#anchors+1]={tile=city.tile,count=1} end
            end
        end
    end
    for _,tile in pairs(state.ownedSamples or {}) do
        if buffer.readu8(state.owners,tile)==state.id and passable(tile)
            and (state.blockedBuild[tile] or 0)<os.clock() then
            local closest=math.huge
            local same=math.huge
            for _,s in pairs(state.structures) do
                local d=Strategy.distance(tile,s.tile)
                closest=math.min(closest,d)
                if s.ownerId==state.id and buffer.readu8(state.owners,s.tile)==state.id and s.kind==kind then same=math.min(same,d) end
            end
            if closest>=spacing then
                local danger=Strategy.nearby_danger(tile)
                local score=nil
                local citySpacing=spacing
                local groupFit,groupBonus=true,0
                if kind==1 and ownCities>0 then
                    groupFit=same>=(blast and blast.outer or 30)*2+8
                    for _,anchor in ipairs(anchors) do
                        local distance=Strategy.distance(tile,anchor.tile)
                        if anchor.count<4 and distance<=cover*0.55 then groupFit=true;groupBonus=60-distance end
                    end
                    for _,sam in pairs(state.structures) do
                        if sam.ownerId==state.id and sam.kind==5 and Strategy.distance(tile,sam.tile)<=cover*0.75 then groupBonus+=70;break end
                    end
                end
                if kind==1 and danger<1 and same>=citySpacing and groupFit then
                    local own=0
                    local x,y=tile%W,math.floor(tile/W)
                    for _,d in ipairs({{12,0},{-12,0},{0,12},{0,-12},{18,18},{-18,-18},{18,-18},{-18,18}}) do
                        local px,py=x+d[1],y+d[2]
                        if px>=0 and px<W and py>=0 and py<H and buffer.readu8(state.owners,py*W+px)==state.id then own=own+1 end
                    end
                    if own>=(ownCities<3 and 2 or 4) then score=own*10+groupBonus-danger*80 end
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
                    local reach=Config.DEFENSE_POST_RANGE or 30
                    local cover=0
                    local x,y=tile%W,math.floor(tile/W)
                    for _,offset in ipairs({{8,0},{-8,0},{0,8},{0,-8},{6,6},{-6,6},{6,-6},{-6,-6}}) do
                        local px,py=x+offset[1],y+offset[2]
                        if px>=0 and px<W and py>=0 and py<H and buffer.readu8(state.owners,py*W+px)==state.id then cover+=1 end
                    end
                    local sheltered=true
                    neighbours(tile,function(other) if buffer.readu8(state.owners,other)~=state.id then sheltered=false end end)
                    if border>=reach*0.45 and border<=reach*0.85 and cover>=7 and sheltered and same>=reach*1.2 then
                        score=80-math.abs(border-reach*0.65)*3+cover*4+danger*4
                    end
                end
                if score and score>bestScore then best,bestScore=tile,score end
            end
        end
    end
    return best
end
function Strategy.cluster_candidate(strategic)
    if not state.structuresReady or not Nukes then return nil end
    local mag=Nukes.magnitude(13)
    if not mag then return nil end
    local atWar={}
    for _,a in ipairs(state.incoming) do if a.id~=0 then atWar[a.id]=true end end
    for _,a in ipairs(state.outgoing) do if a.id~=0 then atWar[a.id]=true end end
    local cities={}
    local me=state.players[state.id]
    local attackers={}
    for _,a in ipairs(state.incoming) do attackers[a.id]=(attackers[a.id] or 0)+a.troops end
    local economicTargets={}
    if strategic and options.preemptNukes and options.attack and me and #state.incoming==0 and #state.outgoing==0 then
        local _,myValue=Strategy.city_value(state.id)
        for id in pairs(Strategy.contacts()) do
            local enemy=state.players[id]
            local _,value=Strategy.city_value(id)
            if enemy and enemy.alive and enemy.isBot~=true and not friendly(id) and enemy.troops>=me.troops*0.60
                and (enemy.troops<=me.troops*1.60 or (state.catchupActive and id==state.catchupLeader)) and value>myValue+1 then
                atWar[id]=true;economicTargets[id]=true
            end
        end
    end
    for _,s in pairs(state.structures) do
        local enemy=state.players[s.ownerId]
        local easyHuman=enemy and enemy.isBot~=true and me and me.troops>=enemy.troops*8
            and Strategy.opportunity_ratio(s.ownerId,false)~=nil
        local captureInstead=options.preserveBotCities and enemy and me
            and ((enemy.isBot==true and me.troops>=enemy.troops*options.strength) or easyHuman)
            and ((enemy.isBot==true and not attackers[s.ownerId]) or (enemy.isBot~=true and (attackers[s.ownerId] or 0)<=me.troops*0.05))
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
            if count>=options.minCluster then table.insert(ranked,{tile=tile,count=count,score=score*10,reason=economicTargets[owner] and "huizenvoorsprong van nabije rivaal verminderen" or "vijandelijk huizencluster uitschakelen"}) end
        end
    end
    if strategic and options.defend and me then
        local seen={}
        for id,contact in pairs(Strategy.contacts()) do
            if (attackers[id] or 0)>=me.troops*0.15 then
                for i=1,math.min(8,#contact.points) do
                    local point=contact.points[i]
                    local px,py=point%W,math.floor(point/W)
                    local inset=math.ceil(mag.outer)+4
                    for _,direction in ipairs({{1,0},{-1,0},{0,1},{0,-1},{1,1},{-1,1},{1,-1},{-1,-1}}) do
                        local x,y=px+direction[1]*inset,py+direction[2]*inset
                        if x>=0 and x<W and y>=0 and y<H then
                            local tile=y*W+x
                            if not seen[tile] and buffer.readu8(state.owners,tile)==id and passable(tile) then
                                seen[tile]=true
                                local hit=0
                                for dy=-mag.inner,mag.inner,3 do for dx=-mag.inner,mag.inner,3 do
                                    local sx,sy=x+dx,y+dy
                                    if dx*dx+dy*dy<=mag.inner*mag.inner and sx>=0 and sx<W and sy>=0 and sy<H
                                        and buffer.readu8(state.owners,sy*W+sx)==id then hit+=1 end
                                end end
                                if hit>=20 then
                                    ranked[#ranked+1]={tile=tile,count=0,score=70+hit+(attackers[id]/math.max(1,me.troops))*30,reason="vijandelijke aanvalszone ontregelen"}
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    table.sort(ranked,function(a,b) return a.score>b.score end)
    for i=1,math.min(48,#ranked) do
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
function Strategy.action_delay()
    if options.defend and #state.incoming>0 then return math.min(options.interval,1) end
    if not options.adaptiveTempo or state.phase~="playing" or #state.incoming>0 then return options.interval end
    local me=state.players[state.id]
    if not me or not me.alive or not state.ready then return options.interval end
    local fill=me.troops/Strategy.capacity(me)
    if os.clock()-(state.campaignUrgencyAt or -100)<0.75 then return math.min(options.interval,0.75) end
    if state.catchupActive and fill>=0.40 then return math.min(options.interval,1) end
    local growth=state.territoryGrowth or {}
    local myRate=growth[state.id] or 0
    local racing=false
    for id in pairs(state.planBorders or {}) do
        local enemy=state.players[id]
        if enemy and enemy.alive and enemy.isBot~=true and not friendly(id)
            and enemy.troops>=me.troops*0.60 and (growth[id] or 0)>myRate*1.2+1 then racing=true;break end
    end
    state.racePressure=racing
    if fill>=0.70 or (racing and fill>=0.45) then return math.min(options.interval,1) end
    if fill>=0.45 then return math.min(options.interval,1.5) end
    return options.interval
end
function Strategy.interleave_ready(kind)
    if not options.parallelActions or options.dry or not alive or not state.ready or state.phase~="playing"
        or state.engineFault or state.awaitingInit or (state.protocolBlocks and next(state.protocolBlocks)) or not fresh() then return false end
    local me=state.players[state.id]
    if not me or not me.alive or state.lastPlayers<=(state.lastSend or -100) or state.lastFronts<=(state.lastSend or -100) then return false end
    local now=os.clock()
    if now-state.lastAction<0.25 or now-state.lastAction>=Strategy.action_delay() then return false end
    local last=state.lastCommand
    if not last then return false end
    if kind=="attack" then
        return last.t=="build" and now-(state.lastTroopOrder or -10000)>=Strategy.action_delay()
    elseif kind=="build" then
        return last.t=="attack" and now-(state.lastBuild or -10000)>=options.buildDelay
    end
    return false
end
function Strategy.offensive_budget(payload)
    if not options.neighborReserve or not options.protect then return true end
    local me=state.players[state.id]
    if not me or not me.alive then return false end
    local strongest,second=0,0
    for id,contact in pairs(Strategy.contacts()) do
        local enemy=state.players[id]
        if enemy and enemy.alive and enemy.isBot~=true and not friendly(id) then
            local direct=false
            for _,tile in ipairs(contact.points or {contact.tile}) do
                if state.frontier[tile] and Strategy.attack_tile_valid(tile,id) then
                    neighbours(tile,function(other) if buffer.readu8(state.owners,other)==state.id then direct=true end end)
                end
                if direct then break end
            end
            if direct then
                local troops=enemy.troops*Strategy.threat_factor(id)
                if troops>strongest then second,strongest=strongest,troops elseif troops>second then second=troops end
            end
        end
    end
    local cap=Strategy.capacity(me)
    local land=false
    neighbours(payload.tile,function(other) if buffer.readu8(state.owners,other)==state.id then land=true end end)
    local spent=land and math.floor(me.troops*payload.ratio)
        or math.floor(me.troops/(Config.TRANSPORT_BOAT_TROOP_DIVISOR or 5))
    local remaining=me.troops-spent
    local cautious=strongest>=me.troops*0.85 or strongest>=remaining*0.85
    if cautious then state.cautionUntil=os.clock()+8 end
    local recovering=(state.cautionUntil or 0)>os.clock() and strongest>remaining/1.20
    if not cautious and not recovering then return true end
    local hold=math.max(strongest*1.05+second*0.15,cap*Strategy.growth_peak(cap)*0.75,me.troops*0.75)
    state.neighborBudget={strongest=strongest,second=second,hold=hold,remaining=me.troops-spent,cautious=true}
    if me.troops-spent<hold then
        local owner=buffer.readu8(state.owners,payload.tile)
        local enemy=state.players[owner]
        local cheap=owner==0 or (enemy and enemy.alive and enemy.troops<=me.troops*0.08 and spent>=enemy.troops*0.65)
        if options.capRecovery and state.capRecoveryOrder and hold>cap and land and #state.incoming==0
            and me.troops>=cap*0.90 and spent<=me.troops*0.05001 and me.troops-spent>=cap*0.85 and cheap then
            Recorder.emit("capacity_reserve_escape",{owner=owner,spent=spent,remaining=me.troops-spent,hold=hold,capacity=cap})
            return true
        end
        state.reason="LEGER OPBOUWEN: sterke buur "..math.ceil(strongest).." | thuisreserve "..math.ceil(hold)
        Recorder.emit("neighbor_reserve_block",{tile=payload.tile,spent=spent,hold=hold,strongest=strongest})
        return false
    end
    return true
end
function Strategy.order_ready(kind)
    if kind=="attack" and state.defenseOrder and options.defend and options.activeDefense then return os.clock()-state.lastAction>=0.5 end
    if kind=="attack" and state.fastFrontOrder and options.fastFrontReinforce then
        return os.clock()-state.lastAction>=0.5
    end
    return os.clock()-state.lastAction>=Strategy.action_delay() or Strategy.interleave_ready(kind)
end
local function send(payload,description)
    if (payload.t=="build" or payload.t=="reinforce") and (state.nukePending
        or (state.nukeBudgetAfter and state.lastFronts<=state.nukeBudgetAfter)) then
        state.reason="Wachten op bevestigd nuke-budget voordat opnieuw goud wordt uitgegeven"
        return false
    end
    if payload.t=="attack" and not Strategy.attack_tile_valid(payload.tile) then
        Recorder.emit("order_revalidated",{payload=payload,reason="invalid, friendly, captured or quarantined tile"})
        return false
    end
    if payload.t=="attack" and state.blockedAttack and (state.blockedAttack[payload.tile] or 0)>os.clock() then return false end
    if payload.t=="attack" and state.owners and type(payload.tile)=="number"
        and payload.tile>=0 and payload.tile<buffer.len(state.owners) and buffer.readu8(state.owners,payload.tile)==state.id then
        Recorder.emit("order_revalidated",{payload=payload,reason="target already owned"})
        return false
    end
    if payload.t=="attack" and not state.defenseOrder and not Strategy.offensive_budget(payload) then return false end
    if not Strategy.order_ready(payload.t) then
        if os.clock()-(Recorder.lastByKind.order_wait or -100)>=2 then
            Recorder.lastByKind.order_wait=os.clock()
            Recorder.emit("order_deferred",{payload=payload,description=description,reason="shared cooldown",lastAction=state.lastAction,delay=Strategy.action_delay()})
        end
        return false
    end
    state.lastAction=os.clock()
    if options.dry then Recorder.emit("plan_only",{payload=payload,description=description});state.reason="Observatie: "..description;log("PLAN: "..description); return false end
    Recorder.emit("order",{payload=payload,description=description,serial=(state.orderSerial or 0)+1})
    folder.Intent:FireServer(payload)
    state.lastCommand=payload;state.orderSerial=(state.orderSerial or 0)+1
    if payload.t=="attack" then
        state.lastTroopOrder=os.clock()
        state.attackOrders=state.attackOrders or {}
        for i=#state.attackOrders,1,-1 do
            if os.clock()-state.attackOrders[i].at>4 then table.remove(state.attackOrders,i) end
        end
        state.attackOrders[#state.attackOrders+1]={tile=payload.tile,at=os.clock(),serial=state.orderSerial}
        if #state.attackOrders>16 then table.remove(state.attackOrders,1) end
    end
    if payload.t=="attack" and state.owners and state.frontier[payload.tile] then
        state.landOrders=state.landOrders or {}
        state.landOrders[buffer.readu8(state.owners,payload.tile)]={tile=payload.tile,at=os.clock()}
    end
    state.reason="Order verstuurd: "..description
    log("ORDER: "..description)
    return true
end
function Strategy.nuke_interval()
    if not options.adaptiveNukeSalvo or Config.NUKE_REQUIRES_SILO~=false
        or os.clock()<(state.nukeFastBlockedUntil or 0) then return options.nukeDelay end
    for _,structure in pairs(state.structures or {}) do
        if structure.ownerId==state.id and structure.kind==4 then return options.nukeDelay end
    end
    if (state.nukeSalvoCount or 0)>=2 and os.clock()-(state.lastNuke or -10000)<options.nukeDelay then
        return options.nukeDelay
    end
    return math.min(options.nukeDelay,1)
end
function Strategy.observe_missiles(payload)
    if type(payload)~="table" then return end
    state.hostileWarheads=state.hostileWarheads or {}
    for id,shot in pairs(state.hostileWarheads) do if os.clock()-shot.at>20 then state.hostileWarheads[id]=nil end end
    for _,event in ipairs(payload) do
        if options.layeredSams and type(event)=="table" and event.e=="l" and type(event.owner)=="number"
            and not friendly(event.owner) and type(event.dst)=="number" and event.dst>=0 and event.dst<N
            and state.ready and buffer.readu8(state.owners,event.dst)==state.id then
            local count=0;for _ in pairs(state.hostileWarheads) do count+=1 end
            if count<128 and event.id then state.hostileWarheads[event.id]={tile=event.dst,at=os.clock()} end
        end
        if type(event)=="table" and (event.e=="l" or event.e=="b") and type(event.owner)=="number" and event.owner~=0 and not friendly(event.owner) then
            state.lastHostileMissile=os.clock()
        end
        if type(event)=="table" and event.e=="l" and event.owner==state.id and event.kind==13 then
            local pending=state.nukePending
            if pending and pending.tile==event.dst and pending.generation==state.generation then
                state.nukePending=nil;state.nukeBudgetAfter=os.clock()
                for _,blast in ipairs(state.plannedBlasts or {}) do
                    if blast.tile==event.dst and blast.sentAt==pending.at then blast.unitId=event.id end
                end
                Recorder.emit("nuke_launch_confirmed",{tile=event.dst,id=event.id,serial=pending.serial})
                log("Nuke-lancering bevestigd; nieuw goudsaldo afwachten.")
            end
        elseif type(event)=="table" and event.e=="b" then
            for i=#(state.plannedBlasts or {}),1,-1 do
                if state.plannedBlasts[i].unitId==event.id then table.remove(state.plannedBlasts,i) end
            end
        end
    end
end
function Strategy.try_nuke()
    if not options.nukes then state.nukeReason="UIT: schakel Strategische atoomnukes in";return false end
    if state.nukePending then
        state.nukeReason=os.clock()-state.nukePending.at>8 and "Lancering niet bevestigd; synchroniseer opnieuw" or "Wachten op nuke-lancering"
        return false
    end
    if state.nukeBudgetAfter and state.lastFronts<=state.nukeBudgetAfter then
        state.nukeReason="Wachten op nieuw goudsaldo na lancering";return false
    end
    local interval=Strategy.nuke_interval()
    if os.clock()-(state.lastNuke or -10000)<interval then state.nukeReason="Wachten op nuke-interval";return false end
    if not state.structuresReady or not state.gold then state.nukeReason="Wachten op gebouw- en goudgegevens";return false end
    local free=(state.freeNukes or 0)>0
    local cost=Config.ATOM_BOMB_COST or 750000
    if not free and state.gold-cost<options.goldReserve then
        state.nukeReason="Onvoldoende nuke-budget: prijs "..tostring(cost).." plus reserve "..options.goldReserve
        return false
    end
    if not free and state.gold-cost<Strategy.shield_savings() then
        state.nukeReason="Antiraketbudget behouden vóór offensieve nuke";return false
    end
    if Config.NUKE_REQUIRES_SILO~=false then
        state.nukeReason="Nukeplanner wacht op ondersteunde siloregels";return false
    end
    if os.clock()-(state.lastNukeScan or -10000)<math.min(8,interval) then return false end
    state.lastNukeScan=os.clock()
    local candidate=Strategy.cluster_candidate(true)
    if not candidate then state.nukeReason="Geen waardevol vrij doel zonder eigen/geallieerde schade of bekende SAM-dekking";return false end
    if send({t="nuke",tile=candidate.tile,kind=13},"STRATEGISCHE NUKE: "..(candidate.reason or "vijandelijk cluster").." | huizen "..candidate.count) then
        local now=os.clock()
        if now-(state.lastNuke or -10000)>=options.nukeDelay then state.nukeSalvoCount=0 end
        state.nukeSalvoCount=(state.nukeSalvoCount or 0)+1
        state.lastNuke=now;state.lastSend=now;state.nukeReason="Verstuurd: "..(candidate.reason or "cluster")
        state.nukePending={tile=candidate.tile,at=now,generation=state.generation,serial=state.orderSerial}
        table.insert(state.plannedBlasts,{tile=candidate.tile,sentAt=now,untilTime=now+180})
        return true
    end
    return false
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
    local useful=benefit>0 and (emergency or benefit>=math.min(cap*0.10,troops*0.80))
    if benefit<=0 or not useful then return false end
    if not emergency and (not active or state.gold-cost<math.max(options.goldReserve,Strategy.shield_savings())) then return false end
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
    if state.catchupActive and not defensive and #state.incoming==0 then floor*=0.50 end
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
        for _,s in pairs(state.structures) do if s.ownerId==state.id and buffer.readu8(state.owners,s.tile)==state.id and s.kind==3 then posts=posts+1 end end
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
        for _,s in pairs(state.structures) do if s.ownerId==state.id and buffer.readu8(state.owners,s.tile)==state.id and s.kind==1 then table.insert(cities,s) end end
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
    if not defensive and kind~=5 and not free and cost and state.gold-cost<Strategy.shield_savings() then
        state.reason="Sparen voor antiraketdekking";return false
    end
    local description=kind==1 and "stad op veilige, verspreide locatie bouwen/upgraden"
        or kind==5 and "anti-nuketoren voor ongedekte belangrijke steden bouwen"
        or "verdedigingspost bij bedreigde grens bouwen"
    if send({t="build",tile=tile,kind=kind},description) then
        state.lastBuild=os.clock();state.lastSend=os.clock();state.blockedBuild[tile]=os.clock()+30
        return true
    end
    return false
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
function Strategy.open_rival()
    if not options.protect or #state.incoming>0 then return nil end
    local open=false
    for tile in pairs(state.frontier) do if buffer.readu8(state.owners,tile)==0 then open=true;break end end
    if not open then return nil end
    local rival=nil
    for id in pairs(Strategy.contacts()) do
        local enemy=state.players[id]
        if enemy and enemy.alive and enemy.isBot~=true then
            if rival then return nil end
            rival=enemy
        end
    end
    return rival
end
function Strategy.open_ready(ratio,hold)
    if not ratio then return false end
    local me=state.players[state.id]
    if state.catchupActive and me and #state.incoming==0 and me.troops>=Strategy.capacity(me)*0.35
        and ratio<=0.25 and me.troops-math.floor(me.troops*ratio)>=(hold or math.huge) then
        state.economicStatus="Inhaalstrategie: eerder betaalbare open-landpuls"
        return true
    end
    if Strategy.open_rival() and me and ratio<=0.25 and me.troops-math.floor(me.troops*ratio)>=(hold or math.huge) then
        state.economicStatus="Open-landrace: kleine preset; thuisleger op peil bij enige menselijke buur"
        return true
    end
    return Strategy.growth_ready(ratio)
end
function Strategy.neutral_ratio(existing,fallback,fallbackReserve)
    local speeds=Config.TERRAIN_SPEED
    if type(speeds)~="table" or type(speeds[1])~="number" or type(Config.NEUTRAL_TILE_NUM)~="number"
        or type(Config.NEUTRAL_TILE_MIN)~="number" or Config.NEUTRAL_TILE_MIN<=0 then return fallback,fallbackReserve,nil end
    local me=state.players[state.id]
    if not me or not me.alive then return nil,nil,nil end
    local desired=math.ceil(Config.NEUTRAL_TILE_NUM*math.max(10,speeds[1])/Config.NEUTRAL_TILE_MIN*1.25)
    desired=math.max(Config.MIN_ATTACK_TROOPS or 250,desired)
    local hold=Strategy.capacity(me)*math.min(options.reserve,options.growthFloor)/100
    local rival=Strategy.open_rival()
    if rival then hold=math.max(Strategy.capacity(me)*0.15,rival.troops*0.85) end
    if options.protect then hold=math.max(hold,Strategy.risk_reserve()) end
    if existing>=desired*0.85 then return nil,hold,desired end
    local needed=desired-existing
    local best,partial=nil,nil
    for _,ratio in ipairs(Strategy.attack_choices(needed)) do
        local committed=math.floor(me.troops*ratio)
        if committed>=(Config.MIN_ATTACK_TROOPS or 250) and me.troops-committed>=hold then
            if committed>=needed and (not best or ratio<best) then best=ratio end
            if not partial or ratio>partial then partial=ratio end
        end
    end
    return best or partial,hold,desired
end
function Strategy.defense_budget()
    local me=state.players[state.id]
    if not me then return math.huge,true end
    local incoming,attackers=0,{}
    for _,front in ipairs(state.incoming) do incoming+=front.troops;attackers[front.id]=true end
    local other=0
    for id,c in pairs(Strategy.contacts()) do if not attackers[id] then other=math.max(other,c.troops*Strategy.threat_factor(id)) end end
    local hold=math.max(Strategy.capacity(me)*0.20,me.troops*0.50,incoming*1.5+other*0.25)
    local heavyLoss=(state.homeLossRate or 0)>math.max(5,me.tiles*0.002)
    return hold,incoming>=me.troops*0.65 or (heavyLoss and incoming>=me.troops*0.15)
end
function Strategy.land_target(id,preferred)
    if state.landTargetGeneration~=state.generation then
        state.landTargetGeneration=state.generation;state.landTargetCache={};state.landTargetCursor={}
    end
    local function valid(tile)
        if not Strategy.attack_tile_valid(tile,id) then return false end
        local adjacent=false
        neighbours(tile,function(other) if buffer.readu8(state.owners,other)==state.id then adjacent=true end end)
        return adjacent
    end
    if preferred and valid(preferred) then state.landTargetCache[id]=preferred;return preferred end
    local cached=state.landTargetCache[id]
    if cached and (not preferred or Strategy.distance(cached,preferred)<=64) and valid(cached) then return cached end
    local cursor=state.landTargetCursor[id]
    local ok,tile=pcall(next,state.frontier,cursor)
    if not ok then tile=next(state.frontier) end
    for checked=1,4096 do
        if not tile then state.landTargetCursor[id]=nil;return nil end
        state.landTargetCursor[id]=tile
        if (not preferred or Strategy.distance(tile,preferred)<=64) and valid(tile) then state.landTargetCache[id]=tile;return tile end
        tile=next(state.frontier,tile)
    end
    return nil
end
function Strategy.defense_contacts()
    local result={};local checked=0
    for tile in pairs(state.frontier) do
        checked+=1;if checked>4096 then break end
        local id=buffer.readu8(state.owners,tile);local enemy=state.players[id]
        if enemy and enemy.alive and not friendly(id) then result[id]={troops=enemy.troops} end
    end
    return result
end
function Strategy.shield_savings()
    if not options.sams or not options.adaptiveSams or not state.structuresReady or not state.samCost then return 0 end
    local status=Strategy.shield_status()
    if status.cities<3 or status.sams>=status.limit or status.plannedCoverage>=0.80 or (state.freeSams or 0)>0 then return 0 end
    if not Strategy.sam_spot() then return 0 end
    return state.samCost+options.goldReserve
end
function Strategy.defense_ratio(id)
    if not options.growthDefense or not options.activeDefense or Config.OPPOSING_ATTACKS_CANCEL==false then return Strategy.force_defense_ratio(id) end
    local me,enemy=state.players[state.id],state.players[id]
    local function blocked(reason) state.counterReason=reason;return nil end
    if not options.defend or not me or not me.alive or not enemy or not enemy.alive or friendly(id) then return blocked("Geen geldig verdedigingsdoel") end
    if state.lastPlayers<=(state.lastSend or -100) or state.lastFronts<=(state.lastSend or -100) then return blocked("Wachten op bevestigde troepen en aanval na order") end
    local target,total,other=0,0,0
    for _,front in ipairs(state.incoming) do
        total+=math.max(0,front.troops)
        if front.id==id then target+=math.max(0,front.troops) end
    end
    if target<=0 then return blocked("Geen inkomend leger van deze tegenstander") end
    for otherId,contact in pairs(Strategy.defense_contacts()) do
        if otherId~=id then other=math.max(other,contact.troops*Strategy.threat_factor(otherId)) end
    end
    local cap=Strategy.capacity(me)
    local peak=Strategy.growth_peak(cap)
    local rate=Strategy.growth_model(me.troops,cap)
    local loss=math.max(0,state.homeLossRate or 0)
    local falling=loss>=math.max(30,(me.tiles or 0)*0.003)
    local collapse=loss>0 and (me.tiles or 0)/loss<90
    local critical=falling or collapse
    local growthFloor=cap*peak*(critical and 0.45 or 0.75)
    local otherIncoming=math.max(0,total-target)
    local hardHold=math.max((Config.MIN_ATTACK_TROOPS or 250)*2,me.troops*(critical and 0.15 or 0.30),
        math.min(me.troops*0.40,other*0.15+otherIncoming*0.5))
    local minimum=math.max(0.05,Config.MIN_ATTACK_RATIO or 0.05)
    local smallest=math.floor(me.troops*minimum)
    if total<me.troops*0.02 and loss<math.max(10,(me.tiles or 0)*0.0005)
        and smallest>math.max(target*3,me.troops*0.01) then
        return blocked("Kleine aanval bewaken: minimale tegeninzet te duur; groeileger behouden")
    end
    local choices=table.clone(Config.attackPresets(state.mode))
    local precise=math.max(minimum,math.ceil(target/me.troops*1000)/1000)
    if precise<=0.75 then choices[#choices+1]=precise end
    local complete,partial=nil,nil
    for _,ratio in ipairs(choices) do
        local spent=math.floor(me.troops*ratio)
        local home=me.troops-spent
        if ratio<=0.75 and spent>=(Config.MIN_ATTACK_TROOPS or 250) and home>=hardHold then
            local gain=Strategy.growth_model(home,cap)
            local clears=spent>=target
            local growthSafe=home>=growthFloor or gain>=rate*0.92
            if clears and (growthSafe or critical or total<=target*1.05) then
                if not complete or ratio<complete then complete=ratio end
            elseif not clears and growthSafe and ratio<=(critical and 0.50 or 0.35) then
                if not partial or ratio>partial then partial=ratio end
            end
        end
    end
    local recovery=state.defenseRecovery
    if not complete and partial and recovery and not critical and me.troops<math.min(growthFloor,recovery.troops)
        and os.clock()-recovery.at<12 then partial=nil end
    if not complete and not critical and me.troops<growthFloor then partial=nil end
    if partial and recovery and os.clock()-recovery.at<3 and me.troops<recovery.troops*0.95
        and me.troops<cap*0.25 then partial=nil end
    local spending=state.defenseSpending
    if partial and spending and os.clock()-spending.at<5
        and spending.spent+math.floor(me.troops*partial)>spending.baseline*(critical and 0.35 or 0.20) then partial=nil end
    if complete and recovery and os.clock()-recovery.at<4 and me.troops<cap*0.20
        and me.troops*(1-complete)<me.troops*0.85 then complete=nil end
    if partial and me.troops<cap*0.20 and recovery and os.clock()-recovery.at<5 then partial=nil end
    if options.attritionAware and partial and target>=me.troops and not collapse then partial=nil end
    local selected=complete or partial
    state.defenseGrowth={capacity=cap,peak=peak,floor=growthFloor,critical=critical,incoming=total,
        currentGrowth=rate,homeLossRate=loss,ratio=selected,
        remaining=selected and me.troops-math.floor(me.troops*selected) or me.troops}
    if not selected then return blocked("Groeiverdediging: leger herstellen; dreiging en landverlies blijven bewaakt") end
    state.counterReason=(complete and "Aanval opvangen" or "Aanval gedoseerd afremmen")..": "..math.floor(selected*100)
        .."%; thuis "..math.floor(state.defenseGrowth.remaining).." | groeidoel "..math.ceil(growthFloor)
        ..(critical and " | snel landverlies: noodreserve" or "")
    return selected
end
function Strategy.force_defense_ratio(id)
    if not options.activeDefense or Config.OPPOSING_ATTACKS_CANCEL==false then return Strategy.legacy_defense_ratio(id) end
    local me,enemy=state.players[state.id],state.players[id]
    local function blocked(reason) state.counterReason=reason;return nil end
    if not options.defend or not me or not me.alive or not enemy or friendly(id) or not enemy.alive then return blocked("Geen geldig verdedigingsdoel") end
    if state.lastPlayers<=(state.lastSend or -100) or state.lastFronts<=(state.lastSend or -100) then return blocked("Wachten op bevestigde troepen en aanval na order") end
    local target,total,other=0,0,0
    for _,front in ipairs(state.incoming) do
        total+=math.max(0,front.troops)
        if front.id==id then target+=math.max(0,front.troops) end
    end
    if target<=0 then return blocked("Geen inkomend leger van deze tegenstander") end
    for otherId,contact in pairs(Strategy.contacts()) do
        if otherId~=id then other=math.max(other,contact.troops*Strategy.threat_factor(otherId)) end
    end
    local unopposed=math.max(0,total-target)
    local hold=math.max((Config.MIN_ATTACK_TROOPS or 250)*2,me.troops*0.15,math.min(me.troops*0.40,other*0.15),math.min(me.troops*0.40,unopposed*0.75))
    local needed=target*1.02
    local enough,partial=nil,nil
    for _,ratio in ipairs(Config.attackPresets(state.mode)) do
        local committed=math.floor(me.troops*ratio)
        if ratio<=0.75 and committed>=(Config.MIN_ATTACK_TROOPS or 250) and me.troops-committed>=hold then
            if committed>=needed then if not enough or ratio<enough then enough=ratio end
            elseif not partial or ratio>partial then partial=ratio end
        end
    end
    local selected=enough or partial
    if not selected then return blocked("Te weinig troepen naast noodreserve "..math.ceil(hold)) end
    state.counterReason="Actief opvangen: "..math.floor(selected*100).."% tegen "..math.ceil(target).." inkomend; thuisreserve "..math.ceil(hold)
    return selected
end
function Strategy.legacy_defense_ratio(id)
    local me,enemy=state.players[state.id],state.players[id]
    local function blocked(reason) state.counterReason=reason;return nil end
    if not me or not enemy or friendly(id) or not enemy.alive then return blocked("Geen geldig vijandelijk doel") end
    if state.lastPlayers<(state.lastSend or -100) then return blocked("Wachten op actuele troepen na vorige order") end
    local incoming,attackers=0,{}
    for _,front in ipairs(state.incoming) do incoming+=front.troops;attackers[front.id]=true end
    if incoming>=me.troops*0.75 then return blocked("Inkomend leger te groot; noodverdediging krijgt voorrang") end
    if me.troops<enemy.troops*0.90 then return blocked("Vijandelijk thuisleger te sterk voor beperkte tegendruk") end
    local other=0
    for otherId,contact in pairs(Strategy.contacts()) do
        if not attackers[otherId] then other=math.max(other,contact.troops*Strategy.threat_factor(otherId)) end
    end
    local hold=math.max(Strategy.capacity(me)*0.12,me.troops*0.55,incoming*1.05+other*0.20)
    for _,front in ipairs(state.outgoing) do
        if front.id==id and front.troops>=math.max(enemy.troops*0.15,(Config.MIN_ATTACK_TROOPS or 250)*4) then
            return blocked("Tegenaanval loopt al met voldoende troepen")
        end
    end
    local best=nil
    for _,ratio in ipairs(Config.attackPresets(state.mode)) do
        local committed=math.floor(me.troops*ratio)
        if ratio<=0.35 and committed>=(Config.MIN_ATTACK_TROOPS or 250) and me.troops-committed>=hold and (not best or ratio<best) then best=ratio end
    end
    if not best then return blocked("Geen beschikbare troepenpreset past naast thuisreserve "..math.ceil(hold)) end
    state.counterReason="Beperkte tegendruk: "..math.floor(best*100).."%; thuisreserve "..math.ceil(hold)
    return best
end
local function enemy_targets()
    local result,scores,groups={},{},{}
    state.targetProtected={}
    for tile in pairs(state.frontier) do
        local id=buffer.readu8(state.owners,tile)
        if Strategy.attack_tile_valid(tile,id) then
            local group=groups[id]
            if not group then group={points={},count=0};groups[id]=group end
            group.count+=1
            if #group.points<24 then group.points[#group.points+1]=tile
            else local index=math.random(1,group.count);if index<=24 then group.points[index]=tile end end
            if group.count<=32 then
            local covered=false
            for _,structure in pairs(state.structures or {}) do
                if structure.ownerId==id and structure.kind==3 and not structure.uc
                    and Strategy.distance(tile,structure.tile)<=(Config.DEFENSE_POST_RANGE or 30) then covered=true;break end
            end
            local score=-bit32.band(buffer.readu8(state.terrain,tile),63)-(covered and 100 or 0)
            if not scores[id] or score>scores[id] then
                result[id]=tile;scores[id]=score;state.targetProtected[id]=covered
            end
            end
        end
    end
    if options.routeAwareTargets then
        for id,group in pairs(groups) do
            local enemy=state.players[id]
            if enemy and Strategy.is_real_human(id,enemy) then
                local first=result[id]
                local distant=first
                for _,point in ipairs(group.points) do
                    if Strategy.distance(first,point)>Strategy.distance(first,distant) then distant=point end
                end
                local third=first
                local spread=-1
                for _,point in ipairs(group.points) do
                    local distance=math.min(Strategy.distance(first,point),Strategy.distance(distant,point))
                    if distance>spread then third=point;spread=distance end
                end
                local bestScore=-math.huge
                for _,point in ipairs({first,distant,third}) do
                    local route=Strategy.land_route(point,id)
                    local covered=false
                    for _,structure in pairs(state.structures or {}) do
                        if structure.ownerId==id and structure.kind==3 and not structure.uc
                            and Strategy.distance(point,structure.tile)<=(Config.DEFENSE_POST_RANGE or 30) then covered=true;break end
                    end
                    local score=Strategy.route_score(route)-(covered and 100 or 0)-bit32.band(buffer.readu8(state.terrain,point),63)
                    if score>bestScore then bestScore=score;result[id]=point;state.targetProtected[id]=covered end
                end
            end
        end
    end
    return result
end
function Strategy.finish_strength(enemy)
 local budgetNeed=enemy.troops*(Config.BUDGET_RATIO_MAX or 0.5)/math.max(0.001,2*(Config.SPEED_RATIO_DIV or 5))
 local tileCostNeed=enemy.troops/math.max(0.001,(Config.SPEED_RATIO_DIV or 5)*(Config.SPEED_RATIO_MIN or 0.2))
 return math.max(Config.MIN_ATTACK_TROOPS or 250,budgetNeed,tileCostNeed)*1.25
end
function Strategy.finish_ratio(id,field,stalled)
 local me,enemy=state.players[state.id],state.players[id]
 if not me or not enemy or me.troops<enemy.troops*8 then return nil end
 local need=Strategy.finish_strength(enemy)
 if field>=need and not stalled then return nil end
 local allowed,reserve=Strategy.opportunity_ratio(id,state.targetProtected and state.targetProtected[id])
 if not allowed then return nil end
 local gap=math.max(Config.MIN_ATTACK_TROOPS or 250,need-field)
 local best=nil
 for _,preset in ipairs(Config.attackPresets(state.mode)) do
  local sent=math.floor(me.troops*preset)
  if preset<=0.50 and sent>=gap and me.troops-sent>=(reserve or 0) and (not best or preset<best) then best=preset end
 end
 return best,need,reserve
end
function Strategy.land_front_limit()
 local serverSlots=Config.MAX_FRONTS_PER_PLAYER or 4
 local limit=math.min(options.maxFronts,serverSlots)
 if state.transportKnown==false and serverSlots>1 then limit=math.min(limit,serverSlots-1) end
 local denied=state.frontLimitDenied
 if denied and os.clock()<denied.retryAt and #state.outgoing>=denied.active then
  limit=math.min(limit,denied.active)
 elseif denied then state.frontLimitDenied=nil end
 return limit
end
function Strategy.human_priority_pending(targets)
    local humans=Strategy.endgame_humans()
    if not next(humans) or Strategy.active_orders()>=Strategy.land_front_limit() then return false end
    local busy={}
    for _,front in ipairs(state.outgoing) do busy[front.id]=true end
    for id,pending in pairs(state.riverOrders or {}) do
        if not pending.failed and pending.untilTime>os.clock() then busy[id]=true end
    end
    for id in pairs(humans) do if targets[id] and not busy[id] then return true end end
    return false
end
function Strategy.try_finish_humans(targets)
    if (#state.incoming>0 and not Strategy.contained_attack()) or not fresh() or not state.ready or state.phase~="playing" then return false end
    local humans,count=Strategy.endgame_humans()
    if not next(humans) then return false end
    local grace=state.historical and (state.historical.grace or 0) or (Config.SPAWN_IMMUNITY_SECONDS or 0)
    if os.clock()-(state.playingAt or 0)<grace then return false end
    if Strategy.active_orders()>=Strategy.land_front_limit() then return false end
    local busy={}
    for _,front in ipairs(state.outgoing) do busy[front.id]=true end
    for id,pending in pairs(state.riverOrders or {}) do
        if not pending.failed and pending.untilTime>os.clock() then busy[id]=true end
    end
    local best=nil
    for id in pairs(humans) do
        local tile=targets[id]
        local route=tile and options.routeAwareTargets and Strategy.land_route(tile,id) or nil
        if tile and not busy[id] and (not route or not route.fragment) then
            local covered=state.targetProtected and state.targetProtected[id]
            local ratio,reserve=Strategy.opportunity_ratio(id,covered)
            if ratio then
                local finishing,_,finishReserve=Strategy.finish_ratio(id,0,false)
                if finishing then ratio=finishing;reserve=finishReserve end
                local score=Strategy.target_score(id,tile,0)
                if score and (not best or score>best.score) then best={id=id,tile=tile,ratio=ratio,reserve=reserve,score=score} end
            end
        end
    end
    if not best then return false end
    if send({t="attack",tile=best.tile,ratio=best.ratio},"OVERWINNINGSPRIORITEIT: zwakke menselijke tegenstander "..best.id
        .." vóór bots; nog "..count.." menselijke tegenstanders | thuisreserve "..math.ceil(best.reserve or 0)) then
        state.lastSend=os.clock();state.requiredReserve=best.reserve
        state.humanFinishReason="Mens "..best.id.." eerst; "..count.." menselijke tegenstanders over"
        Recorder.emit("human_endgame_target",{id=best.id,count=count,ratio=best.ratio,reserve=best.reserve})
        return true
    end
    return false
end
function Strategy.try_land_campaign(targets)
    if not options.adaptiveLandCampaign or not options.attack or not fresh() or not state.ready
        or state.phase~="playing" or (#state.incoming>0 and not Strategy.contained_attack()) then return false end
    local me=state.players[state.id]
    if not me or not me.alive or me.troops<Strategy.capacity(me)*0.55 then return false end
    local grace=state.historical and (state.historical.grace or 0) or (Config.SPAWN_IMMUNITY_SECONDS or 0)
    if os.clock()-(state.playingAt or 0)<grace or Strategy.active_orders()>=Strategy.land_front_limit() then return false end
    local busy={}
    for _,front in ipairs(state.outgoing) do busy[front.id]=true end
    for id,pending in pairs(state.riverOrders or {}) do if not pending.failed and pending.untilTime>os.clock() then busy[id]=true end end
    local contacts=Strategy.contacts()
    local best=nil
    for id,tile in pairs(targets) do
        local enemy=state.players[id]
        if enemy and Strategy.is_real_human(id,enemy) and enemy.alive and not busy[id] and not friendly(id)
            and me.troops>=enemy.troops*1.35 then
            local route=Strategy.land_route(tile,id)
            if route and not route.fragment then
                local top,total,incoming=0,0,0
                for other,contact in pairs(contacts) do
                    if other~=id then
                        local troops=contact.troops*Strategy.threat_factor(other)
                        top=math.max(top,troops);total+=troops
                    end
                end
                for _,front in ipairs(state.incoming) do incoming+=front.troops end
                local hold=math.max(me.troops*0.50,top*0.65+total*0.10+incoming*1.50)
                local covered=state.targetProtected and state.targetProtected[id]
                local need=math.max(Config.MIN_ATTACK_TROOPS or 250,enemy.troops*(covered and 0.65 or 0.35))
                for _,ratio in ipairs(Strategy.attack_choices(need)) do
                    local committed=math.floor(me.troops*ratio)
                    if ratio<=0.35 and committed>=need and me.troops-committed>=hold then
                        local score=Strategy.target_score(id,tile,0,true)
                        if score and (not best or score>best.score or (best.id==id and ratio<best.ratio)) then
                            best={id=id,tile=tile,ratio=ratio,hold=hold,score=score,area=route.area,capped=route.capped}
                        end
                    end
                end
            end
        end
    end
    if best and send({t="attack",tile=best.tile,ratio=best.ratio},"LANDCAMPAGNE: bereikbare hoofdmacht "..best.id
        .." | gebied "..best.area..(best.capped and "+" or "").." | thuisreserve "..math.ceil(best.hold)) then
        state.lastSend=os.clock();state.requiredReserve=best.hold
        Recorder.emit("land_campaign",best)
        return true
    end
    return false
end
function Strategy.quick_campaign(targets)
 if not options.attack or #state.outgoing==0 or (#state.incoming>0 and not Strategy.contained_attack()) or not fresh() then return false end
 local me=state.players[state.id]
 if not me or not me.alive or not state.ready then return false end
 if state.lastPlayers<=(state.lastSend or -100) or state.lastFronts<=(state.lastSend or -100) then return false end
 local grace=state.historical and (state.historical.grace or 0) or (Config.SPAWN_IMMUNITY_SECONDS or 0)
 if os.clock()-(state.playingAt or 0)<grace then return false end
 local slots=Strategy.land_front_limit()
 if options.protect and options.defend and (Config.MAX_FRONTS_PER_PLAYER or 4)>1 then
  for id,contact in pairs(Strategy.contacts()) do
   if state.players[id] and state.players[id].isBot~=true and contact.troops>=me.troops*0.60 then
    slots=math.min(slots,(Config.MAX_FRONTS_PER_PLAYER or 4)-1);break
   end
  end
 end
 state.planFrontLimit=slots
 if Strategy.active_orders()>=slots then return false end
 local busy={}
 for _,front in ipairs(state.outgoing) do busy[front.id]=true end
 for id,pending in pairs(state.riverOrders or {}) do if pending.untilTime>os.clock() then busy[id]=true end end
 local best=nil
 for id,tile in pairs(targets) do
  local enemy=state.players[id]
  if id~=0 and not busy[id] and enemy and enemy.alive and enemy.troops<=me.troops*0.20 then
   local ratio,reserve=Strategy.opportunity_ratio(id,state.targetProtected and state.targetProtected[id])
   local score=ratio and Strategy.target_score(id,tile,0)
   if score and (not best or score>best.score) then best={id=id,tile=tile,ratio=ratio,reserve=reserve,score=score} end
  end
 end
 if not best then return false end
 state.campaignUrgencyAt=os.clock()
 if not Strategy.order_ready("attack") then state.campaignUrgencyAt=nil;return false end
 if send({t="attack",tile=best.tile,ratio=best.ratio},"PARALLELLE CAMPAGNE: zwak land "..best.id.." | actieve fronten "..Strategy.active_orders().." | reserve "..math.ceil(best.reserve or 0)) then
  state.lastSend=os.clock()
  Recorder.emit("campaign_selection",best)
  state.campaignUrgencyAt=nil
  return true
 end
 state.campaignUrgencyAt=nil
 return false
end
function Strategy.front_reinforce_delay(id,me,front,fastFinish,neutralNeed)
    if options.fastFrontReinforce then return math.min(options.reinforceDelay,0.5) end
    if options.adaptiveTempo and me.troops>=Strategy.capacity(me)*0.70 and (id==0 or fastFinish) then
        return math.min(options.reinforceDelay,2)
    end
    if options.adaptiveTempo and id==0 and neutralNeed and front.troops<neutralNeed*0.50 then
        return math.min(options.reinforceDelay,2)
    end
    return options.reinforceDelay
end
function Strategy.fast_front_step()
    if options.activeDefense and options.defend and #state.incoming>0 then return false end
    if not options.fastFrontReinforce or not options.reinforce or options.dry or not alive or not state.ready
        or state.phase~="playing" or state.engineFault or state.awaitingInit
        or (state.protocolBlocks and next(state.protocolBlocks)) or not fresh() or (#state.incoming>0 and not Strategy.contained_attack())
        or #state.outgoing==0 or os.clock()-state.lastAction<0.5
        or os.clock()-state.lastAction>=Strategy.action_delay()
        or state.lastPlayers<=(state.lastSend or -100) or state.lastFronts<=(state.lastSend or -100) then return false end
    if Strategy.human_priority_pending(enemy_targets()) then return false end
    local me=state.players[state.id]
    if not me or not me.alive then return false end
    local normalRatio=choose_ratio(false)
    local normalReserve=state.requiredReserve
    local economicRatio=choose_ratio(false,true)
    state.economicReserve=state.requiredReserve;state.requiredReserve=normalReserve
    local economicReady=Strategy.growth_ready(economicRatio)
    local before=state.orderSerial or 0
    state.fastFrontOrder=true
    local ok,err=pcall(Strategy.try_reinforce,enemy_targets(),normalRatio,economicRatio,economicReady)
    state.fastFrontOrder=nil
    if not ok then error(err,0) end
    return (state.orderSerial or 0)>before
end
function Strategy.try_reinforce(targets,normalRatio,economicRatio,economicReady)
    if not options.reinforce or #state.outgoing==0 then return false end
    local me=state.players[state.id]
    local now=os.clock()
    local busy={}
    for _,front in ipairs(state.outgoing) do busy[front.id]=true end
    local slots=state.planFrontLimit or math.min(options.maxFronts,Config.MAX_FRONTS_PER_PLAYER or 4)
    if Strategy.active_orders()<slots then
        for id,tile in pairs(targets) do
            local other=state.players[id]
            if not busy[id] and other and other.isBot==true and Strategy.city_value(id)>0
                and economicRatio and economicReady and Strategy.target_score(id,tile,0) then
                local score=Strategy.target_score(id,tile,0)
                local deployedValue=0
                for _,front in ipairs(state.outgoing) do
                    local current=Strategy.target_score(front.id,targets[front.id] or tile,0)
                    deployedValue=math.max(deployedValue,current or 0)
                end
                if score>deployedValue then return false end
            end
        end
    end
    state.boosts=state.boosts or {}
    local best=nil
    local humanTargets=Strategy.endgame_humans()
    for _,front in ipairs(state.outgoing) do
        local id=front.id
        local enemy=state.players[id]
        local economic=id==0 or (enemy and enemy.isBot==true)
        local enabled=(id==0 and options.expand) or (id~=0 and (options.attack or (economic and options.expand)))
        local ratio=economic and economicRatio or normalRatio
        local tile=targets[id]
        local neutralNeed=nil
        if id==0 then
            local neutralHold
            ratio,neutralHold,neutralNeed=Strategy.neutral_ratio(front.troops,economicRatio,state.economicReserve)
        end
        local breakout=state.breakout and state.breakout.id==id and now<state.breakout.untilTime
        local progress=state.frontProgress and state.frontProgress[id]
        local stalled=enemy and progress and now-progress.at>=15
        local fastFinish=enemy and enemy.alive and me.troops>=enemy.troops*8
        if fastFinish then ratio=Strategy.finish_ratio(id,front.troops,stalled) end
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
        if id==0 then
            if (state.lastCaptureAt or -10000)>record.captureAt then record.bursts=0 end
        elseif enemy and record.tiles and enemy.tiles<record.tiles then record.bursts=0 end
        local eligible=id==0 or breakout or fastFinish or Strategy.target_score(id,tile or 0,0)~=nil
        if enabled and ratio and tile and eligible and not friendly(id)
            and (not options.protect or not state.targetProtected[id] or breakout or fastFinish)
            and now-record.at>=Strategy.front_reinforce_delay(id,me,front,fastFinish,neutralNeed)
            and record.bursts<options.maxBoosts then
            local committed=math.floor(me.troops*ratio)
            local depleted=front.troops<committed*0.5
            local ready=not economic or economicReady or depleted
            local oversupplied=front.troops>committed*2 and me.troops/Strategy.capacity(me)<0.9
            if id==0 then
                if neutralNeed then oversupplied=front.troops>=neutralNeed*0.85;ready=true
                elseif not depleted then oversupplied=true end
            end
            if fastFinish then
                oversupplied=front.troops>=Strategy.finish_strength(enemy) and not stalled
                ready=true
            end
            if options.routeAwareTargets and enemy and tile then
                local route=Strategy.land_route(tile,id)
                if route and route.fragment then
                    local localNeed=math.max((Config.MIN_ATTACK_TROOPS or 250)*4,
                        enemy.troops*route.area/math.max(1,enemy.tiles or 0)*2)
                    if front.troops>=localNeed then oversupplied=true end
                end
            end
            if ready and not oversupplied then
                local score=(depleted and 1000 or 0)+(id~=0 and 100 or 0)-front.troops/math.max(1,committed)
                if humanTargets[id] then score+=1000000 end
                if not best or score>best.score then best={id=id,tile=tile,ratio=ratio,record=record,score=score} end
            end
        end
    end
    if not best then return false end
    best.tile=Strategy.land_target(best.id,best.tile)
    if not best.tile then return false end
    if send({t="attack",tile=best.tile,ratio=best.ratio},"bestaand front "..best.id.." gericht versterken") then
        best.record.at=now;best.record.bursts=best.record.bursts+1
        best.record.captureAt=state.lastCaptureAt or -10000
        best.record.tiles=state.players[best.id] and state.players[best.id].tiles
        if state.frontProgress and state.frontProgress[best.id] then state.frontProgress[best.id].at=now end
        state.boosts[best.id]=best.record;state.lastSend=now
    end
    return true
end
function Strategy.spawn_region(tile)
    local queue,seen={tile},{[tile]=true}
    local sx,sy=tile%W,math.floor(tile/W)
    local area,terrain,water,hostile=0,0,0,0
    local directions={false,false,false,false}
    local head=1
    while head<=#queue do
        local point=queue[head];head+=1;area+=1
        local x,y=point%W,math.floor(point/W)
        terrain+=bit32.band(buffer.readu8(state.terrain,point),63)
        if x<sx-24 then directions[1]=true end;if x>sx+24 then directions[2]=true end
        if y<sy-24 then directions[3]=true end;if y>sy+24 then directions[4]=true end
        neighbours(point,function(other)
            if not seen[other] then
                seen[other]=true
                local dx,dy=other%W-sx,math.floor(other/W)-sy
                if math.abs(dx)<=96 and math.abs(dy)<=96 then
                    if not passable(other) then water+=1
                    else
                        local owner=buffer.readu8(state.owners,other)
                        if owner==0 or owner==state.id then
                            if #queue<8000 then queue[#queue+1]=other end
                        else
                            local user=state.rosterUsers and state.rosterUsers[owner]
                            hostile+=type(user)=="number" and user>0 and 4 or 1
                        end
                    end
                end
            end
        end)
    end
    local exits=0;for _,v in ipairs(directions) do if v then exits+=1 end end
    return {area=area,capped=#queue>=8000,exits=exits,water=water,hostile=hostile,
        score=math.sqrt(area)*18+exits*120-terrain/math.max(1,area)*8-water*0.5-hostile*5}
end
function Strategy.spawn_score(tile)
    if not tile or tile<0 or tile>=N or not passable(tile) then return nil end
    local owner=buffer.readu8(state.owners,tile)
    if owner~=0 and owner~=state.id then return nil end
    local x,y=tile%W,math.floor(tile/W)
    local nearest,crowding=W+H,0
    for id,other in pairs(state.representatives) do
        if id~=state.id and buffer.readu8(state.owners,other)==id then
            local distance=math.abs(x-other%W)+math.abs(y-math.floor(other/W))
            nearest=math.min(nearest,distance)
            local user=state.rosterUsers[id]
            local human=type(user)=="number" and user>0
            if distance<140 then crowding+=(140-distance)*(human and 2 or 0.6) end
        end
    end
    if nearest<(Config.MIN_SPAWN_DISTANCE or 30)+10 then return nil end
    local free,wide=0,0
    for dy=-24,24,8 do for dx=-24,24,8 do
        local px,py=x+dx,y+dy
        if px>=0 and px<W and py>=0 and py<H then
            local t=py*W+px;local id=buffer.readu8(state.owners,t)
            if passable(t) and (id==0 or id==state.id) then free+=1 end
        end
    end end
    for dy=-80,80,20 do for dx=-80,80,20 do
        local px,py=x+dx,y+dy
        if px>=0 and px<W and py>=0 and py<H then
            local t=py*W+px
            if passable(t) and buffer.readu8(state.owners,t)==0 then wide+=1 end
        end
    end end
    if free<30 then return nil end
    return free*12+wide*5+math.min(nearest,300)-crowding-bit32.band(buffer.readu8(state.terrain,tile),63)*2
end
function Strategy.defense_harvest(targets,valuableOnly)
    local hold,critical=Strategy.defense_budget()
    local me=state.players[state.id]
    if critical or not me or not options.defend then return false end
    if state.lastPlayers<=(state.lastSend or -100) or state.lastFronts<=(state.lastSend or -100) then return false end
    if Strategy.active_orders()>=math.min(options.maxFronts,Config.MAX_FRONTS_PER_PLAYER or 4) then return false end
    local busy={}
    for _,front in ipairs(state.outgoing) do busy[front.id]=true end
    for _,front in ipairs(state.incoming) do busy[front.id]=true end
    local candidates=table.clone(targets)
    local sea={}
    if Strategy.transport_available() then
        for id,entry in pairs(state.waterTargets or {}) do
            local pending=state.riverOrders and state.riverOrders[id]
            if not candidates[id] and not busy[id] and buffer.readu8(state.owners,entry.tile)==id
                and (not pending or pending.untilTime<=os.clock()) then candidates[id]=entry.tile;sea[id]=true end
        end
    end
    local best,bestRatio,bestScore=nil,nil,-math.huge
    for id,tile in pairs(candidates) do
        local enemy=state.players[id]
        local valuable=enemy and enemy.isBot~=true and options.attack
            and (Strategy.city_value(id)>=1 or (enemy.tiles or 0)>=me.tiles*0.15)
        if enemy and ((enemy.isBot==true and (options.attack or options.expand) and not valuableOnly) or valuable)
            and not busy[id] and enemy.troops<=me.troops*0.10 then
            local score=Strategy.target_score(id,tile,0)
            for _,ratio in ipairs(Config.attackPresets(state.mode)) do
                local committed=math.floor(me.troops*(sea[id] and 1/(Config.TRANSPORT_BOAT_TROOP_DIVISOR or 5) or ratio))
                local cost=sea[id] and math.max(committed,math.floor(me.troops*ratio)) or committed
                if score and committed>=math.max(Config.MIN_ATTACK_TROOPS or 250,enemy.troops*(enemy.isBot==true and 1.1 or 1.5))
                    and me.troops-cost>=hold and (not best or score>bestScore or (id==best and ratio<bestRatio)) then
                    best,bestRatio,bestScore=id,ratio,score
                end
            end
        end
    end
    if best and send({t="attack",tile=candidates[best],ratio=bestRatio},"ACTIEVE VERDEDIGING: waardevol zwak land "..best..(sea[best] and " via water" or " via land").."; thuisreserve "..math.ceil(hold)) then
        if sea[best] then Strategy.track_transport(best,candidates[best]) end
        state.lastSend=os.clock();return true
    end
    return false
end
function Strategy.emergency_defense_step()
    if not options.defend or not options.activeDefense or options.dry or not alive or not state.ready
        or state.phase~="playing" or state.awaitingInit or state.engineFault
        or (state.protocolBlocks and next(state.protocolBlocks)) or not fresh() or #state.incoming==0 then return false end
    if os.clock()-(state.defenseCounterAt or -10000)<0.75 or os.clock()-state.lastAction<0.5 then return false end
    if state.lastPlayers<=(state.lastSend or -100) or state.lastFronts<=(state.lastSend or -100) then return false end
    local targets={}
    for _,front in ipairs(state.incoming) do targets[front.id]=Strategy.land_target(front.id) end
    local worst=nil
    for _,front in ipairs(state.incoming) do
        if targets[front.id] and (not worst or front.troops>worst.troops) then worst=front end
    end
    if not worst then state.counterReason="Geen betrouwbare aangrenzende route naar aanvaller";return false end
    local ratio=Strategy.defense_ratio(worst.id)
    if not ratio then return false end
    state.defenseOrder=true
    local ok,sent=pcall(send,{t="attack",tile=targets[worst.id],ratio=ratio},"NOODVERDEDIGING: "..state.counterReason)
    state.defenseOrder=nil
    if not ok then error(sent,0) end
    if sent then
        state.lastSend=os.clock();state.defenseCounterAt=os.clock()
        local me=state.players[state.id]
        state.defenseRecovery={at=os.clock(),troops=me.troops}
        local spending=state.defenseSpending
        if not spending or os.clock()-spending.at>=5 then spending={at=os.clock(),baseline=me.troops,spent=0};state.defenseSpending=spending end
        spending.spent+=math.floor(me.troops*ratio)
        Recorder.emit("active_defense",{id=worst.id,incoming=worst.troops,ratio=ratio})
        return true
    end
    return false
end
function Strategy.try_cap_recovery(targets)
    if not options.capRecovery or not options.neighborReserve or not options.protect or not fresh()
        or state.phase~="playing" or not state.ready or #state.incoming>0
        or os.clock()-(state.lastCapRecovery or -10000)<8 or Strategy.active_orders()>=Strategy.land_front_limit() then return false end
    local me=state.players[state.id]
    if not me or not me.alive then return false end
    local cap=Strategy.capacity(me)
    if me.troops<cap*0.90 then return false end
    local grace=state.historical and (state.historical.grace or 0) or (Config.SPAWN_IMMUNITY_SECONDS or 0)
    if os.clock()-(state.playingAt or 0)<grace then return false end
    local ratio=math.max(0.05,Config.MIN_ATTACK_RATIO or 0.05)
    if ratio>0.05 then return false end
    local busy={};for _,front in ipairs(state.outgoing) do busy[front.id]=true end
    local best=nil
    for id,tile in pairs(targets) do
        local enemy=state.players[id]
        local allowed=id==0 and options.expand or id~=0 and enemy and (options.attack or (options.expand and enemy.isBot==true))
        local weak=id==0 or (enemy and enemy.alive and enemy.troops<=me.troops*0.08
            and math.floor(me.troops*ratio)>=enemy.troops*0.65)
        if allowed and weak and not busy[id] and not friendly(id) then
            local point=Strategy.land_target(id,tile)
            if point then
                local score=id==0 and 100 or Strategy.target_score(id,point,0,true)
                if score and (not best or score>best.score) then best={id=id,tile=point,score=score} end
            end
        end
    end
    if not best then return false end
    local payload={t="attack",tile=best.tile,ratio=ratio}
    if Strategy.offensive_budget(payload) then return false end
    local budget=state.neighborBudget
    if not budget or budget.hold<=cap then return false end
    state.capRecoveryOrder=true
    local ok,sent=pcall(send,{t="attack",tile=best.tile,ratio=ratio},"CAPACITEIT HERSTELLEN: kleine verovering "..best.id.." met 95% leger thuis")
    state.capRecoveryOrder=nil
    if not ok then error(sent,0) end
    if sent then state.lastSend=os.clock();state.lastCapRecovery=os.clock();return true end
    return false
end
function Strategy.try_shield()
    if not options.sams or not state.structuresReady or not state.gold or Strategy.city_value(state.id)<3 then return false end
    local status=Strategy.shield_status()
    if status.sams>=status.limit or status.plannedCoverage>=0.90 then return false end
    local urgent=options.adaptiveSams and (status.coverage<0.60 or os.clock()-(state.lastHostileMissile or -10000)<90)
    if os.clock()-(state.lastBuild or -10000)<(urgent and math.min(2,options.buildDelay) or options.buildDelay) then return false end
    local free=(state.freeSams or 0)>0
    if not free and (not state.samCost or state.gold-state.samCost<options.goldReserve) then return false end
    local tile=Strategy.sam_spot()
    if tile and send({t="build",tile=tile,kind=5},"ANTI-NUKE: ongedekte huizengroep beschermen") then
        state.lastBuild=os.clock();state.lastSend=os.clock();state.blockedBuild[tile]=os.clock()+30;return true
    end
    return false
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
    local best=state.spawnTile
    local bestScore=-math.huge
    local rng=Random.new()
    local finalists={}
    local function consider(tile)
        local score=Strategy.spawn_score(tile)
        if score then
            finalists[#finalists+1]={tile=tile,score=score}
            table.sort(finalists,function(a,b) return a.score>b.score end)
            if #finalists>10 then table.remove(finalists) end
        end
    end
    if best then consider(best) end
    for attempt=1,400 do
        consider(rng:NextInteger(0,N-1))
        if attempt%80==0 then task.wait() end
    end
    for _,candidate in ipairs(finalists) do
        local profile=Strategy.spawn_region(candidate.tile)
        local score=candidate.score+profile.score
        if profile.area>=512 and score>bestScore then best,bestScore=candidate.tile,score;state.spawnProfile=profile end
    end
    if not best and finalists[1] then best=finalists[1].tile end
    if state.spawnTile and best~=state.spawnTile then
        local current=Strategy.spawn_score(state.spawnTile)
        if current then current+=Strategy.spawn_region(state.spawnTile).score end
        if current and bestScore-current<math.max(100,math.abs(current)*0.18) then return state.spawnTile end
    end
    return best
end
function Strategy.capture_round_memory(payload)
    if state.round~=payload.round or state.id~=payload.yourId or state.mapId~=(payload.mapId or "us") then return nil end
    local memory={}
    for _,key in ipairs({"playingAt","lastCaptureAt","lastBreakoutAt","breakout","frontProgress","boosts",
        "territoryGrowth","catchupLeader","catchupActive","orderSerial","lastNuke","lastNukeScan","nukeSalvoCount",
        "nukeFastBlockedUntil","nukePending","nukeBudgetAfter","defenseCounterAt","riverOrders","waterFailures","waterOwnerRetry","waterStalledAt","lastFallbackTransport","lastHostileMissile","defenseRecovery","defenseSpending","cautionUntil","lastCapRecovery","hostileWarheads"}) do memory[key]=state[key] end
    return memory
end
function Strategy.restore_round_memory(memory)
    if not memory then return end
    for key,value in pairs(memory) do state[key]=value end
    if state.nukePending then state.nukePending.generation=state.generation end
    Recorder.emit("strategy_restored",{round=state.round,serial=state.orderSerial})
end
local function state_event(kind,payload,extra)
    Recorder.receive(kind,payload,extra)
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
    if kind=="players" or kind=="fronts" or kind=="structs" or kind=="vehicles" or kind=="armies" or kind=="roster" then
        local key="decoded."..kind
        if kind=="structs" or kind=="roster" or os.clock()-(Recorder.lastByKind[key] or -100)>=2 then
            Recorder.lastByKind[key]=os.clock();Recorder.emit(key,{payload=payload,extra=extra})
        end
    end
    if kind=="init" then
        assert(type(payload)=="table" and type(payload.yourId)=="number","Onbekend init-formaat")
        local memory=Strategy.capture_round_memory(payload)
        if state.round~=payload.round then state.resyncAttempts=0 end
        state.awaitingInit=false;state.mapFault=nil;state.engineFault=nil
        state.generation=state.generation+1
        local generation=state.generation
        state.round=payload.round; state.id=payload.yourId; state.phase=payload.phase
        state.mode=payload.modeId; state.historical=payload.historical; state.mapId=payload.mapId or "us"
        state.frontLimitDenied=nil;state.transportRetryAt=0;state.lastFallbackTransport=-10000;state.blockedAttack={}
        state.rosterUsers={};state.spawnProfile=nil;state.rejectedSpawn={};state.pendingSpawn=nil;state.spawnTile=nil;state.previewChosen=false;state.frontProgress={};state.territoryGrowth={};state.racePressure=false;state.homeLossRate=0;state.defenseCounterAt=-10000;state.planBorders={};state.counterReason=nil;state.lastDefenseLog=-10000;state.planFrontLimit=nil;state.mapRevision=0;state.orderSerial=0;state.lastTroopOrder=-10000;state.catchupLeader=nil;state.catchupActive=false;state.lastBorderAudit=-10000;state.lastTargetReport=-10000
        state.ownedSamples={};state.structures={};state.structuresReady=false
        state.armies=nil;state.boosts={};state.landOrders={};state.growthProfile=nil;state.measuredGrowth=nil;state.economicStatus=nil;state.lastCaptureAt=-10000
        state.coast={};state.waterTargets={};state.riverOrders={};state.blockedLanding={};state.transportCount=0;state.lastWaterScan=-10000;state.waterFailures={};state.waterOwnerRetry={};state.waterStalledAt=nil;state.lastTransportPoll=-10000;state.vehicles={};state.lastVehicles=-10000;state.transportKnown=false
        state.blockedBuild={};state.plannedBlasts={};state.gold=nil;state.cityCost=nil;state.postCost=nil
        state.freeCities=0;state.freePosts=0;state.freeNukes=0;state.freeSams=0;state.samCost=nil
        state.reinforceCost=nil;state.reinforceTroops=nil;state.reinforceQuoteAt=nil
        state.boxedSince=nil;state.lastBreakoutAt=nil;state.breakout=nil
        state.reinforceReadyAt=nil;state.reinforceCooldownUntil=0;state.reinforcePendingUntil=0;state.reinforceDenied=false
        state.quarantinedAttack={};state.attackOrders={};state.mapRepairPending=false;state.containedDefense=false
        state.humanFinishReason=nil;state.shieldStatus=nil;state.lastHostileMissile=nil;state.defenseOrder=nil;state.defenseGrowth=nil;state.defenseRecovery=nil;state.defenseSpending=nil;state.cautionUntil=nil;state.neighborBudget=nil;state.capRecoveryOrder=nil;state.lastCapRecovery=nil;state.hostileWarheads={}
        state.nukePending=nil;state.nukeBudgetAfter=nil;state.nukeSalvoCount=0;state.nukeFastBlockedUntil=0;state.fastFrontOrder=nil
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
        Strategy.restore_round_memory(memory)
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
        state.frontProgress=state.frontProgress or {}
        state.territoryGrowth=state.territoryGrowth or {}
        local elapsed=os.clock()-(state.lastPlayers or 0)
        for id,entry in pairs(players) do
            local previous=state.players[id]
            if previous and elapsed>=0.1 and elapsed<=5 then
                local rate=math.max(0,entry.tiles-previous.tiles)/elapsed
                state.territoryGrowth[id]=(state.territoryGrowth[id] or rate)*0.65+rate*0.35
                if id==state.id then state.homeLossRate=(state.homeLossRate or 0)*0.65+math.max(0,previous.tiles-entry.tiles)/elapsed*0.35 end
            end
            local progress=state.frontProgress[id] or {at=os.clock(),tiles=entry.tiles}
            if previous and entry.tiles<previous.tiles then progress.at=os.clock() end
            progress.tiles=entry.tiles;state.frontProgress[id]=progress
        end
        state.players=players; state.lastPlayers=os.clock()
    elseif kind=="fronts" and state.id then
        assert(type(payload.out)=="table" and type(payload.inc)=="table","Onbekend fronts-formaat")
        state.incoming=payload.inc; state.outgoing=payload.out

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
    elseif kind=="missiles" and state.id then
        Strategy.observe_missiles(payload)
    elseif kind=="armies" and state.id then
        state.armies=payload
    elseif kind=="vehicles" and state.id then
        state.transportCount=0;state.vehicles=payload;state.lastVehicles=os.clock()
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
    elseif kind=="spawned" then
        state.spawned=payload.preview~=true;state.previewChosen=payload.preview==true
        state.spawnTile=payload.tile or state.pendingSpawn;state.pendingSpawn=nil;state.errorCount=0
        log(state.previewChosen and "Voorlopige spawn bevestigd; omgeving blijft gecontroleerd." or "Spawn bevestigd.")
    elseif kind=="denied" then
        log("Server weigert: "..tostring(payload.reason))
        if state.phase=="spawn" and state.pendingSpawn then
            state.rejectedSpawn[state.pendingSpawn]=true
            state.pendingSpawn=nil
            state.spawnAt=-100
        end
        local command=state.lastCommand
        if state.nukePending and ((payload.kind==13 and payload.tile==state.nukePending.tile) or (command and command.t=="nuke")) then
            local pending=state.nukePending
            for i=#state.plannedBlasts,1,-1 do
                if state.plannedBlasts[i].sentAt==pending.at then table.remove(state.plannedBlasts,i) end
            end
            state.nukePending=nil;state.nukeBudgetAfter=os.clock()
            if payload.reason=="cooldown" or payload.reason=="nosilo" then state.nukeFastBlockedUntil=os.clock()+options.nukeDelay end
        end
        if command and command.t=="attack" and state.riverOrders then
            for id,entry in pairs(state.riverOrders) do
                if entry.tile==command.tile then
                    local route=payload.reason=="nobeach" or payload.reason=="nocoast" or payload.reason=="nosearoute"
                    entry.untilTime=os.clock()+(route and 30 or options.interval);entry.failed=true
                    if route then Strategy.water_failure(id,entry,"server: "..payload.reason) end
                end
            end
        end
        if command and command.t=="reinforce" then
            state.reinforcePendingUntil=os.clock()+10
            if payload.reason=="pass" then state.reinforceDenied=true;log("Reinforcement niet beschikbaar voor dit account.") end
            state.reinforceQuoteAt=nil
        end
        if payload.reason=="own" then Strategy.handle_own_denial(payload) end
        if payload.reason=="toomanytransportboats" then state.transportRetryAt=os.clock()+30 end
        if command and command.t=="build" and state.blockedBuild then state.blockedBuild[command.tile]=os.clock()+45 end
        local expected={own=true,pass=true,gold=true,crowded=true,maxlevel=true,immunity=true,toonear=true,taken=true,notadjacent=true,troops=true,full=true,cooldown=true,
            busy=true,nobeach=true,nocoast=true,nosearoute=true,toomanytransportboats=true,toomanyfronts=true}
        if not expected[payload.reason] then state.errorCount=state.errorCount+1 end
        if payload.reason=="toomanyfronts" then
            state.frontLimitDenied={active=#state.outgoing,retryAt=os.clock()+10}
            Recorder.emit("front_limit_denied",state.frontLimitDenied)
        end
        state.lastAction=payload.reason=="own" and (os.clock()-options.interval) or (os.clock()+5)
        if state.errorCount>=4 then
            state.engineFault="Vier onverwachte serverweigeringen; stuur Foutlog. Instellingen behouden."
            log(state.engineFault)
        end
    end
end
function Strategy.audit_border()
    if not state.ready or os.clock()-(state.lastBorderAudit or -10000)<10 then return end
    state.lastBorderAudit=os.clock()
    local changed=false
    local function inspect(tile)
        local before=state.frontier[tile]
        refresh_tile(tile)
        if state.frontier[tile]~=before then changed=true end
    end
    for _,tile in pairs(state.ownedSamples or {}) do
        if tile>=0 and tile<N and buffer.readu8(state.owners,tile)==state.id then inspect(tile);neighbours(tile,inspect) end
    end
    if changed then state.mapRevision=(state.mapRevision or 0)+1;log("GRENSCONTROLE: aangrenzende doelvelden opnieuw bijgewerkt") end
end
function Strategy.target_diagnostics()
    local me=state.players[state.id]
    if not state.ready or not me or not me.alive or os.clock()-(state.lastTargetReport or -10000)<20 then return end
    state.lastTargetReport=os.clock()
    local busy={}
    for _,front in ipairs(state.outgoing) do busy[front.id]=true end
    local printed=0
    for id,contact in pairs(Strategy.contacts()) do
        local enemy=state.players[id]
        if enemy and enemy.troops<=me.troops*0.15 and printed<4 then
            local why
            if not options.attack and enemy.isBot~=true then why="Aanvallen staat UIT"
            elseif busy[id] then why="Veldleger vecht al tegen dit land"
            elseif #state.incoming>0 and not Strategy.contained_attack() then
                local hold,critical=Strategy.defense_budget()
                why=critical and "Zware inkomende aanval" or ("Verdedigingsbudget thuis "..math.ceil(hold))
            elseif Strategy.active_orders()>=(state.planFrontLimit or options.maxFronts) then why="Actieve fronten/transporten vullen limiet"
            else
                local ratio,hold=Strategy.opportunity_ratio(id,state.targetProtected and state.targetProtected[id])
                why=ratio and ("Aanval haalbaar: "..math.floor(ratio*100).."%; selectie op waarde/tempo") or ("Troepenpreset of reserve blokkeert; reserve "..tostring(hold or "overige voorwaarden"))
            end
            log("DOEL "..id.." | vijand "..math.floor(enemy.troops).." | eigen "..math.floor(me.troops).." | "..why)
            printed+=1
        end
    end
end
local function run_step_inner()
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
        #warnings>0 and table.concat(warnings,", ") or "geen",(state.reason or "Initialiseren")..(options.nukes and ("\nNukes: "..(state.nukeReason or "doelen beoordelen")) or "\nNukes: UIT"))
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
    if not Strategy.order_ready("attack") and not Strategy.order_ready("build") then state.reason="Actievertraging";return end
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
            else Recorder.emit("order.lobby",{action="join",key=slot.key});folder.LobbyIntent:FireServer("join",slot.key); state.reason="Join verstuurd: "..chosen.name;log("Join gevraagd: "..chosen.name) end
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
        if os.clock()-state.spawnAt<5 then state.reason="Wachten op spawnbevestiging";return end
        state.spawnAt=os.clock()
        local generation=state.generation
        local tile=choose_spawn()
        if alive and state.generation==generation and state.phase=="spawn" and options.spawn and tile and tile~=state.spawnTile then
            if send({t="spawn",tile=tile},state.historical and "groot beschikbaar land kiezen" or "spawn op tegel "..tile) then state.pendingSpawn=tile end
        elseif not tile then state.reason="Geen geschikte beschikbare spawn gevonden"
        end
        return
    end
    if state.phase~="playing" then state.reason="Wachten op start wedstrijd";return end
    if not me or not me.alive or me.tiles<=0 then state.reason="Geen levend eigen rijk gevonden";return end
    if not fresh() then state.reason="Wachten op actuele troepen/fronten";return end
    Strategy.update_catchup()
    local defending=options.defend and #state.incoming>0
    state.containedDefense=#state.incoming>0 and Strategy.contained_attack()
    if (not defending or state.containedDefense) and (state.lastPlayers<=(state.lastSend or -100) or state.lastFronts<=(state.lastSend or -100)) then state.reason="Wachten op server na order";return end
    if Strategy.emergency_defense_step() then return end
    Strategy.poll_transports()
    Strategy.audit_border()
    local targets=enemy_targets()
    state.containedDefense=#state.incoming>0 and Strategy.contained_attack()
    if #state.incoming>0 and not state.containedDefense then
        state.reason="VERDEDIGEN: druk en beschikbare thuisreserve beoordelen"
        state.counterReason=nil
        if defending and Strategy.try_buy_reinforcements() then return end
        if Strategy.try_nuke() then return end
        if defending and Strategy.defense_harvest(targets,true) then return end
        if options.defend then
            local worst=nil
            for _,attack in ipairs(state.incoming) do
                if targets[attack.id] and (not worst or attack.troops>worst.troops) then worst=attack end
            end
            local defenseRatio=worst and os.clock()-(state.defenseCounterAt or -10000)>=6 and Strategy.defense_ratio(worst.id)
            if worst and defenseRatio then
                if send({t="attack",tile=targets[worst.id],ratio=defenseRatio},"TEGENDRUK op "..worst.id.." | inzet "..math.floor(me.troops*defenseRatio).." | thuis "..(me.troops-math.floor(me.troops*defenseRatio)).." | nuke: "..(state.nukeReason or "niet beschikbaar")) then state.lastSend=os.clock();state.defenseCounterAt=os.clock() end
                return
            else state.reason="Aanval binnenkomend; geen veilige tegenaanval beschikbaar" end
        else state.reason="Aanval binnenkomend; offensief gepauzeerd" 
        end
        if Strategy.try_build(true) then return end
        if defending and Strategy.defense_harvest(targets) then return end
        if os.clock()-(state.lastDefenseLog or -10000)>=8 then
            log("VERDEDIGING: "..(options.defend and (state.counterReason or "Geen aangrenzende aanvalsroute of tegenaanval herstelt") or "Verdedigen staat UIT").." | NUKE: "..(state.nukeReason or "geen beschikbaar doel"))
            state.lastDefenseLog=os.clock()
        end
        local hold,critical=Strategy.defense_budget()
        state.reason="VERDEDIGEN: "..(critical and "zware druk; " or "")..(state.counterReason or "tegenaanval loopt of wacht op herbeoordeling").." | thuisreserve "..math.ceil(hold)
        return
    end
    if Strategy.try_shield() then return end
    if Strategy.try_cap_recovery(targets) then return end
    if Strategy.try_finish_humans(targets) then return end
    if Strategy.try_land_campaign(targets) then return end
    if Strategy.quick_campaign(targets) then return end
    local mapGeneration=state.generation
    local beforeRouteOrder=state.orderSerial or 0
    Strategy.water_targets()
    if beforeRouteOrder~=(state.orderSerial or 0) then state.reason="Routeplan herzien na tussentijdse verdedigingsorder";return end
    if mapGeneration~=state.generation or not state.ready or not fresh() or (#state.incoming>0 and not Strategy.contained_attack()) then return end
    if Strategy.try_buy_reinforcements() then return end
    if Strategy.try_shield() then return end
    local ratio=choose_ratio(false)
    state.planBorders={}
    for id,contact in pairs(Strategy.contacts()) do state.planBorders[id]=contact.border end
    if Strategy.try_nuke() then return end
    local pressureId,pressureRatio,pressureHold=Strategy.capacity_plan(targets)
    if pressureId then
        if send({t="attack",tile=targets[pressureId],ratio=pressureRatio},(state.catchupActive and "INHAALKEUZE: " or "CAPACITEITSKEUZE: ")..state.pressureReason.." | thuisreserve "..math.ceil(pressureHold)) then
            state.lastSend=os.clock();state.breakout={id=pressureId,untilTime=os.clock()+90}
        end
        return
    end
    local parallelOpportunity=false
    if options.attack and #state.outgoing>0 then
        local busyTargets={}
        for _,front in ipairs(state.outgoing) do busyTargets[front.id]=true end
        for id in pairs(targets) do
            local enemy=state.players[id]
            if id~=0 and not busyTargets[id] and enemy and enemy.troops<=me.troops*0.20
                and Strategy.opportunity_ratio(id,state.targetProtected[id]) then parallelOpportunity=true;break end
        end
    end
    local reserveBeforePlanning=state.requiredReserve
    local capPressure=me.troops>=Strategy.capacity(me)*0.80
    local freeExpansion=options.expand and targets[0]~=nil and choose_ratio(false,true)~=nil
    local cheapCapture=false
    local botHarvest=false
    local treasureCapture=false
    if options.attack or options.expand then
        local occupied={}
        for _,front in ipairs(state.outgoing) do occupied[front.id]=true end
        for id in pairs(targets) do
            local enemy=state.players[id]
            if id~=0 and not occupied[id] and enemy and (options.attack or enemy.isBot==true)
                and enemy.troops<=me.troops*0.20 and Strategy.opportunity_ratio(id,state.targetProtected[id]) then
                cheapCapture=true
                if enemy.isBot==true then botHarvest=true
                elseif Strategy.city_value(id)>=3 then treasureCapture=true end
            end
        end
    end
    local growthPriority=capPressure and (freeExpansion or cheapCapture)
        and Strategy.active_orders()<math.min(options.maxFronts,Config.MAX_FRONTS_PER_PLAYER or 4)
    state.requiredReserve=reserveBeforePlanning
    local harvestPriority=botHarvest and ((state.cityCost and state.gold and state.gold<state.cityCost) or me.troops<Strategy.capacity(me)*0.65)
        and Strategy.active_orders()<math.min(options.maxFronts,Config.MAX_FRONTS_PER_PLAYER or 4)
    local treasurePriority=treasureCapture and Strategy.active_orders()<math.min(options.maxFronts,Config.MAX_FRONTS_PER_PLAYER or 4)
    local waterOpportunity=false
    if options.rivers and (options.attack or options.expand) and Strategy.transport_available() then
        local occupied={}
        for _,front in ipairs(state.outgoing) do occupied[front.id]=true end
        local grace=state.historical and (state.historical.grace or 0) or (Config.SPAWN_IMMUNITY_SECONDS or 0)
        local allowed=os.clock()-(state.playingAt or 0)>=grace
        for id,entry in pairs(state.waterTargets or {}) do
            if Strategy.water_order(id,entry,allowed,targets,occupied) then waterOpportunity=true;break end
        end
    end
    if not waterOpportunity and not parallelOpportunity and not growthPriority and not harvestPriority and not treasurePriority and Strategy.try_build(false) then return end
    local normalReserve=state.requiredReserve
    local economicRatio=choose_ratio(false,true)
    local economicReserve=state.requiredReserve
    state.economicReserve=economicReserve
    state.requiredReserve=normalReserve
    local economicReady=Strategy.growth_ready(economicRatio)
    local openRatio,openReserve=Strategy.neutral_ratio(0,economicRatio,economicReserve)
    local openReady=Strategy.open_ready(openRatio,openReserve)
    local active=Strategy.active_orders()
    local allowedFronts=Strategy.land_front_limit()
    local serverSlots=Config.MAX_FRONTS_PER_PLAYER or 4
    if options.protect and options.defend and serverSlots>1 then
        for id in pairs(state.planBorders or {}) do
            local other=state.players[id]
            if other and other.isBot~=true and other.troops>=me.troops*0.60 then allowedFronts=math.min(allowedFronts,serverSlots-1);break end
        end
    end
    state.planFrontLimit=math.min(allowedFronts,serverSlots)
    if active>=state.planFrontLimit then
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
        local selectedEnemy=weakest and state.players[weakest]
        if targets[0] and not busy[0] and options.expand and openRatio and openReady
            and (not weakest or (selectedEnemy and selectedEnemy.isBot~=true and selectedEnemy.troops>me.troops*0.20)) then
            local open=Strategy.open_tile()
            if open and send({t="attack",tile=open,ratio=openRatio},"PLAN GROEI: "..(Strategy.open_rival() and "kleine uitbreidingspuls naast enige buur" or "passend open-landleger").."; thuisreserve "..math.ceil(openReserve or 0)) then state.lastSend=os.clock() end
            return
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
        if Strategy.transport_available() then
            local targetId,target,waterScore,waterRatio,waterReserve=nil,nil,-math.huge,nil,nil
            for id,entry in pairs(state.waterTargets or {}) do
                local score,orderRatio,hold=Strategy.water_order(id,entry,attacksAllowed,targets,busy)
                if score and score>waterScore then targetId,target,waterScore,waterRatio,waterReserve=id,entry,score,orderRatio,hold end
            end
            local boatTroops=math.floor(me.troops/(Config.TRANSPORT_BOAT_TROOP_DIVISOR or 5))
            if target and waterScore>bestScore and boatTroops>=(Config.TRANSPORT_BOAT_MIN_TROOPS or 250)
                and me.troops-boatTroops>=(waterReserve or 0) then
                if send({t="attack",tile=target.tile,ratio=waterRatio},"wateroversteek naar "..targetId.." | afstand "..target.distance.." | transport ongeveer "..boatTroops.." troepen") then
                    state.lastSend=os.clock()
                    Strategy.track_transport(targetId,target.tile)
                end
                return
            end
            state.reason="Geen veilige landing; "..(state.waterSearchInfo or "waterkaart onderzoeken")
        end
        if weakest then
            local cityCount=Strategy.city_value(weakest)
            local bot=state.players[weakest].isBot==true
            local description=bot and ("botland "..weakest.." veroveren; "..cityCount.." zichtbare steden") or "voorzichtige aanval op speler/onbekend land "..weakest
            state.reason="Plan: "..(bot and "botland oogsten: land, gebouwen en serverbeloning" or (active>0 and "parallel zwak buurland innemen" or "zwakke buur en huizen innemen"))
            log(state.reason.." | doel "..weakest.." | lopende fronten "..active)
            state.requiredReserve=math.ceil(bestReserve or normalReserve or 0)
            description=description..(state.racePressure and " | groeirace" or "").." | huizen "..cityCount.." | waarde "..math.floor(bestScore).." | inzet "..math.floor(me.troops*bestRatio).." | thuis "..math.floor(me.troops*(1-bestRatio))
            if send({t="attack",tile=targets[weakest],ratio=bestRatio},description) then state.lastSend=os.clock() end
            return
        end
        if Strategy.try_reinforce(targets,ratio,economicRatio,economicReady) then return end
        if options.expand and targets[0] and not busy[0] and openRatio and openReady then
            local tile=Strategy.open_tile()
            if tile and send({t="attack",tile=tile,ratio=openRatio},"groeivenster benutten: uitbreiden via minder bedreigde grens") then state.lastSend=os.clock() end
            return
        end
        if not ratio and not economicRatio then
            state.reason="Reserve blokkeert order: leger "..math.floor(me.troops).." | strijd "..math.ceil(normalReserve or 0).." | groei "..math.ceil(economicReserve or 0)
            return
        end
        if options.rivers and next(state.waterTargets or {}) and not Strategy.transport_available() then
            state.reason="Oversteek wacht: "..(state.transportReason or "transportvoorwaarden beoordelen");return
        end
        state.reason=state.island and ("Eiland: "..(state.waterSearchInfo or "zoekronde afwachten").."; geen betaalbare veilige landing") or state.pressureReason or "Geen betaalbaar veilig doel; wachten op troepen of beschikbare grens"
    else state.reason="Uitbreiden en aanvallen staan uit"
    end
end

function Recorder.sample()
 if not options.recordData or os.clock()-Recorder.lastSample<2 then return end
 Recorder.lastSample=os.clock()
 local summaries={};local contacts={}
 local totalLand,totalTroops=0,0
 for _,entry in pairs(state.players) do
  if entry.alive then totalLand+=entry.tiles or 0;totalTroops+=entry.troops or 0 end
 end
 if state.ready and state.owners then contacts=Strategy.contacts() end
 local buildings={}
 for tile,structure in pairs(state.structures or {}) do
  local owner=structure.ownerId
  if state.owners and tile>=0 and tile<buffer.len(state.owners) then owner=buffer.readu8(state.owners,tile) end
  local counts=buildings[owner] or {cities=0,levels=0,defenses=0,sams=0,unfinished=0};buildings[owner]=counts
  if structure.kind==1 then counts.cities+=1;counts.levels+=structure.level or 1 end
  if structure.kind==3 then counts.defenses+=1 end
  if structure.kind==5 then counts.sams+=1 end
  if structure.uc then counts.unfinished+=1 end
 end
 for id,entry in pairs(state.players) do
  local copy=table.clone(entry)
  copy.knownLandShare=entry.tiles/math.max(1,totalLand)
  copy.knownArmyShare=entry.troops/math.max(1,totalTroops)
  copy.buildings=buildings[id];copy.territoryGainPerSecond=state.territoryGrowth and state.territoryGrowth[id]
  copy.friendly=friendly(id);copy.contact=contacts[id]~=nil;copy.userId=state.rosterUsers and state.rosterUsers[id]
  local previous=Recorder.previousPlayers and Recorder.previousPlayers[id]
  if previous and previous.generation==state.generation then
   local elapsed=os.clock()-previous.at
   if elapsed>0 then copy.troopNetRate=(entry.troops-previous.troops)/elapsed;copy.tileNetRate=(entry.tiles-previous.tiles)/elapsed end
  end
  summaries[#summaries+1]=copy
 end
 Recorder.previousPlayers={}
 for id,entry in pairs(state.players) do Recorder.previousPlayers[id]={troops=entry.troops,tiles=entry.tiles,at=os.clock(),generation=state.generation} end
 table.sort(summaries,function(a,b) return a.id<b.id end)
 local me=state.players[state.id]
 Recorder.emit("world",{players=summaries,selfId=state.id,phase=state.phase,mapId=state.mapId,
  width=W,height=H,mapRevision=state.mapRevision,ready=state.ready,
  gold=state.gold,capacity=me and Strategy.capacity(me),measuredGrowth=state.measuredGrowth,
  ownLossRate=state.homeLossRate,allies=state.allies,teams=state.teams,
  incoming=state.incoming,outgoing=state.outgoing,
  costs={city=state.cityCost,defense=state.postCost,sam=state.samCost,reinforce=state.reinforceCost},
  reinforceTroops=state.reinforceTroops,reinforceReadyAt=state.reinforceReadyAt,
  free={cities=state.freeCities,posts=state.freePosts,sams=state.freeSams,nukes=state.freeNukes},
  playerAge=os.clock()-state.lastPlayers,frontAge=os.clock()-state.lastFronts,
  messages=Recorder.rates,delta=Recorder.deltaStats,protocolWarnings=state.protocolWarnings,
  engineFault=state.engineFault,mapFault=state.mapFault})
 Recorder.rates={};Recorder.deltaStats=nil
 if Recorder.lastStructureGeneration~=state.generation or os.clock()-(Recorder.lastStructureBaseline or -100)>=30 then
  Recorder.lastStructureGeneration=state.generation;Recorder.lastStructureBaseline=os.clock()
  Recorder.emit("structure_baseline",{complete=state.structuresReady,structures=state.structures})
 end
end
function Recorder.decisions()
 if not options.recordData or os.clock()-Recorder.lastDecision<2 then return end
 Recorder.lastDecision=os.clock()
 local alternatives={};local me=state.players[state.id]
 local borders={}
 if state.ready and state.owners then
  for tile in pairs(state.frontier) do
   if tile>=0 and tile<buffer.len(state.owners) then
    local owner=buffer.readu8(state.owners,tile)
    local entry=borders[owner] or {count=0,samples={}};borders[owner]=entry
    entry.count+=1
    if #entry.samples<16 then entry.samples[#entry.samples+1]=tile end
   end
  end
 end
 if state.ready and state.owners and me then
  for id,contact in pairs(Strategy.contacts()) do
   local enemy=state.players[id]
   local covered=state.targetProtected and state.targetProtected[id] or false
   local ratio,reserve=Strategy.opportunity_ratio(id,covered)
   local score=Strategy.target_score(id,contact.tile,nil,false)
   local reason=not options.attack and "attack disabled" or not fresh() and "stale state"
    or #state.incoming>0 and "defense arbitration active"
    or not ratio and "normal attack budget/strength gate" or "normal budget feasible; selection competes with other work"
   alternatives[#alternatives+1]={id=id,tile=contact.tile,border=contact.border,troops=enemy.troops,
    score=score,ratio=ratio,reserve=reserve,covered=covered,reason=reason,
    route=state.waterTargets and state.waterTargets[id],cities=Strategy.city_value(id)}
  end
 end
 table.sort(alternatives,function(a,b) return (a.score or -math.huge)>(b.score or -math.huge) end)
 Recorder.emit("decision",{reason=state.reason,alternatives=alternatives,systems=Recorder.systems,
  catchup=state.catchupActive,leader=state.catchupLeader,pressure=state.pressureReason,
  requiredReserve=state.requiredReserve,economicReserve=state.economicReserve,
  fronts=state.planFrontLimit or options.maxFronts,lastOrder=state.lastCommand,
  borderTargets=borders,waterTargets=state.waterTargets,transportCount=state.transportCount,
  transportKnown=state.transportKnown,transportReason=state.transportReason,transportRetryAt=state.transportRetryAt,landFrontLimit=Config and Strategy.land_front_limit(),
  pendingTransports=state.riverOrders,blockedLandings=state.blockedLanding,waterFailures=state.waterFailures,waterCandidates=state.waterCandidates,
  pendingBlasts=state.plannedBlasts,lastBuild=state.lastBuild,lastNuke=state.lastNuke,
  lastAction=state.lastAction,actionDelay=Config and Strategy.action_delay(),
  timeSinceCapture=os.clock()-(state.lastCaptureAt or os.clock()),
  counterReason=state.counterReason,nukeReason=state.nukeReason,humanFinishReason=state.humanFinishReason,containedDefense=state.containedDefense,
  spawnProfile=state.spawnProfile,neighborBudget=state.neighborBudget,defenseGrowth=state.defenseGrowth,shieldStatus=state.shieldStatus,lastHostileMissile=state.lastHostileMissile,waterReason=state.waterSearchInfo,settings=options})
end
function Recorder.render()
 local lines={}
 for _,name in ipairs({"Data","Verdediging","Uitbreiding","Economie","Nukes","Routes","Versterken"}) do
  local entry=Recorder.systems[name]
  if entry then lines[#lines+1]=name..": "..entry.status.." | "..entry.detail.." ("..math.floor(os.clock()-entry.at).."s)" end
 end
 if Recorder.systemLabel then Recorder.systemLabel.Text=table.concat(lines,"\n") end
 if Recorder.healthLabel then Recorder.healthLabel.Text=string.format("Opname: %s | %d gebeurtenissen | %d/%d delen | %d KB geheugen\n%s",
  options.recordData and "AAN" or "UIT",Recorder.total,Recorder.part,Recorder.maxParts,math.floor(Recorder.bytes/1024),
  Recorder.error or (Recorder.disk and "Bestanden worden automatisch opgeslagen." or "Geheugenopname; exporteer of kopieer vóór afsluiten.")) end
end
function Recorder.tick_inner()
 local now=os.clock()
 if state.phase=="playing" and next(state.players) then Recorder.matchObserved=true end
 Recorder.system("Data",state.ready and "gereed" or "wachten",state.engineFault or state.mapFault or
  string.format("spelers %.1fs / fronten %.1fs oud",now-state.lastPlayers,now-state.lastFronts))
 Recorder.system("Uitbreiding",options.expand and "ingeschakeld" or "uit",state.reason or "wachten op planner")
 local defense=Recorder.systems.Verdediging
 if #state.incoming==0 then Recorder.system("Verdediging",options.defend and "bewaken" or "uit","geen gemelde inkomende fronten")
 elseif Strategy.contained_attack() then Recorder.system("Verdediging","beheerst","kleine aanval; offensief blijft actief met thuisreserve")
 elseif not defense or now-defense.at>3 then Recorder.system("Verdediging",options.defend and "bedreigd" or "uit",state.counterReason or "inkomende fronten beoordelen") end
 Recorder.sample();Recorder.decisions();Recorder.flush(false);Recorder.render()
 if state.phase~=Recorder.lastPhase then
  Recorder.emit("phase_observed",{from=Recorder.lastPhase,to=state.phase});Recorder.lastPhase=state.phase
  if state.phase=="ended" or state.phase=="finished" or state.phase=="results" then
   local path,message=Recorder.export()
   if Recorder.exportStatus then Recorder.exportStatus.Text=message..(path and ("\n"..path) or "") end
  end
 end
end
function Recorder.tick()
 local previous=state.planContext
 if not previous then state.planContext={} end
 local ok,err=xpcall(Recorder.tick_inner,debug.traceback)
 state.planContext=previous
 if not ok then error(err,0) end
end
function Recorder.install_workers()
 local workers={try_build="Economie",try_shield="Economie",try_nuke="Nukes",water_targets="Routes",
  try_buy_reinforcements="Versterken",try_reinforce="Versterken",defense_harvest="Verdediging"}
 for method,system in pairs(workers) do
  local original=Strategy[method]
  Strategy[method]=function(...)
   local started=os.clock();local serial=state.orderSerial or 0
   local result=table.pack(original(...))
   local acted=(state.orderSerial or 0)>serial
   local enabled=system=="Nukes" and options.nukes or system=="Routes" and options.rivers
    or system=="Economie" and (options.cities or options.posts or options.sams)
    or system=="Verdediging" and options.defend or system=="Versterken" and (options.reinforce or options.buyReinforcements)
   local detail=system=="Nukes" and state.nukeReason or system=="Routes" and state.waterSearchInfo
    or system=="Verdediging" and state.counterReason or method
   Recorder.system(system,acted and "order verstuurd" or enabled and "beoordeeld" or "uit",detail)
   if options.recordData and (acted or os.clock()-(Recorder.lastByKind[method] or -100)>=2) then
    Recorder.lastByKind[method]=os.clock()
    Recorder.emit("worker",{method=method,duration=os.clock()-started,acted=acted,result=result[1],detail=detail})
   end
   return table.unpack(result,1,result.n)
  end
 end
end
Recorder.systemLabel=label("Overzicht","Onderdeelstatussen worden geladen...",230)
Recorder.healthLabel=label("Data","Opnamestatus wordt geladen...",90)
Recorder.install_workers()
for _,name in ipairs({"Data","Verdediging","Uitbreiding","Economie","Nukes","Routes","Versterken"}) do
 Recorder.system(name,"wachten","nog niet beoordeeld")
end

local function run_step()
    local stepStarted=os.clock()
    state.planContext={}
    local before=state.orderSerial or 0
    local ok,result=xpcall(function()
        Strategy.repair_map_if_needed()
        if not Strategy.emergency_defense_step() and not Strategy.fast_front_step() then run_step_inner() end
        if state.phase=="playing" then Strategy.target_diagnostics() end
        if (state.orderSerial or 0)==before and Strategy.interleave_ready("build") then
            if #state.incoming>0 then Strategy.try_build(true)
            elseif not Strategy.try_shield() then Strategy.try_build(false) end
        end
    end,debug.traceback)
    state.contactScansLast=(state.planContext and state.planContext.scans) or 0
    if options.recordData and (not ok or os.clock()-stepStarted>=0.1) then
        Recorder.emit("planner_timing",{duration=os.clock()-stepStarted,success=ok,contactScans=state.contactScansLast,error=not ok and tostring(result) or nil})
    end
    local telemetryOk,telemetryError=pcall(Recorder.tick)
    if not telemetryOk then Recorder.error="Telemetrie: "..tostring(telemetryError);Recorder.render() end
    state.planContext=nil
    if not ok then error(result,0) end
    return result
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
    Recorder.emit("runtime_config",{config=Config,attackPresets=Config.attackPresets(state.mode)})
    task.spawn(function()
        while alive do
            local ok,err=pcall(Recorder.tick)
            if not ok then Recorder.error="Telemetrie: "..tostring(err);Recorder.render() end
            task.wait(1)
        end
    end)
    task.spawn(function()
        while alive do
            local ok,err=pcall(Strategy.emergency_defense_step)
            if not ok and os.clock()-(state.lastDefenseWorkerError or -10000)>10 then
                state.lastDefenseWorkerError=os.clock();log("Verdedigingscontrole: "..tostring(err))
            end
            task.wait(0.25)
        end
    end)
    while alive do guard(run_step)(); task.wait(0.5) end
end))
