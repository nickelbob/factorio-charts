-- Events module tests
local charts = require("__factorio-charts__/charts")

test("get_tick_handler returns a function", function()
	local handler = charts.get_tick_handler()
	assert.is_function(handler)
end)
