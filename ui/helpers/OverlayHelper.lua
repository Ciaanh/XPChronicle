local Addon = XPBarEnhanced
Addon.UI = Addon.UI or {}
Addon.UI.Helpers = Addon.UI.Helpers or {}

local OverlayHelper = {}
Addon.UI.Helpers.OverlayHelper = OverlayHelper

-- Return a textual summary for quest completion overlays (delegates to TextFormatter)
function OverlayHelper:GetQuestSummaryText(completeXP, incompleteXP, totalXP, maxXP, restedXP, decimals)
    local tf = Addon.TextFormatter
    if tf and tf.GetQuestSummaryText then
        return tf:GetQuestSummaryText(completeXP, incompleteXP, totalXP, maxXP, restedXP, decimals)
    end
    return ""
end

_G.OverlayHelper = OverlayHelper
return OverlayHelper
