import map, filter, isk from require'opeth.common.utils'
import remove from table

(fnblock) ->
	-- clean unused closures
	closdef = filter (=> @op == CLOSURE), fnblock.instruction
	closidx = 0

	while fnblock.prototype[closidx + 1]
		unless (filter (=> @[2] == closidx), closdef)[1]
			remove fnblock.prototype, closidx + 1
			fnblock.optdebug\mod_inc!
			map (=> @[2] -= 1), filter (=> @[2] >= closidx), closdef
			continue

		closidx += 1

	-- clean unused constants
	cstidx = 0

	while fnblock.constant[cstidx + 1]
		unless (filter (=> switch @op
				when EXTRAARG then @[1] == cstidx
				when LOADK, GETGLOBAL, SETGLOBAL then @[2] == cstidx
				when GETTABLE, SELF, GETTABUP then (isk @[3]) and (@[3] == -(cstidx + 1))
				when ADD, SUB, MUL, DIV, MOD, IDIV, BAND, BXOR, BOR, SHL, SHR, POW, EQ, LT, LE, SETTABLE, SETTABUP
					((isk @[2]) and (@[2] == -(cstidx + 1))) or
						((isk @[3]) and (@[3] == -(cstidx + 1)))
				), fnblock.instruction)[1]
			remove fnblock.constant, cstidx + 1
			fnblock.optdebug\mod_inc!
			map (=> switch @op
				when EXTRAARG then @[1] -= 1 if @[1] >= cstidx
				when LOADK then @[2] -= 1 if @[2] >= cstidx
				when GETTABLE, SELF, GETTABUP then @[3] += 1 if (isk @[3]) and @[3] < -cstidx
				when ADD, SUB, MUL, DIV, MOD, IDIV, BAND, BXOR, BOR, SHL, SHR, POW, EQ, LT, LE, SETTABLE, SETTABUP
					if (isk @[2]) and @[2] < -cstidx
						@[2] += 1

					if (isk @[3]) and @[3] < -cstidx
						@[3] += 1
				), fnblock.instruction
			continue

		cstidx += 1

