-- Players read inches and pounds; the data stays metric (leg plan L1).
return function(t, Shared)
	local Config = require(Shared.Config)
	local Units = require(Shared.Units)

	local function with(units: string, fn: () -> ())
		local old = Config.UNITS
		Config.UNITS = units
		local ok, err = pcall(fn)
		Config.UNITS = old
		if not ok then
			error(err, 0)
		end
	end

	t.test("imperial is the default", function()
		t.eq(Config.UNITS, "imperial", "Config.UNITS")
	end)

	t.test("lengths in inches", function()
		with("imperial", function()
			t.eq(Units.length(25.4), "10.0 in", "25.4 cm")
			t.eq(Units.length(36.1), "14.2 in", "36.1 cm")
			t.eq(Units.length(127, 0), "50 in", "no decimals")
		end)
	end)

	t.test("weights in ounces, pounds and ounces, then pounds", function()
		with("imperial", function()
			t.eq(Units.weight(0.17), "6 oz", "small panfish")
			t.eq(Units.weight(0.001), "1 oz", "never 0 oz")
			t.eq(Units.weight(1.05), "2 lb 5 oz", "bass")
			t.eq(Units.weight(0.4536), "1 lb", "exactly a pound")
			t.eq(Units.weight(0.9), "2 lb", "15.7 oz rounds up to the next pound, not 1 lb 16 oz")
			t.eq(Units.weight(6.5), "14.3 lb", "big fish")
		end)
	end)

	t.test("goal sizes round up so the text never asks for more than the goal", function()
		with("imperial", function()
			t.eq(Units.atLeast(30), "12 in", "30 cm is 11.8 in")
			t.eq(Units.atLeast(25.4), "10 in", "exact")
		end)
	end)

	t.test("metric still works", function()
		with("metric", function()
			t.eq(Units.length(36.14), "36.1 cm", "length")
			t.eq(Units.weight(1.234), "1.23 kg", "weight")
			t.eq(Units.weight(14.26), "14.3 kg", "big weight")
			t.eq(Units.atLeast(30), "30 cm", "goal")
		end)
	end)
end
