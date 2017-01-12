-- name        = $(awk '$1 !~ /^--/ {print $1}' HERE)
-- version     = $(awk '$1 !~ /^--/ {print $1}' opeth/opeth/cmd/version.lua)
-- description = $(awk '$1 !~ /^--/ {print $5}' HERE)
name: "opeth" , version: (require'opeth.opeth.cmd.version') , description: "Lua VM Bytecode Optimizer"
