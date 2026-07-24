local TextureMapUtils = {}

local function clamp(value, minimum, maximum)
	return math.max(minimum, math.min(maximum, value))
end

local function round_to_byte(value)
	return math.floor(clamp(value, 0, 255) + 0.5)
end

function TextureMapUtils.valid_strength(value)
	return value ~= nil and value == value and value ~= math.huge and value ~= -math.huge and value >= 0
end

function TextureMapUtils.valid_layer_shape(value, layer_shapes)
	for _, shape in ipairs(layer_shapes) do
		if value == shape then
			return true
		end
	end
	return false
end

local function sample_texture(texture, width, height, x, y)
	x = clamp(x, 0, width - 1)
	y = clamp(y, 0, height - 1)
	return texture[y * width + x + 1]
end

---Calculates one tangent-space normal using a 3x3 Sobel kernel.
---@param luminance_map number[]
---@param width integer
---@param height integer
---@param x integer
---@param y integer
---@param edge_strength number
---@return number x
---@return number y
---@return number z
function TextureMapUtils.sobel_normal(luminance_map, width, height, x, y, edge_strength)
	local top_left = sample_texture(luminance_map, width, height, x - 1, y - 1)
	local top = sample_texture(luminance_map, width, height, x, y - 1)
	local top_right = sample_texture(luminance_map, width, height, x + 1, y - 1)
	local left = sample_texture(luminance_map, width, height, x - 1, y)
	local right = sample_texture(luminance_map, width, height, x + 1, y)
	local bottom_left = sample_texture(luminance_map, width, height, x - 1, y + 1)
	local bottom = sample_texture(luminance_map, width, height, x, y + 1)
	local bottom_right = sample_texture(luminance_map, width, height, x + 1, y + 1)

	local gradient_x = top_left + 2 * left + bottom_left - top_right - 2 * right - bottom_right
	local gradient_y = top_left + 2 * top + top_right - bottom_left - 2 * bottom - bottom_right

	local normal_x = gradient_x * edge_strength
	local normal_y = gradient_y * edge_strength
	local normal_z = 1
	local length = math.sqrt(normal_x * normal_x + normal_y * normal_y + normal_z * normal_z)

	return normal_x / length, normal_y / length, normal_z / length
end

local function image_to_luminance_texture(image)
	local luminance_map = {}
	local alpha_map = {}
	local pixel_color = app.pixelColor

	for y = 0, image.height - 1 do
		for x = 0, image.width - 1 do
			local pixel = image:getPixel(x, y)
			local red = pixel_color.rgbaR(pixel)
			local green = pixel_color.rgbaG(pixel)
			local blue = pixel_color.rgbaB(pixel)
			local alpha = pixel_color.rgbaA(pixel)
			local index = y * image.width + x + 1

			-- Rec. 709 luminance luminance calculation formula
			luminance_map[index] = (0.2126 * red + 0.7152 * green + 0.0722 * blue) / 255 * alpha / 255
			alpha_map[index] = alpha
		end
	end

	return luminance_map, alpha_map
end

function TextureMapUtils.create_normal_image(source, edge_strength, layer_shape)
	local luminance_map, alpha_map = image_to_luminance_texture(source)
	local normal_map = Image(source.width, source.height, ColorMode.RGB)
	local pixel_color = app.pixelColor
	local direction = layer_shape == "Concave" and -1 or 1

	for y = 0, source.height - 1 do
		for x = 0, source.width - 1 do
			local normal_x, normal_y, normal_z = TextureMapUtils.sobel_normal(
				luminance_map,
				source.width,
				source.height,
				x,
				y,
				edge_strength * direction
			)
			local index = y * source.width + x + 1
			normal_map:drawPixel(
				x,
				y,
				pixel_color.rgba(
					round_to_byte((normal_x * 0.5 + 0.5) * 255),
					round_to_byte((normal_y * 0.5 + 0.5) * 255),
					round_to_byte((normal_z * 0.5 + 0.5) * 255),
					alpha_map[index]
				)
			)
		end
	end

	return normal_map
end

return TextureMapUtils
