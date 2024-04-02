import gleam/int
import gleam/set
import nibble/lexer.{type Lexer}

// ---- TYPES ------------------------------------------------------------------

pub type Token {
  // Literals
  String(String)
  Number(Float)
  // Identifiers
  Ident(String)
  Symbol(String)
  // Pairs
  LParen
  RParen
  LBracket
  RBracket
  // Double characters
  EqEq
  Ne
  GtEq
  LtEq
  ArrowRight
  ArrowLeft
  // Single characters
  Comma
  Dot
  Colon
  Semicolon
  Backslash
  Bar
  Eq
  Plus
  Minus
  Star
  Slash
  Caret
  Bang
  Gt
  Lt
  // Keywords
  Def
  Pub
  Const
  Of
  As
  Any
  And
  Or
  Case
  Let
  In
  Import
  External
  // Misc
  Comment(String)
}

pub type Tokens =
  List(lexer.Token(Token))

// ---- LEXER ------------------------------------------------------------------

pub fn lex(input: String) {
  lexer.run(input, lexer())
}

fn lexer() -> Lexer(Token, Nil) {
  // nibble needs a set of keywords to disambiguate them from identifiers
  let keywords =
    set.from_list([
      "def", "pub", "const", "of", "as", "any", "and", "or", "not", "case",
      "let", "in", "import", "external",
    ])

  lexer.simple([
    // Some tokens are ambiguous (they start with the same character) and need
    // a custom lexer rule. They include:
    // = == ! != < <= <- > >= - ->
    ambiguous_tokens(),
    // These tokens don't need custom lexing rules
    lexer.token("(", LParen),
    lexer.token(")", RParen),
    lexer.token("[", LBracket),
    lexer.token("]", RBracket),
    lexer.token(",", Comma),
    lexer.token(".", Dot),
    lexer.token(":", Colon),
    lexer.token(";", Semicolon),
    lexer.token("\\", Backslash),
    lexer.token("|", Bar),
    lexer.token("=", Eq),
    lexer.token("+", Plus),
    lexer.token("*", Star),
    lexer.token("/", Slash),
    lexer.token("^", Caret),
    // Keywords
    lexer.token("def", Def),
    lexer.token("pub", Pub),
    lexer.token("const", Const),
    lexer.token("of", Of),
    lexer.token("as", As),
    lexer.token("any", Any),
    lexer.token("and", And),
    lexer.token("or", Or),
    lexer.token("case", Case),
    lexer.token("let", Let),
    lexer.token("in", In),
    lexer.token("import", Import),
    lexer.token("external", External),
    // Literals & identifiers
    lexer.string("\"", String),
    lexer.number_with_separator("_", int.to_float, fn(x) { x })
      |> lexer.map(Number),
    lexer.identifier("@", "[a-zA-Z0-9_]", keywords, Symbol),
    lexer.identifier("[a-zA-Z_]", "[a-zA-Z0-9_?]", keywords, Ident),
    // Ignored text
      lexer.comment("#", Comment)
      |> lexer.ignore,
    lexer.whitespace(Nil)
      |> lexer.ignore,
  ])
}

fn ambiguous_tokens() {
  use mode, lexeme, lookahead <- lexer.custom

  case lexeme, lookahead {
    "=", "=" | "!", "=" | "<", "-" | "<", "=" | ">", "=" | "-", ">" ->
      // Skip since we know the next iteration we'll have a match
      lexer.Skip

    "=", _ -> lexer.Keep(Eq, mode)
    "==", _ -> lexer.Keep(EqEq, mode)

    "!", _ -> lexer.Keep(Bang, mode)
    "!=", _ -> lexer.Keep(Ne, mode)

    "<", _ -> lexer.Keep(Lt, mode)
    "<-", _ -> lexer.Keep(ArrowLeft, mode)
    "<=", _ -> lexer.Keep(LtEq, mode)

    ">", _ -> lexer.Keep(Gt, mode)
    ">=", _ -> lexer.Keep(GtEq, mode)

    "-", _ -> lexer.Keep(Minus, mode)
    "->", _ -> lexer.Keep(ArrowRight, mode)

    _, _ -> lexer.NoMatch
  }
}
