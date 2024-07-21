@include "lib/utils.awk"
@include "lib/types.awk"
@include "lib/json.awk"

BEGIN {
    utils_init()
    types_init()

    g_src = ""
    g_label_id = 0
}

# --------------------------------

function asm_prologue() {
    print "  push bp"
    print "  mov bp sp"
}

function asm_epilogue() {
    print "  mov sp bp"
    print "  pop bp"
}

function to_lvar_disp(names_, name,    i) {
    i = Names_index(names_, name)
    return -(i + 1)
}

function to_fn_arg_disp(names_, name,    i) {
    i = Names_index(names_, name)
    return i + 2
}

function get_label_id() {
    g_label_id++
    return g_label_id
}

# --------------------------------

function _gen_expr_add() {
    print "  pop reg_b"
    print "  pop reg_a"
    print "  add reg_a reg_b"
}

function _gen_expr_mult() {
    print "  pop reg_b"
    print "  pop reg_a"
    print "  mul reg_b"
}

function _gen_expr_eq_common(eq_type, then_val, else_val,    label_id) {
    label_id = get_label_id()

    print  "  pop reg_b"
    print  "  pop reg_a"
    print  "  cmp"
    printf "  je then_%d\n", label_id
    printf "  mov reg_a %d\n", else_val
    printf "  jmp end_%s_%d\n", eq_type, label_id
    printf "label then_%d\n", label_id
    printf "  mov reg_a %d\n", then_val
    printf "label end_%s_%d\n", eq_type, label_id
}

function _gen_expr_eq() {
    _gen_expr_eq_common("eq", 1, 0)
}

function _gen_expr_neq() {
    _gen_expr_eq_common("neq", 0, 1)
}

function _gen_expr_binary(fn_args_, lvars_, expr_,    xs_, op, lhs_, rhs_) {
    xs_ = Node_get_val(expr_)
    op   = List_get_val(xs_, 0)
    lhs_ = List_get(    xs_, 1)
    rhs_ = List_get(    xs_, 2)

    gen_expr(fn_args_, lvars_, lhs_)
    print "  push reg_a"
    gen_expr(fn_args_, lvars_, rhs_)
    print "  push reg_a"

    switch (op) {
        case "+":
            _gen_expr_add()
            break
        case "*":
            _gen_expr_mult()
            break
        case "==":
            _gen_expr_eq()
            break
        case "!=":
            _gen_expr_neq()
            break
        default:
            panic("_gen_expr_binary: unsupported")
    }
}

function gen_expr(fn_args_, lvars_, expr_,    disp, val) {
    switch (Node_get_type(expr_)) {
        case "int":
            printf "  mov reg_a %d\n", Node_get_val(expr_)
            break
        case "str":
            val = Node_get_val(expr_)
            if (Names_includes(lvars_, val)) {
                disp = to_lvar_disp(lvars_, val)
                printf "  mov reg_a [bp:%d]\n", disp
            } else if (Names_includes(fn_args_, val)) {
                disp = to_fn_arg_disp(fn_args_, val)
                printf "  mov reg_a [bp:%d]\n", disp
            } else {
                puts_kv_e("val", val)
                panic("gen_expr: unsupported")
            }

            break
        case "list":
            _gen_expr_binary(fn_args_, lvars_, expr_)
            break
        default:
            puts_kv_e("expr_", expr_)
            puts_kv_e("node type", Node_get_type(expr_))
            puts_kv_e("node val", Node_get_val(expr_))
            panic("gen_expr: unsupported")
    }
}

function gen_return(fn_args_, lvars_, stmt_,    expr_) {
    switch (List_size(stmt_)) {
        case 1:
            # do nothing
            break
        case 2:
            expr_ = List_get(stmt_, 1)
            gen_expr(fn_args_, lvars_, expr_)
            break
        default:
            panic("gen_return: unsupported")
            break
    }

    asm_epilogue()
    print "  ret"
}

function _gen_set(fn_args_, lvars_, dest, expr_,    disp) {
    gen_expr(fn_args_, lvars_, expr_)

    if (Names_includes(lvars_, dest)) {
        disp = to_lvar_disp(lvars_, dest)
        printf "  mov [bp:%d] reg_a\n", disp
    } else {
        puts_kv_e("dest", dest)
        panic("_gen_set: unsupported")
    }
}

function gen_set(fn_args_, lvars_, stmt_,    dest, expr_) {
    dest  = List_get_val(stmt_, 1)
    expr_ = List_get(    stmt_, 2)
    _gen_set(fn_args_, lvars_, dest, expr_)
}

function gen_funcall(fn_args_, lvars_, funcall_,    fn_name, num_args, i, expr_) {
    fn_name = List_get_val(funcall_, 0)

    for (i = List_size(funcall_) - 1; i >= 1; i--) {
        expr_ = List_get(funcall_, i)
        gen_expr(fn_args_, lvars_, expr_)
        print "  push reg_a"
    }

    _gen_vm_comment("call  " fn_name)

    num_args = List_size(funcall_) - 1

    printf "  call %s\n", fn_name
    printf "  add sp %d\n", num_args
}

function gen_call(fn_args_, lvars_, stmt_,    funcall_) {
    funcall_ = List_get_val(stmt_, 1)
    gen_funcall(fn_args_, lvars_, funcall_)
}

function gen_call_set(fn_args_, lvars_, stmt_,     lvar_name, funcall_, disp) {
    lvar_name = List_get_val(stmt_, 1)
    funcall_  = List_get_val(stmt_, 2)

    gen_funcall(fn_args_, lvars_, funcall_)

    disp = to_lvar_disp(lvars_, lvar_name)
    printf "  mov [bp:%d] reg_a\n", disp
}

