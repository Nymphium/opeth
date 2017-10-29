unless RETURN
	require'opeth.common.opname'

import deepcpy, isk from require'opeth.common.utils'
optbl = require'opeth.opeth.common.optbl'
inspect = require'inspect'
toint = math.tointeger
printer = require'opeth.bytecode.printer'

__ENV = deepcpy _ENV

switchmatch = (str, t) ->
	for i = 1, #t, 2
		if (type(t[i]) ~= "string") or type(t[i + 1]) ~= "function"
			error "switchmatch failed"

		matches = {str\match t[i]}
		if #matches > 0
			return t[i + 1] unpack matches

	t.default! if t.default

COLOR = 93
CURRENT_COLOR = 96
coloring = (color, str) -> "\027[#{color}m#{str}\027[0m"

level_tostring = => (coloring COLOR, (table.concat ["[#{i}]=" for i in *@])) .. (coloring CURRENT_COLOR, "[$status]=> ")
initsrc = (fnblock) -> {pc: 0, reg: {}, src: fnblock}

class VMctrler
	class VMCo
		new: (co) => @co = coroutine.create co
		status: => coroutine.status @co
		resume: => coroutine.resume @co

	new: (@fnblock, @filename = "(closure)", @src = (initsrc @fnblock), @levels = {}) =>
		@vmco = @create_vm fnblock, @src
		@indialogue = true
		@bp = nil
	run: =>
		while @indialogue
			@doprompt!
			line = if l =  io.read! then l else break

			switchmatch line, {
				"^bp%s+(%d+)%s*$", (pc) ->
					@bp = toint pc
				"^r%s*$", ->
					while @vmco\resume!
						if @bp and @bp == @src.pc + 1
							print "breakpoint #{@bp}"
							break

					if @vmco\status! == "dead"
						print "[#{@filename}: exited program]"
				"^n%s*$", ->
					if @vmco\status! == "dead"
						print "[#{@filename}: exited program]"
					else @vmco\resume!
				"^d%s*$", -> print inspect @src
				"^dp%s*$", -> printer.fnblock @fnblock, @filename
				"^q%s*$", -> @indialogue = false
				"^%s*$", ->
				default: ->
					io.write "command:\n",
						"\tbp <pc>: set a breakpoint to <pc>\n",
						"\tr: run the code. if the breakpoint is set, stop at <pc>\n",
						"\tn: execute the next instruction\n",
						"\td: dump the current register and PC\n",
						"\tdp: dump the bytecode structure\n",
						"\tq: quit\n"
			}

		@src
	linestatus: => @vmco\status! == "dead" and "(dead)" or toint @src.pc + 1
	doprompt: => io.write ((level_tostring @levels)\gsub "%$status", @linestatus!)
	create_vm: (upreg = {}) =>
		{:constant, :instruction, :upvalue, :prototype} = @fnblock
		{:reg} = @src

		getrk = (rk) ->
			if isk rk
				constant[-rk].val
			else
				reg[rk]

		VMCo ->
			_ENV = deepcpy __ENV
			while @src.pc < #instruction
				@src.pc += 1

				ins = instruction[@src.pc]
				{RA, RB, RC, op: opec} = ins

				switch opec
					when MOVE
						reg[RA] = reg[RB]
					when LOADK
						reg[RA] = constant[RB + 1].val
					when LOADKX
						assert instruction[@src.pc + 1].op == EXTRAARG

						reg[RA] = constant[(513 + instruction[@src.pc + 1][1]) % 256].val

						@src.pc += 1
					when LOADBOOL
						reg[RA] = RB == 0

						if RC != 0
							@src.pc += 1
					-- when LOADNIL
					when GETUPVAL
						reg[RA] = upreg[RB + 1]
					when GETTABUP
						reg[RA] = if upvalue[RB + 1].instack == 0
							_ENV[constant[-RC].val]
					when GETTABLE
						reg[RA] = reg[RB][getrk RC]
					when SETTABUP
						_ENV[-RB] = constant[-RC]
					when SETUPVAL
						upreg[RA] = reg[RB]
					when SETTABLE
						reg[RA][getrk RB] = getrk RC
					when NEWTABLE
						reg[RA] = {}
					when SELF
						reg[RA + 1] = reg[RB]
						reg[RA] = reg[RB][getrk RC]
					when ADD, SUB, MUL, DIV, BAND, BOR, BXOR, SHL, SHR, MOD, IDIV, POW
						reg[RA] = optbl[opec] (getrk RB), (getrk RC)
					when UNM
						reg[RA] = -reg[RB]
					when BNOT
						reg[RA] = ~ reg[RB]
					when NOT
						reg[RA] = not reg[RB]
					when LEN
						reg[RA] = #reg[RB]
					when CONCAT
						for r = RB, RC
							reg[RA] ..= reg[r]
					when JMP
						@src.pc += RB
					when EQ, LT, LE
						@src.pc += 1 if (optbl[opec] (getrk RB), (getrk RC)) != RA
					when TEST
						@src.pc += 1 unless reg[RA]
					when TESTSET
						if reg[RB]
							reg[RA] = reg[RB]
						else
							@src.pc += 1
					when CALL
						fn = reg[RA]
						calllimit = RB == 0 and #reg or (RA + RB - 1)

						retvals = if (type fn) == "table" and fn.regnum
							with nreg = {}
								for r = 0, calllimit - (RA + 1)
									nreg[r] = reg[RA + 1 + r]

								table.insert @levels, @src.pc
								runnerfn = VMctrler fn, "inner closure", (initsrc fn), @levels
								runnerfn\run!
								table.remove @levels, #@levels

								for i = 0, calllimit - (RA + 1)
									nreg[r] = runnerfn.src.reg[i]
						else {fn unpack reg, (RA + 1), calllimit}
						retlimit  = RC == 0 and #retvals or (RC - 2)

						for r = RA, RA + retlimit
							reg[r] = retvals[r - RA + 1]
					when TAILCALL
						fn = reg[RA]

						return fn unpack reg, (RA + 1), (RA + RB - 1)
					when RETURN
						retlimit = switch RB
							when 0 then #reg
							when 1 then 0
							else        RB - 2

						@src.reg = {unpack reg, RA, (RA + retlimit)}
						reg = @src.reg
						break
					when FORLOOP
						reg[RA] += reg[RA + 2]

						if reg[RA] <= reg[RA + 1]
							@src.pc += RB
							reg[RA + 3] = reg[RA]
					when FORPREP
						reg[RA] -= reg[RA + 2]
						@src.pc += RB
					when TFORCALL
						cb = RA + 3
						reg[cb + 2] = reg[RA + 2]
						reg[cb + 1] = reg[RA + 1]
						reg[cb] = reg[RA]
						fn = reg[cb]

						retvals = {fn unpack reg, cb + 1, cb + RC}
						table.move retvals, 1, RC, cb, reg

						assert instruction[@src.pc + 1].op == TFORLOOP
					when TFORLOOP
						if reg[RA + 1]
							reg[RA] = reg[RA + 1]
							@src.pc += instruction[@src.pc][2]
					when SETLIST
						for i = 1, RB
							reg[RA][RC - 1 + i] = reg[RA + i]
					when CLOSURE
						reg[RA] = prototype[RB + 1]


				coroutine.yield!
			reg

VMctrler

