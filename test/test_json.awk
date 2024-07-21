@include "lib/types.awk"
@include "lib/json.awk"

BEGIN {
    g_src = ""
}

{
    g_src = g_src $0 "\n"
}

END {
    xs_ = Json_parse(g_src)
    Json_print_pretty(xs_)
}
