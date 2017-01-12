import P, S, V, C, Ct, locale, match from require'lpeg'

locale = locale!
tointeger = math.tointeger

multiwrap = (...) -> {...}


natnum = P'-'^-1 * (
			P'0x'*locale.xdigit^1 + locale.digit^1 *
			(P'.' * locale.digit^1)^-1
		) / => (tointeger @) or tonumber @

lasm = P{
	V'Main' * V'Space' / (...) -> {(table.remove a, 1), a for a in *{...}}
	Comment: P'--' * (P(1) - P'\n')^0
	Space: (locale.space + V'Comment')^0
	Main: V'Space' * V'MainBlock' * (V'Space' * V'Block')^0
	MainBlock: C(P"main") * P':' * V'Space' * V'ArgNum' * V'Space' * V'Vararg' * V'Space' * V'BlockBody' / (label, params, vararg, instruction, constant) -> {label, :params, :vararg, :instruction, :constant}
	Block: C(locale.alnum^1) * P':' * V'Space' * V'ArgNum' * V'Space' * V'Vararg' * V'Space' * V'BlockBody' / (label, params, vararg, instruction, constant) -> {label, :params, :vararg, :instruction, :constant}
	ArgNum: natnum
	Vararg: natnum
	BlockBody: V'InsList' * V'Space' *
		((P'{') * V'Space' *
			V'ConsList' * V'Space' *
		P'}')^-1

	InsList: V'Ins' * (V'Space' * V'Ins')^0 / multiwrap
	Ins: ((C(P'CLOSURE') * V'Space' * natnum * V'Space' * C(locale.alnum^1)) + V'Opcode' * V'Space' * V'Operand') / (op, ...) -> {:op, ...}
	Opcode: C locale.upper^1
	Operand: (natnum) * (V'Space' * natnum)^-2
	ConsList: V'Cons' * (V'Space' * V'Cons')^0 / multiwrap
	Cons: P'"' * C((locale.print - P'"')^0) * P'"' + natnum
}

(msg) -> lasm\match msg

