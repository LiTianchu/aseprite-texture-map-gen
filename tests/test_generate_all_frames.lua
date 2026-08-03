package.path = "./?.lua;" .. package.path

local AsepriteLayerUtils = require("src.AsepriteLayerUtils")
local NormalMapGenerator = require("src.NormalMapGenerator")
local TextureMapUtils = require("src.TextureMapUtils")

assert(app and app.pixelColor, "Run this test with Aseprite")

---@param horizontal boolean Whether the gradient should run from left to right
---@return Image image A small grayscale test image
local function gradient_image(horizontal)
	---@diagnostic disable-next-line: param-type-mismatch
	local image = Image(3, 3, ColorMode.RGB)
	local values = { 0, 128, 255 }
	for y = 0, 2 do
		for x = 0, 2 do
			local value = horizontal and values[x + 1] or values[y + 1]
			image:drawPixel(x, y, app.pixelColor.rgba(value, value, value, 255))
		end
	end
	return image
end

---@param sprite Sprite The sprite containing the source layers
---@param layers Layer[] The source layers to render
---@param frame_number integer The source frame
---@return Image image The expected quantized normal map
local function expected_normal(sprite, layers, frame_number)
	local source, _, _, has_source_cel = AsepriteLayerUtils.render_layers(sprite, layers, frame_number)
	assert(has_source_cel, "Expected at least one source cel")
	return TextureMapUtils.quantize_image(TextureMapUtils.create_normal_image(source, 1, "Convex"), 16)
end

---@diagnostic disable-next-line: param-type-mismatch
local sprite = Sprite(3, 3, ColorMode.RGB)
sprite:newEmptyFrame()
sprite:newEmptyFrame()
sprite:newEmptyFrame()

local first_input = sprite:newLayer()
first_input.name = "First"
sprite:newCel(first_input, 1, gradient_image(true), Point(0, 0))
sprite:newCel(first_input, 3, gradient_image(false), Point(0, 0))

local second_input = sprite:newLayer()
second_input.name = "Second"
sprite:newCel(second_input, 2, gradient_image(false), Point(0, 0))

local empty_input = sprite:newLayer()
empty_input.name = "Empty"

local settings = {
	selected_layers_are_input = true,
	separate_layers = true,
	input_layer = "First",
	generate_all_frames = true,
	layer_shape = "Convex",
	edge_strength = 1,
	max_color_value_levels = 16,
}

NormalMapGenerator.pref = {}
NormalMapGenerator.sprite = sprite
NormalMapGenerator.last_generation = nil
NormalMapGenerator.regenerate_available = false
app.layer = second_input

NormalMapGenerator:generate_new({ first_input, second_input, empty_input }, settings)

local separate_generation = assert(NormalMapGenerator.last_generation, "All-frame generation should be recorded")
assert(separate_generation.generate_all_frames, "The generation record should cover the full timeline")
assert(#separate_generation.jobs == 3, "Separate generation should retain one job per input layer")

local first_output = separate_generation.jobs[1].outputs[1].content.layer
local second_output = separate_generation.jobs[2].outputs[1].content.layer
local empty_output = separate_generation.jobs[3].outputs[1].content.layer

assert(first_output:cel(1).image:isEqual(expected_normal(sprite, { first_input }, 1)))
assert(first_output:cel(2) == nil, "A missing source cel should leave the corresponding output cel empty")
assert(first_output:cel(3).image:isEqual(expected_normal(sprite, { first_input }, 3)))
assert(first_output:cel(4) == nil, "An unused trailing frame should remain empty")

assert(second_output:cel(1) == nil, "Generation should not fill frames before the source cel")
assert(second_output:cel(2).image:isEqual(expected_normal(sprite, { second_input }, 2)))
assert(second_output:cel(3) == nil and second_output:cel(4) == nil)
for frame_number = 1, 4 do
	assert(empty_output:cel(frame_number) == nil, "An entirely empty input layer should produce an empty output layer")
end

settings.separate_layers = false
app.layer = first_input
NormalMapGenerator:generate_new({ first_input, second_input }, settings)

local combined_generation = assert(NormalMapGenerator.last_generation)
assert(#combined_generation.jobs == 1, "Combined generation should retain one layer job")
local combined_output = combined_generation.jobs[1].outputs[1].content.layer
for frame_number = 1, 3 do
	assert(
		combined_output:cel(frame_number).image:isEqual(
			expected_normal(sprite, { first_input, second_input }, frame_number)
		),
		"A combined output should use whichever selected inputs have cels in each frame"
	)
end
assert(combined_output:cel(4) == nil, "A combined output should remain empty when every input is empty")

-- Regeneration should follow new and removed source cels across the full timeline.
sprite:deleteCel(first_input:cel(3))
sprite:newCel(first_input, 4, gradient_image(true), Point(0, 0))
NormalMapGenerator.dialog_box = {
	data = {
		selected_layers_are_input = true,
		separate_layers = false,
		input_layer = "First",
		generate_all_frames = true,
		layer_shape = "Convex",
		edge_strength = 1,
		normal_max_color_value_levels = 16,
	},
	modify = function() end,
}
NormalMapGenerator:regenerate_last()

assert(combined_output:cel(3) == nil, "Regeneration should remove output where all source cels were removed")
assert(
	combined_output:cel(4).image:isEqual(expected_normal(sprite, { first_input, second_input }, 4)),
	"Regeneration should create output for a newly populated source frame"
)

print("All-frame generation tests passed")
