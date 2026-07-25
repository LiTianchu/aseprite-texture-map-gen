package.path = "./?.lua;" .. package.path

-- This test should be checked using Asperite's Lua runtime for safety and compatibility
-- To use Aseprite's Lua runtine, it requires Aseprite to be installed:
-- To run:
-- "your_path_to_aseprite_binary" -b --script tests/test_normal_map_regenerate.lua

local AsepriteLayerUtils = require("src.AsepriteLayerUtils")
local NormalMapGenerator = require("src.NormalMapGenerator")
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

local function expected_normal(sprite, input_layers, edge_strength, layer_shape, frame_number)
	local source, has_cel = AsepriteLayerUtils.render_layers(sprite, input_layers, frame_number or 1)
	assert(has_cel, "Expected every test input to have a cel")
	return TextureMapUtils.create_normal_image(source, edge_strength, layer_shape)
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

local sprite = Sprite(3, 3, ColorMode.RGB)
local bottom_input = sprite:newLayer()
bottom_input.name = "Bottom"
sprite:newCel(bottom_input, 1, grayscale_image(horizontal_gradient), Point(0, 0))

local top_input = sprite:newLayer()
top_input.name = "Top"
sprite:newCel(top_input, 1, grayscale_image(vertical_gradient), Point(0, 0))

local dialog = {
	data = {
		selected_layers_are_input = true,
		separate_layers = true,
		input_layer = "Bottom",
		layer_shape = "Convex",
		edge_strength = 1,
	},
	modifications = {},
}

function dialog:modify(options)
	self.modifications[options.id] = options
end

NormalMapGenerator.pref = {}
NormalMapGenerator.sprite = sprite
NormalMapGenerator.option_layers = {
	Bottom = bottom_input,
	Top = top_input,
}
NormalMapGenerator.dialog_box = dialog
NormalMapGenerator.last_generation = nil
NormalMapGenerator.regenerate_available = false

app.layer = top_input
app.range.layers = { bottom_input, top_input }
NormalMapGenerator:generate_from_dialog()

