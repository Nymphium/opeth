import removeins from require'opeth.opeth.common.utils'
import mkcfg from require'opeth.common.blockrealm'

(fnblock) ->
	for cfg in *(mkcfg fnblock.instruction)
		-- unreachable? the block, the beggining of which line is greater than 1
		--   and doesn't have the predecessive blocks
		start = cfg.start
		if start > 1 and #cfg.pred == 0

			if #fnblock.instruction < start then break
			if start == cfg.end then continue

			for _ = start, cfg.end
				switch fnblock.instruction[start].op
					when LOADBOOL
						if fnblock.instruction[start - 1].op == LOADBOOL
							fnblock.instruction[start - 1][3] = 0
							break
					when JMP
						break if fnblock.instruction[start][1] > 0

				removeins fnblock.instruction, start

			fnblock.optdebug.modified += cfg.end - start + 1
			break -- :)

