package.path = "./?.lua;" .. package.path

local NormalMapGenerator = require("src.NormalMapGenerator")

local function approx_equal(actual, expected, message)
	assert(math.abs(actual - expected) < 0.000001, message)
end

local flat = {
	0.5,
	0.5,
	0.5,
	0.5,
	0.5,
	0.5,
	0.5,
	0.5,
	0.5,
}
local x, y, z = NormalMapGenerator.sobel_normal(flat, 3, 3, 1, 1, 1)
approx_equal(x, 0, "A flat height map should have no X component")
approx_equal(y, 0, "A flat height map should have no Y component")
approx_equal(z, 1, "A flat height map should point straight out")

local left_to_right = {
	0,
	0.5,
	1,
	0,
	0.5,
	1,
	0,
	0.5,
	1,
}
x, y, z = NormalMapGenerator.sobel_normal(left_to_right, 3, 3, 1, 1, 1)
assert(x < 0, "A height map rising to the right should produce a negative X normal")
approx_equal(y, 0, "A horizontal gradient should have no Y component")
approx_equal(x * x + y * y + z * z, 1, "The output normal should be normalized")

local top_to_bottom = {
	0,
	0,
	0,
	0.5,
	0.5,
	0.5,
	1,
	1,
	1,
}
x, y, z = NormalMapGenerator.sobel_normal(top_to_bottom, 3, 3, 1, 1, 1)
approx_equal(x, 0, "A vertical gradient should have no X component")
assert(y < 0, "A height map rising downward should produce a negative Y normal")
approx_equal(x * x + y * y + z * z, 1, "The output normal should be normalized")

x, y, z = NormalMapGenerator.sobel_normal(left_to_right, 3, 3, 1, 1, 0)
approx_equal(x, 0, "Zero edge strength should remove the X component")
approx_equal(y, 0, "Zero edge strength should remove the Y component")
approx_equal(z, 1, "Zero edge strength should produce a flat normal")

print("Normal map Sobel tests passed")
