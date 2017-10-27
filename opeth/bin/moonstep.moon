#!/bin/env moon

import Reader, read from require'opeth.bytecode.reader'
VMCtrler = require'opeth.moonstep.vm'

local filename

vmfmt = do
	filename = arg[1] or "luac.out"
	rd = Reader filename
	with rd\read!
		rd\close!

runner = VMCtrler vmfmt.fnblock, filename
runner\run!

