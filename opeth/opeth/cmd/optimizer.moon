import map, deepcpy from require'opeth.common.utils'
Debuginfo = require'opeth.opeth.cmd.debuginfo'

print_moddiffgen = (optfn, optname) -> (fnblock) ->
	fnblock.optdebug\start_rec!
	optfn fnblock
	fnblock.optdebug\print_modified optname

opt_names = {
	{
		name:"unreachable blocks removal"
		description: "remove all the blocks which are unreachable for the top"
	}
	{
		name: "constant fold"
		description: "evaluate some operations beforehand"
	}
	{
		name: "constant propagation"
		description: "replace `MOVE` instruction with the another"
	}
	{
		name:"dead-code elimination"
		description: "eliminate the instructions which aren't needed"
	}
	{
		name:"function inlining"
		description: "expand a funcion call with the function's instructions"
	}
}

unreachable_remove = print_moddiffgen require'opeth.opeth.unreachable_remove', opt_names[1].name
cst_fold = print_moddiffgen require'opeth.opeth.cst_fold', opt_names[2].name
cst_prop = print_moddiffgen require'opeth.opeth.cst_prop', opt_names[3].name
dead_elim = print_moddiffgen require'opeth.opeth.dead_elim', opt_names[4].name
func_inline = print_moddiffgen require'opeth.opeth.func_inline', opt_names[5].name
unused_remove = print_moddiffgen require'opeth.opeth.unused_remove', "unused resources removal"

opt_tbl = {
	unreachable_remove
	(=> func_inline @ if #@prototype > 0)
	cst_fold
	cst_prop
	dead_elim
	mask: (mask) =>
		newtbl = deepcpy @
		newtbl[i] = (=>) for i in *mask
		newtbl
}

optimizer = (fnblock, mask, verbose) ->
	unless fnblock.optdebug
		fnblock.optdebug = Debuginfo 0, 0, nil, verbose
	else fnblock.optdebug\reset_modified!

	map (=> @ fnblock), opt_tbl\mask mask

	for pi = 1, #fnblock.prototype
		debuginfo = Debuginfo fnblock.optdebug.level + 1, pi, fnblock.optdebug\fmt!, verbose
		fnblock.prototype[pi].optdebug = debuginfo
		optimizer fnblock.prototype[pi], mask, verbose

	optimizer fnblock, mask if fnblock.optdebug.modified > 0

recursive_clean = (fnblock, verbose) ->
	unused_remove fnblock

	for pi  = 1, #fnblock.prototype
		debuginfo = Debuginfo fnblock.optdebug.level + 1, pi, fnblock.optdebug\fmt!, verbose
		fnblock.prototype[pi].optdebug = debuginfo
		recursive_clean fnblock.prototype[pi], verbose

setmetatable {:opt_names},
	__call: (fnblock, mask = {}, verbose) =>
		optimizer fnblock, mask, verbose
		recursive_clean fnblock, verbose
		fnblock

