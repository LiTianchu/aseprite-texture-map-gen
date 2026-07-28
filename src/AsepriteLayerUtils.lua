---@class AsepriteLayerUtils
local AsepriteLayerUtils = {}

---@param layer Layer The Aseprite layer to check
---@return boolean # true if the layer is an image layer, false otherwise
local function is_image_layer(layer)
	return layer.isImage and not layer.isTilemap and not layer.isReference
end

---@param layers Layer[] The Aseprite layers to process
---@param output Layer[] The Aseprite image layers to append to
local function append_image_layers(layers, output)
	for _, layer in ipairs(layers) do
		if layer.isGroup then
			-- recursively append image layers from groups
			append_image_layers(layer.layers, output)
		elseif is_image_layer(layer) then
			output[#output + 1] = layer -- append
		end
	end
end

---@private
---@param layers Layer[] The Aseprite layers that may contain the target layer
---@param target Layer The Aseprite layer to check for containment
---@return boolean # true if the target layer is contained in the layers, false otherwise
function AsepriteLayerUtils.contains_layer(layers, target)
	for _, layer in ipairs(layers) do
		if layer == target then
			return true
		end
	end
	return false
end

---@param layer Layer The Aseprite layer pending to be added
---@param selected Layer[] The Aseprite layer container to append the layer to
local function add_layer_and_children(layer, selected)
	if layer.isGroup then
		for _, child in ipairs(layer.layers) do
			add_layer_and_children(child, selected)
		end
	elseif is_image_layer(layer) and not AsepriteLayerUtils.contains_layer(selected, layer) then
		selected[#selected + 1] = layer
	end
end

---@param sprite Sprite The Aseprite sprite document to process
---@param selected_layers Layer[] The Aseprite layers to order
---@return Layer[] ordered_layers # The ordered list of Aseprite image layers in the order recorded in the sprite document
function AsepriteLayerUtils.ordered_image_layers(sprite, selected_layers)
	-- get all selected image layers
	local selected = {}
	for _, layer in ipairs(selected_layers) do
		add_layer_and_children(layer, selected)
	end

	-- get all image layers in the sprite document
	local all_layers = {}
	append_image_layers(sprite.layers, all_layers)

	local result = {}
	for _, layer in ipairs(all_layers) do -- for every layer in the sprite document
		-- filter out the layers that are not selected
		if AsepriteLayerUtils.contains_layer(selected, layer) then
			result[#result + 1] = layer
		end
	end
	return result
end

---@private
---@param layers Layer[] The aseprite layers to process
---@param prefix string The aseprite layer path prefix, e.g. "Group / Subgroup / "
---@param layer_paths string[] Accumulator for the unique image-layer paths
---@param layer_path_dict table<string, Layer> Accumulator mapping unique layer paths to their image layers
local function append_layer_paths(layers, prefix, layer_paths, layer_path_dict)
	for _, layer in ipairs(layers) do
		local path = prefix .. layer.name
		if layer.isGroup then
			append_layer_paths(layer.layers, path .. " / ", layer_paths, layer_path_dict)
		elseif is_image_layer(layer) then
			local layer_path = path
			local suffix = 2
			while layer_path_dict[layer_path] do
				layer_path = path .. " (" .. suffix .. ")"
				suffix = suffix + 1
			end

			layer_paths[#layer_paths + 1] = layer_path
			layer_path_dict[layer_path] = layer
		end
	end
end

---@param sprite Sprite The Aseprite sprite document from which to extract image-layer paths
---@return string[] layer_paths # The unique image-layer paths, e.g. "Group / Subgroup / Layer"
---@return table<string, Layer> layer_path_dict # A mapping of unique layer paths to their corresponding image layers
function AsepriteLayerUtils.layer_paths(sprite)
	local layer_paths = {}
	local layer_path_dict = {}
	append_layer_paths(sprite.layers, "", layer_paths, layer_path_dict)
	return layer_paths, layer_path_dict
end

---Composite the layers frame_number N onto a new image using the dimension of a reference sprite
---@param ref_sprite Sprite The Aseprite sprite document used as a reference for render output dimensions
---@param layers Layer[] The Aseprite layers to draw onto the sprite document
---@param frame_number integer The Aseprite frame number selected from the layers
---@return Image composite_image # The new image with the layers composited onto it
---@return boolean cell_valid_for_all_layers # true if all layers have a cel at the frame_number, false otherwise
---@return Layer[] missing_layers # The layers that does not have a cel at the frame_number
function AsepriteLayerUtils.render_layers(ref_sprite, layers, frame_number)
	---@diagnostic disable-next-line: param-type-mismatch
	local source = Image(ref_sprite.width, ref_sprite.height, ColorMode.RGB)
	local cell_valid_for_all_layers = true
	local missing_layers = {}
	for _, layer in ipairs(layers) do
		local cel = layer:cel(frame_number)
		if not cel then
			cell_valid_for_all_layers = false
			missing_layers[#missing_layers + 1] = layer
			-- return source, false, layer
		else
			-- render the cel image onto the source image
			source:drawImage(
				cel.image,
				cel.position,
				math.floor((cel.opacity * layer.opacity) / 255 + 0.5),
				layer.blendMode
			)
		end
	end

	return source, cell_valid_for_all_layers, missing_layers
end

---@param layer_paths string[] The unique image-layer paths, e.g. "Group / Subgroup / Layer"
---@param layer_path_dict table<string, Layer> A mapping of unique layer paths to their corresponding image layers
---@param preferred_layer_path string|nil The preferred layer path, if it still identifies an image layer
---@param active_layer Layer|nil The active timeline layer, used when the preferred path is unavailable
---@return string layer_path # The preferred path, the active layer's path, or the first available path
function AsepriteLayerUtils.selected_layer_path(layer_paths, layer_path_dict, preferred_layer_path, active_layer)
	if preferred_layer_path and layer_path_dict[preferred_layer_path] then
		return preferred_layer_path
	end

	if active_layer then
		for _, layer_path in ipairs(layer_paths) do
			if layer_path_dict[layer_path] == active_layer then
				return layer_path
			end
		end
	end

	return layer_paths[1]
end

--- Extracts the selected layers from the Aseprite range object
---@param range Range The Aseprite range object, which may contain a list of selected layers
---@param active_layer Layer The Aseprite layer corresponding to the active layer in the timeline, fallback to this layer if the range does not contain any selected layers
---@return Layer[] layers # The list of selected layers, or the active layer if no layers are
function AsepriteLayerUtils.selected_layers(range, active_layer)
	local layers = range and range.layers or {}
	if #layers > 0 then
		return layers
	end

	-- when there is no explicit range selected in the timeline.
	return active_layer and { active_layer } or {}
end

---@param sprite Sprite The Aseprite sprite document to create the layer in
---@param input_layer Layer The Aseprite layer to create the new layer above
---@param name string The name of the new layer
---@param image Image The image to assign to the new layer's cel
---@param frame_number integer The frame number to assign the new layer's cel to
---@return Layer new_layer # The newly created Aseprite layer in the sprite document
function AsepriteLayerUtils.create_layer_above(sprite, input_layer, name, image, frame_number)
	local output_layer = sprite:newLayer()
	output_layer.name = name
	output_layer.parent = input_layer.parent
	output_layer.stackIndex = input_layer.stackIndex + 1
	sprite:newCel(output_layer, frame_number, image, Point(0, 0))
	return output_layer
end

---Create a new layer in the sprite document above the input layers, if they share a common parent, otherwise create a new layer at the top of the sprite document
---@param sprite Sprite The Aseprite sprite document to create the layer in
---@param input_layers Layer[] The Aseprite layers used as reference to create the new layer above
---@param name string The name of the new layer
---@param image Image The image to assign to the new layer's cel
---@param frame_number integer The frame number to assign the new layer's cel to
---@return Layer new_layer # The newly created Aseprite layer in the sprite document
function AsepriteLayerUtils.create_layer_for_inputs(sprite, input_layers, name, image, frame_number)
	local first_input = input_layers[1]
	if #input_layers == 1 then
		return AsepriteLayerUtils.create_layer_above(sprite, first_input, name, image, frame_number)
	end

	---@type Layer|Sprite|nil
	local common_parent = first_input.parent

	local anchor_layer = first_input

	-- find the last layer in the input layers that shares the same parent
	-- to use as the anchor for the new layer
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

---Check if the layers or any of their subgroups contain the target layer
---@param layers Layer[] The Aseprite layers that may contain the target layer
---@param target Layer The Aseprite layer to check for containment
---@return boolean # true if the target layer is contained in the layers or the subgroups, false otherwise
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

---Check if the sprite contains the target layer, including subgroups
---@param sprite Sprite The Aseprite sprite document to check for the target layer
---@param target Layer The Aseprite layer to check for containment in the sprite document
---@return boolean # true if the target layer is contained in the sprite document, false otherwise
function AsepriteLayerUtils.sprite_contains_layer(sprite, target)
	return sprite ~= nil and target ~= nil and contains_layer_recursive(sprite.layers, target)
end

---Update the image of a layer's cel at a specific frame number, creating a new cel if the specified cell doesn't exist at the frame number
---@param sprite Sprite The Aseprite sprite document to update the layer in
---@param layer Layer The Aseprite layer to update
---@param new_image Image The new image to assign to the layer's cel
---@param frame_number integer The selected frame number for the layer's cel
---@return boolean succeeded # true if the layer's cel was updated or created, false if the layer does not exist in the sprite
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
