-- Ground sprite sheets at their visible feet, not transparent canvas padding.
-- One baseline across the sheet preserves authored walking/idle bobbing.
-- Explicit anchors (including swimming immersion) remain authoritative.
local M={}
local cache={}
function M.measure(data,w,h,frames,trueColor)
 if not(data and data.getPixel and data.getDimensions)then return end
 local iw,ih=data:getDimensions()
 if w<1 or h<1 or w>iw or h>ih then return end
 local baseline=0
 for f=0,math.min(frames or 1,math.floor(ih/h))-1 do
  for y=h-1,baseline,-1 do
   local found=false
   for x=0,w-1 do
    local r,_,_,a=data:getPixel(x,f*h+y)
    if a>=.5 and (trueColor or r<=.83)then baseline=math.max(baseline,y+1);found=true;break end
   end
   if found then break end
  end
 end
 return baseline>0 and baseline or nil
end
function M.apply(def)
 if type(def)~='table'or def.anchorY~=nil or type(def.image)~='string'then return def end
 local w,h=def.frameWidth or 16,def.frameHeight or 16
 local key=def.image..':'..w..':'..h..':'..tostring(def.frames)..':'..tostring(def.trueColor)
 local anchor=cache[key]
 if anchor==nil then
  local ok,data=pcall(function()return require('src.render.Assets').imageData(def.image)end)
  if not ok or not data then return def end -- retry assets still streaming
  anchor=M.measure(data,w,h,def.frames,def.trueColor)or false
  if data.release then data:release()end
  cache[key]=anchor
 end
 if not anchor or anchor==h then return def end
 local out={};for k,v in pairs(def)do out[k]=v end
 out.anchorY=anchor
 return out
end
return M
