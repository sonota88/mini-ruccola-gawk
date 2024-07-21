function types_init() {
    g_id_max = 0

    g_data[0] = 0
    delete g_data[0]
}

function List_new(    id_) {
    g_id_max++
    id_ = g_id_max

    g_data[id_][0] = 0
    delete g_data[id_][0]

    return id_
}

function List_size(list_) {
    return length(g_data[list_])
}

function List_add(list_, node_,    i) {
    i = List_size(list_)
    g_data[list_][i] = node_
}

function List_add_int(list_, intval,    node_) {
    node_ = Node_new_int(intval)
    List_add(list_, node_)
}

function List_add_str(list_, strval,    node_) {
    node_ = Node_new_str(strval)
    List_add(list_, node_)
}

function List_add_list(list_, xs_inner_,    node_) {
    node_ = Node_new_list(xs_inner_)
    List_add(list_, node_)
}

function List_add_all(list_, xs2_,    i) {
    for (i = 0; i < List_size(xs2_); i++) {
        List_add(list_, List_get(xs2_, i))
    }
}

function List_get(list_, i) {
    return g_data[list_][i]
}

function List_get_type(list_, i,    node_) {
    node_ = List_get(list_, i)
    return Node_get_type(node_)
}

function List_get_val(list_, i,    node_) {
    node_ = List_get(list_, i)
    return Node_get_val(node_)
}

function List_tail(list_, i,    new_xs_, i2, node_) {
    new_xs_ = List_new()
    for (i2 = i; i2 < List_size(list_); i2++) {
        node_ = List_get(list_, i2)
        List_add(new_xs_, node_)
    }
    return new_xs_
}

function Names_index(names_, str,    i) {
    for (i = 0; i < List_size(names_); i++) {
        if (List_get_val(names_, i) == str) {
            return i
        }
    }
    return -1
}

function Names_includes(names_, str,    i) {
    return Names_index(names_, str) >= 0
}

# --------------------------------

function Node_new(type, val,    id_) {
    g_id_max++
    id_ = g_id_max

    g_data[id_][0] = type
    g_data[id_][1] = val

    return id_
}

function Node_new_int(val) {
    return Node_new("int", val)
}

function Node_new_str(val) {
    return Node_new("str", val)
}

function Node_new_list(val) {
    return Node_new("list", val)
}

function Node_get_type(node_) {
    return g_data[node_][0]
}

function Node_get_val(node_) {
    return g_data[node_][1]
}
