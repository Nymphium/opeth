package = "opeth-lasm"
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
	"lpeg"
}

build = {
	type = "builtin",
	modules = {},
	install = {
		lua = {
			[ [[opeth.lasm.syntax]] ] = [[opeth/lasm/syntax.moon]],
		},
		bin = {
			lasmc = [[opeth/bin/lasmc.moon]]
		}
	}
}
