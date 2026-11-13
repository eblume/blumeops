let spec = { type = "github"; owner = "eblume"; repo = "x"; }; in
builtins.fetchTree spec
