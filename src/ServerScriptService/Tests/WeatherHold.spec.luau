-- The Studio-only weather hold (leg 3, N1 close-out): WeatherService keeps a DebugWeather
-- kind through every refresh (new date, game midnight) in Studio, never in a live server.
return function(t, Shared)
	local Weather = require(Shared.Weather)

	local dated = Weather.planForDate(20000)

	t.test("hold: in Studio a valid kind wins over the date's plan", function()
		for _, k in Weather.list do
			local p = Weather.heldPlan(dated, k.id, true, 3, nil)
			t.eq(p.kind, k.id, "held " .. k.id)
			t.eq(p.day, 3, "day counter kept")
		end
		local clear = Weather.heldPlan(dated, "Clear", true, 7, nil)
		for c = 0, 23.5, 0.5 do
			t.eq(Weather.at(clear, c, 0).weather, "Clear", "Clear all day at " .. c)
		end
	end)

	t.test("hold: never in a live server", function()
		t.ok(Weather.heldPlan(dated, "Clear", false, 3, nil) == dated, "live keeps the date's plan")
		t.ok(Weather.heldPlan(dated, "Storm", false, 3, nil) == dated, "live ignores Storm too")
	end)

	t.test("hold: nothing or junk falls back to the date's plan", function()
		for _, v in { "", "clear", "Sunny", 1, true } :: { any } do
			t.ok(Weather.heldPlan(dated, v, true, 3, nil) == dated, "fallback for " .. tostring(v))
		end
		t.ok(Weather.heldPlan(dated, nil, true, 3, nil) == dated, "nil")
	end)

	t.test("hold: a forced wind carries through", function()
		t.eq(Weather.heldPlan(dated, "Wind", true, 1, "NW").wind, "NW")
	end)
end