local first_generation = NormalMapGenerator.last_generation
assert(first_generation, "Generate New should record regeneration state")
assert(
	first_generation.frame_anchors[1].cel == bottom_input:cel(1),
	"The original frame should be anchored by an input cel"
)
assert(#first_generation.jobs == 2, "Separate generation should record one job per input")
assert(first_generation.jobs[1].input_layers[1] == bottom_input, "The bottom input should remain paired")
assert(first_generation.jobs[2].input_layers[1] == top_input, "The top input should remain paired")

local bottom_output = first_generation.jobs[1].outputs[1].layer
local top_output = first_generation.jobs[2].outputs[1].layer
assert(bottom_output.name == "Bottom_normal", "The bottom output should keep its input name")
assert(top_output.name == "Top_normal", "The top output should keep its input name")
assert(bottom_output.stackIndex == bottom_input.stackIndex + 1, "The bottom output should be directly above its input")
assert(top_output.stackIndex == top_input.stackIndex + 1, "The top output should be directly above its input")

dialog.data.edge_strength = 2
dialog.data.layer_shape = "Concave"
local expected_bottom = expected_normal(sprite, { bottom_input }, 2, "Concave")
local expected_top = expected_normal(sprite, { top_input }, 2, "Concave")
NormalMapGenerator:regenerate_last()

assert(
	bottom_output:cel(1).image:isEqual(expected_bottom),
	"Regenerate should update the output paired with the bottom input"
)
assert(top_output:cel(1).image:isEqual(expected_top), "Regenerate should update the output paired with the top input")
assert(NormalMapGenerator.pref.edge_strength == 2, "Regenerate should use the current Edge Height")
assert(NormalMapGenerator.pref.layer_shape == "Concave", "Regenerate should use the current Object Shape")

sprite:deleteCel(bottom_output, 1)
assert(bottom_output:cel(1) == nil, "The output cel should be deleted for the recreation test")
NormalMapGenerator:regenerate_last()
assert(
	bottom_output:cel(1).image:isEqual(expected_bottom),
	"Regenerate should recreate a missing output cel through Sprite:newCel"
)

sprite:newEmptyFrame(2)
app.frame = sprite.frames[2]
dialog.data.edge_strength = 3
dialog.data.layer_shape = "Convex"
local expected_original_frame = expected_normal(sprite, { bottom_input }, 3, "Convex")
NormalMapGenerator:regenerate_last()
assert(
	bottom_output:cel(1).image:isEqual(expected_original_frame),
	"Regenerate should continue updating the originally generated frame"
)
assert(bottom_output:cel(2) == nil, "Regenerate should not create output in a newly selected frame")

sprite:newEmptyFrame(1)
assert(
	first_generation.frame_anchors[1].cel == bottom_input:cel(2),
	"The recorded cel should survive timeline insertion"
)
app.frame = sprite.frames[1]
local expected_shifted_frame = expected_normal(sprite, { bottom_input }, 3, "Convex", 2)
NormalMapGenerator:regenerate_last()
assert(
	bottom_output:cel(2).image:isEqual(expected_shifted_frame),
	"Regenerate should follow the original frame when its frame number changes"
)
assert(bottom_output:cel(1) == nil, "Regenerate should not write into the inserted frame")

local output_with_missing_cel = sprite:newLayer()
output_with_missing_cel.name = "Missing Cel"
local frame_two_image = grayscale_image(horizontal_gradient)
sprite:newCel(output_with_missing_cel, 2, frame_two_image, Point(0, 0))
local frame_one_image = grayscale_image(vertical_gradient)
assert(
	AsepriteLayerUtils.update_layer_image(sprite, output_with_missing_cel, frame_one_image, 1),
	"Updating a live output layer should succeed"
)
assert(output_with_missing_cel:cel(1), "A missing output cel should be created")
assert(output_with_missing_cel:cel(2), "Creating a missing cel should preserve other frames")

local surviving_output_before = bottom_output:cel(2).image:clone()
local unrelated_frame_one_before = output_with_missing_cel:cel(1).image:clone()
local unrelated_frame_two_before = output_with_missing_cel:cel(2).image:clone()
sprite:deleteLayer(top_output)
NormalMapGenerator:regenerate_last()

assert(
	NormalMapGenerator.last_generation == nil,
	"Deleting any one of several generated layers should invalidate regeneration"
)
assert(
	AsepriteLayerUtils.sprite_contains_layer(sprite, bottom_output),
	"Invalid regeneration must not delete a surviving generated layer"
)
assert(
	bottom_output:cel(2).image:isEqual(surviving_output_before),
	"Invalid regeneration must not modify a surviving generated layer"
)
assert(
	AsepriteLayerUtils.sprite_contains_layer(sprite, output_with_missing_cel),
	"Invalid regeneration must not delete an unrelated user layer"
)
assert(
	output_with_missing_cel:cel(1).image:isEqual(unrelated_frame_one_before)
		and output_with_missing_cel:cel(2).image:isEqual(unrelated_frame_two_before),
	"Invalid regeneration must not modify unrelated user cels"
)
assert(
	AsepriteLayerUtils.sprite_contains_layer(sprite, bottom_input)
		and AsepriteLayerUtils.sprite_contains_layer(sprite, top_input),
	"Invalid regeneration must preserve every input layer"
)

dialog.data.separate_layers = false
dialog.data.layer_shape = "Convex"
dialog.data.edge_strength = 1
app.frame = sprite.frames[first_generation.frame_anchors[1].cel.frameNumber]
app.layer = top_input
app.range.layers = { bottom_input, top_input }
NormalMapGenerator:generate_from_dialog()

local combined_generation = NormalMapGenerator.last_generation
assert(#combined_generation.jobs == 1, "Combined generation should record one regeneration job")
assert(#combined_generation.jobs[1].input_layers == 2, "The combined job should retain both inputs")
assert(
	combined_generation.jobs[1].outputs[1].layer.name == "Combined_normal",
	"Combined generation should create a clearly named output"
)

sprite:deleteLayer(combined_generation.jobs[1].outputs[1].layer)
NormalMapGenerator:regenerate_last()
assert(NormalMapGenerator.last_generation == nil, "Deleting an output layer should invalidate regeneration")
assert(
	dialog.modifications.regenerate_normal_map.enabled == false,
	"Invalid regeneration state should disable the button"
)

print("Normal map regeneration tests passed")
