package.path = "./?.lua;" .. package.path

-- Test for Height map reconstruction from slope
local TextureMapUtils = require("src.TextureMapUtils")

local function approx_equal(actual, expected, message)
	assert(math.abs(actual - expected) < 0.000001, message)
end

local flat_slopes = {
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
	0,
}
local flat_heights = TextureMapUtils.slope_extract_height(flat_slopes, flat_slopes, 3, 3, 16)
for _, height in ipairs(flat_heights) do
	approx_equal(height, 0.5, "A flat normal field should produce neutral height")
end

local horizontal_slopes = {
	0.3,
	0.3,
	0.3,
}
local zero_slopes = {
	0,
	0,
	0,
}
local horizontal_heights = TextureMapUtils.slope_extract_height(horizontal_slopes, zero_slopes, 3, 1, 64)
local one_iteration_heights = TextureMapUtils.slope_extract_height(horizontal_slopes, zero_slopes, 3, 1, 1)
assert(
	horizontal_heights[1] < horizontal_heights[2] and horizontal_heights[2] < horizontal_heights[3],
	"A positive X slope should reconstruct a height field rising to the right"
)
assert(
	horizontal_heights[3] - horizontal_heights[1] > one_iteration_heights[3] - one_iteration_heights[1],
	"Additional slope iterations should continue converging the reconstructed height range"
)
approx_equal(
	(horizontal_heights[1] + horizontal_heights[2] + horizontal_heights[3]) / 3,
	0.5,
	"Slope extraction should keep the undetermined average height at neutral gray"
)

local vertical_heights = TextureMapUtils.slope_extract_height(zero_slopes, horizontal_slopes, 1, 3, 64)
assert(
	vertical_heights[1] < vertical_heights[2] and vertical_heights[2] < vertical_heights[3],
	"A positive Y slope should reconstruct a height field rising downward"
)

local masked_heights =
	TextureMapUtils.slope_extract_height(horizontal_slopes, zero_slopes, 3, 1, 64, { true, false, true })
for _, height in ipairs(masked_heights) do
	approx_equal(height, 0.5, "Disconnected or transparent pixels should not leak height")
end

print("Height map slope extraction tests passed")
