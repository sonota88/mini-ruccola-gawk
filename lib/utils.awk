function utils_init() {
    g_true = 1 == 1
    g_false = !g_true

    g_re[0] = 0
    delete g_re[0]

    g_retvals[0] = 0
    delete g_retvals[0]
}

function puts_e(arg) {
    printf arg "\n" > "/dev/stderr"
}

function puts_kv_e(k, v) {
    puts_e(k " (" v ")")
}

function panic(arg) {
    puts_e("PANIC " arg)
    exit 1
}

function re_match(str, re) {
    return match(str, re, g_re)
}

function re_group(n) {
    return g_re[n]
}
