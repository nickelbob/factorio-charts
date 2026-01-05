-- Animation module tests
local charts = require("__factorio-charts__/charts")
local animation = charts.animation

test("ease_linear returns input unchanged", function()
	assert.equals(0, animation.ease_linear(0))
	assert.equals(0.5, animation.ease_linear(0.5))
	assert.equals(1, animation.ease_linear(1))
end)

test("ease_in starts slow", function()
	-- At t=0.5, ease_in should be less than 0.5 (slow start)
	local mid = animation.ease_in(0.5)
	assert.is_true(mid < 0.5)
	assert.equals(0, animation.ease_in(0))
	assert.equals(1, animation.ease_in(1))
end)

test("ease_out ends slow", function()
	-- At t=0.5, ease_out should be greater than 0.5 (fast start)
	local mid = animation.ease_out(0.5)
	assert.is_true(mid > 0.5)
	assert.equals(0, animation.ease_out(0))
	assert.equals(1, animation.ease_out(1))
end)

test("ease_in_out is symmetric around 0.5", function()
	assert.equals(0, animation.ease_in_out(0))
	assert.equals(1, animation.ease_in_out(1))
	-- At t=0.5, ease_in_out should be exactly 0.5
	assert.equals(0.5, animation.ease_in_out(0.5))
end)

test("lerp interpolates numbers correctly", function()
	assert.equals(0, animation.lerp(0, 10, 0))
	assert.equals(5, animation.lerp(0, 10, 0.5))
	assert.equals(10, animation.lerp(0, 10, 1))
	assert.equals(7.5, animation.lerp(5, 10, 0.5))
end)

test("lerp_color interpolates colors correctly", function()
	local red = {r = 1, g = 0, b = 0}
	local blue = {r = 0, g = 0, b = 1}

	local result = animation.lerp_color(red, blue, 0.5)
	assert.equals(0.5, result.r)
	assert.equals(0, result.g)
	assert.equals(0.5, result.b)
end)

test("lerp_color handles alpha", function()
	local a = {r = 1, g = 0, b = 0, a = 0}
	local b = {r = 0, g = 0, b = 1, a = 1}

	local result = animation.lerp_color(a, b, 0.5)
	assert.equals(0.5, result.a)
end)

test("lerp_position interpolates positions correctly", function()
	local from = {x = 0, y = 0}
	local to = {x = 10, y = 20}

	local result = animation.lerp_position(from, to, 0.5)
	assert.equals(5, result.x)
	assert.equals(10, result.y)
end)

test("animation.create returns animation table", function()
	local anim = animation.create({
		id = "test_anim",
		duration = 30,
		from = {value = 0},
		to = {value = 100},
	})

	assert.is_table(anim)
	assert.equals("test_anim", anim.id)
	assert.equals(30, anim.duration)
end)

test("animation.get_values returns interpolated values", function()
	local start_tick = 100
	local anim = animation.create({
		id = "test_anim",
		start_tick = start_tick,
		duration = 10,
		from = {value = 0},
		to = {value = 100},
		easing = "linear",
	})

	-- At start
	local values, t = animation.get_values(anim, start_tick)
	assert.equals(0, t)
	assert.equals(0, values.value)

	-- At midpoint
	values, t = animation.get_values(anim, start_tick + 5)
	assert.equals(0.5, t)
	assert.equals(50, values.value)

	-- At end
	values, t = animation.get_values(anim, start_tick + 10)
	assert.equals(1, t)
	assert.equals(100, values.value)
end)

