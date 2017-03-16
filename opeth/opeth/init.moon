-- optimizing in scripts

import Reader, read from require'opeth.bytecode.reader'
import Writer, write from require'opeth.bytecode.writer'
optimizer = require'opeth.opeth.cmd.optimizer'

(fn, mask, verbose) ->
	-- it's not good to use `debug` info but...
	if type(fn) == "function" and (debug.getinfo fn).what == "Lua"
		newbytecode = (Reader fn)\read!
		optimizer newbytecode.fnblock, mask, verbose
		fn_ = write Writer!, newbytecode

		load fn_.cont.block

