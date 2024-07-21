@include "lib/utils.awk"

BEGIN {
    utils_init()

    g_src = ""
}

# --------------------------------

function is_kw(str) {
    return \
           str == "func" || str == "var" \
        || str == "return" || str =="set" || str == "call" || str == "call_set" \
        || str == "while" || str == "case" ||  str == "when" \
        || str == "_cmt" || str == "_debug"
}

function print_token(lineno, kind, val) {
    printf "[%d, \"%s\", \"%s\"]\n", lineno, kind, val
}

function lex(src,    pos, n, rest, val) {
    lineno = 1

    pos = 0
    while (pos < length(src)) {
        n = pos + 1
        rest = substr(src, n);

        if (match(rest, /^ /)) {
            pos += 1
        } else if (match(rest, /^\n/)) {
            lineno++
            pos++
        } else if (re_match(rest, @/^(==|!=|[(){};=+*,])/)) {
            val = re_group(1)
            print_token(lineno, "sym", val)
            pos += length(val)
        } else if (re_match(rest, @/^(\-?[0-9]+)/)) {
            val = re_group(1)
            print_token(lineno, "int", val)
            pos += length(val)
        } else if (re_match(rest, @/^([a-z0-9_]+)/)) {
            val = re_group(1)
            if (is_kw(val)) {
                print_token(lineno, "kw", val)
            } else {
                print_token(lineno, "ident", val)
            }
            pos += length(val)
        } else if (re_match(rest, @/^(\/\/[^\n]*)\n/)) { # comment
            val = re_group(1)
            pos += length(val)
        } else if (re_match(rest, @/^"([^"]*)"/)) {
            val = re_group(1)
            print_token(lineno, "str", val)
            pos += length(val) + 2
        } else {
            puts_kv_e("rest", rest)
            panic("unexpected pattern")
        }
    }
}

# --------------------------------

{
    g_src = g_src $0 "\n"
}

END {
    lex(g_src)
}
