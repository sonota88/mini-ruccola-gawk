@include "lib/utils.awk"

function Json_print_node(type, val, lv, pretty) {
    if (type == "int") {
        printf val
    } else if (type == "str") {
        printf "\"" val "\""
    } else if (type == "list") {
        Json_print_list(val, lv, pretty)
    } else {
        puts_kv_e("type", type)
        puts_kv_e("val", val)
        panic("Json_print_node: unsupported")
    }
}

function print_indent(lv,    i) {
    for (i = 0; i < lv; i++) {
        printf "  "
    }
}

function Json_print_list(xs_, lv, pretty,    i, type, val) {
    printf "["

    for (i = 0; i < List_size(xs_); i++) {
        if (i == 0) {
            if (pretty) { printf "\n" }
        } else {
            printf ","
            if (pretty) {
                printf "\n"
            } else {
                printf " "
            }
        }

        if (pretty) { print_indent(lv + 1) }

        type = List_get_type(xs_, i)
        val = List_get_val(xs_, i)
        Json_print_node(type, val, lv + 1, pretty)
    }

    if (pretty) {
        printf "\n"
        print_indent(lv)
    }
    printf "]"
}

function Json_print(xs_) {
  Json_print_list(xs_, 0, 0)
}

function Json_print_pretty(xs_) {
  Json_print_list(xs_, 0, 1)
}

function _Json_parse(src,    rest, pos, xs_, val, n, xs_inner_, size) {
    xs_ = List_new()

    pos = 2 # skip first '['

    while (pos <= length(src)) {
        rest = substr(src, pos)

        if (match(rest, /^]/)) {
            g_retvals[0] = xs_
            g_retvals[1] = pos
            return
        } else if (match(rest, /^[\n ,]/)) {
            pos += 1 # skip
        } else if (re_match(rest, @/^(-?[0-9]+)/)) {
            val = re_group(1)
            n = strtonum(val)
            List_add_int(xs_, n)
            pos += length(val)
        } else if (re_match(rest, @/^"([^"]*)"/)) {
            val = re_group(1)
            List_add_str(xs_, val)
            pos += length(val) + 2
        } else if (match(rest, /^\[/)) {
            _Json_parse(rest)
            xs_inner_ = g_retvals[0]
            size      = g_retvals[1]
            List_add_list(xs_, xs_inner_)
            pos += size
        } else {
            puts_kv_e("rest", rest)
            puts_kv_e("pos", pos)
            panic("_Json_parse: unexpected pattern")
        }
    }

    puts_kv_e("pos", pos)
    puts_kv_e("src size", length(src))
    puts_kv_e("src", src)
    panic("_Json_parse: invalid json")
}

function Json_parse(src) {
    _Json_parse(src)
    return g_retvals[0]
}
