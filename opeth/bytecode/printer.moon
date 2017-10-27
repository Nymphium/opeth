import undecimal, map from require'opeth.common.utils'

mklbl = (lbl, c = "=") ->
	cc = c\rep 5
	"#{cc}%s#{cc}"\format lbl

typetable = {"nil", "bool", "number", "string", [0x13]: "integer", [0x14]: "long string"}

-- printer
-- {{{
printer = with  head: =>
		for k, v in pairs @
			if type(v) == "table"
				for k_, v_ in pairs v
					print "#{k}.#{k_}", v_
			else
				print k, v

	fnblock = (chunkname, is_closure) => with @
		print "#{is_closure and "function" or "main"} <%s: %d, %d> param: %s"\format (#chunkname == 0 and '(stripped)' or chunkname), unpack map (=> undecimal.hextoint @), {.line.defined, .line.lastdefined, .params}
		dbg = .debug
		with ins = .instruction
			print  mklbl"INSTRUCTIONS"
			for i = 1, #@instruction do print ("\t%-4d  [%d]  %-8s "\format i, (.has_debug and dbg.opline[i] or -1), ins[i].op), unpack map (=> "%-4d"\format @), ins[i]  --, "#{"%-4d "\rep (#ins[i] - 2)}"\format(unpack table.move ins[i], 3, 5, 1, {})

		with cst =  .constant
			print mklbl"CONSTANTS"
			for i = 1, #cst do if l = cst[i] then print "\t%d\t%s"\format i, l.val

		with pt =  .prototype
			for i = 1, #@prototype
				print mklbl "prototype", "~"
				fnblock pt[i], chunkname, true
				print mklbl "~"\rep(5), "~"

		with .debug
			print mklbl"DEBUG"
			print "#{mklbl"LOCALS"} (#{.varnum})"
			for i = 1, .varnum
				with .varinfo[i] do print "\t%-d\t%-s\t%-d\t%-d"\format i-1, .varname, .life.begin + 1, .life.end + 1

			print "#{mklbl"UPVALUES"} (#{.upvnum})"
			for i = 1, .upvnum do print "", i - 1, "#{.upvinfo[i]}", @upvalue[i].instack, @upvalue[i].reg

	.fnblock = fnblock
-- }}}

printer

