import concat from table
import char from string
import floor, tointeger from math

import zsplit, map, insgen, prerr, undecimal from require'opeth.common.utils'
import hexdecode, hextobin, adjustdigit, bintoint, hextoint, hextochar, bintohex, inttobin from undecimal
op_list = require'opeth.common.oplist' "abc", "abx", "asbx", "ab"

string = string
string.zsplit = zsplit

-- TODO: now only supported signed 64bit float
f2ieee = (flt) ->
	if flt == 0 then return "0"\rep 64

	bias = 1023
	abs_flt = math.abs flt
	e, m = math.modf abs_flt

	while e == 0
		abs_flt *= 2
		bias -= 1
		e, m = math.modf abs_flt

	while e > 9.223372e18
		e /= 2
		bias += 1

	mb = ""
	pa = (inttobin e)\match"0*1(.*)" or ""
	e = #pa + bias

	for b in pa\gmatch"."
		if #mb == 52 then break
		mb ..= b

	eb = adjustdigit (hextobin "%x"\format e)\match"0*(.*)", 11

	for i = -1, -(52 - #mb), -1
		p = 2^i

		if m - p >= 0
			m -= p
			mb ..= "1"
			if m == 0
				while #mb < 52 do mb ..= "0"
				break
		else mb ..= "0"

	(flt < 0 and "1" or "0") .. eb .. mb

-- Writer class
-- interface to write to file
-- {{{
class Writer
	new: (cont) =>
		typ = type cont
		@cont = switch typ
			when "userdata" then cont
			when "string" then assert io.open(cont, "w+b"), "Writer.new #1: failed to open file `#{cont}'"
			when "nil" then {block: "", write: ((a) => @block ..= a), flush: (=>), close: (=>), seek: (=>), read: (=>)}
			else error "Writer.new receives only the type of string or file (got `#{typ}')"
		@size = 0
	__shl: (v) =>
		@size += #v
		with @ do @cont\write v
	__len: => @size
	close: =>
		@cont\flush!
		@cont\close!
	show: =>
		pos = @cont\seek "cur"
		@cont\seek "set"
		with @cont\read "*a"
			@cont\seek "set", pos
-- }}}

-- write (re) encoded data to file
-- {{{
local adjust_endianness

regx = (i) -> hextobin "%x"\format i
writeint = (wt, int, dig = 8) -> map (=> wt << hextochar @), adjust_endianness (adjustdigit ("%x"\format int), dig)\zsplit 2

write_fnblock = (wt, fnblock, has_debug) ->
	import chunkname, line, params, vararg, regnum, instruction, constant, upvalue, prototype, debug from fnblock

	-- chunkname
	-- {{{
	if has_debug or #chunkname > 0
		has_debug = true
		wt << char #chunkname + 1
		map (=> wt << @), chunkname\zsplit!
	else wt << "\0"
	-- }}}

	-- parameters
	-- {{{
	map (=> writeint wt, (hextoint @)), {line.defined, line.lastdefined}
	map (=> wt << hextochar @), {
			params
			vararg
			regnum
		}
	-- }}}

	-- instruction
	-- {{{
	writeint wt, #instruction

	for i = 1, #instruction
		{RA, RB, RC, :op} = instruction[i]
		a = adjustdigit (regx RA), 8
		rbc = if RC
			concat map (=> adjustdigit (regx if @ < 0 then 2^8 - 1 - @ else @), 9), {RB, RC}
		else adjustdigit (regx if op_list[op][2] == "asbx" then RB +2^17-1 else RB), 18

		bins = rbc ..a..(adjustdigit (regx (op_list[op].idx - 1)), 6)
		assert #bins == 32
		map (=> wt << hextochar @), adjust_endianness (concat map (=> bintohex @), bins\zsplit 4)\zsplit 2
	-- }}}

	-- constant
	-- {{{
	writeint wt, #constant

	for i = 1, #constant do with constant[i]
		wt << char .type

		switch .type
			when 0x1 then wt << char .val
			when 0x3
				wt << c for c in *(adjust_endianness [("0x"..(bintohex cxa) .. (bintohex cxb))\char! for cxa, cxb in (f2ieee .val)\gmatch "(....)(....)"])
			when 0x13 then writeint wt, .val, 16
			when 0x4, 0x14
				if #.val > 0xff
					wt << char 0xff
					writeint wt, #.val + 1, 16
				else writeint wt, #.val + 1, 2

				wt << .val
	-- }}}

	-- upvalue
	-- {{{
	writeint wt, #upvalue
	map (=> wt << char @), adjust_endianness {upvalue[i].reg, upvalue[i].instack} for i = 1, #upvalue
	-- }}}

	-- prototype
	-- {{{
	writeint wt, #prototype
	write_fnblock wt, prototype[i], has_debug for i = 1, #prototype
	-- }}}

	-- debug
	-- {{{
	-- {:linenum, :opline, :varnum, :varinfo, :upvnum, :upvinfo} = debug
	import linenum, opline, varnum, varinfo, upvnum, upvinfo from debug

	writeint wt, (has_debug and linenum or 0)

	if has_debug then for i = 1, #(opline or "")
		writeint wt, opline[i]

	writeint wt, (has_debug and varnum or 0)

	if has_debug then for i = 1, #(varinfo or "")
		with varinfo[i]
			writeint wt, #.varname+1, 2
			wt << .varname
			writeint wt, .life.begin
			writeint wt, .life.end

	writeint wt, (has_debug and upvnum or 0)

	if has_debug then for i = 1, #(upvinfo or "")
		writeint wt, #upvinfo[i]+1, 2
		wt << upvinfo[i]
	-- }}}

write = (wt, vmformat) ->
	import header, fnblock from vmformat
	adjust_endianness = header.endian < 1 and (=> @) or (xs) -> [xs[i] for i = #xs, 1, -1]

	with header
		map (=> wt << @), {
				.hsig
				(hextochar tointeger .version * 10)
				(char .format)
				.luac_data
			}

		with .size
			map (=> wt << (char @)), {
					.int
					.size_t
					.instruction
					.lua_integer
					.lua_number
				}

		map (=> wt << @), {
				(concat adjust_endianness (((char 0x00)\rep 6) .. char 0x56, 0x78)\zsplit!)
				.luac_num
				.has_debug
			}

	write_fnblock wt, fnblock

	wt
-- }}}

Writer.__base.write = write
:Writer, :write

