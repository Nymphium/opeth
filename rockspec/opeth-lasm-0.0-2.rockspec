package = "opeth-lasm"
version = "0.0-2"
source = {
   url = "git://github.com/nymphium/opeth"
}
description = {
   homepage = "https://github.com/nymphium/opeth",
   license = "MIT"
}
dependencies = {
   "lua >= 5.3",
   "opeth-core",
   "lpeg"
}
build = {
   type = "builtin",
   modules = {},
   install = {
      bin = {
         lasmc = "opeth/bin/lasmc.moon"
      },
      lua = {
         ["opeth.lasm.syntax"] = "opeth/lasm/syntax.moon"
      }
   }
}
