-- Animation utilities for smooth transitions
local animation = {}

-- Easing functions
-- All take t in [0,1] and return eased value in [0,1]

---Linear interpolation (no easing)
---@param t number Progress 0-1
---@return number
function animation.ease_linear(t)
	return t
end

---Cubic ease in (slow start)
---@param t number Progress 0-1
---@return number
function animation.ease_in(t)
	return t * t * t
end

---Cubic ease out (slow end)
---@param t number Progress 0-1
---@return number
function animation.ease_out(t)
	return 1 - (1 - t) ^ 3
end

---Cubic ease in-out (slow start and end)
---@param t number Progress 0-1
---@return number
function animation.ease_in_out(t)
	if t < 0.5 then
		return 4 * t * t * t
	else
		return 1 - (-2 * t + 2) ^ 3 / 2
	end
end

-- Interpolation functions

---Linear interpolation for numbers
---@param a number Start value
---@param b number End value
---@param t number Progress 0-1
---@return number
function animation.lerp(a, b, t)
	return a + (b - a) * t
end

---Linear interpolation for colors
---@param a table {r, g, b, a?} Start color
---@param b table {r, g, b, a?} End color
---@param t number Progress 0-1
---@return table Interpolated color
function animation.lerp_color(a, b, t)
	return {
		r = a.r + (b.r - a.r) * t,
		g = a.g + (b.g - a.g) * t,
		b = a.b + (b.b - a.b) * t,
		a = (a.a or 1) + ((b.a or 1) - (a.a or 1)) * t,
	}
end

---Linear interpolation for positions
---@param a table {x, y} Start position
---@param b table {x, y} End position
---@param t number Progress 0-1
---@return table Interpolated position
function animation.lerp_position(a, b, t)
	return {
		x = a.x + (b.x - a.x) * t,
		y = a.y + (b.y - a.y) * t,
	}
end

-- Animation management

---@class Animation
---@field id string Unique animation identifier
---@field start_tick number Game tick when animation started
---@field duration number Duration in ticks
---@field from table Starting values (arbitrary key-value pairs)
---@field to table Target values (must have same keys as from)
---@field easing string|function Easing type or custom function
---@field on_update function? Called each tick with (t, current_values, animation)
---@field on_complete function? Called when animation completes
---@field render_objects table? Render objects to update

local easing_functions = {
	linear = animation.ease_linear,
	ease_in = animation.ease_in,
	ease_out = animation.ease_out,
	ease_in_out = animation.ease_in_out,
}

---Create a new animation
---@param params table Animation parameters
---@return Animation
function animation.create(params)
	local anim = {
		id = params.id or tostring(math.random(1000000)),
		start_tick = params.start_tick or game.tick,
		duration = params.duration or 30,
		from = params.from,
		to = params.to,
		easing = params.easing or "ease_in_out",
		on_update = params.on_update,
		on_complete = params.on_complete,
		render_objects = params.render_objects,
	}
	return anim
end

---Get current interpolated values for an animation
---@param anim Animation The animation
---@param current_tick number Current game tick
---@return table values Current interpolated values
---@return number t Raw progress 0-1
---@return number eased_t Eased progress 0-1
function animation.get_values(anim, current_tick)
	local elapsed = current_tick - anim.start_tick
	local t = math.min(1, elapsed / anim.duration)

	local easing_fn = anim.easing
	if type(easing_fn) == "string" then
		easing_fn = easing_functions[easing_fn] or animation.ease_linear
	end
	local eased_t = easing_fn(t)

	local values = {}
	for key, from_val in pairs(anim.from) do
		local to_val = anim.to[key]
		if type(from_val) == "number" then
			values[key] = animation.lerp(from_val, to_val, eased_t)
		elseif type(from_val) == "table" then
			if from_val.r ~= nil then
				values[key] = animation.lerp_color(from_val, to_val, eased_t)
			elseif from_val.x ~= nil then
				values[key] = animation.lerp_position(from_val, to_val, eased_t)
			end
		end
	end

	return values, t, eased_t
end

---Update a single animation
---@param anim Animation The animation to update
---@param current_tick number Current game tick
---@return boolean completed True if animation completed this tick
function animation.update(anim, current_tick)
	local values, t, eased_t = animation.get_values(anim, current_tick)

	if anim.on_update then
		anim.on_update(eased_t, values, anim)
	end

	if t >= 1 then
		if anim.on_complete then
			anim.on_complete(anim)
		end
		return true
	end

	return false
end

---Update all active animations
---@param animations table<string, Animation> Table of active animations by ID
---@param current_tick number Current game tick
---@return string[] completed_ids IDs of animations that completed
function animation.update_all(animations, current_tick)
	local completed = {}
	for id, anim in pairs(animations) do
		if animation.update(anim, current_tick) then
			completed[#completed + 1] = id
		end
	end
	return completed
end

---Cancel an animation
---@param animations table<string, Animation> Table of active animations
---@param animation_id string Animation to cancel
---@return boolean success True if animation was found and cancelled
function animation.cancel(animations, animation_id)
	if animations[animation_id] then
		animations[animation_id] = nil
		return true
	end
	return false
end

---Check if an animation is running
---@param animations table<string, Animation> Table of active animations
---@param animation_id string Animation to check
---@return boolean running True if animation is active
function animation.is_running(animations, animation_id)
	return animations[animation_id] ~= nil
end

return animation
