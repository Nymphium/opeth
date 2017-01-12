if not RETURN then
	require'opeth.common.opname'
end

return function(abc, abx, asbx, ax)
	local t = {
		{MOVE, abc}, {LOADK, abx}, {LOADKX, abx}, {LOADBOOL, abc}, {LOADNIL, abc}, {GETUPVAL, abc}, {GETTABUP, abc},
		{GETTABLE, abc}, {SETTABUP, abc}, {SETUPVAL, abc}, {SETTABLE, abc}, {NEWTABLE, abc},
		{SELF, abc}, {ADD, abc}, {SUB, abc}, {MUL, abc}, {MOD, abc}, {POW, abc}, {DIV, abc},
		{IDIV, abc}, {BAND, abc}, {BOR, abc}, {BXOR, abc}, {SHL, abc}, {SHR, abc}, {UNM, abc}, {BNOT, abc},
		{NOT, abc}, {LEN, abc}, {CONCAT, abc}, {JMP, asbx}, {EQ, abc}, {LT, abc}, {LE, abc}, {TEST, abc},
		{TESTSET, abc}, {CALL, abc}, {TAILCALL, abc}, {RETURN, abc}, {FORLOOP, asbx}, {FORPREP, asbx},
		{TFORCALL, abc}, {TFORLOOP, asbx}, {SETLIST, abc}, {CLOSURE, abx}, {VARARG, abc}, {EXTRAARG, ax}
	}

	for i = 1, #t do
		t[i].idx = i
		-- table.insert(t[i], i)
		-- t[i][3] = i
	end

	for k, v in pairs(t) do
		t[v[1] ] = v
	end

	return t
end

