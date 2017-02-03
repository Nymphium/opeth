#!/bin/env moon

import Reader, read from require'opeth.bytecode.reader'
VMCtrler = require'opeth.moonstep.vm'

local filename

vmfmt = do
	filename = arg[1] or "luac.out"
	f = assert (io.open filename), "Failed to open #{filename} No such file or directory"
	with read Reader f
		f\close!

runner = VMCtrler vmfmt.fnblock, filename
runner\run!

