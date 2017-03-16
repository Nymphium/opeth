package = "opeth-opeth"
version = "0.0-1"
source = {
	url = "git://github.com/nymphium/opeth"
}
description = {
	homepage = "https://github.com/nymphium/opeth",
	license = "MIT"
}

dependencies = {
	"opeth-core",
	"argparse",
	"luasocket"
}

build = {
	type = "builtin",
	modules = {},
	install = {
		lua = {
			[ [[opeth.opeth.init]] ] = [[opeth/opeth/init.moon]],
			[ [[opeth.opeth.common.du_chain]] ] = [[opeth/opeth/common/du_chain.moon]],
			[ [[opeth.opeth.common.constant]] ] = [[opeth/opeth/common/constant.moon]],
			[ [[opeth.opeth.common.optbl]] ] = [[opeth/opeth/common/optbl.moon]],
			[ [[opeth.opeth.common.utils]] ] = [[opeth/opeth/common/utils.moon]],
			[ [[opeth.opeth.cmd.debuginfo]] ] = [[opeth/opeth/cmd/debuginfo.moon]],
			[ [[opeth.opeth.cmd.version]] ] = [[opeth/opeth/cmd/version.lua]],
			[ [[opeth.opeth.cmd.optimizer]] ] = [[opeth/opeth/cmd/optimizer.moon]],
			[ [[opeth.opeth.cmd.metainfo]] ] = [[opeth/opeth/cmd/metainfo.moon]],
			[ [[opeth.opeth.dead_elim]] ] = [[opeth/opeth/dead_elim.moon]],
			[ [[opeth.opeth.unreachable_remove]] ] = [[opeth/opeth/unreachable_remove.moon]],
			[ [[opeth.opeth.defrag_reg]] ] = [[opeth/opeth/defrag_reg.moon]],
			[ [[opeth.opeth.unused_remove]] ] = [[opeth/opeth/unused_remove.moon]],
			[ [[opeth.opeth.func_inline]] ] = [[opeth/opeth/func_inline.moon]],
			[ [[opeth.opeth.cst_prop]] ] = [[opeth/opeth/cst_prop.moon]],
			[ [[opeth.opeth.cst_fold]] ] = [[opeth/opeth/cst_fold.moon]],
			[ [[opeth.opeth.clean_cstclos]] ] = [[opeth/opeth/clean_cstclos.moon]],
		},
		bin = {
			opeth = [[opeth/bin/opeth.moon]]
		}
	}
}
