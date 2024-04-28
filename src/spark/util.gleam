import gleam/string

pub fn legalize(name: String) -> String {
  case name {
    "await"
    | "arguments"
    | "break"
    | "case"
    | "catch"
    | "class"
    | "const"
    | "continue"
    | "debugger"
    | "default"
    | "delete"
    | "do"
    | "else"
    | "enum"
    | "export"
    | "extends"
    | "eval"
    | "false"
    | "finally"
    | "for"
    | "function"
    | "if"
    | "implements"
    | "import"
    | "in"
    | "instanceof"
    | "interface"
    | "let"
    | "new"
    | "null"
    | "package"
    | "private"
    | "protected"
    | "public"
    | "return"
    | "static"
    | "super"
    | "switch"
    | "this"
    | "throw"
    | "true"
    | "try"
    | "typeof"
    | "var"
    | "void"
    | "while"
    | "with"
    | "yield"
    | // `undefined` to avoid any unintentional overriding.
      "undefined"
    | // `then` to avoid a module that defines a `then` function being
      // used as a `thenable` in JavaScript when the module is imported
      // dynamically, which results in unexpected behaviour.
      // It is rather unfortunate that we have to do this.
      "then" -> name <> "$"

    _ -> name
  }
}

pub fn remove_prefix(string: String, prefix: String) -> String {
  case string.starts_with(string, prefix) {
    True -> string.drop_left(string, string.length(prefix))
    False -> string
  }
}

pub fn capitalise(string: String) -> String {
  case string.pop_grapheme(string) {
    Ok(#(first, rest)) -> string.uppercase(first) <> rest
    _ -> string
  }
}