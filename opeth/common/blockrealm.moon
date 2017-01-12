import insert, remove, sort from table
import tointeger from math
import map, filter from require'opeth.common.utils'

local get_block

validly_insert = (t, v) ->
	unless v.start and v.end
		error "lack of block elements v.start: #{v.start}, v.end: #{v.end}"

	if v.start > v.end
		error "invalid block"

	unless #(filter (=> @start == v.start and @.end == v.end), t) > 0
		insert t, v
		map tointeger, {v.start, v.end}

		sort t, (a, b) -> a.end < b.start

-- shrink `blk` from `delimp` to `blk.end`,
-- and return new block `blk.start` to `delimp - 1`
split_block = (blk, delimp) ->
	with newblk = {start: blk.start, end: delimp - 1, succ: {blk}, pred: blk.pred}
		blk.start = delimp
		blk.pred = {newblk}

mkcfg = (instruction) ->
	blocks = {}

	for ins_idx = 1, #instruction
		singleblock = {start: ins_idx, end: ins_idx, succ: {}, pred: {}}
		{RA, RB, RC, :op} = instruction[ins_idx]

		singleblock.succ_pos = switch op
			when JMP, FORPREP then {ins_idx + RB + 1}
			when LOADBOOL then {ins_idx + 2} if RC == 1
			when TESTSET, TEST, LT, LE, EQ then {ins_idx + 1, ins_idx + 2}
			when FORLOOP, TFORLOOP then {ins_idx + 1, ins_idx + RB + 1}
			when RETURN, TAILCALL then {}

		validly_insert blocks, singleblock

	blk_idx = 1

	while blocks[blk_idx]
		blk = blocks[blk_idx]

		if blk.succ_pos
			while #blk.succ_pos > 0
				succ_pos = remove blk.succ_pos, 1

				if blk_ = get_block instruction, succ_pos, blocks
					if blk_.start < succ_pos
						newblk = split_block blk_, succ_pos
						validly_insert blocks, newblk
						validly_insert blk_.pred, blk
						validly_insert blk.succ, blk_
					else
						validly_insert blk_.pred, blk
						validly_insert blk.succ, blk_
				else
					if #blk.succ_pos > 0
						insert blk.succ_pos, succ_pos
					else
						error "cannot resolve succ_pos #{succ_pos} / ##{#instruction}"

			blk.succ_pos = nil
		elseif #blk.succ == 0
			nextblock = blocks[blk_idx + 1]

			if #nextblock.pred > 0
				validly_insert nextblock.pred, blk
				validly_insert blk.succ, nextblock
			else
				{:start, :pred} = blk
				remove blocks, blk_idx
				(for psucci = 1, #p.succ
					if p.succ[psucci].start == start
						remove p.succ, psucci
						validly_insert p.succ, nextblock
						break
				) for p in *pred

				nextblock.start = start
				nextblock.pred = pred
				continue

		blk_idx += 1

	blocks

get_block = (instruction, nth, blocks = mkcfg instruction) ->
	return b for b in *blocks when ((b.start <= nth) and (b.end >= nth))

:get_block, :mkcfg

