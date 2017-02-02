-- vm = require'opeth.moonstep.vm'
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

-- class
	-- new: (@fnblock, @filename = "(closure)", @src = {pc: 0, reg: {}}) =>
		-- @vmco = vm fnblock, @src
		-- @indialogue = true
		-- @bp = nil
	-- run: =>
		-- while @indialogue
			-- io.write "[#{@vmco\status! == "dead" and "(dead)" or toint @src.pc + 1}]> "
			-- line = if l =  io.read! then l else break

			-- switchmatch line, {
				-- "^bp%s+(%d+)%s*$", (pc) ->
					-- @bp = toint pc
				-- "^r%s*$", ->
					-- while @vmco\resume!
						-- if @bp and @bp == @src.pc + 1
							-- print "breakpoint #{@bp}"
							-- break

					-- if @vmco\status! == "dead"
						-- print "[#{@filename}: exited program]"
				-- "^n%s*$", ->
					-- if @vmco\status! == "dead"
						-- print "[#{@filename}: exited program]"
					-- else @vmco\resume!
				-- "^d", -> print inspect @src
				-- "^q%s*$", -> @indialogue = false
				-- "^%s*$", ->
				-- default: ->
					-- io.write "command:\n",
						-- "\tbp <pc>: set a breakpoint to <pc>\n",
						-- "\tr: run the code. if the breakpoint is set, stop at <pc>\n",
						-- "\tn: execute the next instruction\n",
						-- "\td: dump the current register and PC\n",
						-- "\tq: quit\n"
			-- }

		-- @src

