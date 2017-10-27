#!/bin/env moon

import Reader, read from require'opeth.bytecode.reader'
import write, Writer from require'opeth.bytecode.writer'
import map, filter, foldl, have, delete, last from require'opeth.common.utils'
import insert from table
parser = require'opeth.lasm.syntax'

format_lasm = (lasms, newbytecode) ->
	for _, proto in pairs lasms
		with proto
			maxreg = 0

			for ins in *.instruction
				switch ins.op
					when"MOVE", "RETURN"
						ins[3] = 0 unless ins[3]

					when "CLOSURE"
						if type(ins[2] ) == "string"
							protono = #lasms

							unless have lasms, lasms[ins[2] ]
								labeled_proto = lasms[ins[2] ]
								lasms[protono - 1] = labeled_proto
								insert newbytecode.fnblock.prototype, labeled_proto

							ins[2] = protono

				maxreg = math.max maxreg, foldl math.max, 0, ins

			-- format constant
			constant = .constant
			if constant then for i = 1, #constant
				cons = constant[i]
				constant[i] = {
						type: switch type cons
							when "number"
								(math.tointeger cons) and 0x13 or 0x03
							when "string"
								(#cons > 255) and 0x14 or 0x04
						val: cons
					}

			-- insert dummy info (debug info, params, etc.)
			.line = {
				defined: "00000000"
				lastdefined: "00000000"
			}

			.regnum = "%02x"\format maxreg + 1
			.params = "%02x"\format tonumber (.params or 0)
			.vararg = "%02x"\format tonumber (.vararg or 0)
			.upvalue = {
				{
					instack: 1
					reg: 0
				}
			}

			.debug = {
				linenum: 0
				upvnum: 0
				varnum: 0
			}

			.constant or= {}
			.prototype or= {}

	for k in pairs lasms
		-- remove label
		if (type(k) == "string") and  k != "main"
			lasms[k] = nil

	lasms

unless arg[1]
	print "Usage lasmc [filename]"
	print!
	print "lasmc -- Lua vm  ASseMbly-like language Compiler"
	os.exit 1

local lasmcode

if arg[1] == "-"
	lasmcode = ""

	while true
		line = io.read!

		unless line
			break

		lasmcode ..= line

else
	io.close with f = assert (io.open arg[1]), "Failed to open #{arg[1]}: No such file or directory"
		lasmcode = f\read "*a"

newbytecode = (Reader (-> print"hello"))\read!

ast = parser lasmcode
unless ast
	error "Failed to parse"

lasms = format_lasm ast, newbytecode
lmain = lasms.main
with newbytecode.fnblock
	.instruction = lmain.instruction
	.constant = lmain.constant
	.line = lmain.line
	.regnum = lmain.regnum
	.params = lmain.params
	.vararg = lmain.vararg
	.constant = lmain.constant
	.upvalue = lmain.upvalue
	.debug = lmain.debug
	.chunkname = ""

wt = Writer "lasm.out"
with newbytecode
	write wt, newbytecode

wt\close!

