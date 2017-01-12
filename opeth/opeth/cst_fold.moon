import rtype, rcst from require'opeth.opeth.common.constant'
import cst_lookup, cst_add, swapins from require'opeth.opeth.common.utils'
import du_chain from require'opeth.opeth.common.du_chain'
import insert, concat from table
optbl = require'opeth.opeth.common.optbl'

INF = 1 / 0
NAN = 0 / 0
isnan = => "-nan" == tostring @

(fnblock) ->
	du_cfg = du_chain fnblock

	registercst = (cst, ins_idx, ra) ->
		if cst != INF and (cst != -INF) and not isnan cst
			if cst_idx = cst_lookup fnblock.constant, cst
				swapins fnblock.instruction, ins_idx, {ra, cst_idx - 1, op: LOADK}
			else
				cst_add fnblock.constant, cst
				swapins fnblock.instruction, ins_idx, {ra, #fnblock.constant - 1, op: LOADK}

			du_cfg = du_chain fnblock
			fnblock.optdebug.modified += 1

	for ins_idx = 1, #fnblock.instruction
		{RA, RB, RC, :op} = fnblock.instruction[ins_idx]

		switch op
			when ADD, SUB, MUL, DIV, MOD, IDIV, BAND, BXOR, BOR, SHL, SHR, POW
				if (rtype fnblock, ins_idx, RB, du_cfg) == "number"
					if (rtype fnblock, ins_idx, RC, du_cfg) == "number"
						has_cst, cst = rcst fnblock, ins_idx, RA, du_cfg
						registercst cst, ins_idx, RA if has_cst
			when NOT
				switch (rtype fnblock, ins_idx, RA, du_cfg)
					when "bool"
						has_cst, cst = rcst fnblock, ins_idx, RB, du_cfg
						registercst cst, ins_idx, RA if has_cst
					when "string", "number"
						registercst false, ins_idx, RA
			when UNM
				switch rtype fnblock, ins_idx, RA, du_cfg
					when "number"
						has_cst, cst = rcst fnblock, ins_idx, RA, du_cfg
						registercst cst, ins_idx, RA if has_cst
			when LEN
				if (rtype fnblock, ins_idx, RB, du_cfg) == "string"
					has_cst, len = rcst fnblock, ins_idx, RA, du_cfg
					registercst len, ins_idx, RA if has_cst
			when CONCAT
				has_cst, cst = rcst fnblock, ins_idx, RA, du_cfg
				registercst cst, ins_idx, RA if has_cst

