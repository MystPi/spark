import chomp/lexer.{type Lexer}
import chomp/span
import gleam/result
import gleam/set
import gleam/string
import spark/error
import spark/lex/token.{type TokenType}

// ---- LEXER ------------------------------------------------------------------

pub fn lex(input: String) {
  input
  |> lexer.run(lexer())
  |> result.map_error(fn(e) {
    let lexer.NoMatchFound(row, col, lexeme) = e
    lexeme
    |> string.first
    |> result.unwrap("")
    |> error.LexError(span.Span(row, col, row, col + 1))
  })
}

fn lexer() -> Lexer(TokenType, Nil) {
  // chomp needs a set of keywords to disambiguate them from identifiers
  let keywords =
    set.from_list([
      "def", "pub", "const", "of", "as", "any", "and", "or", "not", "case",
      "let", "in", "import", "external",
    ])

  lexer.simple([
    // Some tokens are ambiguous (they start with the same character) and need
    // a custom lexer rule. They include:
    // = == ! != < <= <- > >= - -> | |> . ..
    ambiguous_tokens(),
    // Literals & identifiers
    lexer.string("\"", token.String),
    lexer.number(token.Int, token.Float),
    lexer.identifier("@", "[a-zA-Z0-9_]", keywords, token.Atom),
    lexer.identifier("[a-z_]", "[a-zA-Z0-9_?]", keywords, token.Ident),
    lexer.identifier("[A-Z]", "[a-zA-Z0-9]", keywords, token.Module),
    // These tokens don't need custom lexing rules
    lexer.token("(", token.LParen),
    lexer.token(")", token.RParen),
    lexer.token("[", token.LBracket),
    lexer.token("]", token.RBracket),
    lexer.token("{", token.LBrace),
    lexer.token("}", token.RBrace),
    lexer.token(",", token.Comma),
    lexer.token(":", token.Colon),
    lexer.token(";", token.Semicolon),
    lexer.token("\\", token.Backslash),
    lexer.token("=", token.Eq),
    lexer.token("+", token.Plus),
    lexer.token("*", token.Star),
    lexer.token("/", token.Slash),
    lexer.token("^", token.Caret),
    // Keywords
    lexer.token("def", token.Def),
    lexer.token("pub", token.Pub),
    lexer.token("const", token.Const),
    lexer.token("of", token.Of),
    lexer.token("as", token.As),
    lexer.token("any", token.Any),
    lexer.token("and", token.And),
    lexer.token("or", token.Or),
    lexer.token("case", token.Case),
    lexer.token("let", token.Let),
    lexer.token("in", token.In),
    lexer.token("import", token.Import),
    lexer.token("external", token.External),
    // Ignored text
    lexer.comment("#", token.Comment)
      |> lexer.ignore,
    lexer.whitespace(Nil)
      |> lexer.ignore,
  ])
}

fn ambiguous_tokens() {
  use mode, lexeme, lookahead <- lexer.custom

  case lexeme, lookahead {
    "=", "="
    | "!", "="
    | "<", "-"
    | "<", "="
    | ">", "="
    | "-", ">"
    | "|", ">"
    | ".", "."
    ->
      // Skip since we know the next iteration we'll have a match
      lexer.Skip

    "=", _ -> lexer.Keep(token.Eq, mode)
    "==", _ -> lexer.Keep(token.EqEq, mode)

    "!", _ -> lexer.Keep(token.Exclamation, mode)
    "!=", _ -> lexer.Keep(token.Ne, mode)

    "<", _ -> lexer.Keep(token.Lt, mode)
    "<-", _ -> lexer.Keep(token.ArrowLeft, mode)
    "<=", _ -> lexer.Keep(token.LtEq, mode)

    ">", _ -> lexer.Keep(token.Gt, mode)
    ">=", _ -> lexer.Keep(token.GtEq, mode)

    "-", _ -> lexer.Keep(token.Minus, mode)
    "->", _ -> lexer.Keep(token.ArrowRight, mode)

    "|", _ -> lexer.Keep(token.Bar, mode)
    "|>", _ -> lexer.Keep(token.PipeRight, mode)

    ".", _ -> lexer.Keep(token.Dot, mode)
    "..", _ -> lexer.Keep(token.DotDot, mode)

    _, _ -> lexer.NoMatch
  }
}
