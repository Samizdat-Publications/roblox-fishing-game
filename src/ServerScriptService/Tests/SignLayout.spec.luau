-- Painted world signs (leg 3, N2): the words fit the board and the lanterns know the night.
return function(t, Shared)
	local SignLayout = require(Shared.SignLayout)

	local function fits(width: number, height: number, text: string)
		local shown, size = SignLayout.fit(width, height, text)
		local lines = string.split(shown, "\n")
		local innerW = width * SignLayout.PIXELS_PER_STUD * (1 - 2 * SignLayout.MARGIN)
		local innerH = height * SignLayout.PIXELS_PER_STUD * (1 - 2 * SignLayout.MARGIN)
		for _, l in lines do
			t.ok(#l * SignLayout.CHAR_WIDTH * size <= innerW + 0.5, text .. ": too wide")
		end
		t.ok(#lines * SignLayout.LINE_HEIGHT * size <= innerH + 0.5, text .. ": too tall")
		t.ok(size >= SignLayout.MIN_TEXT_SIZE and size <= SignLayout.MAX_TEXT_SIZE, text .. ": size out of range")
		return lines, size
	end

	t.test("short names stay on one line", function()
		local lines = fits(9, 2, "Sell Fish")
		t.eq(#lines, 1, "Sell Fish lines")
		lines = fits(9, 2, "Bait and Tackle")
		t.eq(#lines, 1, "Bait and Tackle lines")
	end)

	t.test("the blue-water warning breaks into two lines on an 8 stud board", function()
		local lines = fits(8, 2.4, "Blue water ahead: big boats only")
		t.eq(#lines, 2, "warning lines")
		t.eq(lines[1], "Blue water ahead:", "first line")
		t.eq(lines[2], "big boats only", "second line")
	end)

	t.test("stand names read from the dock (text near a stud tall)", function()
		local _, size = fits(9, 2, "Bait and Tackle")
		t.ok(size / SignLayout.PIXELS_PER_STUD >= 0.8, "letters too small: " .. size)
	end)

	t.test("slip numbers and one-word signs fit", function()
		fits(1.3, 0.9, "4")
		fits(5.3, 3.2, "Boat slips")
		fits(6, 1.3, "Cedar Creek")
		fits(4.5, 1.4, "Your Pond")
	end)

	t.test("the lean is 1 to 2 degrees and repeatable", function()
		for _, s in { "Sell Fish", "Bait and Tackle", "Your Pond", "Cedar Creek", "1", "2" } do
			local a = SignLayout.tilt(s)
			t.ok(math.abs(a) >= 1 and math.abs(a) <= 2, s .. " lean " .. a)
			t.eq(SignLayout.tilt(s), a, s .. " repeat")
		end
	end)

	t.test("lanterns burn at night only", function()
		t.eq(SignLayout.lanternsOn(0), true, "midnight")
		t.eq(SignLayout.lanternsOn(6.4), true, "before dawn")
		t.eq(SignLayout.lanternsOn(6.6), false, "after dawn")
		t.eq(SignLayout.lanternsOn(12), false, "noon")
		t.eq(SignLayout.lanternsOn(18.1), false, "before dusk")
		t.eq(SignLayout.lanternsOn(18.3), true, "after dusk")
	end)
end
