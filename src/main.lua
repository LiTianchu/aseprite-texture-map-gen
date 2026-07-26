local HeightMapGenerator = require("src.HeightMapGenerator")
local NormalMapGenerator = require("src.NormalMapGenerator")

---@return boolean is_enabled Whether a sprite is open for texture-map generation
local function is_texture_map_generation_enabled()
	return app.sprite ~= nil
end

---@param plugin Plugin The Aseprite plugin instance
---@return nil
function init(plugin)
	plugin:newMenuGroup({
		id = "texture_gen_menu",
		title = "Texture Map Generator",
		group = "edit_fx",
	})
	plugin:newMenuGroup({
		id = "height_map_menu",
		title = "Height Map",
		group = "texture_gen_menu",
	})
	plugin:newCommand({
		id = "generate_height_map",
		title = "Generate Height Map (Dialog)",
		group = "height_map_menu",
		onclick = function()
			HeightMapGenerator:show_dialog(plugin)
		end,
		onenabled = is_texture_map_generation_enabled,
	})
	plugin:newCommand({
		id = "quick_generate_height_map",
		title = "Quick Generate Height Map",
		group = "height_map_menu",
		onclick = function()
			HeightMapGenerator:generate_from_preferences(plugin)
		end,
		onenabled = is_texture_map_generation_enabled,
	})
	plugin:newMenuGroup({
		id = "normal_map_menu",
		title = "Normal Map",
		group = "texture_gen_menu",
	})
	plugin:newCommand({
		id = "generate_normal_map",
		title = "Generate Normal Map (Dialog)",
		group = "normal_map_menu",
		onclick = function()
			NormalMapGenerator:show_dialog(plugin)
		end,
		onenabled = is_texture_map_generation_enabled,
	})
	plugin:newCommand({
		id = "quick_generate_normal_map",
		title = "Quick Generate Normal Map",
		group = "normal_map_menu",
		onclick = function()
			NormalMapGenerator:generate_from_preferences(plugin)
		end,
		onenabled = is_texture_map_generation_enabled,
	})
end
