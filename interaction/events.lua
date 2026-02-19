-- Event handler registration for interactive charts
local events = {}

---@class ChartEventHandlers
---@field on_tick function? Additional tick handler to chain

local registered = false
local user_handlers = {}

---Internal tick handler
---@param event EventData.on_tick
local function on_tick_handler(event)
	-- Chain user handler if provided
	if user_handlers.on_tick then
		user_handlers.on_tick(event)
	end
end

---Register event handlers for interactive charts
---@param handlers ChartEventHandlers? Custom handlers to chain
function events.register(handlers)
	if registered then
		return
	end

	user_handlers = handlers or {}

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

return events
