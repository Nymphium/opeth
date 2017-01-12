import cst_lookup, cst_add, insertins, removeins, swapins, adjust_jump_pos_down, adjust_jump_pos_up from require'opeth.opeth.common.utils'
import du_chain, root_def, this_def from require'opeth.opeth.common.du_chain'
import get_block from require'opeth.common.blockrealm'
import undecimal, deepcpy, cstid from require'opeth.common.utils'
import hextoint from undecimal

trace_MOVE = (instruction, n, du_cfg) ->
	switch instruction[n].op
		when MOVE
			if blk = get_block nil, n, du_cfg
				if moved = this_def blk, n, instruction[n][2]
					trace_MOVE instruction, moved.line, du_cfg
		when CLOSURE then n

max_reg = (instruction, pos) ->
	with maxn = 0 do for i = 1, pos
		{RA} = instruction[i]
		maxn = math.max maxn, RA

is_recursive = (fnblock, clos_ins) ->
	proto = fnblock.prototype[clos_ins[2] + 1]

	with bool = false
		for pu in *proto.upvalue
			bool or= pu.instack == 1 and pu.reg == clos_ins[1]

lookup_upvalue_index = (upvlist, upvalue) ->
	for i = 1, #upvlist
		if upvlist[i].reg == upvalue.reg and upvlist[i].instack == upvalue.instack
			return i

