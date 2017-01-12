import concat from table
import char from string

import zsplit, map, prerr, undecimal from require'opeth.common.utils'
import hexdecode, hextobin, adjustdigit, bintoint, hextoint, hextochar, bintohex from undecimal

string = string
string.zsplit = zsplit

insgen = (ins) ->
	abc = (a, b, c) ->
		unpack map (=> with r = bintoint @ do if r > 255 then return 255 - r), {a, b, c}
	abx = (a, b, _b) ->
		unpack map bintoint, {a, b .. _b}
	asbx = (a, b, _b) ->
		mpjs = map bintoint, {a, b .. _b}
		mpjs[2] -= 2^17 - 1
		unpack mpjs
	ax = (a, _, _) -> bintoint a

	oplist = require'opeth.common.oplist' abc, abx, asbx, ax
	setmetatable oplist,
		__index: (v) =>
			if e = rawget @, v then e
			else error "invalid op: #{math.tointeger v}"

	b, c, a, i = (hextobin ins)\match "(#{"."\rep 9})(#{"."\rep 9})(#{"."\rep 8})(#{"."\rep 6})"
	{op, fn} = oplist[(bintoint i) + 1]

	{:op, fn(a, b, c)}

-- XXX: supported little endian 64bit float only
ieee2f = (rd) ->
	mantissa = (rd\byte 7) % 16
	for i = 6, 1, -1 do mantissa = mantissa * 256 + rd\byte i
	exponent = ((rd\byte 8) % 128) * 16 + ((rd\byte 7) // 16)
	exponent == 0 and 0 or ((mantissa * 2 ^ -52 + 1) * ((rd\byte 8) > 127 and -1 or 1)) * (2 ^ (exponent - 1023))

-- Reader class
-- add common operations to string and file object
-- {{{
class Reader
	read = (n) =>
		if n == "*a" then n = #@
		@cur += n
		local ret

		ret, @val = @val\match("^(#{(".")\rep n})(.*)$")
		ret
	new: (file, val) =>
		typ = type file
		file = switch typ
			when "userdata" then file
			when "string" then assert io.open(file, "r"), "Reader.new #1: failed to open file `#{file}'"
			when "nil" then nil
			else error "Reader.new receives only the type of string or file (got `#{typ}')"

		@val = val or  file\read "*a"
		@priv = {:file, val: @val}
		@cur = 1
	__shr: (n) => read @, n
	__len: => #@priv.val - @cur + 1
	close: =>
		@priv.file\close!
		@priv = nil
	seek: (s, ofs) =>
		if s == "seek"
			@cur = 0
			@val = @priv.val
		else
			unless ofs then @cur
			else
				if type(ofs) != "number"
					error "Reader\\seek #2 require number, got #{type ofs}"
				else
					@cur += ofs
					@val = @priv.val\match ".*$", @cur
-- }}}

-- decodeer
----{{{
read_header = (rd) ->
	{
		hsig: rd >> 4
		version: (hexdecode! (rd >> 1)\byte!)\gsub("(%d)(%d)", "%1.%2")
		format: (rd >> 1)\byte!
		luac_data: rd >> 6
		size: {
			int: (rd >> 1)\byte!
			size_t: (rd >> 1)\byte!
			instruction: (rd >> 1)\byte!
			lua_integer: (rd >> 1)\byte!
			lua_number: (rd >> 1)\byte!
		}

		-- luac_int, 0x5678
		endian: (rd >> 8) == ((char(0x00))\rep(6) .. char(0x56, 0x78)) and 0 or 1

		-- luac_num, checking IEEE754 float format
		luac_num: rd >> 9
	}

assert_header = (header) ->
	with header
		assert .hsig == char(0x1b, 0x4c, 0x75, 0x61), "HEADER SIGNATURE ERROR" -- header signature
		assert .luac_data == char(0x19, 0x93, 0x0d, 0x0a, 0x1a, 0x0a), "PLATFORM CONVERSION ERROR"
		assert 370.5 == (ieee2f .luac_num), "IEEE754 FLOAT ERROR"

providetools = (rd, header) ->
	import endian, size from header or read_header rd

	adjust_endianness = if endian < 1 then (=> @) else (xs) -> [xs[i] for i = #xs, 1, -1]
	undumpchar = -> hexdecode! (rd >> 1)\byte!
	undump_n = (n) -> hexdecode(n) unpack adjust_endianness {(rd >> n)\byte 1, n}
	undumpint = -> undump_n tonumber size.int

	:adjust_endianness, :undump_n, :undumpchar, :undumpint

read_fnblock = (rd, header = (read_header rd), has_debug) ->
	import adjust_endianness, undump_n, undumpchar, undumpint from providetools rd, header

	local instnum

	{
		chunkname:
			with ret = table.concat [char hextoint undumpchar! for _ = 2, hextoint undumpchar!]
				has_debug = has_debug or #ret > 0

		line: {
			defined: undumpint!
			lastdefined: undumpint!
		}

		params: undumpchar!
		vararg: undumpchar!
		regnum: undumpchar! -- number of register to use

		-- instructions: [num (size of int)] [instructions..]
		-- instruction: [inst(4)]
		instruction: do
			-- with num: hextoint undumpint!
			(=> [insgen undumpint! for _ = 1, @]) with num = hextoint undumpint!
				instnum = num

		-- constants: [num (size of int)] [constants..]
		-- constant: [type(1)] [...]
		constant: for _ = 1, hextoint undumpint!
			with type: (rd >> 1)\byte!
				.val = switch .type
					when  0x1
						-- bool
						undumpchar!
					when  0x3
						-- number
						ieee2f rd >> header.size.lua_number
					when 0x13
						-- signed integer
						n = undump_n header.size.lua_integer
						if n\match"^[^0-7]" then 0x10000000000000000 + hextoint n
						else hextoint n
					when  0x4, 0x14
						-- string
						if s = (=> concat adjust_endianness map hextochar, (undump_n @)\zsplit 2 if @ > 0) with len = hextoint undumpchar!
								if len == 0xff -- #str > 255
									len = hextoint undump_n header.size.lua_integer
								return len - 1 -- remove '\0' in internal expression
							s
						else ""
					else nil

		upvalue: for _ = 1, hextoint undumpint!
			u = adjust_endianness {(hextoint undumpchar!), (hextoint undumpchar!)}
			{reg: u[1], instack: u[2]} -- {reg, instack}, instack is whether it is in stack

		prototype: [read_fnblock rd, header, has_debug for i = 1, hextoint undumpint!]

		debug: with ret = {}
			.linenum = hextoint undumpint!

			if has_debug then .opline = [hextoint undumpint! for _ = 1, instnum]

			.varnum = hextoint undumpint!

			if has_debug then .varinfo = for _ = 1, .varnum
				{
					varname: concat adjust_endianness map hextochar, (undump_n (hextoint undumpchar!) - 1)\zsplit 2
					life: {
						begin: hextoint undumpint! -- lifespan begin
						end: hextoint undumpint! -- lifespan end
					}
				}

			.upvnum = hextoint undumpint!

			if has_debug then .upvinfo = for _ = 1, .upvnum
				concat adjust_endianness map hextochar, (undump_n (hextoint undumpchar!) - 1)\zsplit 2
	}
-- }}}

read = (reader, top = true) ->
	header = assert_header read_header reader
	fnblock = read_fnblock reader, header

	:header, :fnblock

Reader.__base.read = read
:Reader, :read

