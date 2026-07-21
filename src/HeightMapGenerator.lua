local HeightMapGenerator = {}

---@param plugin Plugin
function HeightMapGenerator:show_dialog(plugin)
	HeightMapGenerator.pref = plugin.preferences

	local use_selected_layers = HeightMapGenerator.pref.use_selected_layers == nil and true
		or HeightMapGenerator.pref.use_selected_layers

	HeightMapGenerator.dialog_box = Dialog({
		title = "Generate Height Map",
		onclose = function()
			HeightMapGenerator.pref.input_layer = HeightMapGenerator.dialog_box.data.input_layer_entry
			HeightMapGenerator.pref.use_selected_layers = HeightMapGenerator.dialog_box.data.use_selected_layers_check
		end,
	})

	HeightMapGenerator.dialog_box
		:separator({ id = "separator_1", text = "Layers" })
		:check({
			id = "use_selected_layers_check",
			label = "Use Selected Layers as Input",
			selected = use_selected_layers,
			onclick = function() end,
		})
		:entry({
			id = "input_layer_entry",
			label = "Input Layer",
			text = HeightMapGenerator.pref.input_layer or "Input Layer Name",
			enabled = not use_selected_layers,
		})
		:button({
			id = "gen_height_map_btn",
			text = "Start Generate!",
			onclick = function()
				HeightMapGenerator:generate_height_map()
			end,
		})

	local window_bounds = Rectangle(100, 100, 300, 200)
	HeightMapGenerator.dialog_box:show({
		wait = false,
		bounds = window_bounds,
	})
end

function HeightMapGenerator:generate_height_map()
	print("Generating Height Map...")
	local layers = app.range.layers
	print("Layers: ", #layers)
	for i,v in ipairs(layers) do
		print(i, v)
	end
end

return HeightMapGenerator
