
    
  
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

