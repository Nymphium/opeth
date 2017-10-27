#!/bin/env moon

import read, Reader from require'opeth.bytecode.reader'
import write, Writer from require'opeth.bytecode.writer'
import gettime from require'socket'
import name, description, version from require'opeth.opeth.cmd.metainfo'
argparse = require'argparse'
optimizer = require'opeth.opeth.cmd.optimizer'

fn_time = (fn) ->
	t1 = gettime!
	fn!
	t2 = gettime!
	t2 - t1

inscounter = (fnblock) ->
	with cnt = #fnblock.instruction
		for proto in *fnblock.prototype
			cnt += inscounter proto

args = (=> @parse!) with argparse name, description
	\argument "input",                                        "luac file"
	\option(   "-o --output",           "output file",         "optimized.out"
		)\overwrite false
	\option(  "-x --disable-optimize", "disable a part of optimizer"
		)\argname("index"
		)\args("1+"
		)\convert(=> tonumber @
		)\target"mask"
	\flag     "-V --verbose",          "verbose optimization process"
	\flag     "-T --time",             "measure the time"
	\flag(    "-v --version",          "version information"
		)\action(->
			print "#{name} v#{version}\n#{description}"
			os.exit 0
		)
	\flag(    "--list-optimizations",  "show a list of otimization"
		)\action(->
			for o in *optimizer.opt_names
				print "%-26s : %s"\format o.name, o.description
			os.exit 0
		)

((ok, cont) ->
	unless ok
		msg = "\noutput file is none\n"

		if cont\match "interrupted!"
			msg = "interrupted!#{msg}"
		else
			msg = "#{cont}#{msg}"

		io.stderr\write "\n[Error]: #{msg}"
) pcall ->
	rd = Reader args.input
	wt = Writer args.output

	io.write  "read from #{args.input} (size: #{#rd} byte" if args.verbose
	local vmfmt
	rtime = (fn_time -> vmfmt = rd\read!) * 1000

	io.write if args.time then args.verbose and ", time: #{rtime} msec)\n" or "read time: #{rtime} msec\n"
	elseif args.verbose then ")\n"
	else ""

	rd\close!

	insnum = if args.verbose then inscounter vmfmt.fnblock
	otime = fn_time -> (optimizer vmfmt.fnblock, args.mask, args.verbose).chunkname = ""
	print "#{args.verbose and "(" or  ""}optimize time: #{otime * 1000} msec#{args.verbose and ")" or ""}" if args.time

	(=> @\close!) with wt
		wtime = (fn_time -> wt\write vmfmt) * 1000
		print "change of the number of instructions: #{insnum} -> #{inscounter vmfmt.fnblock}" if args.verbose
		io.write "\nwrite to #{args.output} (size: #{#wt} byte" if args.verbose
		io.write if args.time then args.verbose and ", time: #{wtime} msec)\n" or "write time: #{wtime} msec\n"
		elseif args.verbose then ")\n"
		else ""

