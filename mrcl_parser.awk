@include "lib/types.awk"
@include "lib/json.awk"

BEGIN {
    types_init()

    g_src = ""

    g_tokens[0] = 0
    delete g_tokens[0]

    g_ti = 0 # token index
}

# --------------------------------

function peek(offset) {
    return g_tokens[g_pos + offset]
}

function peek_val(offset,    t_) {
    t_ = peek(offset)
    return Token_get_val(t_)
}

function bump() {
    g_pos++
}

function Token_get_kind(t_) {
    return List_get_val(t_, 1)
}

function Token_get_val(t_) {
    return List_get_val(t_, 2)
}

function consume(val_exp,    t_, val_act) {
  t_ = peek(0)
  val_act = Token_get_val(t_)

  if (val_act != val_exp) {
      puts_kv_e("exp", val_exp)
      puts_kv_e("act", val_act)
      panic("consume: unexpected token")
  }

  bump()
}

function token_to_node(t_,    kind, val) {
    kind = Token_get_kind(t_)
    val  = Token_get_val(t_)

    switch (kind) {
        case "ident":
            return Node_new_str(val)
        case "int":
            return Node_new_int(strtonum(val))
        default:
            panic("token_to_node: unsupported")
            break
    }
}

# --------------------------------

function parse_arg(    t_, kind, val) {
    t_ = peek(0)
    bump()

    return token_to_node(t_)
}

function parse_args(    args_) {
  args_ = List_new()

  if (peek_val(0) == ")") {
      return args_
  }

  List_add(args_, parse_arg())

  while (peek_val(0) != ")") {
      consume(",")
      List_add(args_, parse_arg())
  }

  return args_
}

function parse_expr_factor(    t_, expr_) {
    t_ = peek(0)
    switch (Token_get_kind(t_)) {
        case "sym":
            consume("(")
            expr_ = parse_expr()
            consume(")")
            return expr_
        case "int":
        case "ident":
            bump()
            expr_ = token_to_node(t_)
            return expr_
        default:
            panic("parse_expr_factor: unsupported")
    }
}

function is_binop(t_,    val) {
    val = Token_get_val(t_)
    return val == "+" || val == "*" || val == "==" || val == "!="
}

function parse_expr(    expr_, op, factor_, new_expr_) {
    expr_ = parse_expr_factor()

    while (is_binop(peek(0))) {
        op = peek_val(0)
        bump()

        factor_ = parse_expr_factor()

        new_expr_ = List_new()
        List_add_str(new_expr_, op)
        List_add(new_expr_, expr_)
        List_add(new_expr_, factor_)

        expr_ = Node_new_list(new_expr_)
    }

    return expr_
}

function parse_return(    stmt_, expr_) {
    consume("return")

    stmt_ = List_new()
    List_add_str(stmt_, "return")

    if (peek_val(0) == ";") {
        consume(";")
        return stmt_
    } else {
        expr_ = parse_expr()
        consume(";")
        List_add(stmt_, expr_)
        return stmt_
    }
}

function parse_set(    stmt_, var_name, expr_) {
    consume("set")

    var_name = peek_val(0)
    bump()

    consume("=")
    expr_ = parse_expr()
    consume(";")

    stmt_ = List_new()
    List_add_str(stmt_, "set")
    List_add_str(stmt_, var_name)
    List_add(    stmt_, expr_)

    return stmt_
}

function parse_funcall(    funcall_, fn_name, args_) {
    fn_name = peek_val(0)
    bump()

    consume("(")
    args_ = parse_args()
    consume(")")

    funcall_ = List_new()

    List_add_str(funcall_, fn_name)
    List_add_all(funcall_, args_)

    return funcall_
}

function parse_call(    stmt_, funcall_) {
    consume("call")
    funcall_ = parse_funcall()
    consume(";")

    stmt_ = List_new()
    List_add_str( stmt_, "call")
    List_add_list(stmt_, funcall_)

    return stmt_
}

function parse_call_set(    stmt_, var_name, funcall_) {
    consume("call_set")

    var_name = peek_val(0)
    bump()

    consume("=")
    funcall_ = parse_funcall()
    consume(";")

    stmt_ = List_new()
    List_add_str( stmt_, "call_set")
    List_add_str( stmt_, var_name)
    List_add_list(stmt_, funcall_)

    return stmt_
}

