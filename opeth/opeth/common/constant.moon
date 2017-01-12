import mkcfg, get_block from require'opeth.common.blockrealm'
import du_chain, this_use, this_def, root_def from require'opeth.opeth.common.du_chain'
import map, foldl, filter, have, isk, cstid from require'opeth.common.utils'
import insert, concat from table
optbl = require'opeth.opeth.common.optbl'

FUNVAR = "userdata"

local rtype

typewidth = (fnblock, blk, ins_idx, reg, du_cfg, visited) ->
	with typs = {}
		for use in *blk.use do with use
			if .line == ins_idx and .reg == reg and #.defined == 1
				typ = rtype fnblock, .defined[1].line, reg, du_cfg, visited
				typ or= FUNVAR
				insert typs, typ unless have  typs, typ

rtype = (fnblock, ins_idx, reg, du_cfg = (du_chain fnblock), visited = {}) ->
	for v in *visited
		if v.reg == reg and v.idx == ins_idx
			return v.typ

	v_ = {idx: ins_idx, :reg}

	insert visited, v_

	if ins_idx == 0
		v_.typ = FUNVAR
		return FUNVAR

	if isk reg
		cst = fnblock.constant[(math.abs reg) % 256 + (reg >= 0 and 1 or 0)]
		return cst and type cst.val

	fallback = (reg_ = reg) ->
		if ins_idx == 1 then return FUNVAR

		blk = get_block nil, ins_idx, du_cfg
		if ins_idx > blk.start then rtype fnblock, ins_idx - 1, reg_, du_cfg, visited
		else
			typs = with t = {}
				typs_ = typewidth fnblock, blk, ins_idx, reg_, du_cfg, visited
				insert t, e for e in *typs_ when not have t, e

			typs[1] if #typs == 1

	ins = fnblock.instruction[ins_idx]
	{RA, RB, RC, :op} = ins

	(=>
		v_.typ = @
		@
	) switch op
		when LOADK
			if reg == RA
				cst = fnblock.constant[(math.abs RB) % 256 + (RB >= 0 and 1 or 0)]
				cst and type cst.val
			else fallback!
		when NEWTABLE, SETTABLE, SETLIST
			if reg == RA then "table"
			else fallback!
		when MOVE
			if reg == RA then rtype fnblock, ins_idx, RB, du_cfg, visited
			else fallback!
		when GETTABUP, GETTABLE
			if reg == RA then FUNVAR
			else fallback!
		when LOADNIL
			if reg == RA or reg == RB then "nil"
			else fallback!
		when LOADBOOL
			if reg == RA then "bool"
			else fallback!
		when CLOSURE
			if reg == RA then "function"
			else fallback!
		when CONCAT
			for ci = RB, RC
				t = rtype fnblock, ins_idx, ci, du_cfg, visited
				if t != "string" and t != "number"
					return nil
			"string"
		when CALL
			if RA <= reg
				blk = get_block nil, ins_idx, du_cfg
				maxdef = foldl ((s, d) -> d.line == ins_idx and (d.reg > s and d.reg or s) or s), -1, blk.def

				if reg <= maxdef then nil
				else fallback!
			else fallback!
		when LEN
			if reg == RB
				typs = typewidth fnblock, (get_block nil, ins_idx, du_cfg), ins_idx, reg, du_cfg, visited
				typs[1] if #typs == 1
			elseif typRB == "string" then "number"
			else fallback!
		when NOT
			if reg == RA
				switch fallback RB
					when "table", "userdata", nil then nil
					else "bool"
			else fallback!
		when UNM
			if reg == RA
				if (fallback RB) == "number" then "number"
			else fallback!
		when ADD, SUB, MUL, DIV, MOD, IDIV, BAND, BXOR, BOR, SHL, SHR, POW
			blk = get_block nil, ins_idx, du_cfg

			typRB = if RA == RB
				typs = typewidth fnblock, blk, ins_idx, RB, du_cfg, visited
				typs[1] if #typs == 1
			elseif isk RB
				type fnblock.constant[-RB].val
			else fallback RB

			typRC = if RA == RC
				typs = typewidth fnblock, blk, ins_idx, RC, du_cfg, visited

				typs[1] if #typs == 1
			elseif RB == RC then typRB
			elseif isk RC then type fnblock.constant[-RC].val
			else fallback RC

			if reg == RA and typRB == typRC and typRB == "number" then "number"
			elseif reg == RB then typRB
			elseif reg == RC then typRC
			else fallback!
		when VARARG
			if RA <= reg and reg <= (RA + RB - 2) then nil
			else fallback!
		when GETUPVAL
			if reg == RA then nil
			else fallback!
		when TESTSET
			if reg == RB or reg == RA then fallback RB
			else fallback!
		when SELF
			if reg == RA + 1 then fallback RB
			elseif reg == RA then nil
			else fallback!
		else -- SETTABUP, JMP, TEST, EQ, LT, LE, TFORLOOP, TFORCALL, FORLOOP, FORPREP
			fallback!

