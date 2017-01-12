oplist = require'opeth.common.oplist'!

cst_lookup = (constant, cst) ->
	for i = 1, #constant do if constant[i].val == cst then return i

v2typ = (cst) ->
	switch type cst
		when "number"
			math.type(cst) == "integer" and 0x13 or 0x3
		when "string"
			#cst > 255 and 0x14 or 0x4

cst_add = (constant, cst) ->
	with idx = #constant + 1
		constant[idx] = {type: v2typ(cst), val: cst}

-- adjust_jump_pos = (instruction, ins_idx, is_remove) ->
	-- for j = 1, #instruction
adjust_jump_pos_core = (j, instruction, ins_idx, is_remove, plus = 1) ->
	jins = instruction[j]
	error "#{j} / #{#instruction}", 4 unless jins
	jRB = jins[2]

	switch jins.op
		when JMP, FORPREP
			if is_remove
				if (j < ins_idx and j + jRB + 1 > ins_idx)
					jins[2] -= plus
				elseif (j > ins_idx and j + jRB + 1 < ins_idx)
					jins[2] += plus
			else
				if (j < ins_idx + 1 and j + jRB >= ins_idx)
					jins[2] += plus
				elseif (j > ins_idx + 1 and j + jRB + 1 <= ins_idx)
					jins[2] -= plus
		when FORLOOP, TFORLOOP
			if j >= ins_idx and j + jRB + 1 <= ins_idx
				jins[2] -= is_remove and -plus or plus

adjust_jump_pos_down = (instruction, ins_idx, is_remove, plus) ->
	for j = ins_idx, #instruction
		adjust_jump_pos_core j, instruction, ins_idx, is_remove, plus

adjust_jump_pos_up = (instruction, ins_idx, is_remove, plus) ->
	for j = ins_idx, 1, -1
		adjust_jump_pos_core j, instruction, ins_idx, is_remove, plus

adjust_jump_pos = (instruction, ins_idx, is_remove, plus) ->
	for i = 1, #instruction
		adjust_jump_pos_core i, instruction, ins_idx, is_remove, plus

insertins = (instruction, ins_idx, ins, is_unchanged_pos) ->
	assert ((type ins[1]) == (type ins[2])) and
		((type ins[1]) == "number") and
		(ins[3] and ((type ins[3]) == "number") or true),
		"insertins #3: invalid instruction `#{ins.op} #{ins[1]} #{ins[2]} #{ins[3] and ins[3] or ""}`"

	assert oplist[ins.op], "insertins #3: invalid op `#{ins.op}'"

	assert instruction[ins_idx],
		"insertins #2: attempt to insert out of range of the instructions (#{ins_idx} / #{#instruction})"

	table.insert instruction, ins_idx, ins
	adjust_jump_pos instruction, ins_idx unless is_unchanged_pos

removeins = (instruction, ins_idx, is_unchanged_pos) ->
	assert instruction[ins_idx],
		"removeins #2: attempt to remove out of range of the instructions (#{ins_idx} / #{#instruction})"

	table.remove instruction, ins_idx
	adjust_jump_pos instruction, ins_idx, true unless is_unchanged_pos

swapins = (instruction, ins_idx, ins) ->
	removeins instruction, ins_idx, true
	insertins instruction, ins_idx, ins, true

:insertins, :removeins, :swapins, :adjust_jump_pos, :adjust_jump_pos_up, :adjust_jump_pos_down, :cst_lookup, :v2typ, :cst_add

