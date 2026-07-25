package.path = "./?.lua;" .. package.path

-- This test should be checked using Asperite's Lua runtime for safety and compatibility
-- To use Aseprite's Lua runtine, it requires Aseprite to be installed:
-- To run:
-- "your_path_to_aseprite_binary" -b --script tests/test_height_map_regenerate.lua

local AsepriteLayerUtils = require("src.AsepriteLayerUtils")
local HeightMapGenerator = require("src.HeightMapGenerator")
local TextureMapUtils = require("src.TextureMapUtils")

assert(app and app.pixelColor, "Run this test with Aseprite")

local function grayscale_image(values)
	local image = Image(3, 3, ColorMode.RGB)
	for index, value in ipairs(values) do
		local x = (index - 1) % 3
		local y = math.floor((index - 1) / 3)
		image:drawPixel(x, y, app.pixelColor.rgba(value, value, value, 255))
	end
	return image
end

local horizontal_gradient = {
	0,
	128,
	255,
	0,
	128,
	255,
	0,
	128,
	255,
}
local vertical_gradient = {
	0,
	0,
	0,
	128,
	128,
	128,
	255,
	255,
	255,
}

local horizontal_color = grayscale_image(horizontal_gradient)
local vertical_color = grayscale_image(vertical_gradient)
local horizontal_normal = TextureMapUtils.create_normal_image(horizontal_color, 1, "Convex")
local vertical_normal = TextureMapUtils.create_normal_image(vertical_color, 1, "Convex")

local sprite = Sprite(3, 3, ColorMode.RGB)
local bottom_input = sprite:newLayer()
bottom_input.name = "Bottom"
sprite:newCel(bottom_input, 1, horizontal_normal, Point(0, 0))

local top_input = sprite:newLayer()
top_input.name = "Top"
sprite:newCel(top_input, 1, vertical_normal, Point(0, 0))

local dialog = {
	data = {
		selected_layers_are_input = true,
		separate_layers = true,
		input_layer = "Bottom",
		height_input_type = "Normal Map",
		dump_intermediate_normal_map = false,
		layer_shape = "Convex",
		edge_strength = 1,
		iteration_count = 64,
	},
	modifications = {},
}

function dialog:modify(options)
	self.modifications[options.id] = options
end

HeightMapGenerator.pref = {}
HeightMapGenerator.sprite = sprite
HeightMapGenerator.option_layers = {
	Bottom = bottom_input,
	Top = top_input,
}
HeightMapGenerator.dialog_box = dialog
HeightMapGenerator.last_generation = nil
HeightMapGenerator.regenerate_available = false

app.layer = top_input
app.range.layers = { bottom_input, top_input }
HeightMapGenerator:generate_from_dialog()

