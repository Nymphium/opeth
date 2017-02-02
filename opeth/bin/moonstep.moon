#!/bin/env moon

import Reader, read from require'opeth.bytecode.reader'
-- Runner = require'opeth.moonstep.runner'
Runner = require'opeth.moonstep.vm'
-- inspect = require'inspect'
-- toint = math.tointeger

-- switchmatch = (str, t) ->
	-- for i = 1, #t, 2
		-- if (type(t[i]) ~= "string") or type(t[i + 1]) ~= "function"
			-- error "switchmatch failed"

		-- matches = {str\match t[i]}
		-- if #matches > 0
			-- return t[i + 1] unpack matches

	-- t.default! if t.default

local filename

vmfmt = do
	filename = arg[1] or "luac.out"
	f = assert (io.open filename), "Failed to open #{filename} No such file or directory"
	with read Reader f
		f\close!

runner = Runner vmfmt.fnblock, filename
runner\run!


-- src = {
	-- pc: 0
	-- reg: {}
-- }

-- local bp
-- vmco = vm vmfmt.fnblock, src
-- indialogue = true

-- while indialogue
	-- io.write "[#{vmco\status! == "dead" and "(dead)" or toint src.pc + 1}]> "
	-- line = if l =  io.read! then l else break

	-- switchmatch line, {
		-- "^bp%s+(%d+)%s*$", (pc) ->
			-- bp = toint pc
		-- "^r%s*$", ->
			-- while vmco\resume!
				-- if bp and bp == src.pc + 1
					-- print "breakpoint #{bp}"
					-- break

			-- if vmco\status! == "dead"
				-- print "[#{filename}: exited program]"
		-- "^n%s*$", ->
			-- if vmco\status! == "dead"
				-- print "[#{filename}: exited program]"
			-- else vmco\resume!
		-- "^d", -> print inspect src
		-- "^q%s*$", -> indialogue = false
		-- "^%s*$", ->
		-- default: ->
			-- io.write "command:\n",
				-- "\tbp <pc>: set a breakpoint to <pc>\n",
				-- "\tr: run the code. if the breakpoint is set, stop at <pc>\n",
				-- "\tn: execute the next instruction\n",
				-- "\td: dump the current register and PC\n",
				-- "\tq: quit\n"
	-- }

