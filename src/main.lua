---@param plugin Plugin
function init(plugin)
	print("Plugin initialized: " .. plugin.name)
	plugin:newCommand({
		id = "NewCommand",
		title = "My New Command",
		group = "cel_popup_properties",
		onclick = function()
			print("My New Command executed!")
		end,
		onenabled = function()
			return true
		end,
	})
end