test("animation.update_all processes multiple animations", function()
	local animations = {}
	local tick = 100

	animations["anim1"] = animation.create({
		id = "anim1",
		start_tick = tick,
		duration = 10,
		from = {value = 0},
		to = {value = 100},
	})

	animations["anim2"] = animation.create({
		id = "anim2",
		start_tick = tick,
		duration = 5,
		from = {value = 0},
		to = {value = 50},
	})

	-- At tick 105, anim2 should complete but not anim1
	local completed = animation.update_all(animations, tick + 5)
	assert.equals(1, #completed)
	assert.equals("anim2", completed[1])
end)

test("animation.cancel removes animation", function()
	local animations = {}
	animations["test"] = animation.create({id = "test", duration = 10, from = {}, to = {}})

	assert.is_true(animation.is_running(animations, "test"))
	animation.cancel(animations, "test")
	assert.is_false(animation.is_running(animations, "test"))
end)

-- ============================================================================
-- Extended Animation Tests
-- ============================================================================

test("animation with custom easing function", function()
	local custom_easing_called = false
	local custom_easing = function(t)
		custom_easing_called = true
		return t * t  -- Quadratic ease-in
	end

	local anim = animation.create({
		id = "custom_ease",
		start_tick = 100,
		duration = 10,
		from = {value = 0},
		to = {value = 100},
		easing = custom_easing,
	})

	local values = animation.get_values(anim, 105)
	assert.is_true(custom_easing_called)
	-- At t=0.5, quadratic should give 0.25
	assert.equals(25, values.value)
end)

test("animation on_update callback receives correct parameters", function()
	local received_t = nil
	local received_values = nil
	local received_anim = nil

	local anim = animation.create({
		id = "callback_test",
		start_tick = 100,
		duration = 10,
		from = {x = 0, y = 0},
		to = {x = 100, y = 200},
		easing = "linear",
		on_update = function(t, values, a)
			received_t = t
			received_values = values
			received_anim = a
		end,
	})

	animation.update(anim, 105)

	assert.equals(0.5, received_t)
	assert.equals(50, received_values.x)
	assert.equals(100, received_values.y)
	assert.equals(anim, received_anim)
end)

test("animation on_complete callback is called at completion", function()
	local complete_called = false
	local completed_anim = nil

	local anim = animation.create({
		id = "complete_test",
		start_tick = 100,
		duration = 10,
		from = {value = 0},
		to = {value = 100},
		on_complete = function(a)
			complete_called = true
			completed_anim = a
		end,
	})

	-- Before completion
	animation.update(anim, 105)
	assert.is_false(complete_called)

	-- At completion
	animation.update(anim, 110)
	assert.is_true(complete_called)
	assert.equals(anim, completed_anim)
end)

test("animation clamps t to maximum of 1", function()
	local anim = animation.create({
		id = "clamp_test",
		start_tick = 100,
		duration = 10,
		from = {value = 0},
		to = {value = 100},
		easing = "linear",
	})

	-- Way past the end
	local values, t = animation.get_values(anim, 200)
	assert.equals(1, t)
	assert.equals(100, values.value)
end)

test("animation handles zero duration", function()
	local anim = animation.create({
		id = "zero_duration",
		start_tick = 100,
		duration = 0,
		from = {value = 0},
		to = {value = 100},
		easing = "linear",
	})

	-- Should immediately complete (t >= 1)
	local values, t = animation.get_values(anim, 100)
	-- Division by zero protection should kick in
	assert.is_true(t >= 1)
end)

test("lerp handles negative values", function()
	assert.equals(-5, animation.lerp(-10, 0, 0.5))
	assert.equals(-15, animation.lerp(-10, -20, 0.5))
end)

test("lerp_color handles colors with values > 1", function()
	local a = {r = 0, g = 0, b = 0}
	local b = {r = 2, g = 2, b = 2}  -- HDR-like values

	local result = animation.lerp_color(a, b, 0.5)
	assert.equals(1, result.r)
	assert.equals(1, result.g)
	assert.equals(1, result.b)
end)

test("lerp_position handles negative coordinates", function()
	local from = {x = -10, y = -20}
	local to = {x = 10, y = 20}

	local result = animation.lerp_position(from, to, 0.5)
	assert.equals(0, result.x)
	assert.equals(0, result.y)
end)

test("animation interpolates multiple value types simultaneously", function()
	local anim = animation.create({
		id = "multi_type",
		start_tick = 100,
		duration = 10,
		from = {
			scalar = 0,
			color = {r = 1, g = 0, b = 0},
			position = {x = 0, y = 0},
		},
		to = {
			scalar = 100,
			color = {r = 0, g = 1, b = 0},
			position = {x = 10, y = 20},
		},
		easing = "linear",
	})

	local values = animation.get_values(anim, 105)

	assert.equals(50, values.scalar)
	assert.equals(0.5, values.color.r)
	assert.equals(0.5, values.color.g)
	assert.equals(5, values.position.x)
	assert.equals(10, values.position.y)
end)

test("ease_in is monotonically increasing", function()
	local prev = 0
	for i = 1, 10 do
		local t = i / 10
		local eased = animation.ease_in(t)
		assert.is_true(eased >= prev)
		prev = eased
	end
end)

test("ease_out is monotonically increasing", function()
	local prev = 0
	for i = 1, 10 do
		local t = i / 10
		local eased = animation.ease_out(t)
		assert.is_true(eased >= prev)
		prev = eased
	end
end)

test("ease_in_out is monotonically increasing", function()
	local prev = 0
	for i = 1, 10 do
		local t = i / 10
		local eased = animation.ease_in_out(t)
		assert.is_true(eased >= prev)
		prev = eased
	end
end)

test("animation.update returns false while in progress", function()
	local anim = animation.create({
		id = "progress_test",
		start_tick = 100,
		duration = 10,
		from = {value = 0},
		to = {value = 100},
	})

	local completed = animation.update(anim, 105)
	assert.is_false(completed)
end)

test("animation.update returns true on completion", function()
	local anim = animation.create({
		id = "complete_return_test",
		start_tick = 100,
		duration = 10,
		from = {value = 0},
		to = {value = 100},
	})

	local completed = animation.update(anim, 110)
	assert.is_true(completed)
end)

test("animation.cancel on non-existent animation returns false", function()
	local animations = {}
	local result = animation.cancel(animations, "does_not_exist")
	assert.is_false(result)
end)

test("animation.cancel on existing animation returns true", function()
	local animations = {}
	animations["exists"] = animation.create({id = "exists", duration = 10, from = {}, to = {}})

	local result = animation.cancel(animations, "exists")
	assert.is_true(result)
end)

test("animation auto-generates id if not provided", function()
	local anim = animation.create({
		duration = 10,
		from = {value = 0},
		to = {value = 100},
	})

	assert.is_not_nil(anim.id)
	assert.is_true(#anim.id > 0)
end)

test("animation uses default duration if not provided", function()
	local anim = animation.create({
		id = "default_duration",
		from = {value = 0},
		to = {value = 100},
	})

	assert.equals(30, anim.duration)
end)

test("animation uses default easing if not provided", function()
	local anim = animation.create({
		id = "default_easing",
		start_tick = 100,
		duration = 10,
		from = {value = 0},
		to = {value = 100},
	})

	-- Default is ease_in_out, at t=0.5 should be exactly 0.5
	local values, t, eased_t = animation.get_values(anim, 105)
	assert.equals(0.5, eased_t)
end)
