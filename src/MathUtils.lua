---@class MathUtils
local MathUtils = {}

---@param value number The value to clamp
---@param minimum number The minimum allowed value
---@param maximum number The maximum allowed value
---@return number # The clamped value within [minimum, maximum]
function MathUtils.clamp(value, minimum, maximum)
	return math.max(minimum, math.min(maximum, value))
end

---@param value number The value to round and clamp
---@return integer # The value rounded to the nearest integer and clamped to [0, 255]
function MathUtils.round_to_u8(value)
	return math.floor(MathUtils.clamp(value, 0, 255) + 0.5) -- +0.5 to turn floor into round
end

return MathUtils
