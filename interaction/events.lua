-- Event handler registration for interactive charts
local events = {}

local animation_module = require("interaction/animation")

-- Storage key for chart animations
local ANIMATIONS_KEY = "charts_animations"

---@class ChartEventHandlers
---@field on_tick function? Additional tick handler to chain
---@field on_gui_hover function? Additional hover handler to chain
---@field on_gui_leave function? Additional leave handler to chain
---@field on_gui_click function? Additional click handler to chain

local registered = false
local user_handlers = {}

---Get or create the animations storage table
---@return table<string, Animation>
local function get_animations_storage()
	if not storage[ANIMATIONS_KEY] then
		storage[ANIMATIONS_KEY] = {}
	end
	return storage[ANIMATIONS_KEY]
end

---Internal tick handler for processing animations
---@param event EventData.on_tick
local function on_tick_handler(event)
	local animations = get_animations_storage()
	if next(animations) then
		local completed = animation_module.update_all(animations, event.tick)
		for _, id in ipairs(completed) do
			animations[id] = nil
		end
	end

	-- Chain user handler if provided
	if user_handlers.on_tick then
		user_handlers.on_tick(event)
	end
end

---Register event handlers for interactive charts
---Call this in your mod's control.lua if using high-level wrappers with animations
---@param handlers ChartEventHandlers? Custom handlers to chain
function events.register(handlers)
	if registered then
		return
	end

	user_handlers = handlers or {}

	-- Register on_tick for animation processing
	script.on_event(defines.events.on_tick, on_tick_handler)

	registered = true
end

---Unregister event handlers
function events.unregister()
	if not registered then
		return
	end

	script.on_event(defines.events.on_tick, nil)
	user_handlers = {}
	registered = false
end

---Check if events are registered
---@return boolean
function events.is_registered()
	return registered
end

---Get the tick handler function (for manual integration)
---Useful if your mod already has an on_tick handler and you want to call this manually
---@return function on_tick_handler
function events.get_tick_handler()
	return on_tick_handler
end

---Add an animation to the global animation pool
---@param anim Animation The animation to add
function events.add_animation(anim)
	local animations = get_animations_storage()
	animations[anim.id] = anim
end

---Remove an animation from the global pool
---@param animation_id string
function events.remove_animation(animation_id)
	local animations = get_animations_storage()
	animations[animation_id] = nil
end

---Check if an animation is running
---@param animation_id string
---@return boolean
function events.is_animation_running(animation_id)
	local animations = get_animations_storage()
	return animations[animation_id] ~= nil
end

---Get all running animations
---@return table<string, Animation>
function events.get_animations()
	return get_animations_storage()
end

---Clear all animations
function events.clear_animations()
	storage[ANIMATIONS_KEY] = {}
end

return events
