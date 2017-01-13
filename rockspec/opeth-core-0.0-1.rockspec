package = "opeth-core"
version = "0.0-1"
source = {
	url = "git://github.com/nymphium/opeth"
}

description = {
	homepage = "https://github.com/nymphium/opeth",
	license = "MIT"
}

dependencies = {
	"lua >= 5.3",
	"moonscript >= 0.5"
}

build = {
	type = "builtin",
	modules = { },
	install = {
		lua = {
			[ [[opeth.bytecode.writer]] ] = [[opeth/bytecode/writer.moon]],
			[ [[opeth.bytecode.reader]] ] = [[opeth/bytecode/reader.moon]],
			[ [[opeth.common.oplist]] ] = [[opeth/common/oplist.lua]],
			[ [[opeth.common.blockrealm]] ] = [[opeth/common/blockrealm.moon]],
			[ [[opeth.common.utils]] ] = [[opeth/common/utils.moon]],
			[ [[opeth.common.opname]] ] = [[opeth/common/opname.lua]],
		}
	}
}

