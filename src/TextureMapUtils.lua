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

function TextureMapUtils.valid_iteration_count(value, maximum)
	return value ~= nil
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
		and value == math.floor(value)
		and value >= 1
		and value <= maximum
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
	-- sample the 3x3 neighborhood of the pixel at (x, y)
	local top_left = sample_texture(luminance_map, width, height, x - 1, y - 1)
	local top = sample_texture(luminance_map, width, height, x, y - 1)
	local top_right = sample_texture(luminance_map, width, height, x + 1, y - 1)
	local left = sample_texture(luminance_map, width, height, x - 1, y)
	local right = sample_texture(luminance_map, width, height, x + 1, y)
	local bottom_left = sample_texture(luminance_map, width, height, x - 1, y + 1)
	local bottom = sample_texture(luminance_map, width, height, x, y + 1)
	local bottom_right = sample_texture(luminance_map, width, height, x + 1, y + 1)

	-- horizontal Sobel operator Gx, shape:
	-- -1 0 1
	-- -2 0 2
	-- -1 0 1
	local gradient_x = -(top_left + 2 * left + bottom_left - top_right - 2 * right - bottom_right)

	-- vertical Sobel operator Gy, shape:
	--  1  2  1
	--  0  0  0
	-- -1 -2 -1
	local gradient_y = top_left + 2 * top + top_right - bottom_left - 2 * bottom - bottom_right

	local normal_x = gradient_x * edge_strength
	local normal_y = gradient_y * edge_strength
	local normal_z = 1
	local length = math.sqrt(normal_x * normal_x + normal_y * normal_y + normal_z * normal_z)

	-- normalize
	return normal_x / length, normal_y / length, normal_z / length
end

--- Converts an image to a luminance texture using Rec. 709 formula.
--- Each pixel is represented by a single luminance value.
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

---Create a tangent-space normal map from a source image using a Sobel filter.
function TextureMapUtils.create_normal_image(source, edge_strength, layer_shape)
	local luminance_map, alpha_map = image_to_luminance_texture(source)
	local normal_map = Image(source.width, source.height, ColorMode.RGB)
	local pixel_color = app.pixelColor
	local direction = layer_shape == "Concave" and 1 or -1

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

local function has_surface(mask, index)
	return mask == nil or mask[index]
end

---Reconstructs height values from per-pixel X/Y slopes using iterative relaxation.
---Slopes are expressed as height change per pixel. Values are centered around 0.5,
---and are not normalized, so changing slope strength changes output contrast.
---@param slope_x number[]
---@param slope_y number[]
---@param width integer
---@param height integer
---@param iteration_count integer
---@param mask boolean[]|nil
---@return number[]
function TextureMapUtils.slope_extract_height(slope_x, slope_y, width, height, iteration_count, mask)
	local current = {}
	local next_values = {}
	local pixel_count = width * height

	for index = 1, pixel_count do
		current[index] = 0.5
		next_values[index] = 0.5
	end

	for _ = 1, iteration_count do
		local maximum_change = 0

		for y = 0, height - 1 do
			for x = 0, width - 1 do
				local index = y * width + x + 1
				if not has_surface(mask, index) then
					next_values[index] = 0.5
				else
					local estimate_sum = 0
					local estimate_count = 0
					local center_slope_x = slope_x[index]
					local center_slope_y = slope_y[index]

					if x > 0 then
						local left = index - 1
						if has_surface(mask, left) then
							estimate_sum = estimate_sum + current[left] + 0.5 * (slope_x[left] + center_slope_x)
							estimate_count = estimate_count + 1
						end
					end
					if x + 1 < width then
						local right = index + 1
						if has_surface(mask, right) then
							estimate_sum = estimate_sum + current[right] - 0.5 * (slope_x[right] + center_slope_x)
							estimate_count = estimate_count + 1
						end
					end
					if y > 0 then
						local top = index - width
						if has_surface(mask, top) then
							estimate_sum = estimate_sum + current[top] + 0.5 * (slope_y[top] + center_slope_y)
							estimate_count = estimate_count + 1
						end
					end
					if y + 1 < height then
						local bottom = index + width
						if has_surface(mask, bottom) then
							estimate_sum = estimate_sum + current[bottom] - 0.5 * (slope_y[bottom] + center_slope_y)
							estimate_count = estimate_count + 1
						end
					end

					local next_height = current[index]
					if estimate_count > 0 then
						local neighbor_estimate = estimate_sum / estimate_count
						-- under-relaxation prevents two-pixel/checkerboard oscillation
						next_height = 0.5 * current[index] + 0.5 * neighbor_estimate
					end
					next_values[index] = next_height
					maximum_change = math.max(maximum_change, math.abs(next_height - current[index]))
				end
			end
		end

		current, next_values = next_values, current
		if maximum_change < 0.0000001 then
			break
		end
	end

	-- a slope field determines relative, not absolute, height. Keep the mean
	-- at neutral gray so additional iterations cannot drift the whole surface
	local height_sum = 0
	local surface_pixel_count = 0
	for index = 1, pixel_count do
		if has_surface(mask, index) then
			height_sum = height_sum + current[index]
			surface_pixel_count = surface_pixel_count + 1
		end
	end

	if surface_pixel_count > 0 then
		local offset = 0.5 - height_sum / surface_pixel_count
		for index = 1, pixel_count do
			if has_surface(mask, index) then
				current[index] = current[index] + offset
			end
		end
	end

	return current
end

local function image_to_slope_texture(image, edge_strength)
	local slope_x = {}
	local slope_y = {}
	local alpha_map = {}
	local surface_mask = {}
	local pixel_color = app.pixelColor

	for y = 0, image.height - 1 do
		for x = 0, image.width - 1 do
			local pixel = image:getPixel(x, y)
			local red = pixel_color.rgbaR(pixel)
			local green = pixel_color.rgbaG(pixel)
			local blue = pixel_color.rgbaB(pixel)
			local alpha = pixel_color.rgbaA(pixel)
			local index = y * image.width + x + 1
			local normal_x = clamp((red - 128) / 127, -1, 1)
			local normal_y = clamp((green - 128) / 127, -1, 1)
			local normal_z = clamp((blue - 128) / 127, -1, 1)

			alpha_map[index] = alpha
			surface_mask[index] = alpha > 0
			if alpha > 0 and normal_z >= 0.001 then
				-- Aseprite normal maps use green-up, while image y grows downward
				-- so use flipped sign for x and y
				slope_x[index] = (-normal_x / normal_z) / image.width * edge_strength
				slope_y[index] = (normal_y / normal_z) / image.height * edge_strength
			else
				slope_x[index] = 0
				slope_y[index] = 0
			end
		end
	end

	return slope_x, slope_y, alpha_map, surface_mask
end

--- Creates a height map from a normal map using iterative relaxation.
function TextureMapUtils.create_height_image(source, edge_strength, iteration_count)
	local slope_x, slope_y, alpha_map, surface_mask = image_to_slope_texture(source, edge_strength)
	local heights = TextureMapUtils.slope_extract_height(
		slope_x,
		slope_y,
		source.width,
		source.height,
		iteration_count,
		surface_mask
	)
	local height_map = Image(source.width, source.height, ColorMode.RGB)
	local pixel_color = app.pixelColor

	for y = 0, source.height - 1 do
		for x = 0, source.width - 1 do
			local index = y * source.width + x + 1
			local height_byte = round_to_byte(heights[index] * 255)
			height_map:drawPixel(x, y, pixel_color.rgba(height_byte, height_byte, height_byte, alpha_map[index]))
		end
	end

	return height_map
end

return TextureMapUtils
