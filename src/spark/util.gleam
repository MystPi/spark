import gleam/list
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

pub fn is_valid_module_name(string: String) -> Bool {
  case string.pop_grapheme(string) {
    Ok(#(first, rest)) ->
      is_capital_letter(first)
      && rest
      |> string.to_graphemes
      |> list.all(is_alphanum)
    _ -> False
  }
}

fn is_capital_letter(grapheme: String) -> Bool {
  case grapheme {
    "A"
    | "B"
    | "C"
    | "D"
    | "E"
    | "F"
    | "G"
    | "H"
    | "I"
    | "J"
    | "K"
    | "L"
    | "M"
    | "N"
    | "O"
    | "P"
    | "Q"
    | "R"
    | "S"
    | "T"
    | "U"
    | "V"
    | "W"
    | "X"
    | "Y"
    | "Z" -> True
    _ -> False
  }
}

fn is_alphanum(grapheme: String) -> Bool {
  case grapheme {
    "a"
    | "b"
    | "c"
    | "d"
    | "e"
    | "f"
    | "g"
    | "h"
    | "i"
    | "j"
    | "k"
    | "l"
    | "m"
    | "n"
    | "o"
    | "p"
    | "q"
    | "r"
    | "s"
    | "t"
    | "u"
    | "v"
    | "w"
    | "x"
    | "y"
    | "z"
    | "0"
    | "1"
    | "2"
    | "3"
    | "4"
    | "5"
    | "6"
    | "7"
    | "8"
    | "9"
    | "_" -> True
    _ -> is_capital_letter(grapheme)
  }
}
