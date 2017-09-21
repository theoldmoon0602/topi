import std.conv;


import token;
import lex;
import node;
import func;
import exception;

Node parseNum(Lexer lexer) {
    auto tok = lexer.get;

    if (tok.type == Token.Type.REAL) {
        return new RealNode(tok.str.to!double);
    }
    if (tok.type == Token.Type.DIGIT) {
        return new IntNode(tok.str.to!long(10));
    }
    if (tok.type == Token.Type.HEX) {
        return new IntNode(tok.str.to!long(16));
    }
    lexer.unget(tok);
    return null;
}

Node parseTerm(Lexer lexer, Node left = null) {
    if (left is null) {
        left = lexer.parseNum;
        if (left is null) { return null; }
    }

    auto op = lexer.get;
    if (op is null) { return left; }

    // binary *
    if (op.type == Token.Type.OP_MUL) {
        auto right = lexer.parseTerm;
        if (right is null) {
            throw new TopiException("expected right hand expr", lexer.loc);
        }
        return parseTerm(lexer, new FuncCall(op.str, [left, right]));
    }
    // otherwise
    lexer.unget(op);
    return left;
}

Node parseExpr(Lexer lexer, Node left = null) {
    if (left is null) {
        left = lexer.parseTerm;
        if (left is null) {
            return null;
        }
    }

    auto op = lexer.get;
    if (op is null) {
        return left;
    }

    // binary +-
    if (op.type == Token.Type.SYM_ADD || op.type == Token.Type.SYM_SUB) {
        auto right = lexer.parseTerm;
        if (right is null) {
            throw new TopiException("expected right hand expr", lexer.loc);
        }
        return parseExpr(lexer, new FuncCall(op.str, [left, right]));
    }
    // otherwise
    lexer.unget(op);
    throw new TopiException("expression is required", lexer.loc);
}
