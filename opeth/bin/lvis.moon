#!/bin/env moon

import read, Reader from require'opeth.bytecode.reader'
import mkcfg from require'opeth.common.blockrealm'
import map from require'opeth.common.utils'
Graph = require'graphviz'

ptr_to_idx = (cfg, to_lua) ->
	indexed_cfg = [{succ: {}, pred: {}, start: b.start, end: b.end} for b in *cfg]

	for i = 1, #cfg
		if to_lua
			indexed_cfg[i].ed = cfg[i].end
			indexed_cfg[i].end = nil

		if instr = cfg[i].instr
			indexed_cfg[i].instr = instr

		for predidx = 1, #(cfg[i].pred)
			for j = 1, #cfg
				if (tostring cfg[i].pred[predidx]) == (tostring cfg[j])
					indexed_cfg[i].pred[predidx] = j
					break
		for toidx = 1, #(cfg[i].succ)
			for j = 1, #cfg
				if (tostring cfg[i].succ[toidx]) == (tostring cfg[j])
					indexed_cfg[i].succ[toidx] = j
					break

	indexed_cfg

process_proto = (fn, dot, lprefix, idx = 1) ->
	cfg = ptr_to_idx mkcfg fn.instruction

	for i = 1, #cfg
		cfg[i].instr = ""
		for j = cfg[i].start, cfg[i].end
			cfg[i].instr ..=  "%4d: %-8s %-14s\n"\format j, fn.instruction[j].op, table.concat (map (=> "%4d"\format math.tointeger @), fn.instruction[j]), " "

		dot\node("#{lprefix}_b#{i}", "\\N: [#{cfg[i].start} ~ #{cfg[i].end}]\n#{cfg[i].instr}")

	for i = 1, #cfg
		for j = 1, #cfg[i].succ
			dot\edge("#{lprefix}_b#{i}", "#{lprefix}_b#{cfg[i].succ[j]}")

	for pi = 1, #fn.prototype
		process_proto fn.prototype[pi], dot, lprefix .. "→clos#{idx}_#{pi}", idx + 1


vmfmt = do
	rd = Reader arg[1]
	with rd\read!
		rd\close!

dot = Graph!
fontname = "Inconsolata Regular"
styles = {
	graph: {
	}

	nodes: {
		:fontname
		shape: "rectangle"
	}

	edges: {
		:fontname
	}
}

dot.nodes.style\update styles.nodes
dot.edges.style\update styles.edges

process_proto vmfmt.fnblock, dot, "main"
dot\render "drawngraph"