function gen_while(fn_args_, lvars_, stmt_, \
                   label_id, cond_expr_, stmts_, label_begin, label_end) {
    cond_expr_ = List_get(    stmt_, 1)
    stmts_     = List_get_val(stmt_, 2)

    label_id = get_label_id()

    label_begin = "while_" label_id
    label_end = "end_while_" label_id

    print "label " label_begin

    gen_expr(fn_args_, lvars_, cond_expr_)

    print "  mov reg_b 0"
    print "  cmp"

    print "  je " label_end

    gen_stmts(fn_args_, lvars_, stmts_)

    print "  jmp " label_begin

    print "label " label_end
}

function gen_case(fn_args_, lvars_, stmt_, \
                  i, label_id, label_end, label_end_when_head, when_clause_, \
                  when_idx, cond_expr_, stmts_) {
    label_id = get_label_id()

    label_end = "end_case_" label_id
    label_end_when_head = "end_when_" label_id

    when_idx = -1

    for (i = 1; i < List_size(stmt_); i++) {
        when_clause_ = List_get_val(stmt_, i)
        when_idx++

        cond_expr_ = List_get(when_clause_, 0)
        stmts_ = List_tail(when_clause_, 1)

        gen_expr(fn_args_, lvars_, cond_expr_)

        print "  mov reg_b 0"
        print "  cmp"

        print "  je " label_end_when_head "_" when_idx

        gen_stmts(fn_args_, lvars_, stmts_)

        print "  jmp " label_end

        print "label " label_end_when_head "_" when_idx
    }

    print "label " label_end
}

function _gen_vm_comment(cmt) {
    gsub(" ", "~", cmt)
    printf "  _cmt %s\n", cmt
}

function gen_vm_comment(fn_args_, lvars_, stmt_,    cmt) {
    cmt = List_get_val(stmt_, 1)
    _gen_vm_comment(cmt)
}

function gen_debug(fn_args_, lvars_, _) {
    print "  _debug"
}

function gen_stmt(fn_args_, lvars_, stmt_) {
    switch (List_get_val(stmt_, 0)) {
        case "return":
            gen_return(fn_args_, lvars_, stmt_)
            break
        case "set":
            gen_set(fn_args_, lvars_, stmt_)
            break
        case "call":
            gen_call(fn_args_, lvars_, stmt_)
            break
        case "call_set":
            gen_call_set(fn_args_, lvars_, stmt_)
            break
        case "while":
            gen_while(fn_args_, lvars_, stmt_)
            break
        case "case":
            gen_case(fn_args_, lvars_, stmt_)
            break
        case "_cmt":
            gen_vm_comment(fn_args_, lvars_, stmt_)
            break
        default:
            panic("gen_stmt: unsupported")
    }
}

function gen_stmts(fn_args_, lvars_, stmts_,    stmt_, i) {
    for (i = 0; i < List_size(stmts_); i++) {
        stmt_ = List_get_val(stmts_, i)
        gen_stmt(fn_args_, lvars_, stmt_)
    }
}

function gen_var(fn_args_, lvars_, stmt_,    dest, expr_) {
    print "  add sp -1"

    if (List_size(stmt_) == 2) {
        ;
    } else if (List_size(stmt_) == 3) {
        dest  = List_get_val(stmt_, 1)
        expr_ = List_get(    stmt_, 2)
        _gen_set(fn_args_, lvars_, dest, expr_)
    } else {
        panic("gen_var: unsupported")
    }
}

function gen_func_def(fn_def_,    fn_name, fn_args_, lvars_, i, stmt_, stmts_, lvar_name) {
    fn_name  = List_get_val(fn_def_, 1)
    fn_args_ = List_get_val(fn_def_, 2)
    stmts_   = List_get_val(fn_def_, 3)

    lvars_ = List_new()

    printf "label %s\n", fn_name
    asm_prologue()

    for (i = 0; i < List_size(stmts_); i++) {
        stmt_ = List_get_val(stmts_, i)
        if (List_get_val(stmt_, 0) == "var") {
            lvar_name = List_get_val(stmt_, 1)
            List_add_str(lvars_, lvar_name)
            gen_var(fn_args_, lvars_, stmt_)
        } else {
            gen_stmt(fn_args_, lvars_, stmt_)
        }
    }

    asm_epilogue()
    print "  ret"
}

function gen_top_stmts(ast_,    i, fn_def_) {
    for (i = 1; i < List_size(ast_); i++) {
        fn_def_ = List_get_val(ast_, i)
        gen_func_def(fn_def_)
    }
}

function gen_builtin_set_vram() {
    print "label set_vram"
    asm_prologue()
    print "  set_vram [bp:2] [bp:3]" # vram_addr value
    asm_epilogue()
    print "  ret"
}

function gen_builtin_get_vram() {
    print "label get_vram"
    asm_prologue()
    print "  get_vram [bp:2] reg_a" # vram_addr dest
    asm_epilogue()
    print "  ret"
}

function codegen(src,    ast_) {
    ast_ = Json_parse(src)

    print "  call main"
    print "  exit"

    gen_top_stmts(ast_)

    print "#>builtins"
    gen_builtin_set_vram()
    gen_builtin_get_vram()
    print "#<builtins"
}

# --------------------------------

{
    g_src = g_src $0 "\n"
}

END {
    codegen(g_src)
}
