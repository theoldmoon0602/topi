module topi.parse;

import topi;
import std.uni;
import std.conv;
import std.format;

bool isFirstChar(dchar c) {
	return (c.isAlpha || c == '_');
}
bool isIdentChar(dchar c) {
	return c.isAlphaNum || c == '_';
}


IdentifierAst read_identifier(Source src) {
	dchar c;
	if (!src.get_with_skip(c)) {
		return null;
	}
	if (c.isFirstChar) {
		return src.read_identifier(c);
	}
	src.unget(c);
	return null;
}
IdentifierAst read_identifier(Source src, dchar c) {
	dchar[] buf;
	buf ~= c;
	while (src.get(c)) {
		if (! c.isIdentChar) {
			src.unget(c);
			break;
		}
		buf ~= c;
	}
	return new IdentifierAst(buf.to!string);
}
IntegerAst read_number(Source src, int n) {
	dchar c;
	while (src.get(c)) {
		if (! c.isNumber) {
			src.unget(c);
			break;
		}
		n = n*10 + (c-'0');
	}
	return new IntegerAst(n);
}
Ast read_factor(Source src) {
	dchar c;
	if (! src.get_with_skip(c)) {
		return null;
	}
	if (c.isNumber) {
		return src.read_number(c-'0');
	}
	if (c.isFirstChar) {
		auto ident = src.read_identifier(c);
		if (! src.get_with_skip(c)) {
			return ident;
		}
		if (c == '(') {
			return src.read_function_call(ident.name);
		}
		src.unget(c);
		return ident;
	}
	if (c == '(') {
		auto e = src.read_expr;
		if (! e) {
			throw new Exception("Meaningless parentheses");
		}
		if (! src.get_with_skip(c)) {
			throw new Exception("Unterminated parentheses");
		}
		if (c != ')') {
			throw new Exception("')' is expected but got '%c'".format(c));
		}
		return e;

	}
	src.unget(c);
	return null;
}
Ast read_term(Source src) {
	auto f1 = src.read_factor;
	if (! f1) {
		return null;
	}
	dchar c;
	if (! src.get_with_skip(c)) {
		return f1;
	}
	if (c != '*') {
		src.unget(c);
		return f1;
	}
	auto f2 = src.read_term;
	if (! f2) {
		throw new Exception("Incomplete term");
	}
	return new BinopAst(c, f1, f2);
}
Ast read_expr(Source src) {
	auto t1 = src.read_term;
	if (!t1) {
		return null;
	}
	dchar c;
	if (! src.get_with_skip(c)) {
		return t1;
	}
	if (c != '+' && c != '-') {
		src.unget(c);
		return t1;
	}
	auto t2 = src.read_expr;
	if (!t2) {
		throw new Exception("Incomplete expr");
	}
	return new BinopAst(c, t1, t2);
}
Ast read_stmt(Source src) {
	dchar c;
	if (! src.get_with_skip(c)) {
		return null;
	}
	if (c == '{') {
		return src.read_block;
	}
	if (c.isFirstChar) {
		auto type = src.read_identifier(c);
		if (type.name == "Int") {
			auto ident = src.read_identifier;
			if (! ident) {
				throw new Exception("Identifier expected");
			}
			if (! src.expect_with_skip(['='])) {
				throw new Exception("= is required");
			}
			auto value = src.read_expr;
			if (! value) {
				throw new Exception("Expression expected");
			}
			if (! src.expect_with_skip([' ', ';'])) {
				throw new Exception("Expression should end with ; or \\n");
			}
			return new DefinitionAst(ident.name, value);
		}
		else {
			src.unget(type.name);
		}
	} else {
		src.unget(c);
	}
	auto e = src.read_expr;
	if (!e ) {
		return null;
	}
	if (! src.expect_with_skip([' ', ';'])) {
		throw new Exception("Expression should end with ; or \\n");
	}
	return e;
}
BlockAst read_block(Source src) {
	Ast[] asts;
	while (true) {
		dchar c;
		if (! src.get_with_skip(c)) {
			throw new Exception("Unclosed {} brace");
		}
		if (c == '}') {
			return new BlockAst(asts);
		}
		src.unget(c);
		asts ~= src.read_stmt;
	}
}
Ast read_toplevel(Source src) {
	dchar c;
	if (! src.get_with_skip(c)) {
		return null;
	}
	if (c.isAlpha || c == '_') {
		IdentifierAst ident = src.read_identifier(c);
		if (ident) {
			if (ident.name == "Func") {
				return src.read_function;
			}
			src.unget(ident.name);
		}
		else {
			src.unget(c);
		}
	}
	else {
		src.unget(c);
	}
	return src.read_stmt;
}
DeclarationAst read_declaration(Source src) {
	auto type = src.read_identifier;
	if (! type) {
		return null;
	}
	if (type.name != "Int") {
		src.unget(type.name);
		return null;
	}
	auto name = src.read_identifier;
	if (!name) {
		throw new Exception("variabel name is required");
	}
	return new DeclarationAst(type.name, name.name);
}
Ast read_function(Source src) {
	IdentifierAst name = src.read_identifier;
	if (! name) {
		throw new Exception("Function Name Required");
	}
	if (! src.expect_with_skip(['('])) {
		throw new Exception("( is expected");
	}
	DeclarationAst[] args;
	while (true) {
		auto arg = src.read_declaration;
		if (! arg) {
			if (args.length > 0) {
				throw new Exception(") is expected");
			}
			if (! src.expect_with_skip([')'])) {
				throw new Exception(") is expected");
			}
			break;
		}
		args ~= arg;
		dchar c;
		if (!src.get_with_skip(c)) {
			throw new Exception(", or ) is expected");
		}
		if (c == ',') {
			continue;
		}
		if (c == ')') {
			break;
		}
		throw new Exception(", or ) is expected but got '%c'".format(c));
	}

	if (! src.expect_with_skip(['{'])) {
		throw new Exception("{ is expected");
	}
	BlockAst block = src.read_block;
	
	return new FunctionAst(name.name, args, block);
}
FunctionCallAst read_function_call(Source src, string fname) {
	Ast[] args;
	while (true) {
		auto arg = src.read_expr;
		if (! arg) {
			if (args.length > 0) {
				throw new Exception("Expression is expected");
			}
			if (!src.expect_with_skip([')'])) {
				throw new Exception(") is expected");
			}
			break;
		}
		args ~= arg;
		dchar c;
		if (!src.get_with_skip(c)) {
			throw new Exception(", or ) is expected");
		}
		if (c == ',') {
			continue;
		}
		if (c == ')') {
			break;
		}
		throw new Exception(", or ) is expected but got '%c'".format(c));
	}
	return new FunctionCallAst(fname, args);
}