package = "opeth-all"
version = "0.0-1"
source = {
	url = "git://github.com/nymphium/opeth"
}

description = {
	homepage = "https://github.com/nymphium/opeth",
	license = "MIT"
}

dependencies = {
	"opeth-opeth",
	"opeth-moonstep",
	"opeth-lvis",
	"opeth-lasm"
}

build = {
	type = "builtin",
	modules = {}
}

