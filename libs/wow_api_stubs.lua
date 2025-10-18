-- Minimal WoW API stubs to aid static analysis (EmmyLua annotations only)
-- This file should not be executed in-game; it's for editor/linter only.

---@class Frame
---@field SetPoint fun(self:string|table, point:string, relative:table|string, relativePoint:string, x:number, y:number)
---@field SetSize fun(self, width:number, height:number)
---@field GetWidth fun(self):number
---@field GetHeight fun(self):number
---@field GetScript fun(self, script:string):function|nil
---@field SetMinMaxValues fun(self, min:number, max:number)
---@field SetValue fun(self, value:number)
---@field SetStatusBarColor fun(self, r:number, g:number, b:number, a?:number)
---@field SetVertexColor fun(self, r:number, g:number, b:number, a?:number)
---@field CreateTexture fun(self, name?:string, layer?:string, region?:string, sublevel?:number):Texture
---@field CreateFontString fun(self, name?:string, layer?:string, font?:string):FontString
---@field Hide fun(self)
---@field Show fun(self)
---@field IsShown fun(self):boolean
---@field ClearAllPoints fun(self)
---@field SetAllPoints fun(self, anchor:table)
---@field SetPoint fun(self, point:string, relative:table|string, relativePoint:string, x:number, y:number)
---@field SetAlpha fun(self, alpha:number)
---@field SetWidth fun(self, width:number)
---@field SetHeight fun(self, height:number)
---@field StartMoving fun(self)
---@field StopMovingOrSizing fun(self)
---@field SetMovable fun(self, movable:boolean)
---@field EnableMouse fun(self, enable:boolean)
---@field SetFrameStrata fun(self, strata:string)
---@field SetUserPlaced fun(self, placed:boolean)
---@field SetClampedToScreen fun(self, clamped:boolean)

---@class Texture
---@field SetTexture fun(self, path:string)
---@field SetColorTexture fun(self, r:number, g:number, b:number, a?:number)
---@field SetSize fun(self, w:number, h:number)
---@field SetPoint fun(self, point:string, relative:table|string, relativePoint:string, x:number, y:number)
---@field SetVertexColor fun(self, r:number, g:number, b:number, a?:number)
---@field SetAlpha fun(self, a:number)
---@field Show fun(self)
---@field Hide fun(self)

---@class FontString
---@field SetText fun(self, text:string)
---@field SetPoint fun(self, point:string, relative:table|string, relativePoint:string, x:number, y:number)
---@field SetJustifyH fun(self, justify:string)

---@class StatusBar : Frame

---@return Frame
function CreateFrame(type, name, parent, template) return {} end

-- Timer API
C_Timer = {}
---@param delay number
---@param func fun()
function C_Timer.After(delay, func) end
---@param interval number
---@param func fun()
---@return table
function C_Timer.NewTicker(interval, func) return {} end

-- Unit / XP stubs
---@return number
function UnitXP(unit) return 0 end
---@return number
function UnitXPMax(unit) return 1 end
---@return number
function UnitLevel(unit) return 1 end
---@return number|nil
function GetXPExhaustion() return nil end
---@return number|nil
function GetRestState() return nil end
---@return number
function GetTime() return 0 end

-- Quest log stubs
C_QuestLog = {}
---@return number
function C_QuestLog.GetNumQuestLogEntries() return 0 end
---@return table|nil
function C_QuestLog.GetInfo(index) return nil end

-- Misc helpers
---@param n number
---@return string
function BreakUpLargeNumbers(n) return tostring(n) end


FlatXPBar = nil
LegacyXPBar = nil
MainStatusTrackingBarContainer = nil

-- Container mixin types used by the mixins in the UI layer
---@class LegacyXPBarContainerMixin : Frame
---@field Bar Frame
---@field WireTextElements fun(self)

---@class FlatXPBarContainerMixin : Frame
---@field Bar Frame
---@field WireTextElements fun(self)
---@field SaveStoredPosition fun(self)

---@class VerticalXPBarContainerMixin : Frame
---@field Bar Frame
---@field WireTextElements fun(self)

---@class CircularXPBarContainerMixin : Frame
---@field Bar Frame
---@field WireTextElements fun(self)


---@class _G
---@field FlatXPBar Frame
---@field LegacyXPBar Frame
---@field MainStatusTrackingBarContainer Frame
_G = _G or {}
_G.XPBarTooltip = _G.XPBarTooltip or nil

-- Expose XML-created global frames on _G to satisfy analyzer
_G.FlatXPBar = _G.FlatXPBar or nil
_G.LegacyXPBar = _G.LegacyXPBar or nil
_G.MainStatusTrackingBarContainer = _G.MainStatusTrackingBarContainer or nil