function parse_while(    stmt_, cond_expr_) {
    consume("while")
    consume("(")
    cond_expr_ = parse_expr()
    consume(")")
    consume("{")
    stmts_ = parse_stmts()
    consume("}")

    stmt_ = List_new()
    List_add_str( stmt_, "while")
    List_add(     stmt_, cond_expr_)
    List_add_list(stmt_, stmts_)

    return stmt_
}

function parse_when_clause(    when_clause_, cond_expr_, stmts_) {
    consume("when")
    consume("(")
    cond_expr_ = parse_expr()
    consume(")")
    consume("{")
    stmts_ = parse_stmts()
    consume("}")

    when_clause_ = List_new()
    List_add(    when_clause_, cond_expr_)
    List_add_all(when_clause_, stmts_)
    
    return when_clause_
}

function parse_case(    stmt_) {
    consume("case")

    stmt_ = List_new()
    List_add_str(stmt_, "case")

    while (peek_val(0) == "when") {
        List_add_list(stmt_, parse_when_clause())
    }

    return stmt_
}

function parse_vm_comment(    stmt_, cmt) {
    consume("_cmt")
    consume("(")

    cmt = peek_val(0)
    bump()

    consume(")")
    consume(";")

    stmt_ = List_new()
    List_add_str(stmt_, "_cmt")
    List_add_str(stmt_, cmt)

    return stmt_
}

function parse_debug(    stmt_) {
    consume("")
    consume("")
    consume("")
    consume("")

    stmt_ = List_new()
    List_add_str("_debug")
    return stmt_
}

function parse_stmt() {
    switch (peek_val(0)) {
        case "return":   return parse_return()
        case "set":      return parse_set()
        case "call":     return parse_call()
        case "call_set": return parse_call_set()
        case "while":    return parse_while()
        case "case":     return parse_case()
        case "_cmt":     return parse_vm_comment()
        default:
            panic("parse_stmt: unsupported")
    }
}

function parse_stmts(    stmts_) {
    stmts_ = List_new()

    while (peek_val(0) != "}") {
        List_add_list(stmts_, parse_stmt())
    }

    return stmts_
}

function parse_var(    stmt_, var_name, expr_) {
    consume("var")

    var_name = peek_val(0)
    bump()

    stmt_ = List_new()
    List_add_str(stmt_, "var")
    List_add_str(stmt_, var_name)

    switch (peek_val(0)) {
        case ";":
            consume(";")
            break
        case "=":
            consume("=")
            expr_ = parse_expr()
            List_add(stmt_, expr_)
            consume(";")
            break
        default:
            panic("parse_var: unexpected token")
    }

    return stmt_
}

function parse_fn_def(    fn_def_, fn_name, fn_args_, fn_body_, t_) {
    consume("func")

    fn_name = peek_val(0)
    bump()

    consume("(")
    fn_args_ = parse_args()
    consume(")")
    consume("{")

    fn_body_ = List_new()
    while (peek_val(0) != "}") {
        if (peek_val(0) == "var") {
            stmt_ = parse_var()
            List_add_list(fn_body_, stmt_)
        } else {
            stmt_ = parse_stmt()
            List_add_list(fn_body_, stmt_)
        }
    }
    consume("}")

    fn_def_ = List_new()
    List_add_str( fn_def_, "func")
    List_add_str( fn_def_, fn_name)
    List_add_list(fn_def_, fn_args_)
    List_add_list(fn_def_, fn_body_)

    return fn_def_
}

function parse_top_stmts(    ast_, fn_def_) {
  ast_ = List_new()

  List_add_str(ast_, "top_stmts")

  while (peek_val(0) == "func") {
      fn_def_ = parse_fn_def()
      List_add_list(ast_, fn_def_)
  }

  return ast_
}

function parse(    top_stmts) {
    top_stmts_ = parse_top_stmts()
    return top_stmts_
}

# --------------------------------

{
    g_src = g_src $0 "\n"

    t_ = Json_parse($0)

    g_tokens[g_ti] = t_
    g_ti++
}

END {
    g_pos = 0
    ast_ = parse()
    Json_print_pretty(ast_)
}
