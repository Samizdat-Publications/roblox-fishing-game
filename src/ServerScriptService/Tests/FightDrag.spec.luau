-- Line and drag (L4d): Medium is the fight as it was, Tight is faster but builds strain on
-- heavy fish through big moves, Light never snaps. Numbers in Config (DRAG_*, STRAIN_*).
return function(t, Shared)
	local FightModel = require(Shared.FightModel)
	local FishData = require(Shared.FishData)
	local RodData = require(Shared.RodData)
	local Config = require(Shared.Config)
	local DT = 1 / 30

	-- A tiny fixed random source, so the recorded trace is the same in Lune and in Studio.
	local function lcg(seed: number)
		local st = seed % 2147483647
		return {
			NextNumber = function(_self)
				st = (st * 48271) % 2147483647
				return st / 2147483647
			end,
		}
	end

	-- Recorded 11/27/2026 from FightModel before L4d (commit 1e82441): eight fights with
	-- scripted input and uneven frame times. Each sample: step, fishPos, zonePos, progress,
	-- mode, tells, darts.
	local CASES = {
		{ id = "LargemouthBass", assist = false, start = nil, seed = 918273645, lazy = false },
		{ id = "ChannelCatfish", assist = false, start = nil, seed = 192837465, lazy = false },
		{ id = "RainbowTrout", assist = true, start = nil, seed = 564738291, lazy = false },
		{ id = "NorthernPike", assist = false, start = 0.5, seed = 1029384756, lazy = false },
		{ id = "Bluegill", assist = true, start = nil, seed = 384756192, lazy = false },
		{ id = "YellowPerch", assist = false, start = 0.45, seed = 777123987, lazy = false },
		{ id = "LargemouthBass", assist = false, start = nil, seed = 31415926, lazy = true },
		{ id = "CommonCarp", assist = true, start = nil, seed = 27182818, lazy = true },
	}
	local DTS = { 1 / 30, 1 / 60, 1 / 45, 1 / 30, 1 / 20 }

	local TRACE = {
		{ result = "won", steps = 160, progress = 1.000000000000, samples = {
			{ 8, 0.500000000000, 0.337032796462, 0.361666666667, "normal", 0, 0 },
			{ 16, 0.487610947526, 0.579304953441, 0.417888888889, "normal", 0, 1 },
			{ 24, 0.530145283346, 0.556174077798, 0.475333333333, "normal", 0, 2 },
			{ 32, 0.584589727791, 0.555902811728, 0.525444444444, "normal", 0, 3 },
			{ 40, 0.950000000000, 0.832790909263, 0.585333333333, "normal", 0, 3 },
			{ 48, 0.950000000000, 0.875000000000, 0.635444444444, "normal", 0, 3 },
			{ 56, 0.950000000000, 0.875000000000, 0.691666666667, "normal", 0, 3 },
			{ 64, 0.950000000000, 0.875000000000, 0.749111111111, "normal", 0, 3 },
			{ 72, 0.950000000000, 0.875000000000, 0.799222222222, "normal", 1, 3 },
			{ 80, 0.950000000000, 0.875000000000, 0.859111111111, "normal", 1, 3 },
			{ 88, 0.407888888889, 0.791635444951, 0.843888888889, "run", 1, 3 },
			{ 96, 0.080000000000, 0.589936856327, 0.792777777778, "run", 1, 3 },
			{ 104, 0.080000000000, 0.369557251659, 0.740555555556, "run", 1, 3 },
			{ 112, 0.080000000000, 0.176089873642, 0.711333333333, "run", 1, 3 },
			{ 120, 0.080000000000, 0.179099619491, 0.726888888889, "rest", 1, 3 },
			{ 128, 0.080000000000, 0.125000000000, 0.777000000000, "rest", 1, 3 },
			{ 136, 0.080000000000, 0.125000000000, 0.833222222222, "rest", 1, 3 },
			{ 144, 0.080000000000, 0.125000000000, 0.890666666667, "rest", 1, 3 },
			{ 152, 0.080000000000, 0.125583408869, 0.940777777778, "normal", 1, 3 },
			{ 160, 0.080000000000, 0.125000000000, 1.000000000000, "normal", 1, 3 },
		} },
		{ result = "won", steps = 134, progress = 1.000000000000, samples = {
			{ 8, 0.500000000000, 0.335483129653, 0.373166666667, "normal", 0, 0 },
			{ 16, 0.500000000000, 0.561762851584, 0.414055555556, "normal", 0, 0 },
			{ 24, 0.500000000000, 0.531923451273, 0.455833333333, "normal", 0, 0 },
			{ 32, 0.500000000000, 0.497210568157, 0.492277777778, "normal", 0, 0 },
			{ 40, 0.500000000000, 0.516968554474, 0.535833333333, "normal", 0, 0 },
			{ 48, 0.500000000000, 0.520518388209, 0.572277777778, "normal", 0, 0 },
			{ 56, 0.500000000000, 0.528011867164, 0.613166666667, "normal", 0, 0 },
			{ 64, 0.500000000000, 0.542674928066, 0.654944444444, "normal", 0, 0 },
			{ 72, 0.500000000000, 0.537290897309, 0.691388888889, "normal", 0, 0 },
			{ 80, 0.500000000000, 0.544143699012, 0.734944444444, "normal", 0, 0 },
			{ 88, 0.500000000000, 0.541833049678, 0.771388888889, "normal", 0, 0 },
			{ 96, 0.500000000000, 0.542191080235, 0.812277777778, "normal", 0, 0 },
			{ 104, 0.500000000000, 0.385282842263, 0.854055555556, "normal", 0, 0 },
			{ 112, 0.500000000000, 0.551707112113, 0.890500000000, "normal", 0, 0 },
			{ 120, 0.500000000000, 0.544681388789, 0.934055555556, "normal", 0, 0 },
			{ 128, 0.500000000000, 0.542370739455, 0.970500000000, "normal", 0, 0 },
		} },
		{ result = "won", steps = 145, progress = 1.000000000000, samples = {
			{ 8, 0.500000000000, 0.338065907668, 0.395000000000, "normal", 0, 0 },
			{ 16, 0.276111111111, 0.495649735223, 0.438333333333, "normal", 0, 1 },
			{ 24, 0.241703392585, 0.332500719800, 0.451000000000, "normal", 0, 1 },
			{ 32, 0.241703392585, 0.260477992476, 0.505666666667, "normal", 0, 1 },
			{ 40, 0.241703392585, 0.289721380978, 0.571000000000, "normal", 0, 1 },
			{ 48, 0.241703392585, 0.220274475217, 0.625666666667, "normal", 0, 1 },
			{ 56, 0.508925614807, 0.445142188762, 0.687000000000, "normal", 0, 2 },
			{ 64, 0.637271378253, 0.702236426033, 0.749666666667, "normal", 0, 2 },
			{ 72, 0.341160267142, 0.602455745451, 0.748333333333, "normal", 0, 4 },
			{ 80, 0.117888542307, 0.383734515975, 0.715666666667, "normal", 0, 4 },
			{ 88, 0.260775887656, 0.287700487586, 0.756333333333, "normal", 0, 5 },
			{ 96, 0.390775887656, 0.346073382803, 0.817666666667, "normal", 0, 6 },
			{ 104, 0.602707137063, 0.298151609295, 0.824333333333, "normal", 0, 6 },
			{ 112, 0.349929359285, 0.512391645614, 0.853000000000, "normal", 0, 7 },
			{ 120, 0.236892953287, 0.422407928094, 0.820333333333, "normal", 0, 7 },
			{ 128, 0.236892953287, 0.240432381394, 0.875000000000, "normal", 0, 7 },
			{ 136, 0.236892953287, 0.250812284794, 0.936333333333, "normal", 0, 7 },
			{ 144, 0.236892953287, 0.274512184077, 0.999000000000, "normal", 0, 7 },
		} },
		{ result = "won", steps = 133, progress = 1.000000000000, samples = {
			{ 8, 0.512158485674, 0.337032796462, 0.461111111111, "normal", 0, 0 },
			{ 16, 0.507035711038, 0.530043114114, 0.492222222222, "normal", 0, 0 },
			{ 24, 0.499385478704, 0.564767388525, 0.544444444444, "normal", 1, 0 },
			{ 32, 0.488728074581, 0.570110181660, 0.590000000000, "normal", 1, 0 },
			{ 40, 0.067050132109, 0.428573998496, 0.597777777778, "run", 1, 0 },
			{ 48, 0.047398355758, 0.242356442620, 0.552222222222, "run", 1, 0 },
			{ 56, 0.063717510049, 0.120000000000, 0.583333333333, "run", 1, 0 },
			{ 64, 0.029184443351, 0.162102965097, 0.615555555556, "run", 1, 0 },
			{ 72, 0.058895400577, 0.165100476101, 0.661111111111, "rest", 1, 0 },
			{ 80, 0.047161230467, 0.120000000000, 0.702222222222, "rest", 1, 0 },
			{ 88, 0.084239365994, 0.153435897852, 0.747777777778, "rest", 1, 0 },
			{ 96, 0.090273586123, 0.155524455792, 0.798888888889, "rest", 1, 0 },
			{ 104, 0.078425916332, 0.120000000000, 0.837777777778, "normal", 1, 0 },
			{ 112, 0.090362959069, 0.120000000000, 0.883333333333, "normal", 1, 0 },
			{ 120, 0.091535515698, 0.144278113344, 0.937777777778, "normal", 2, 0 },
			{ 128, 0.112017507605, 0.120000000000, 0.970000000000, "normal", 2, 0 },
		} },
		{ result = "won", steps = 74, progress = 1.000000000000, samples = {
			{ 8, 0.500000000000, 0.338582463271, 0.399500000000, "normal", 0, 0 },
			{ 16, 0.448492123079, 0.596847055298, 0.476166666667, "normal", 0, 2 },
			{ 24, 0.493492123079, 0.505387432385, 0.534100000000, "normal", 0, 3 },
			{ 32, 0.671957943298, 0.673183403006, 0.602433333333, "normal", 0, 3 },
			{ 40, 0.915539889303, 0.790000000000, 0.684100000000, "normal", 0, 4 },
			{ 48, 0.950000000000, 0.790000000000, 0.752433333333, "normal", 0, 5 },
			{ 56, 0.950000000000, 0.790000000000, 0.829100000000, "normal", 0, 5 },
			{ 64, 0.950000000000, 0.790000000000, 0.907433333333, "normal", 0, 6 },
			{ 72, 0.950000000000, 0.790000000000, 0.975766666667, "normal", 0, 6 },
		} },
		{ result = "won", steps = 75, progress = 1.000000000000, samples = {
			{ 8, 0.500000000000, 0.338065907668, 0.419333333333, "normal", 0, 0 },
			{ 16, 0.500000000000, 0.590999688012, 0.490888888889, "normal", 0, 0 },
			{ 24, 0.500000000000, 0.498019913948, 0.564000000000, "normal", 0, 0 },
			{ 32, 0.500000000000, 0.511887378434, 0.627777777778, "normal", 0, 0 },
			{ 40, 0.500000000000, 0.528158325295, 0.704000000000, "normal", 0, 0 },
			{ 48, 0.533333333333, 0.551363559008, 0.767777777778, "normal", 0, 1 },
			{ 56, 0.638251837909, 0.666474979147, 0.839333333333, "normal", 0, 1 },
			{ 64, 0.638251837909, 0.674097088021, 0.912444444444, "normal", 0, 1 },
			{ 72, 0.638251837909, 0.692485234236, 0.976222222222, "normal", 0, 1 },
		} },
		{ result = "lost", steps = 394, progress = 0.000000000000, samples = {
			{ 8, 0.500000000000, 0.617589549462, 0.450111111111, "normal", 0, 0 },
			{ 16, 0.500000000000, 0.596155407063, 0.420000000000, "normal", 0, 0 },
			{ 24, 0.500000000000, 0.393947126394, 0.477444444444, "normal", 0, 0 },
			{ 32, 0.227777777778, 0.202148814211, 0.513555555556, "normal", 0, 1 },
			{ 40, 0.168749035932, 0.125000000000, 0.573444444444, "normal", 0, 1 },
			{ 48, 0.168749035932, 0.125000000000, 0.605777777778, "normal", 0, 1 },
			{ 56, 0.168749035932, 0.241524156395, 0.622888888889, "normal", 0, 1 },
			{ 64, 0.168749035932, 0.456911118467, 0.580000000000, "normal", 0, 1 },
			{ 72, 0.168749035932, 0.337676998011, 0.534444444444, "normal", 0, 1 },
			{ 80, 0.168749035932, 0.125000000000, 0.580333333333, "normal", 0, 1 },
			{ 88, 0.464304591487, 0.125000000000, 0.565111111111, "normal", 0, 2 },
			{ 96, 0.624515718848, 0.125000000000, 0.514000000000, "normal", 0, 2 },
			{ 104, 0.624515718848, 0.125000000000, 0.461777777778, "normal", 0, 2 },
			{ 112, 0.624515718848, 0.306010125418, 0.416222222222, "normal", 0, 2 },
			{ 120, 0.624515718848, 0.418146508557, 0.361777777778, "normal", 0, 2 },
			{ 128, 0.577849052181, 0.259597178826, 0.316222222222, "normal", 0, 3 },
			{ 136, 0.525022124525, 0.125000000000, 0.265111111111, "normal", 0, 3 },
			{ 144, 0.525022124525, 0.125000000000, 0.212888888889, "normal", 1, 3 },
			{ 152, 0.472133235636, 0.125000000000, 0.167333333333, "run", 1, 3 },
			{ 160, 0.080000000000, 0.192607056419, 0.158444444444, "run", 1, 3 },
			{ 168, 0.080000000000, 0.427420211722, 0.112888888889, "run", 1, 3 },
			{ 176, 0.080000000000, 0.357027558010, 0.061777777778, "run", 1, 3 },
			{ 184, 0.080000000000, 0.149884078026, 0.044555555556, "rest", 1, 3 },
			{ 192, 0.080000000000, 0.125000000000, 0.094666666667, "rest", 1, 3 },
			{ 200, 0.080000000000, 0.125000000000, 0.154555555556, "rest", 1, 3 },
			{ 208, 0.080000000000, 0.125000000000, 0.170888888889, "rest", 1, 3 },
			{ 216, 0.080000000000, 0.264498958929, 0.153111111111, "rest", 1, 3 },
			{ 224, 0.080000000000, 0.461093858902, 0.100888888889, "normal", 1, 3 },
			{ 232, 0.050000000000, 0.331559965433, 0.055333333333, "normal", 1, 4 },
			{ 240, 0.050000000000, 0.125000000000, 0.035888888889, "normal", 1, 4 },
			{ 248, 0.050000000000, 0.125000000000, 0.086000000000, "normal", 1, 4 },
			{ 256, 0.050000000000, 0.125000000000, 0.142222222222, "normal", 1, 4 },
			{ 264, 0.050000000000, 0.125000000000, 0.133888888889, "normal", 1, 4 },
			{ 272, 0.050000000000, 0.342589549462, 0.109333333333, "normal", 1, 5 },
			{ 280, 0.050000000000, 0.370734770191, 0.054888888889, "normal", 1, 5 },
			{ 288, 0.050000000000, 0.199402591856, 0.009333333333, "normal", 1, 5 },
			{ 296, 0.050000000000, 0.125000000000, 0.065555555556, "normal", 1, 5 },
			{ 304, 0.050000000000, 0.125000000000, 0.123000000000, "normal", 1, 5 },
			{ 312, 0.050000000000, 0.125000000000, 0.166000000000, "normal", 1, 5 },
			{ 320, 0.050000000000, 0.224740868477, 0.141111111111, "normal", 1, 5 },
			{ 328, 0.050000000000, 0.450896205747, 0.095555555556, "normal", 1, 5 },
			{ 336, 0.050000000000, 0.354132743948, 0.044444444444, "normal", 1, 5 },
			{ 344, 0.050000000000, 0.144330988814, 0.013222222222, "normal", 1, 5 },
			{ 352, 0.050000000000, 0.125000000000, 0.063333333333, "normal", 1, 5 },
			{ 360, 0.050000000000, 0.125000000000, 0.123222222222, "normal", 1, 6 },
			{ 368, 0.050000000000, 0.125000000000, 0.139555555556, "normal", 1, 6 },
			{ 376, 0.050000000000, 0.282109133608, 0.113111111111, "normal", 1, 6 },
			{ 384, 0.050000000000, 0.432400690693, 0.060888888889, "normal", 1, 6 },
			{ 392, 0.050000000000, 0.286118033987, 0.015333333333, "normal", 1, 6 },
		} },
		{ result = "won", steps = 575, progress = 1.000000000000, samples = {
			{ 8, 0.500000000000, 0.608330419697, 0.434166666667, "normal", 0, 0 },
			{ 16, 0.500000000000, 0.582180850653, 0.472500000000, "normal", 0, 0 },
			{ 24, 0.500000000000, 0.379497237509, 0.511666666667, "normal", 1, 0 },
			{ 32, 0.500000000000, 0.189000000000, 0.511300000000, "normal", 1, 0 },
			{ 40, 0.395000000000, 0.189000000000, 0.491700000000, "dive", 1, 0 },
			{ 48, 0.219021352571, 0.189000000000, 0.511833333333, "dive", 1, 0 },
			{ 56, 0.219021352571, 0.300565681655, 0.527433333333, "dive", 1, 0 },
			{ 64, 0.219021352571, 0.505433908367, 0.520966666667, "normal", 1, 0 },
			{ 72, 0.219021352571, 0.384388998057, 0.513200000000, "normal", 1, 0 },
			{ 80, 0.239021352571, 0.189000000000, 0.554033333333, "normal", 1, 1 },
			{ 88, 0.344556550134, 0.189000000000, 0.588200000000, "normal", 1, 1 },
			{ 96, 0.344556550134, 0.189000000000, 0.626533333333, "normal", 1, 1 },
			{ 104, 0.501223216801, 0.189000000000, 0.620066666667, "normal", 1, 2 },
			{ 112, 0.570251358366, 0.362307566890, 0.603666666667, "normal", 1, 2 },
			{ 120, 0.570251358366, 0.466124761169, 0.644500000000, "normal", 1, 2 },
			{ 128, 0.570251358366, 0.306723114081, 0.655233333333, "normal", 1, 2 },
			{ 136, 0.570251358366, 0.189000000000, 0.636833333333, "normal", 1, 2 },
			{ 144, 0.570251358366, 0.189000000000, 0.618033333333, "normal", 1, 2 },
			{ 152, 0.570251358366, 0.189000000000, 0.601633333333, "normal", 1, 2 },
			{ 160, 0.570251358366, 0.253730160401, 0.582033333333, "normal", 2, 2 },
			{ 168, 0.570251358366, 0.478387221684, 0.589066666667, "normal", 2, 2 },
			{ 176, 0.385251358366, 0.404425285842, 0.627400000000, "dive", 2, 2 },
			{ 184, 0.155462551869, 0.196922008996, 0.666566666667, "dive", 2, 2 },
			{ 192, 0.155462551869, 0.189000000000, 0.700733333333, "dive", 2, 2 },
			{ 200, 0.155462551869, 0.189000000000, 0.741566666667, "normal", 2, 2 },
			{ 208, 0.155462551869, 0.189000000000, 0.756100000000, "normal", 2, 2 },
			{ 216, 0.155462551869, 0.322562833017, 0.775833333333, "normal", 2, 2 },
			{ 224, 0.155462551869, 0.509052321544, 0.757033333333, "normal", 2, 2 },
			{ 232, 0.168795885203, 0.377957298782, 0.740633333333, "normal", 2, 3 },
			{ 240, 0.332129218536, 0.189000000000, 0.781466666667, "normal", 2, 3 },
			{ 248, 0.468795885203, 0.189000000000, 0.781100000000, "normal", 2, 3 },
			{ 256, 0.622129218536, 0.189000000000, 0.762700000000, "normal", 2, 3 },
			{ 264, 0.755462551869, 0.189000000000, 0.743900000000, "normal", 2, 3 },
			{ 272, 0.755462551869, 0.397330419697, 0.727500000000, "normal", 2, 3 },
			{ 280, 0.825462551869, 0.419188082409, 0.707900000000, "normal", 2, 4 },
			{ 288, 0.950000000000, 0.247315738111, 0.691500000000, "normal", 2, 5 },
			{ 296, 0.950000000000, 0.189000000000, 0.673100000000, "normal", 3, 5 },
			{ 304, 0.950000000000, 0.189000000000, 0.654300000000, "normal", 3, 5 },
			{ 312, 0.885000000000, 0.189000000000, 0.637900000000, "dive", 3, 5 },
			{ 320, 0.712884114521, 0.284496576201, 0.618300000000, "dive", 3, 5 },
			{ 328, 0.712884114521, 0.500600144695, 0.601900000000, "dive", 3, 5 },
			{ 336, 0.712884114521, 0.400903981542, 0.583500000000, "dive", 3, 5 },
			{ 344, 0.712884114521, 0.190806599247, 0.564700000000, "normal", 3, 5 },
			{ 352, 0.712884114521, 0.189000000000, 0.548300000000, "normal", 3, 5 },
			{ 360, 0.712884114521, 0.189000000000, 0.528700000000, "normal", 4, 5 },
			{ 368, 0.712884114521, 0.189000000000, 0.512300000000, "normal", 4, 5 },
			{ 376, 0.622884114521, 0.339423638560, 0.493900000000, "dive", 4, 5 },
			{ 384, 0.387884114521, 0.480721193598, 0.528133333333, "dive", 4, 5 },
			{ 392, 0.182884114521, 0.333288028801, 0.562300000000, "dive", 4, 5 },
			{ 400, 0.144169088162, 0.189000000000, 0.603133333333, "normal", 4, 5 },
			{ 408, 0.144169088162, 0.189000000000, 0.637300000000, "normal", 4, 5 },
			{ 416, 0.144169088162, 0.189000000000, 0.675633333333, "normal", 4, 5 },
			{ 424, 0.144169088162, 0.225319548339, 0.685866666667, "normal", 4, 5 },
			{ 432, 0.144169088162, 0.451014674924, 0.692900000000, "normal", 4, 5 },
			{ 440, 0.144169088162, 0.416008494898, 0.673300000000, "normal", 4, 5 },
			{ 448, 0.144169088162, 0.238556790379, 0.691433333333, "normal", 4, 5 },
			{ 456, 0.144169088162, 0.189000000000, 0.729766666667, "normal", 4, 5 },
			{ 464, 0.144169088162, 0.189000000000, 0.768933333333, "normal", 4, 5 },
			{ 472, 0.144169088162, 0.189000000000, 0.789666666667, "normal", 4, 5 },
			{ 480, 0.144169088162, 0.306007763827, 0.805700000000, "normal", 4, 5 },
			{ 488, 0.144169088162, 0.510774084307, 0.793000000000, "normal", 4, 5 },
			{ 496, 0.144169088162, 0.394801058144, 0.774600000000, "normal", 4, 5 },
			{ 504, 0.144169088162, 0.189000000000, 0.801433333333, "normal", 4, 5 },
			{ 512, 0.144169088162, 0.189000000000, 0.835600000000, "normal", 4, 5 },
			{ 520, 0.144169088162, 0.189000000000, 0.876433333333, "normal", 4, 5 },
			{ 528, 0.144169088162, 0.189000000000, 0.881666666667, "normal", 4, 5 },
			{ 536, 0.144169088162, 0.373898044147, 0.899600000000, "normal", 4, 5 },
			{ 544, 0.144169088162, 0.438792156340, 0.880800000000, "normal", 4, 5 },
			{ 552, 0.144169088162, 0.274525311077, 0.891533333333, "normal", 4, 5 },
			{ 560, 0.144169088162, 0.189000000000, 0.932366666667, "normal", 4, 5 },
			{ 568, 0.144169088162, 0.189000000000, 0.966533333333, "normal", 4, 5 },
		} },
	}

	-- The same scripted fight the trace was recorded with, on a chosen load and drag.
	local function runCase(c, load: number?, drag: any?)
		local s = FightModel.new(FishData.byId[c.id].fight, c.assist, 1, c.start, load, drag)
		s.rng = lcg(c.seed) :: any
		local samples = {}
		local result = "none"
		local steps = 0
		local was = false
		for i = 1, 2400 do
			local hold
			if c.lazy then
				hold = (i % 53) < 9
			else
				hold = (s.zonePos < s.fishPos or s.idle > 0.96) and (i % 97) > 7
			end
			if hold and not was then
				FightModel.press(s)
			end
			was = hold
			local r = FightModel.step(s, DTS[(i % #DTS) + 1], hold)
			steps = i
			if i % 8 == 0 then
				table.insert(samples, { i, s.fishPos, s.zonePos, s.progress, s.mode, s.tells, s.darts })
			end
			if r then
				result = r
				break
			end
		end
		return result, steps, s.progress, samples
	end

	t.test("Medium drag is the fight before L4d, step for step (recorded trace)", function()
		local variants = {
			{ load = nil, drag = nil, name = "default" },
			{ load = 0, drag = "Medium", name = "Medium" },
			{ load = 0.59, drag = "Medium", name = "Medium, fish at 59 percent of the line" },
		}
		for _, v in variants do
			for i, c in CASES do
				local want = TRACE[i]
				local result, steps, progress, samples = runCase(c, v.load, v.drag)
				local tag = string.format("%s, case %d (%s)", v.name, i, c.id)
				t.eq(result, want.result, tag .. " result")
				t.eq(steps, want.steps, tag .. " steps")
				t.ok(math.abs(progress - want.progress) < 1e-9, tag .. " final progress")
				t.eq(#samples, #want.samples, tag .. " sample count")
				for j, w in want.samples do
					local x = samples[j]
					t.eq(x[1], w[1], tag .. " sample step")
					for k = 2, 4 do
						t.ok(math.abs(x[k] - w[k]) < 1e-9, string.format("%s step %d field %d: %.12f vs %.12f", tag, w[1], k, x[k], w[k]))
					end
					t.eq(x[5], w[5], tag .. " mode at step " .. w[1])
					t.eq(x[6], w[6], tag .. " tells at step " .. w[1])
					t.eq(x[7], w[7], tag .. " darts at step " .. w[1])
				end
			end
		end
	end)

	t.test("Medium with a light fish matches the default fight exactly, every field, every step", function()
		for i, c in CASES do
			local a = FightModel.new(FishData.byId[c.id].fight, c.assist, 1, c.start)
			local b = FightModel.new(FishData.byId[c.id].fight, c.assist, 1, c.start, 0.59, "Medium")
			a.rng = lcg(c.seed) :: any
			b.rng = lcg(c.seed) :: any
			for n = 1, 2400 do
				local hold = (n % 41) < 23
				if hold and n % 41 == 0 then
					FightModel.press(a)
					FightModel.press(b)
				end
				local dt = DTS[(n % #DTS) + 1]
				local ra = FightModel.step(a, dt, hold)
				local rb = FightModel.step(b, dt, hold)
				t.eq(rb, ra, "case " .. i .. " result at step " .. n)
				for _, f in { "fishPos", "zonePos", "zoneVel", "progress", "fishTarget", "idle", "modeTimer", "pendingTimer" } do
					t.ok((a :: any)[f] == (b :: any)[f], string.format("case %d step %d %s differs", i, n, f))
				end
				t.eq(b.strain, 0, "no strain under 60 percent on Medium")
				if ra then
					break
				end
			end
		end
	end)

	t.test("rods carry a line rating: Willow 6 lb, Fiberglass 10 lb, Graphite 15 lb", function()
		t.eq(RodData.byId.Willow.lineLb, 6)
		t.eq(RodData.byId.Fiberglass.lineLb, 10)
		t.eq(RodData.byId.Graphite.lineLb, 15)
		t.eq(RodData.lineText("Graphite"), "15 lb line")
		local sixPounds = 6 * 0.45359237
		t.ok(math.abs(RodData.lineLoad(sixPounds, "Willow") - 1) < 1e-9, "6 lb on a 6 lb line is load 1")
		t.ok(math.abs(RodData.lineLoad(sixPounds, "Graphite") - 0.4) < 1e-9, "6 lb on a 15 lb line is load 0.4")
		t.eq(FightModel.nextDrag("Light"), "Medium")
		t.eq(FightModel.nextDrag("Medium"), "Tight")
		t.eq(FightModel.nextDrag("Tight"), "Light")
	end)

	-- Watch a fish with progress frozen (the fight never ends by itself) under an input policy.
	-- Returns "snapped" or "none", the highest strain seen, and when it ended.
	local function strainRun(id: string, load: number, drag: string, seed: number, secs: number, policy: (any) -> boolean)
		local s = FightModel.new(FishData.byId[id].fight, false, seed, nil, load, drag :: any)
		local was = false
		local peak = 0
		for _ = 1, math.floor(secs / DT) do
			local hold = policy(s)
			if hold and not was then
				FightModel.press(s)
			end
			was = hold
			local r = FightModel.step(s, DT, hold)
			s.progress = 0.5
			peak = math.max(peak, s.strain)
			if r == "snapped" then
				return "snapped", peak, s.t
			end
		end
		return "none", peak, s.t
	end

	local function holdAlways(_s)
		return true
	end
	local function tracker(s)
		return s.zonePos < s.fishPos or s.idle > Config.FIGHT_IDLE_GRACE * 0.8
	end
	-- Holds all the time, but lets go `reaction` seconds after a big move's tell shows, until
	-- the move is over.
	local function easer(reaction: number)
		local seen: number? = nil
		return function(s)
			if FightModel.bigMove(s) then
				seen = (seen or 0) + DT
				return (seen :: number) < reaction
			end
			seen = nil
			return true
		end
	end

	local big = {}
	for _, sp in FishData.list do
		if FightModel.BIG_MOVE_STYLES[sp.fight.style or "tugger"] then
			table.insert(big, sp.id)
		end
	end

	t.test("on Medium a fish under 60 percent of the line's rating never strains it", function()
		t.ok(#big >= 8, "fish with big moves " .. #big)
		for _, id in big do
			for seed = 1, 6 do
				for _, policy in { holdAlways, tracker } do
					local r, peak = strainRun(id, 0.59, "Medium", seed, 30, policy)
					t.eq(r, "none", id .. " seed " .. seed)
					t.eq(peak, 0, id .. " strain")
				end
			end
		end
		-- And a fish at the line's full rating still can't snap it in one run on Medium.
		t.ok(FightModel.strainRise(1, "Medium") * (Config.TELL_LEAD + 1.0) < 1, "one run at load 1 on Medium")
	end)

	t.test("on Tight a fish over half the line's rating snaps if you hold through a big move", function()
		for _, id in big do
			for seed = 1, 6 do
				local r = strainRun(id, 0.55, "Tight", seed, 60, holdAlways)
				t.eq(r, "snapped", id .. " seed " .. seed .. " held through on Tight")
			end
		end
	end)

	t.test("a big catfish on the Willow rod: holding through its dive snaps the line, easing off at the tell lands it", function()
		local cat = FishData.byId.ChannelCatfish
		local kg = cat.weightCoef * 80 ^ 3 -- an 80 cm catfish, about 12 lb
		local load = RodData.lineLoad(kg, "Willow")
		t.ok(load > 1.8 and load < 2.3, string.format("load %.2f", load))
		for seed = 1, 8 do
			t.eq((strainRun("ChannelCatfish", load, "Tight", seed, 60, holdAlways)), "snapped", "held through, seed " .. seed)
			t.eq((strainRun("ChannelCatfish", load, "Medium", seed, 60, holdAlways)), "snapped", "12 lb on 6 lb line snaps on Medium too, seed " .. seed)
			local r, peak = strainRun("ChannelCatfish", load, "Tight", seed, 60, easer(0.4))
			t.eq(r, "none", "eased at the tell, seed " .. seed)
			t.ok(peak < 1, "peak " .. peak)
		end
		-- And a real fight (progress not frozen): a player who tracks the fish and eases off on
		-- every tell lands it on Tight.
		local wins = 0
		for seed = 1, 10 do
			local s = FightModel.new(RodData.applyFight(cat.fight, "Willow"), false, seed, nil, load, "Tight")
			local ease = easer(0.4)
			local was = false
			for _ = 1, math.floor(90 / DT) do
				local hold = ease(s) and tracker(s)
				if hold and not was then
					FightModel.press(s)
				end
				was = hold
				local r = FightModel.step(s, DT, hold)
				t.ok(r ~= "snapped", "snapped while easing, seed " .. seed)
				if r then
					if r == "won" then
						wins += 1
					end
					break
				end
			end
		end
		t.ok(wins >= 7, "landed " .. wins .. " of 10")
	end)

	t.test("easing off at the tell always saves the line, even a monster on Tight", function()
		for _, id in big do
			for seed = 1, 10 do
				local r, peak = strainRun(id, 6, "Tight", seed, 60, easer(0.4))
				t.eq(r, "none", id .. " seed " .. seed)
				t.ok(peak < 0.95, string.format("%s peak %.2f", id, peak))
			end
		end
		t.ok(Config.STRAIN_RISE_MAX * (Config.TELL_LEAD + Config.STRAIN_REEL_WINDOW) < 1, "reeling through a whole tell, and one last tap, never snaps the line")
	end)

	t.test("Light drag never snaps, however heavy the fish", function()
		for _, id in big do
			for seed = 1, 3 do
				local r, peak = strainRun(id, 10, "Light", seed, 40, holdAlways)
				t.eq(r, "none", id .. " seed " .. seed)
				t.eq(peak, 0, id .. " strain on Light")
			end
		end
		t.eq(FightModel.strainRise(100, "Light"), 0)
	end)

	t.test("Light fills slower and a running fish takes line; Tight fills faster", function()
		local bass = FishData.byId.LargemouthBass.fight
		for seed = 1, 5 do
			local light = FightModel.new(bass, false, seed, 0.6, 0, "Light")
			local med = FightModel.new(bass, false, seed, 0.6, 0, "Medium")
			local tight = FightModel.new(bass, false, seed, 0.6, 0, "Tight")
			local ran = false
			for _ = 1, math.floor(3 / DT) do
				local hold = tracker(med)
				for _, s in { light, med, tight } do
					if hold and s.idle > 0.5 then
						FightModel.press(s)
					end
					FightModel.step(s, DT, hold)
					s.progress = math.clamp(s.progress, 0.05, 0.95) -- keep all three going
				end
				ran = ran or med.mode == "run"
			end
			t.ok(light.progress <= med.progress + 1e-9, "light " .. light.progress .. " vs medium " .. med.progress)
			t.ok(tight.progress >= med.progress - 1e-9, "tight " .. tight.progress .. " vs medium " .. med.progress)
		end
		local gill = FishData.byId.Bluegill.fight
		local m, ti = FightModel.minSeconds(gill, false), FightModel.minSeconds(gill, false, nil, "Tight")
		t.ok(math.abs(ti - m / Config.DRAG_TIGHT_GAIN) < 1e-9, "Tight minimum time")
		t.ok(Config.DRAG_TIGHT_GAIN >= 1.25 and Config.DRAG_TIGHT_GAIN <= 1.35, "Tight fill rate " .. Config.DRAG_TIGHT_GAIN)
		t.eq(FightModel.minSeconds(gill, false, nil, "Medium"), m)
		t.eq(FightModel.minSeconds(gill, false, nil, "Light"), m)
	end)

	t.test("drag can change any time; Tight at any point is remembered for the server", function()
		local s = FightModel.new(FishData.byId.Bluegill.fight, false, 1)
		t.eq(s.drag, "Medium")
		t.ok(not s.usedTight, "not tight yet")
		FightModel.setDrag(s, "Tight")
		FightModel.step(s, DT, true)
		FightModel.setDrag(s, "Light")
		t.eq(s.drag, "Light")
		t.ok(s.usedTight, "remembers Tight")
		FightModel.setDrag(s, "Bogus" :: any)
		t.eq(s.drag, "Light", "an unknown drag is ignored")
		t.ok(FightModel.new(FishData.byId.Bluegill.fight, false, 1, nil, 0, "Tight").usedTight, "starting on Tight counts")
	end)

	t.test("a tracking player on Tight lands every light fish, no faster than Tight's minimum", function()
		for _, sp in FishData.list do
			for seed = 1, 3 do
				local s = FightModel.new(sp.fight, false, seed, nil, 0.2, "Tight")
				local was, result = false, nil
				for _ = 1, math.floor(60 / DT) do
					local hold = tracker(s)
					if hold and not was then
						FightModel.press(s)
					end
					was = hold
					result = FightModel.step(s, DT, hold)
					if result then
						break
					end
				end
				t.eq(result, "won", sp.id .. " seed " .. seed)
				t.ok(s.t >= FightModel.minSeconds(sp.fight, false, nil, "Tight") - 1e-6, sp.id .. " faster than Tight's minimum")
			end
		end
	end)

	t.test("the server refuses an impossible snap and a too-fast win", function()
		local cat = FishData.byId.ChannelCatfish.fight
		local gill = FishData.byId.Bluegill.fight
		local check = FightModel.checkFor(cat, nil, 2.0)
		local tightReport = { tight = true, drag = "Tight" }
		-- Snaps.
		t.eq((FightModel.judge(check, "snapped", tightReport, 3)), "snapped", "a heavy catfish on Tight")
		t.eq((FightModel.judge(check, "snapped", { tight = false, drag = "Medium" }, 3)), "snapped", "12 lb on 6 lb, Medium")
		t.eq((FightModel.judge(check, "snapped", tightReport, 0.2)), "lost", "too quick for strain to build")
		t.eq((FightModel.judge(check, "snapped", { drag = "Light" }, 5)), "lost", "Light never snaps")
		t.eq((FightModel.judge(check, "snapped", nil, 5)), "lost", "no drag reported")
		t.eq((FightModel.judge(FightModel.checkFor(gill, nil, 3), "snapped", tightReport, 5)), "lost", "a bluegill makes no big moves")
		t.eq((FightModel.judge(FightModel.checkFor(cat, nil, 0.5), "snapped", { drag = "Medium" }, 5)), "lost", "under 60 percent on Medium")
		t.eq((FightModel.judge(FightModel.checkFor(cat, nil, 0.2), "snapped", tightReport, 5)), "lost", "under Tight's free share")
		local _, why = FightModel.judge(check, "snapped", { drag = "Light" }, 5)
		t.ok(type(why) == "string", "a refusal says why")
		-- Wins.
		t.ok(check.minSecsTight < check.minSecs * 0.8, "Tight's minimum is shorter")
		t.eq((FightModel.judge(check, "won", tightReport, check.minSecsTight)), "won", "a fast Tight win")
		t.eq((FightModel.judge(check, "won", tightReport, check.minSecsTight * 0.8)), "lost", "too fast even for Tight")
		t.eq((FightModel.judge(check, "won", { tight = false, drag = "Medium" }, check.minSecsTight)), "lost", "Tight speed without Tight")
		t.eq((FightModel.judge(check, true, nil, check.minSecs)), "won", "older clients still send true")
		t.eq((FightModel.judge(check, "lost", nil, 10)), "lost")
		t.eq((FightModel.judge(check, "nonsense", nil, 10)), "lost")
	end)
end
