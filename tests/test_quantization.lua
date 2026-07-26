package.path = "./?.lua;" .. package.path

local TextureMapUtils = require("src.TextureMapUtils")

assert(app and app.pixelColor, "Run this test with Aseprite")

---@diagnostic disable-next-line: param-type-mismatch
local source_image = Image(4, 1, ColorMode.RGB)
source_image:drawPixel(0, 0, app.pixelColor.rgba(0, 63, 127, 17))
source_image:drawPixel(1, 0, app.pixelColor.rgba(64, 128, 192, 64))
source_image:drawPixel(2, 0, app.pixelColor.rgba(129, 200, 254, 128))
source_image:drawPixel(3, 0, app.pixelColor.rgba(255, 10, 100, 255))

local four_level_image = TextureMapUtils.quantize_image(source_image, 4)
local allowed_four_level_values = {
	[0] = true,
	[85] = true,
	[170] = true,
	[255] = true,
}
---@type table<integer, boolean>
local red_values = {}
---@type table<integer, boolean>
local green_values = {}
---@type table<integer, boolean>
local blue_values = {}

for x = 0, source_image.width - 1 do
	local source_pixel = source_image:getPixel(x, 0)
	local quantized_pixel = four_level_image:getPixel(x, 0)
	local quantized_red = app.pixelColor.rgbaR(quantized_pixel)
	local quantized_green = app.pixelColor.rgbaG(quantized_pixel)
	local quantized_blue = app.pixelColor.rgbaB(quantized_pixel)

	assert(allowed_four_level_values[quantized_red], "Quantized red values should use one of four levels")
	assert(allowed_four_level_values[quantized_green], "Quantized green values should use one of four levels")
	assert(allowed_four_level_values[quantized_blue], "Quantized blue values should use one of four levels")
	assert(
		app.pixelColor.rgbaA(quantized_pixel) == app.pixelColor.rgbaA(source_pixel),
		"RGB quantization should preserve alpha"
	)

	red_values[quantized_red] = true
	green_values[quantized_green] = true
	blue_values[quantized_blue] = true
end

---@param values table<integer, boolean> The unique channel values to count
---@return integer count The number of unique values
local function unique_value_count(values)
	local count = 0
	for _ in pairs(values) do
		count = count + 1
	end
	return count
end

assert(unique_value_count(red_values) <= 4, "The red channel should not exceed the requested level count")
assert(unique_value_count(green_values) <= 4, "The green channel should not exceed the requested level count")
assert(unique_value_count(blue_values) <= 4, "The blue channel should not exceed the requested level count")
assert(
	app.pixelColor.rgbaG(source_image:getPixel(0, 0)) == 63,
	"Quantization should not mutate its source image"
)

local full_precision_image = TextureMapUtils.quantize_image(source_image, 256)
assert(full_precision_image:isEqual(source_image), "Using 256 levels should preserve every RGB value")

local one_level_image = TextureMapUtils.quantize_image(source_image, 1)
for x = 0, one_level_image.width - 1 do
	local pixel = one_level_image:getPixel(x, 0)
	assert(
		app.pixelColor.rgbaR(pixel) == 128
			and app.pixelColor.rgbaG(pixel) == 128
			and app.pixelColor.rgbaB(pixel) == 128,
		"One-level quantization should use one neutral RGB value"
	)
end

assert(
	not TextureMapUtils.valid_color_value_levels(2.5, 256),
	"Color Value Levels should require a whole number"
)

print("Texture-map quantization tests passed")
