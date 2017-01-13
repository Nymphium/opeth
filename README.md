Opeth
===

Opeth is the optimizer and debug tools for [Lua](https://lua.org) VM bytecode, or [Metal band](http://www.opeth.com/).

# tools
## opeth
Lua VM Bytecode optimizer

### install
```
luarocks --local install opeth-opeth
```
### usage

```
Usage: opeth [-o <output>] [-V] [-T] [-v] [--show-optimizations] [-h]
       <input> [-x index [index] ...]

Lua VM Bytecode Optimizer

Arguments:
   input                 luac file

Options:
   -o <output>, --output <output>
                         output file (default: optimized.out)
   -x index [index] ..., --disable-optimize index [index] ...
                         disable a part of optimizer
   -V, --verbose         verbose optimization process
   -T, --time            measure the time
   -v, --version         version information
   --show-optimizations  show a sort of otimization
   -h, --help            Show this help message and exit.
```

## lvis
Lua VM Bytecode Control Flow Graph Visualizer
### install
```
luarocks --local install opeth-lvis
```

## moonstep
Lua VM Bytecode step-by-step execution machine
### install
```
luarocks --local install opeth-moonstep
```

## commands
```
command:
        bp <pc>: set a breakpoint to <pc>
        r: run the code. if the breakpoint is set, stop at <pc>
        n: execute the next instruction
        d: dump the current register and PC
        q: quit
```

## lasmc
**L**ua VM Bytecode **As**se**m**bly-like Language **C**ompiler
### install
```
luarocks --local install opeth-lasm
```

### syntax
......

# dependency
- [MoonScript](https://moonscript.org)
- [luasocket](http://w3.impa.br/~diego/software/luasocket/)
- [argparse](http://mpeterv.github.io/argparse/)
- [lua-graphviz](https://github.com/Nymphium/lua-graphviz)
- [inspect.lua](https://github.com/kikito/inspect.lua)

# LICENSE
[MIT](https://opensource.org/licenses/MIT)

