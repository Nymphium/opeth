import have, filter, map, foldl, last from require'opeth.common.utils'
import get_block, mkcfg from require'opeth.common.blockrealm'
import insert, sort, remove from table
import max, tointeger from math
STACKTOP = 254

have_pos = (s, e) -> (filter ((b) -> b.line == e.line and b.reg == e.reg), s)[1]

-- T ∩S
intersec = (t = {}, s = {}) -> [e for e in *t when have_pos s, e]

-- T - S
diff = (t = {}, s = {}) -> [e for e in *t when not have_pos s, e]

-- T ∪ S
union = (t = {}, s = {}) -> with ret = [e for e in *t]
	insert ret, e for e in *(diff s, t)

-- latest registers' status
latest = (t) ->
	with ret = {} do for e in *t
		-- If no instruction overwrites `reg` ?
		if #(filter (=> @reg == e.reg), ret) == 0
			insert ret, e
		else
			if #(filter (=> @reg == e.reg and @line < e.line), ret) > 0
				for ri = 1, #ret
					if ret[ri].reg == e.reg
						remove ret, ri
						insert ret, e
						break

pos_tgen = (ins_idx) -> (rx) -> {line: ins_idx, reg: rx}

du_chain = (fnblock, cfg = mkcfg fnblock.instruction) ->
	instruction = fnblock.instruction
	upvs = {}

	for block in *cfg
		gen = with d = {}
			block.gen = d
			if block.start == 1
				-- 0: R(vx) <- ARG(vx) for vx = 0, function_arguments
				insert d, (pos_tgen 0) r for r = 0, tointeger (tonumber fnblock.params, 16) - 1

		use = with u = {}
			block.use = u

		for ins_idx = block.start, block.end
			ins = instruction[ins_idx]
			{RA, RB, RC} = map tointeger, ins

			pos_t = pos_tgen ins_idx

			switch ins.op
				-- R(A) = R(B) (`op` R(C))
				when ADD, SUB, MUL, MOD, POW, DIV, IDIV, BAND, BOR, BXOR, SHL, SHR, BNOT, NOT, UNM, NEWTABLE
					insert gen, pos_t RA
					insert use, pos_t RB if RB >= 0
					insert use, pos_t RC if RC and (RC >= 0 and RC != RB)
				when MOVE, LEN, TESTSET
					insert gen, pos_t RA
					insert use, pos_t RB
				when LOADK, LOADKX, GETUPVAL, LOADBOOL
					insert gen, pos_t RA
					-- insert use, RB if RB >= 0
				when GETTABUP
					insert gen, pos_t RA
					insert use, pos_t RC if RC >= 0
				when GETTABLE
					insert gen, pos_t RA
					insert use, pos_t RB
					insert use, pos_t RC if RC >= 0
				when SETTABLE
					insert gen, pos_t RA
					insert use, pos_t RB if RB >= 0
					insert use, pos_t RC if RC >= 0
				when SETUPVAL, TEST
					insert use, pos_t RA
				when SETTABUP
					insert use, pos_t RB if RB >= 0
					insert use, pos_t RC if RC >= 0
				when CLOSURE
					insert gen, pos_t RA

					-- consider `GETUPVAL` in closure[ins[2] + 1]
					proto = fnblock.prototype[RB + 1]

					for u in *proto.upvalue
						if u.instack == 1
							insert use, pos_t u.reg
							insert upvs, u.reg
				when LOADNIL
					insert gen, pos_t r for r = RA, RA + RB
				-- `t:f()` to  R(A + 1) = `f`; R(A) = `t`
				when SELF
					insert gen, pos_t RA
					insert gen, pos_t RA + 1
					insert use, pos_t RB
				when CALL
					insert use, pos_t a for a = RA, RA + RB - 1

					uselimit = RB == 0 and (#gen > 0 and (max unpack [u.reg for u in *gen]) or STACKTOP) or (RA + RB - 1)
					insert use, pos_t a for a = RA, uselimit

					def_relat = RC == 0 and ((with dp =  filter (=> @ > uselimit), [i.line for i in *gen] do sort dp)[1] or STACKTOP) or RA + RC - 2
					insert gen, pos_t r for r = RA, def_relat

					-- I've given up to check whether `SETUPVAL` is used in the closure of R(A),
					--   so assume that  ALL the value the previous CLOSURE instruction closed is defined/used.
					for u in *upvs
						-- insert gen, pos_t u
						insert use, pos_t u
				when TAILCALL
					arglimit = RB == 1 and 0 or (RB == 0 and (#use > 0 and (max unpack [u.reg for u in *use]) or STACKTOP) or RA + RB - 1)
					insert use, pos_t a for a = RA, arglimit
				when EQ, LT, LE
					insert use, pos_t RB if RB >= 0
					insert use, pos_t RC if RC >= 0
				when FORLOOP
					insert gen, pos_t RA
					insert gen, pos_t RA + 3
					insert use, pos_t RA
					insert use, pos_t RA + 1
				when FORPREP
					insert gen, pos_t RA
					insert use, pos_t RA
					insert use, pos_t RA + 2
				when TFORCALL
					insert gen, pos_t r for r = RA + 3, RA + 2 + RC
					insert use, pos_t u for u = RA, RA + 2
				when TFORLOOP
					insert use, pos_t RA + 1
					insert gen, pos_t RA

					with instruction[ins_idx - 1]
						assert .op == TFORCALL, "next TO TFORCALL must be TFORLOOP"
				when SETLIST
					len = RB != 0 and RB or (#use > 0 and (max unpack [u.reg for u in *use]) or STACKTOP)
					insert use, pos_t RA + i for i = 0, len
				when VARARG
					genlimit = RB == 0 and STACKTOP or RA + RB  - 2
					insert gen, pos_t r for r = RA, genlimit
				when CONCAT
					insert gen, pos_t RA
					insert use, pos_t a for a = RB, RC
				when RETURN
					ret = RB == 1 and -1 or (RB == 0 and (#use > 0 and (max unpack [u.reg for u in *use]) or STACKTOP) or RA + RB - 2)
					insert use, pos_t r for r = RA, ret
				when JMP
					insert use, pos_t RA - 1 if RA > 0
				-- nop

		with block
			.in, .kill, .out = {}, {}, {modified: true}

	while foldl ((bool, blk) -> bool or blk.out.modified), false, cfg
		for block in *cfg do with block
			out = .out
			.in = foldl ((in_, pblk) -> union in_, pblk.out), {}, .pred
			.kill = intersec .in, .gen
			.out = union (latest .gen), diff .in, .kill
			.out.modified = #(diff .out, out) > 0


	-- referring `use.defined` <--> `def.used`
	for block in *cfg do with block
		.def = union .gen, .in

		for use in *.use
			use.defined = {}

			if defined = last latest filter ((g) -> g.line < use.line and g.reg == use.reg), .gen
				insert use.defined, defined unless have use.defined, defined
				unless defined.used
					defined.used = {use}
				else
					insert defined.used, use unless have use.defined, use
			else
				for defined in *(filter ((i) -> i.reg == use.reg), .in)
					insert use.defined, defined unless have use.defined, defined
					unless defined.used
						defined.used = {use}
					else
						insert defined.used, use unless have defined.used, use

		for d in *.def
			d.used or= {}

	for blk in *cfg do with blk
		.out.modified, .kill, .gen, .out, .in = nil

	cfg

-- utils
this_use = (blk, ins_idx, reg) ->
	for u in *blk.use
		if u.line == ins_idx and u.reg == reg
			return u

this_def = (blk, ins_idx, reg) ->
	last latest filter (=> @line <= ins_idx and @reg == reg), blk.def

root_def = do
	pred_def = (blk, reg, visited = {}) ->
		if have visited, blk
			return
		insert visited, blk

		if d = last latest filter (=> @reg == reg), blk.def
			return d

		preds = [pred_def pred, reg, visited for pred in *blk.pred]

		if #preds == 1
			preds[1]

	(blk, ins_idx, reg) ->
		if d = last latest filter (=> @line <= ins_idx and @reg == reg), blk.def
			return d

		pred_def blk, reg

:du_chain, :this_use, :this_def, :root_def

