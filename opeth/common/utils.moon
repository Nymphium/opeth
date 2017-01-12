import concat from table
import char from string

--- utils
----{{{
zsplit = (n = 1) => [c for c in @\gmatch "."\rep n]
string = string  -- in THIS chunk, add `zsplit` to `string` module
string.zsplit = zsplit

map = (fn, xs) -> [fn x for x in *xs]
filter = (fn, xs) -> [x for x in *xs when fn x]
foldl = (fn, xr, xs) ->
	for x in *xs
		xr = fn xr, x
	xr

idcomp = (obj1, obj2) -> (tostring obj1) == (tostring obj2)
have = (t, e) -> (filter (=> (idcomp @, e) or @ == e), t)[1]
delete = (t, v) -> table.remove t, i for i = 1, #t when (idcomp t[i], v) or t[i] == v
last = => @[#@]
isk = (rk) -> rk < 0 and (rk % 256) != 0
cstid = (k) -> (math.abs k) % 256 + (k >= 0 and 1 or 0)

undecimal = do
	hexdecode = (cnt = 1) -> ("%02X"\rep cnt)\format

	-- `"ff"` -> `"11111111"`
	hextobin = do
		bintbl = {
			[0]: "0000", "0001", "0010", "0011", "0100", "0101", "0110", "0111",
			"1000", "1001", "1010", "1011", "1100", "1101", "1110", "1111"
		}
		(hex) -> concat map (=> bintbl[(tonumber "0x#{@}")]), hex\zsplit!

	-- `"00011", 4` -> `"0011"`
	adjustdigit = (r, a) ->
		if #r > a
			r\match("#{'.'\rep (#r - a)}(.*)")
		else
			"0"\rep(a - #r) .. r

	-- `"11111111"` -> `256`
	bintoint = (bin) ->
		i = -1
		with ret = 0
			for c in bin\reverse!\gmatch"."
				i += 1
				ret += 2^i * math.tointeger c

	-- `"0xff"` -> `256`
	hextoint = (hex) -> tonumber hex, 16

	-- `"41"` -> `"A"`
	hextochar = (ahex) -> string.char tonumber "0x#{ahex}"

	bintohex = do
		b2htbl = {
			["0000"]: "0", ["0001"]: "1", ["0010"]: "2", ["0011"]: "3",
			["0100"]: "4", ["0101"]: "5", ["0110"]: "6", ["0111"]: "7",
			["1000"]: "8", ["1001"]: "9", ["1010"]: "a", ["1011"]: "b",
			["1100"]: "c", ["1101"]: "d", ["1110"]: "e", ["1111"]: "f"
		}
		(b) -> b2htbl[b]

	inttobin = => (hextobin "%x"\format @)

	{:hexdecode, :hextobin, :adjustdigit, :bintoint, :hextoint, :hextochar, :bintohex, :inttobin}

deepcpy = (t, list = {}) -> with ret = {}
	for k, v in pairs t
		if type(v) == "table"
			kk = tostring v

			unless  list[kk]
				list[kk] = v
				ret[k] = deepcpy v, list
			else ret[k] = list[kk]
		else ret[k] = v

prerr = (ne, msg) -> not ne and io.stdout\write(msg , '\n')
----}}}

{:zsplit, :map, :filter, :foldl, :idcomp, :have, :delete, :last, :isk, :cstid, :prerr, :undecimal, :deepcpy}

