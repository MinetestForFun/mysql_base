unused_args = false
allow_defined_top = true
max_line_length = 999

globals ={
    "minetest",
}

read_globals = {
    string = {fields = {"split", "trim"}},
    table = {fields = {"copy", "getn"}},
}

files["init.lua"].ignore = { "modname", "tab" }
files["mysql/mysql.lua"].ignore = { "" }
files["mysql/mysql_h.lua"].ignore = { "" }
files["mysql/mysql_print.lua"].ignore = { "" }
files["mysql/mysql_test.lua"].ignore = { "" }
                                     -- ^ Ignore everything
