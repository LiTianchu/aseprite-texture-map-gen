local AsepriteLayerUtils = {}

local function is_image_layer(layer)
	return layer.isImage and not layer.isTilemap and not layer.isReference
end

local function append_image_layers(layers, output)
	for _, layer in ipairs(layers) do
		if layer.isGroup then
			append_image_layers(layer.layers, output)
		elseif is_image_layer(layer) then
			output[#output + 1] = layer
		end
	end
end

function AsepriteLayerUtils.contains_layer(layers, target)
	for _, layer in ipairs(layers) do
		if layer == target then
			return true
		end
	end
	return false
end

local function add_layer_and_children(layer, selected)
	if layer.isGroup then
		for _, child in ipairs(layer.layers) do
			add_layer_and_children(child, selected)
		end
	elseif is_image_layer(layer) and not AsepriteLayerUtils.contains_layer(selected, layer) then
		selected[#selected + 1] = layer
	end
end

function AsepriteLayerUtils.ordered_image_layers(sprite, selected_layers)
	local selected = {}
	for _, layer in ipairs(selected_layers) do
		add_layer_and_children(layer, selected)
	end

	local all_layers = {}
	append_image_layers(sprite.layers, all_layers)

	local result = {}
	for _, layer in ipairs(all_layers) do
		if AsepriteLayerUtils.contains_layer(selected, layer) then
			result[#result + 1] = layer
		end
	end
	return result
end

local function append_layer_options(layers, prefix, options, option_layers)
	for _, layer in ipairs(layers) do
		local path = prefix .. layer.name
		if layer.isGroup then
			append_layer_options(layer.layers, path .. " / ", options, option_layers)
		elseif is_image_layer(layer) then
			local option = path
			local suffix = 2
			while option_layers[option] do
				option = path .. " (" .. suffix .. ")"
				suffix = suffix + 1
			end

			options[#options + 1] = option
			option_layers[option] = layer
		end
	end
end

function AsepriteLayerUtils.layer_options(sprite)
	local options = {}
	local option_layers = {}
	append_layer_options(sprite.layers, "", options, option_layers)
	return options, option_layers
end

function AsepriteLayerUtils.render_layer(sprite, layer, frame_number)
	local source = Image(sprite.width, sprite.height, ColorMode.RGB)
	local cel = layer:cel(frame_number)
	if not cel then
		return source, false
	end

	source:drawImage(cel.image, cel.position, math.floor((cel.opacity * layer.opacity) / 255 + 0.5), layer.blendMode)
	return source, true
end

function AsepriteLayerUtils.selected_option(options, option_layers, preferred_option, active_layer)
	if preferred_option and option_layers[preferred_option] then
		return preferred_option
	end

	if active_layer then
		for _, option in ipairs(options) do
			if option_layers[option] == active_layer then
				return option
			end
		end
	end

	return options[1]
end

function AsepriteLayerUtils.selected_layers(range, active_layer)
	local layers = range and range.layers or {}
	if #layers > 0 then
		return layers
	end

	-- when there is no explicit range selected in the timeline.
	return active_layer and { active_layer } or {}
end

function AsepriteLayerUtils.create_layer_above(sprite, input_layer, name, image, frame_number)
	local output_layer = sprite:newLayer()
	output_layer.name = name
	output_layer.parent = input_layer.parent
	output_layer.stackIndex = input_layer.stackIndex + 1
	sprite:newCel(output_layer, frame_number, image, Point(0, 0))
	return output_layer
end

return AsepriteLayerUtils
