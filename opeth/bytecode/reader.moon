import Ct, Cg, Cb, C, R, Cp, P, Cc, V, Cmt, match from require'lpeg'
import concat from table
import char from string
import zsplit, map, prerr, undecimal from require'opeth.common.utils'
import hexdecode, hextobin, adjustdigit, bintoint, hextoint, hextochar, bintohex from undecimal

string = string
string.zsplit = zsplit

CP = => C (P @)

insgen = do
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

	(ins) ->
		b, c, a, i = (hextobin ins)\match "(#{"."\rep 9})(#{"."\rep 9})(#{"."\rep 8})(#{"."\rep 6})"
		{op, fn} = oplist[(bintoint i) + 1]

		{:op, fn(a, b, c)}

-- XXX: supported little endian 64bit float only
ieee2f = (rd) ->
	mantissa = (rd\byte 7) % 16
	for i = 6, 1, -1 do mantissa = mantissa * 256 + rd\byte i
	exponent = ((rd\byte 8) % 128) * 16 + ((rd\byte 7) // 16)
	exponent == 0 and 0 or ((mantissa * 2 ^ -52 + 1) * ((rd\byte 8) > 127 and -1 or 1)) * (2 ^ (exponent - 1023))

sizesgen = =>
	t = map (=> @\byte!), @
	{int: t[1], size_t: t[2], instruction: t[3], lua_integer: t[4], lua_number: t[5]}

header_syntax = P {
	V'Header' * Cp!
	Header: V'Hsig' * V'Version' * V'Format' * V'Luac_data' * V'Sizes' * V'Endian' * V'Luac_num' / (
			hsig,
			version,
			format,
			luac_data,
			size,
			endian,
			luac_num
		) -> {
			:hsig,
			version: "#{version\byte! // 0x10}.#{version\byte! % 0x10}",
			:format,
			:luac_data,
			size: sizesgen size\zsplit 1,
			endian: (endian == ((char 0x00)\rep 6) .. char 0x56, 0x78) and 0 or 1,
			:luac_num
		}
	,
	Hsig: Cmt (CP 4), (_, _, capt) -> (assert (capt == '\x1bLua'), "HEADER SIGNATURE ERROR"), capt
	Version: CP 1
	Format: (CP 1) / => @\byte!
	Luac_data: Cmt (CP 6), (_, _, capt) -> (assert (capt == "\x19\x93\r\n\x1a\n"), "PLATFORM CONVERSION ERROR"), capt
	Sizes: CP 5
	Endian: CP 8
	Luac_num: Cmt (CP 9), (_, _, capt) -> (assert (370.5 == ieee2f capt), "IEEE754 FLOAT ERROR"), capt
}

providetools = (header) ->
	import endian, size from header

	adjust_endianness = if endian < 1 then (=> @) else (xs) -> [xs[i] for i = #xs, 1, -1]
	undump_n = => hexdecode(#@) unpack adjust_endianness {@\byte 1, #@}
	rawhextoint = => hextoint undump_n @

	:adjust_endianness, :undump_n, :rawhextoint

build_fnblock_syntax = (header, has_debug, top) ->
	import size from header
	{int: size_int, lua_integer: size_luaint, lua_number: size_luanum, instruction: size_ins} = size
	import adjust_endianness, undump_n, rawhextoint from providetools header
	local insnum

	P {
		V'Fnblock' * Cp!
		Fnblock: V'Chunkname' * V'Line' * V'Params' * V'Vararg' * V'Regnum' * V'Instruction' * V'Constant'* V'Upvalue' * V'Prototype' * V'Debug' / (
				chunkname,
				line,
				params,
				vararg,
				regnum,
				instruction,
				constant,
				upvalue,
				prototype,
				debug
			) -> {:chunkname, :line, :params, :vararg, :regnum, :instruction, :constant, :upvalue, :prototype, :debug}
		Chunkname: Cmt (CP 1), (entire, pos, capt) ->
			if top
				str = entire\sub pos, pos + (rawhextoint capt) - 2
				has_debug = #str > 1
				pos + #str, str
			else
				pos, ""
		Line: CP(size_int) * CP(size_int) / (defined, lastdefined) -> {defined: (undump_n defined), lastdefined: (undump_n lastdefined)}
		Params: (CP 1) / => undump_n @
		Vararg: (CP 1) / => undump_n @
		Regnum: (CP 1) / => undump_n @
		Instruction: Cmt (CP size_int), (entire, pos, capt) ->
			num =  (rawhextoint capt)
			insnum = num
			num *= size_int
			inses = map (=> insgen undump_n @), (entire\sub pos, pos + num)\zsplit size_ins
			pos + num, inses
		Constant: Cmt (CP size_int), (entire, pos, capt) ->
			num = rawhextoint capt
			base_pos = pos
			base = =>
				base_pos += @
				base_pos - 1

			t = for _ = 1, num
				with type: (entire\sub base_pos, base 1)\byte!
					.val = switch .type
						when 0x1
							(entire\sub base_pos, base 1)\byte!
						when 0x3
							ieee2f (entire\sub base_pos, base size_luanum)
						when 0x13
							n = undump_n (entire\sub base_pos, base size_luaint)
							if n\match"^[0-7]" then 0x10000000000000000 + hextoint n
							else hextoint n
						when 0x04, 0x14
							len = rawhextoint entire\sub base_pos, base 1
							if len == 0xff
								len = rawhextoint entire\sub base_pos, base size_luaint

							len = len - 1

							if len > 0
								entire\sub base_pos, base len
							else ""
						else nil
			base_pos, t

		Upvalue: Cmt (CP size_int), (entire, pos, capt) ->
			num = rawhextoint capt

			t = for i = 0, num - 1
				v = pos + i * 2
				u = adjust_endianness {(entire\sub v, v)\byte!, (entire\sub v - 1, v - 1)\byte!}
				{reg: u[1], instack: u[2]}
			pos + num * 2 , t

		Prototype: Cmt (CP size_int), (entire, pos, capt) ->
			num = rawhextoint capt
			base_pos = pos

			t = for _ = 1, num
				fnblock_syntax = build_fnblock_syntax header, has_debug
				proto, base_pos_ = fnblock_syntax\match entire\sub base_pos
				base_pos += base_pos_ - 1
				proto

			base_pos, t

		-- term `Debug` captures nothing but the position
		Debug: Cmt Cp!, (entire, _, pos) ->
			base_pos = pos
			base = =>
				base_pos += @
				base_pos - 1

			t = with {}
				.linenum = rawhextoint entire\sub base_pos, base size_int
				.opline = [rawhextoint (entire\sub base_pos, base size_int) for _ = 1, insnum] if has_debug
				.varnum = rawhextoint (entire\sub base_pos, base size_int)

				if has_debug then .varinfo = for _ = 1, .varnum
					{
						varname: do
							len = (rawhextoint entire\sub base_pos, base 1) - 1
							concat adjust_endianness map hextochar, (undump_n entire\sub base_pos, base len)\zsplit 2
						life: {
							begin: rawhextoint entire\sub base_pos, base size_int
							end: rawhextoint entire\sub base_pos, base size_int
						}
					}

				.upvnum = rawhextoint entire\sub base_pos, base size_int

				if has_debug then .upvinfo = for _ = 1, .upvnum
					len = (rawhextoint entire\sub base_pos, base 1) - 1
					concat adjust_endianness map hextochar, (undump_n entire\sub base_pos, base len)\zsplit 2

			base_pos, t
	}

read = (str) ->
	header, pos = header_syntax\match str
	fnblock = (build_fnblock_syntax header, true, true)\match (str\sub pos)
	{:header, :fnblock}

class Reader
	new: (cont) =>
		typ = type cont

		@type = typ
		@cont = switch typ
			when "userdata" then cont
			when "function" string.dump cont, true
			when "string" then
				with assert (io.open cont), "Reader.new #1: failed to open file `#{cont}'"
					@type = "file"
			else error "Reader.new receives only the type of string, function or file (got `#{typ}')"
	close: =>
		switch @type
			when "function" then true
			when "file" then @cont\close!
	__len: =>
		switch @type
			when "function" then #@cont
			when "file"
				with #(@cont\read "*a")
					@cont\seek "set"
	read: =>
		read switch @type
			when "function" then @cont
			when "file" then
				with @cont\read "*a"
					@cont\seek "set"
			else
				error "What?! #{@type}"

:Reader, :read