(fnblock) ->
	du_cfg = du_chain fnblock
	ins_idx = 1

	while ins_idx <= #fnblock.instruction
		ins = fnblock.instruction[ins_idx]
		{RA, RB, RC, :op} = ins

		switch op
			when CALL
				blk = get_block nil, ins_idx, du_cfg

				unless blk.start < ins_idx
					ins_idx += 1
					continue

				if d_ra = this_def blk, ins_idx - 1, RA
					if clos_idx = trace_MOVE fnblock.instruction, d_ra.line, du_cfg
						proto_idx = fnblock.instruction[clos_idx][2] + 1

						if proto = deepcpy fnblock.prototype[proto_idx]
							if (hextoint proto.regnum) + (hextoint fnblock.regnum) < 256 and not is_recursive fnblock, fnblock.instruction[clos_idx]
								params = hextoint proto.params

								-- #arg for the closure
								argnum = RA + RB - 2

								cst_transfer = (prev_ins, rx) ->
									positive = (prev_ins[rx]) >= 0
									cst = proto.constant[cstid prev_ins[rx] ].val
									prev_ins[rx] = if cidx = cst_lookup fnblock.constant, cst
										positive and cidx - 1 or -cidx
									else
										cidx = cst_add fnblock.constant, cst
										positive and cidx - 1 or -cidx

								proto_ins_idx = 1
								OFFS = (RB == 0 and ((max_reg fnblock.instruction, ins_idx) + 2) or (RA + RB)) - params
								modifiable = true
								jmp_store = {}

								while proto_ins_idx <= #proto.instruction
									prev_ins = proto.instruction[proto_ins_idx]
									{pRA, pRB, pRC, op: prev_op} = prev_ins

									switch prev_op
										when LOADK, GETGLOBAL, SETGLOBAL
											prev_ins[1] += OFFS
											cst_transfer prev_ins, 2
										when MOVE, UNM, NOT, LEN, TESTSET
											prev_ins[1] += OFFS
											prev_ins[2] += OFFS
										when LOADNIL
											prev_ins[1] += OFFS
											prev_ins[2] += OFFS if pRB > 0
										when ADD, SUB, MUL, MOD, POW, DIV, IDIV, BAND, BOR, BXOR, SHL, SHR, SETTABLE
											prev_ins[1] += OFFS

											if pRB < 0 then cst_transfer prev_ins, 2
											else prev_ins[2] += OFFS

											if pRC < 0 then cst_transfer prev_ins, 3
											else prev_ins[3] += OFFS
										when GETUPVAL
											prev_upv = proto.upvalue[pRB + 1]

											if prev_upv.instack == 0
												if fnblock.upvalue[prev_upv.reg + 1]
													prev_ins[1] += OFFS
													prev_ins[2] = prev_upv.reg
												else
													modifiable = false
													break
											else
												if def = root_def blk, ins_idx, prev_upv.reg
													swapins proto.instruction, proto_ins_idx, {pRA + OFFS, def.reg, 0, op: MOVE}
												else
													modifiable = false
													break
										when GETTABUP
											prev_upv = proto.upvalue[pRB + 1]

											if pRC < 0
												cst_transfer prev_ins, 3
											else
												prev_ins[3] += OFFS

											if prev_upv.instack == 0
												if fnblock.upvalue[prev_upv.reg + 1]
													prev_ins[1] += OFFS
													prev_ins[2] = prev_upv.reg
												else
													modifiable = false
													break
											else swapins proto.instruction, proto_ins_idx, {pRA + OFFS, prev_upv.reg + OFFS, prev_ins[3], op: GETTABLE}
										when SETUPVAL
											prev_upv = proto.upvalue[pRA + 1]

											if prev_upv.instack == 0
												modifiable = false
												break

											swapins proto.instruction, proto_ins_idx, {prev_upv.reg, pRB + OFFS, op: MOVE}
										when EQ, LT, LE
											if pRB < 0 then cst_transfer prev_ins, 2
											else prev_ins[2] += OFFS

											if pRC < 0 then cst_transfer prev_ins, 3
											else prev_ins[3] += OFFS
										when GETTABLE, SELF
											prev_ins[1] += OFFS
											prev_ins[2] += OFFS

											if pRC < 0 then cst_transfer prev_ins, 3
											else prev_ins[3] += OFFS
										when LOADBOOL, CLOSURE, CALL, FORPREP, FORLOOP, TFORLOOP, TFORCALL, TEST, NEWTABLE
											prev_ins[1] += OFFS
										when JMP
											_ = 0 -- skip
										when RETURN
											nextins = fnblock.instruction[ins_idx + 1]

											-- the number of return values
											if nextins.op == CALL
												if pRB == 1 then nextins[2] = 1
												elseif pRB > 1 then nextins[2] = pRB

											removeins proto.instruction, proto_ins_idx
											proto_ins_idx -= 1

											if RC != 1 and pRB != 1
												movelimit = pRB == 0 and (max_reg proto.instruction, proto_ins_idx) or pRA + pRB - 2

												for moved_reg = movelimit, pRA, -1
													moveRA = RA + moved_reg - pRA -- register for caller to put the return value
													insertins proto.instruction, proto_ins_idx + 1, {moveRA, moved_reg + OFFS, 0, op: MOVE}
													proto_ins_idx += 1

												proto_ins_idx += 1
											elseif proto_ins_idx > 0
												insertins proto.instruction, proto_ins_idx, {RA, RA + RC - 1, op: LOADNIL}
												proto_ins_idx += 1

											if proto_ins_idx < #proto.instruction - 1
												jmp = {proto_ins_idx, 0, op: JMP}
												insertins proto.instruction, proto_ins_idx, jmp
												proto_ins_idx += 1
												table.insert jmp_store, jmp
											else
												break
										when EXTRAARG
											cst_transfer prev_ins, 1
										when TAILCALL
											modifiable = false
											break

									proto_ins_idx += 1

								if modifiable
									-- remove CALL from main
									removeins fnblock.instruction, ins_idx
									fnblock.optdebug.modified += 1
									proto_ins_idx -= 1

									for jmp in *jmp_store
										jmp[2] = proto_ins_idx - jmp[1] - 1
										jmp[1] = 0

									for pii = 1, proto_ins_idx
										insertins fnblock.instruction, ins_idx + pii - 1, proto.instruction[pii], true
										fnblock.optdebug.modified += 1

									adjust_jump_pos_up fnblock.instruction, ins_idx, nil, proto_ins_idx
									adjust_jump_pos_down fnblock.instruction, ins_idx + proto_ins_idx, nil, proto_ins_idx

									ins_idx += 1
									du_cfg = du_chain fnblock

		ins_idx += 1

