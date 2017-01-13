import rtype, rcst from require'opeth.opeth.common.constant'
import foldl from require'opeth.common.utils'
import removeins, swapins from require'opeth.opeth.common.utils'
import get_block from require'opeth.common.blockrealm'
import du_chain, root_def, this_def from require'opeth.opeth.common.du_chain'
optbl = require'opeth.opeth.common.optbl'

xor = (p, q) -> (p or q) and not (p and q)

(fnblock) ->
	du_cfg = du_chain fnblock
	ins_idx = 1

	proc_rm = (ins_idx) =>
		removeins fnblock.instruction, ins_idx
		ins_idx -= 1
		fnblock.optdebug\mod_inc!
		du_cfg = du_chain fnblock

	while fnblock.instruction[ins_idx]
		ins = fnblock.instruction[ins_idx]
		{RA, RB, RC, :op} = ins

		switch op
			when LOADK, CLOSURE
				blk = get_block nil, ins_idx, du_cfg

				if d_ra = this_def blk, ins_idx, RA
					if d_ra.used == nil or #d_ra.used == 0
						swapins fnblock.instruction, ins_idx, {RA, RA, 0, op: MOVE}
						ins_idx -= 1
						fnblock.optdebug\mod_inc!
						du_cfg = du_chain fnblock
						continue
			when MOVE
				if RA == RB
					proc_rm fnblock, ins_idx
					continue
				else
					blk = get_block nil, ins_idx, du_cfg

					-- if blk.start != blk.end
					if d_ra = this_def blk, ins_idx, RA
						if d_ra.used == nil or #d_ra.used == 0
							if d_rb = root_def blk, ins_idx, RB
								if d_rb.line > 0 and
										not foldl ((bool, op) -> bool or op == fnblock.instruction[d_rb.line].op),
											false, {GETTABUP, GETTABLE, CALL}
									proc_rm fnblock, ins_idx
									continue
			when LOADNIL
				blk = get_block nil, ins_idx, du_cfg

				if blk.start != blk.end
					if #[u for u in *blk.def when u.line == ins_idx and #u.used > 0] == 0
						proc_rm fnblock, ins_idx
						continue
			-- when LOADBOOL
				-- blk = get_block nil, ins_idx, du_cfg

				-- if #blk.pred == 0
					-- proc_rm fnblock, ins_idx
					-- continue
				-- else
					-- sscope = get_block nil, ins_idx + 1, du_cfg
					-- if #sscope.pred == 0
						-- proc_rm fnblock, ins_idx
						-- ins[3] = 0 if RC == 1
						-- continue
			when FORLOOP
				-- empty forloop
				if RB == -1 and fnblock.instruction[ins_idx - 1].op == FORPREP
					proc_rm fnblock, ins_idx - 1
					proc_rm fnblock, ins_idx - 1
					continue
			-- iterator function call must not be removed
			-- when TFORLOOP
			-- when JMP
				-- proc_rm fnblock, ins_idx if RA == 0 and RB == 0
			when LT, LE, EQ
				if "number" == rtype fnblock, ins_idx, RB, du_cfg
					if "number" == rtype fnblock, ins_idx, RC, du_cfg
						has_cstRB, cstRB = rcst fnblock, ins_idx, RB, du_cfg

						if has_cstRB
							has_cstRC, cstRC = rcst fnblock, ins_idx, RC, du_cfg

							if has_cstRC
								cond = (RA == 1) != optbl[ins.op] cstRB, cstRC

								proc_rm fnblock, ins_idx
								proc_rm fnblock, ins_idx if cond
								continue
			when TEST
				typeRA = rtype fnblock, ins_idx, RA, du_cfg
				cond = switch typeRA
					when nil, "table", "userdata"
						ins_idx += 1
						continue
					when "bool"
						has_cstRA, cstRA = rcst fnblock, ins_idx, RA, du_cfg
						
						unless has_cstRA
							ins_idx += 1
							continue

						cstRA
					when "nil" then false
					else true

				proc_rm fnblock, ins_idx
				-- if cond then pc++
				proc_rm fnblock, ins_idx if xor (RC != 0), cond  -- RC ~= 0 and (not cond) or cond
				continue
			when TESTSET
				typeRB = rtype fnblock, ins_idx, RB, du_cfg
				cond = switch typeRB
					when nil, "table", "userdata"
						ins_idx += 1
						continue
					when "bool"
						has_cstRB, cstRB = rcst fnblock, ins_idx, RB, du_cfg

						unless has_cstRB
							ins_idx += 1
							continue

						cstRB
					when "nil" then false
					else true

				proc_rm fnblock, ins_idx

				unless  xor (RC != 0), cond
					swapins fnblock.instruction, ins_idx, {RA, RB, 0, op: MOVE}
					du_cfg = du_chain fnblock
					fnblock.optdebug\mod_inc!
					proc_rm fnblock, ins_idx + 1

				continue

		ins_idx += 1

