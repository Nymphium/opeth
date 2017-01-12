import filter from require'opeth.common.utils'
import rtype, rcst from require'opeth.opeth.common.constant'
import cst_lookup, cst_add, removeins, swapins from require'opeth.opeth.common.utils'
import get_block from require'opeth.common.blockrealm'
import du_chain, this_def from require'opeth.opeth.common.du_chain'

(fnblock) ->
	fnblock.optdebug\start_rec!

	du_cfg = du_chain fnblock
	ins_idx = 1

	hoisting = (to_idx, from_ins, ra) ->
		fnblock.instruction[to_idx] = {ra, from_ins[2], from_ins[3], op: from_ins.op}
		fnblock.optdebug.modified += 1
		du_cfg = du_chain fnblock

	while  fnblock.instruction[ins_idx]
		ins = fnblock.instruction[ins_idx]
		{RA, RB, RC, :op} = ins

		if op == MOVE
			if RA == RB
				removeins fnblock.instruction, ins_idx
				fnblock.optdebug.modified += 1
				du_cfg = du_chain fnblock
				continue

			blk = get_block nil, ins_idx, du_cfg

			if d_rb = this_def blk, ins_idx, RB
				if #d_rb.used == 1 and #d_rb.used[1].defined == 1
					moved_idx = d_rb.line
					if pins = fnblock.instruction[moved_idx]
						{pRA, pRB, pRC, op: pop} = pins

						switch pop
							when ADD, SUB, MUL, DIV, MOD, IDIV, BAND, BXOR, BOR, SHL, SHR, POW
								typeRB = rtype fnblock, moved_idx, pRB, du_cfg
								typeRC = rtype fnblock, moved_idx, pRB, du_cfg

								if typeRB == "number" and typeRC == "number"
									if d_rb.def
										if #(filter (=> (@reg == pRB or @reg == pRC) and moved_idx < @line and  @line < ins_idx), d_rb.def) == 0
											hoisting ins_idx, pins, RA
							when MOVE
								if d_rb.def and #(filter (=> @reg == pRB and moved_idx < @line and  @line < ins_idx), d_rb.def) == 0
									hoisting ins_idx, pins, RA
							when LOADK
								hoisting ins_idx, pins, RA

							-- TODO: consider of closed variables
							-- when CLOSURE
								-- hoisting fnblock, ins_idx, moved_idx, pins, RA

								-- proto = fnblock.prototype[pRB + 1]

								-- for u in *proto.upvalue
									-- if u.instack == 1 and u.reg == pRA
										-- u.reg = RA

		ins_idx += 1

