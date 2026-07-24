local HeightMapGenerator = require("src.HeightMapGenerator")
local NormalMapGenerator = require("src.NormalMapGenerator")

---@param plugin Plugin
function init(plugin)
	plugin:newMenuGroup({
		id = "texture_gen_menu",
		title = "Texture Map Generator",
		group = "edit_fx",
	})
	plugin:newCommand({
		id = "generate_height_map",
		title = "Generate Height Map",
		group = "texture_gen_menu",
		onclick = function()
			HeightMapGenerator:show_dialog(plugin)
		end,
		onenabled = function()
			return true
		end,
	})
	plugin:newCommand({
		id = "generate_normal_map",
		title = "Generate Normal Map",
		group = "texture_gen_menu",
		onclick = function()
			NormalMapGenerator:show_dialog(plugin)
		end,
		onenabled = function()
			return app.sprite ~= nil
		end,
	})
end
