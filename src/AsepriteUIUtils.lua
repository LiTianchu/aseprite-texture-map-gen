---@class AsepriteUIUtils
local AsepriteUIUtils = {}

---@param title string The title of the alert
---@param text string The text to display in the alert
function AsepriteUIUtils.show_alert(title, text)
	app.alert({
		title = title,
		text = text,
	})
end

return AsepriteUIUtils
