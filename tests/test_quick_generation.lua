package.path = "./?.lua;" .. package.path

local HeightMapGenerator = require("src.HeightMapGenerator")
local NormalMapGenerator = require("src.NormalMapGenerator")
local TextureMapUtils = require("src.TextureMapUtils")

assert(app and app.pixelColor, "Run this test with Aseprite")

---@param values integer[] The grayscale values to write from left to right, top to bottom
---@return Image image The resulting RGB image
local function grayscale_image(values)
	---@diagnostic disable-next-line: param-type-mismatch
	local image = Image(3, 3, ColorMode.RGB)
	for index, value in ipairs(values) do
		local x = (index - 1) % 3
		local y = math.floor((index - 1) / 3)
		image:drawPixel(x, y, app.pixelColor.rgba(value, value, value, 255))
	end
	return image
end

---@param sprite Sprite The sprite containing the layer
---@param name string The exact layer name to find
---@return Layer|nil layer The matching layer, or nil when it does not exist
local function find_layer_by_name(sprite, name)
	for _, layer in ipairs(sprite.layers) do
		if layer.name == name then
			return layer
		end
	end
	return nil
end

local source_image = grayscale_image({
	0,
	128,
	255,
	0,
	128,
	255,
	0,
	128,
	255,
})
---@diagnostic disable-next-line: param-type-mismatch
local sprite = Sprite(3, 3, ColorMode.RGB)
local input_layer = sprite:newLayer()
input_layer.name = "Input"
sprite:newCel(input_layer, 1, source_image, Point(0, 0))
app.layer = input_layer

---@type table
local preferences = {
	selected_layers_are_input = false,
	separate_layers = true,
	input_layer = "Input",
	edge_strength = 2,
	layer_shape = "Concave",
	normal_max_color_value_levels = 32,
	input_type = "Color",
	height_dump_intermediate_normal_map = true,
	height_layer_shape = "Concave",
	height_edge_strength = 3,
	height_max_iteration_count = 8,
	height_max_color_value_levels = 32,
}

---@diagnostic disable-next-line: missing-fields
local plugin = {
	preferences = preferences,
}

local original_dialog_constructor = Dialog
---@type boolean
local dialog_was_opened = false

---@return nil
Dialog = function()
	dialog_was_opened = true
	error("Quick generation must not construct a dialog")
end

---@diagnostic disable-next-line: param-type-mismatch
NormalMapGenerator:generate_from_preferences(plugin)

local normal_output_layer = find_layer_by_name(sprite, "Input_normal")
assert(normal_output_layer, "Quick normal-map generation should create an output layer")
local expected_normal_image = TextureMapUtils.create_normal_image(source_image, 2, "Concave")
assert(
	normal_output_layer:cel(1).image:isEqual(expected_normal_image),
	"Quick normal-map generation should use the saved edge intensity and object shape"
)
assert(app.layer == normal_output_layer, "Quick normal-map generation should activate its output")

app.layer = input_layer

---@diagnostic disable-next-line: param-type-mismatch
HeightMapGenerator:generate_from_preferences(plugin)

local height_output_layer = find_layer_by_name(sprite, "Input_height")
assert(height_output_layer, "Quick height-map generation should create an output layer")
local expected_height_normal_image = TextureMapUtils.create_normal_image(source_image, 3, "Concave")
local expected_height_image = TextureMapUtils.create_height_image(expected_height_normal_image, 1, 8)
assert(
	height_output_layer:cel(1).image:isEqual(expected_height_image),
	"Quick height-map generation should use the saved input type, shape, intensity, and iteration count"
)
assert(
	height_output_layer.stackIndex == input_layer.stackIndex + 2,
	"Quick height-map generation should honor the saved intermediate-output setting"
)
assert(app.layer == height_output_layer, "Quick height-map generation should activate its primary output")
assert(not dialog_was_opened, "Quick texture-map generation should not open either settings dialog")

Dialog = original_dialog_constructor

print("Quick generation tests passed")
