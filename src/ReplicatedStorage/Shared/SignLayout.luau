--!strict
-- Pure helpers for the painted world signs (leg 3, N2): how big the words are on a board of a
-- given size, how much a hand-painted label leans, and when the sign lanterns are lit.
-- Server/Signs builds the boards; ClientModules/Lanterns switches the lights.
local SignLayout = {}

SignLayout.PIXELS_PER_STUD = 50 -- the SurfaceGui's canvas density
SignLayout.CHAR_WIDTH = 0.56 -- average glyph width as a share of the text size (Merriweather bold)
SignLayout.LINE_HEIGHT = 1.15 -- a line's height as a share of the text size
SignLayout.MARGIN = 0.12 -- unpainted edge on each side, as a share of the board
SignLayout.MIN_TEXT_SIZE = 8
SignLayout.MAX_TEXT_SIZE = 100 -- Roblox caps TextSize at 100
SignLayout.TWO_LINE_GAIN = 1.08 -- two lines only when they paint the words this much bigger

-- Lanterns burn outside this window of Lighting.ClockTime (hours).
SignLayout.DAWN = 6.5
SignLayout.DUSK = 18.2

-- The text size (pixels) that fits these lines inside the board's painted area.
local function sizeFor(width: number, height: number, lines: { string }): number
	local innerW = width * SignLayout.PIXELS_PER_STUD * (1 - 2 * SignLayout.MARGIN)
	local innerH = height * SignLayout.PIXELS_PER_STUD * (1 - 2 * SignLayout.MARGIN)
	local longest = 1
	for _, l in lines do
		longest = math.max(longest, #l)
	end
	local byWidth = innerW / (longest * SignLayout.CHAR_WIDTH)
	local byHeight = innerH / (#lines * SignLayout.LINE_HEIGHT)
	return math.min(byWidth, byHeight)
end

-- Two lines, broken at the space nearest the middle; nil when there is no space.
function SignLayout.split(text: string): { string }?
	local best: number? = nil
	local middle = #text / 2
	for i = 1, #text do
		if string.sub(text, i, i) == " " and (best == nil or math.abs(i - middle) < math.abs((best :: number) - middle)) then
			best = i
		end
	end
	if not best then
		return nil
	end
	return { string.sub(text, 1, best - 1), string.sub(text, best + 1) }
end

-- The words as painted (with a line break if two lines read bigger) and their text size.
function SignLayout.fit(width: number, height: number, text: string): (string, number)
	local lines = { text }
	local size = sizeFor(width, height, lines)
	local two = SignLayout.split(text)
	if two then
		local size2 = sizeFor(width, height, two)
		if size2 > size * SignLayout.TWO_LINE_GAIN then
			lines, size = two, size2
		end
	end
	return table.concat(lines, "\n"), math.clamp(math.floor(size), SignLayout.MIN_TEXT_SIZE, SignLayout.MAX_TEXT_SIZE)
end

-- A hand-painted lean in degrees, 1 to 2 either way, the same every time for the same words.
function SignLayout.tilt(text: string): number
	local hash = 0
	for i = 1, #text do
		hash = (hash * 31 + string.byte(text, i)) % 1000003
	end
	local magnitude = 1 + (hash % 11) / 10
	return if hash % 2 == 0 then magnitude else -magnitude
end

function SignLayout.lanternsOn(clockTime: number): boolean
	return clockTime < SignLayout.DAWN or clockTime > SignLayout.DUSK
end

return SignLayout
