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

function AsepriteLayerUtils.render_layers(sprite, layers, frame_number)
	local source = Image(sprite.width, sprite.height, ColorMode.RGB)
	for _, layer in ipairs(layers) do
		local cel = layer:cel(frame_number)
		if not cel then
			return source, false, layer
		end

		source:drawImage(
			cel.image,
			cel.position,
			math.floor((cel.opacity * layer.opacity) / 255 + 0.5),
			layer.blendMode
		)
	end

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

function AsepriteLayerUtils.create_layer_for_inputs(sprite, input_layers, name, image, frame_number)
	local first_input = input_layers[1]
	if #input_layers == 1 then
		return AsepriteLayerUtils.create_layer_above(sprite, first_input, name, image, frame_number)
	end

	local common_parent = first_input.parent
	local anchor_layer = first_input
	for index = 2, #input_layers do
		local input_layer = input_layers[index]
		if input_layer.parent ~= common_parent then
			common_parent = nil
			break
		end
		if input_layer.stackIndex > anchor_layer.stackIndex then
			anchor_layer = input_layer
		end
	end

	local output_layer = sprite:newLayer()
	output_layer.name = name
	if common_parent then
		output_layer.parent = common_parent
		output_layer.stackIndex = anchor_layer.stackIndex + 1
	end
	sprite:newCel(output_layer, frame_number, image, Point(0, 0))
	return output_layer
end

local function contains_layer_recursive(layers, target)
	for _, layer in ipairs(layers) do
		if layer == target then
			return true
		end
		if layer.isGroup and contains_layer_recursive(layer.layers, target) then
			return true
		end
	end
	return false
end

function AsepriteLayerUtils.sprite_contains_layer(sprite, target)
	return sprite ~= nil and target ~= nil and contains_layer_recursive(sprite.layers, target)
end

function AsepriteLayerUtils.update_layer_image(sprite, layer, new_image, frame_number)
	if not AsepriteLayerUtils.sprite_contains_layer(sprite, layer) then
		return false
	end

	local cel = layer:cel(frame_number)
	if cel then
		cel.image = new_image
	else
		sprite:newCel(layer, frame_number, new_image, Point(0, 0))
	end
	return true
end

return AsepriteLayerUtils
