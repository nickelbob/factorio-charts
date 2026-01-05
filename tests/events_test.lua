-- Events module tests
local charts = require("__factorio-charts__/charts")

-- Note: These tests focus on the animation management functions
-- The actual event registration (script.on_event) cannot be fully tested
-- in the test framework, but we can test the helper functions.

test("add_animation stores animation in global pool", function()
	-- Clear any existing animations
	charts.clear_animations()

	local anim = charts.animation.create({
		id = "test_event_anim_1",
		duration = 30,
		from = {value = 0},
		to = {value = 100},
	})

	charts.add_animation(anim)

	assert.is_true(charts.is_animation_running("test_event_anim_1"))

	-- Cleanup
	charts.clear_animations()
end)

test("remove_animation removes from global pool", function()
	charts.clear_animations()

	local anim = charts.animation.create({
		id = "test_event_anim_2",
		duration = 30,
		from = {value = 0},
		to = {value = 100},
	})

	charts.add_animation(anim)
	assert.is_true(charts.is_animation_running("test_event_anim_2"))

	charts.remove_animation("test_event_anim_2")
	assert.is_false(charts.is_animation_running("test_event_anim_2"))

	charts.clear_animations()
end)

test("is_animation_running returns correct state", function()
	charts.clear_animations()

	assert.is_false(charts.is_animation_running("non_existent"))

	local anim = charts.animation.create({
		id = "test_event_anim_3",
		duration = 30,
		from = {value = 0},
		to = {value = 100},
	})

	charts.add_animation(anim)
	assert.is_true(charts.is_animation_running("test_event_anim_3"))

	charts.clear_animations()
	assert.is_false(charts.is_animation_running("test_event_anim_3"))
end)

test("get_animations returns all animations", function()
	charts.clear_animations()

	local anim1 = charts.animation.create({
		id = "test_event_anim_4a",
		duration = 30,
		from = {value = 0},
		to = {value = 100},
	})

	local anim2 = charts.animation.create({
		id = "test_event_anim_4b",
		duration = 30,
		from = {value = 0},
		to = {value = 50},
	})

	charts.add_animation(anim1)
	charts.add_animation(anim2)

	local animations = charts.get_animations()
	assert.is_table(animations)
	assert.is_not_nil(animations["test_event_anim_4a"])
	assert.is_not_nil(animations["test_event_anim_4b"])

	charts.clear_animations()
end)

test("clear_animations removes all animations", function()
	charts.clear_animations()

	local anim1 = charts.animation.create({
		id = "test_event_anim_5a",
		duration = 30,
		from = {value = 0},
		to = {value = 100},
	})

	local anim2 = charts.animation.create({
		id = "test_event_anim_5b",
		duration = 30,
		from = {value = 0},
		to = {value = 50},
	})

	charts.add_animation(anim1)
	charts.add_animation(anim2)

	assert.is_true(charts.is_animation_running("test_event_anim_5a"))
	assert.is_true(charts.is_animation_running("test_event_anim_5b"))

	charts.clear_animations()

	assert.is_false(charts.is_animation_running("test_event_anim_5a"))
	assert.is_false(charts.is_animation_running("test_event_anim_5b"))

	local animations = charts.get_animations()
	assert.is_nil(next(animations))
end)

test("get_tick_handler returns a function", function()
	local handler = charts.get_tick_handler()
	assert.is_function(handler)
end)

test("tick handler processes animations", function()
	charts.clear_animations()

	local update_count = 0
	local completed = false

	local anim = charts.animation.create({
		id = "test_event_anim_6",
		start_tick = game.tick,
		duration = 5,
		from = {value = 0},
		to = {value = 100},
		on_update = function(t, values, a)
			update_count = update_count + 1
		end,
		on_complete = function(a)
			completed = true
		end,
	})

	charts.add_animation(anim)

	-- Manually call tick handler to simulate ticks
	local handler = charts.get_tick_handler()

	-- Simulate 6 ticks (animation duration is 5)
	for i = 1, 6 do
		handler({tick = game.tick + i})
	end

	-- Animation should have been updated and completed
	assert.is_true(update_count > 0)
	assert.is_true(completed)
	assert.is_false(charts.is_animation_running("test_event_anim_6"))

	charts.clear_animations()
end)

test("multiple animations process independently", function()
	charts.clear_animations()

	local anim1_updates = 0
	local anim2_updates = 0
	local anim1_completed = false
	local anim2_completed = false

	local anim1 = charts.animation.create({
		id = "test_event_anim_7a",
		start_tick = game.tick,
		duration = 3,
		from = {value = 0},
		to = {value = 100},
		on_update = function() anim1_updates = anim1_updates + 1 end,
		on_complete = function() anim1_completed = true end,
	})

	local anim2 = charts.animation.create({
		id = "test_event_anim_7b",
		start_tick = game.tick,
		duration = 6,
		from = {value = 0},
		to = {value = 50},
		on_update = function() anim2_updates = anim2_updates + 1 end,
		on_complete = function() anim2_completed = true end,
	})

	charts.add_animation(anim1)
	charts.add_animation(anim2)

	local handler = charts.get_tick_handler()

	-- After 4 ticks, anim1 should be done but anim2 still running
	for i = 1, 4 do
		handler({tick = game.tick + i})
	end

	assert.is_true(anim1_completed)
	assert.is_false(anim2_completed)
	assert.is_false(charts.is_animation_running("test_event_anim_7a"))
	assert.is_true(charts.is_animation_running("test_event_anim_7b"))

	-- After 3 more ticks, both should be done
	for i = 5, 7 do
		handler({tick = game.tick + i})
	end

	assert.is_true(anim2_completed)
	assert.is_false(charts.is_animation_running("test_event_anim_7b"))

	charts.clear_animations()
end)

test("removing animation during processing doesn't break iteration", function()
	charts.clear_animations()

	-- Create animations where one removes another
	local anim1 = charts.animation.create({
		id = "test_event_anim_8a",
		start_tick = game.tick,
		duration = 5,
		from = {value = 0},
		to = {value = 100},
		on_update = function()
			-- Try to remove the other animation during processing
			charts.remove_animation("test_event_anim_8b")
		end,
	})

	local anim2 = charts.animation.create({
		id = "test_event_anim_8b",
		start_tick = game.tick,
		duration = 10,
		from = {value = 0},
		to = {value = 50},
	})

	charts.add_animation(anim1)
	charts.add_animation(anim2)

	local handler = charts.get_tick_handler()

	-- This should not error
	handler({tick = game.tick + 1})

	-- anim2 should have been removed
	assert.is_false(charts.is_animation_running("test_event_anim_8b"))

	charts.clear_animations()
end)