-- return `true, value` or `false`, `true, ...` means "value is decidable"
rcst = (fnblock, ins_idx, reg, du_cfg = (du_chain fnblock), visited) ->
	if ins_idx == 0 then return false -- may be functoin argument

	ins = fnblock.instruction[ins_idx]

	{RA, RB, RC, :op} = ins

	fallback = (reg_ = reg) ->
		if ins_idx == 1 then return nil

		blk = get_block nil, ins_idx, du_cfg

		if ins_idx > blk.start
			has_cst, cst = rcst fnblock, ins_idx - 1, reg_, du_cfg
			has_cst and cst or nil
		else
			if d_rx = root_def blk, ins_idx, reg_
				-- watch defined position if `reg_` is not `RA`
				has_cst, cst = rcst fnblock, d_rx.line, reg_, du_cfg if d_rx.line != ins_idx and d_rx.reg_ != reg_
				has_cst and cst or nil
			else
				csts = {}

				for pred in *blk.pred
					has_cst, cst = rcst fnblock, pred.end, reg_, du_cfg, visited
					insert csts, cst if has_cst and not have csts, cst

				csts[1] if #csts == 1

				-- for pred in *blk.pred
					-- cst_t = {rtype fnblock, pred.end, reg_, du_cfg, visited}
					-- is_uniq = true

					-- for c in *csts
						-- if c[1] and c[2] == cst_t[2]
							-- is_uniq = false
							-- break

					-- insert csts, {rtype fnblock, pred.end, reg_, du_cfg, visited} if is_uniq

				-- csts[1][2] if #csts == 1

	if op != LOADK and reg != RA
		if reg < 0 and isk reg
			cst = fnblock.constant[cstid reg]
			if cst then return true, cst.val
			else return false

		cst = fallback!
		return cst != nil, cst

	(=> @ != nil, @) switch op
		when LOADK then fnblock.constant[cstid RB].val
		when LOADBOOL then RB != 0
		when CALL
			if RA <= reg
				blk = get_block nil, ins_idx, du_cfg
				maxdef = foldl ((s, d) -> d.line == ins_idx and (d.reg > s and d.reg or s) or s), -1, blk.def

				if reg <= maxdef then nil
				else fallback!
			else fallback!
		when MOVE
			blk = get_block nil, ins_idx, du_cfg
			use = this_use blk, ins_idx, RB

			if #use.defined == 1
				has_cst, cst = rcst fnblock, use.defined[1].line, use.defined[1].reg, du_cfg

				if has_cst then cst
			else fallbak RB
		when LEN
			blk = get_block nil, ins_idx, du_cfg
			has_cst, str = do
				d_rb = this_def blk, ins_idx, RB
				rcst fnblock, d_rb.line, RB, du_cfg

			#str if has_cst -- `LEN X X` can't determine which to return, R(A) or R(B)
		when UNM
			if cst = fallback RB
				-cst
		when NOT
			if cst = fallback RB
				not cst
		when ADD, SUB, MUL, DIV, BAND, BXOR, BOR, SHL, SHR, POW
			blk = get_block nil, ins_idx, du_cfg

			has_cstB, cstRB = if isk RB
				if cst = fnblock.constant[cstid RB] then true, cst.val
				else false
			else
				if RA == RB
					cst = fallback RB
					cst != nil, cst
				elseif u_rb = this_use blk, ins_idx, RB
					if #u_rb.defined == 1
						rcst fnblock, u_rb.defined[1].line, RB, du_cfg

			has_cstC, cstRC = if isk RC
				if cst = fnblock.constant[cstid RC] then true, cst.val
				else false
			elseif RB == RC then has_cstB, cstRB
			else
				if RA == RC
					cst = fallback RC
					cst != nil, cst
				elseif u_rc = this_use blk, ins_idx, RC
					if #u_rc.defined == 1
						rcst fnblock, u_rc.defined[1].line, RC, du_cfg

			if has_cstB and has_cstC
				optbl[op] cstRB, cstRC
		when IDIV, MOD
			blk = get_block nil, ins_idx, du_cfg

			has_cstC, cstRC = if isk RC
				if cst = fnblock.constant[cstid RC] then true, cst.val
				else false
			else
				if RA == RC
					cst = fallback RC
					cst != nil, cst
				elseif u_rc = this_use blk, ins_idx, RC
					if #u_rc.defined == 1
						rcst fnblock, u_rc.defined[1].line, RC, du_cfg

			if has_cstC and cstRC == 0 then return nil

			has_cstB, cstRB = if isk RB
				if cst = fnblock.constant[cstid RB] then true, cst.val
				else false
			elseif RB == RC then has_cstC, cstRC
			else
				if RA == RB
					cst = fallback RB
					cst != nil, cst
				elseif u_rb = this_use blk, ins_idx, RB
					if #u_rb.defined == 1
						rcst fnblock, u_rb.defined[1].line, RB, du_cfg

			if has_cstB and has_cstC
				optbl[op] cstRB, cstRC
		-- `CONCAT` only checks all the types of `R(range RB, RC)`
		when CONCAT
			typ_cst = rtype fnblock, ins_idx, reg, du_cfg

			return unless typ_cst == "string"

			csts = {}

			for cat_reg = RB, RC
				if cst = fallback cat_reg
					insert csts, cst
				else return

			concat csts if #csts == (RC - RB + 1)
		else fallback!

:rtype, :rcst

