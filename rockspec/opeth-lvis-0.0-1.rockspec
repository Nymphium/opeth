package = "opeth-lvis"
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
	"graphviz"
}

build = {
	type = "builtin",
	modules = {},
	install = {
		bin = {
			lvis = [[opeth/bin/lvis.moon]]
		}
	}
}