local separate_generation = HeightMapGenerator.last_generation
assert(separate_generation, "Generate New should record height-map regeneration state")
assert(#separate_generation.jobs == 2, "Separate generation should create one job per normal input")
assert(
	separate_generation.jobs[1].outputs[1].layer.name == "Bottom_height",
	"The lower separate output should retain its source name"
)
assert(
	separate_generation.jobs[2].outputs[1].layer.name == "Top_height",
	"The upper separate output should retain its source name"
)
assert(#separate_generation.jobs[1].outputs == 1, "Normal-map input should not create an intermediate normal output")

local bottom_height = separate_generation.jobs[1].outputs[1].layer
local top_height = separate_generation.jobs[2].outputs[1].layer
local expected_bottom = TextureMapUtils.create_height_image(horizontal_normal, 1, 64)
local expected_top = TextureMapUtils.create_height_image(vertical_normal, 1, 64)
assert(bottom_height:cel(1).image:isEqual(expected_bottom), "The lower normal should produce its expected height")
assert(top_height:cel(1).image:isEqual(expected_top), "The upper normal should produce its expected height")
assert(
	app.pixelColor.rgbaR(bottom_height:cel(1).image:getPixel(0, 1))
		< app.pixelColor.rgbaR(bottom_height:cel(1).image:getPixel(2, 1)),
	"A generated convex X gradient should rise from left to right"
)
assert(
	app.pixelColor.rgbaR(top_height:cel(1).image:getPixel(1, 0))
		< app.pixelColor.rgbaR(top_height:cel(1).image:getPixel(1, 2)),
	"A generated convex Y gradient should rise from top to bottom"
)

dialog.data.edge_strength = 0
local flat_bottom = TextureMapUtils.create_height_image(horizontal_normal, 0, 64)
local flat_top = TextureMapUtils.create_height_image(vertical_normal, 0, 64)
HeightMapGenerator:regenerate_last()
assert(
	bottom_height:cel(1).image:isEqual(flat_bottom),
	"Regenerate should apply the current edge intensity to the lower output"
)
assert(
	top_height:cel(1).image:isEqual(flat_top),
	"Regenerate should apply the current edge intensity to the upper output"
)
assert(HeightMapGenerator.pref.height_edge_strength == 0, "Regenerate should persist Edge Intensity")

dialog.data.selected_layers_are_input = false
dialog.data.input_layer = "Bottom"
dialog.data.edge_strength = 1
HeightMapGenerator:generate_from_dialog()
local single_generation = HeightMapGenerator.last_generation
assert(#single_generation.jobs == 1, "Single-layer mode should generate one height output")
assert(
	single_generation.jobs[1].input_layers[1] == bottom_input,
	"Single-layer mode should use the layer selected in the combobox"
)
assert(single_generation.jobs[1].outputs[1].layer.name == "Bottom_height", "Single-layer output should be named")

bottom_input:cel(1).image = horizontal_color
top_input:cel(1).image = vertical_color
dialog.data.selected_layers_are_input = true
dialog.data.separate_layers = false
dialog.data.height_input_type = "Color"
dialog.data.dump_intermediate_normal_map = true
dialog.data.layer_shape = "Convex"
dialog.data.edge_strength = 1
dialog.data.iteration_count = 32
app.layer = top_input
app.range.layers = { bottom_input, top_input }

local combined_source, has_combined_cels = AsepriteLayerUtils.render_layers(sprite, { bottom_input, top_input }, 1)
assert(has_combined_cels, "The combined color inputs should both contain cels")
local expected_combined_normal = TextureMapUtils.create_normal_image(combined_source, 1, "Convex")
local expected_combined_height = TextureMapUtils.create_height_image(expected_combined_normal, 1, 32)

HeightMapGenerator:generate_from_dialog()
local combined_generation = HeightMapGenerator.last_generation
assert(#combined_generation.jobs == 1, "Merged generation should record one height job")
assert(#combined_generation.jobs[1].input_layers == 2, "Merged generation should retain both color inputs")
assert(#combined_generation.jobs[1].outputs == 2, "Keeping the intermediate should record both outputs")

local combined_height = combined_generation.jobs[1].outputs[1].layer
local combined_normal = combined_generation.jobs[1].outputs[2].layer
assert(combined_height.name == "Combined_height", "Merged height output should be clearly named")
assert(combined_normal.name == "Combined_normal", "Merged intermediate normal should be clearly named")
assert(
	combined_normal.stackIndex + 1 == combined_height.stackIndex,
	"The intermediate normal should be inserted between the inputs and height output"
)
assert(
	combined_normal:cel(1).image:isEqual(expected_combined_normal),
	"The kept intermediate should match the normal used by slope extraction"
)
assert(
	combined_height:cel(1).image:isEqual(expected_combined_height),
	"The merged height should be extracted from the generated intermediate normal"
)
assert(app.layer == combined_height, "The height result should become active instead of its intermediate")

dialog.data.layer_shape = "Concave"
dialog.data.edge_strength = 2
dialog.data.iteration_count = 16
local regenerated_normal = TextureMapUtils.create_normal_image(combined_source, 2, "Concave")
local regenerated_height = TextureMapUtils.create_height_image(regenerated_normal, 1, 16)
HeightMapGenerator:regenerate_last()
assert(
	combined_normal:cel(1).image:isEqual(regenerated_normal),
	"Regenerate should update a dumped intermediate normal"
)
assert(
	combined_height:cel(1).image:isEqual(regenerated_height),
	"Regenerate should update height from the new intermediate settings"
)
assert(
	HeightMapGenerator.pref.height_iteration_count == 16,
	"Regenerate should persist the current slope iteration count"
)

local surviving_height = combined_height:cel(1).image:clone()
sprite:deleteLayer(combined_normal)
HeightMapGenerator:regenerate_last()
assert(
	HeightMapGenerator.last_generation == nil,
	"Deleting a dumped intermediate should invalidate the complete regeneration record"
)
assert(
	combined_height:cel(1).image:isEqual(surviving_height),
	"Invalid regeneration must not modify the surviving height output"
)
assert(
	dialog.modifications.regenerate_height_map.enabled == false,
	"Invalid height regeneration should disable its button"
)

print("Height map regeneration tests passed")
