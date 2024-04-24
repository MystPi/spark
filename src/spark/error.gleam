import chomp
import chomp/lexer.{type Span}
import gleam_community/ansi
import hug
import spark/lex/token
import spark/parse/ctx

// ---- TYPES ------------------------------------------------------------------

pub type Error {
  LexError(lexeme: String, pos: Span)
  ParseError(
    error: chomp.Error(String, token.TokenType),
    pos: Span,
    ctx_stack: ctx.Stack,
  )
}

// ----

pub fn to_string(error: Error, source: String, path: String) -> String {
  let #(message, hint, pos) = case error {
    LexError(lexeme, pos) -> lex_error_to_string(lexeme, pos)
    ParseError(e, pos, ctx_stack) -> parse_error_to_string(e, pos, ctx_stack)
  }

  hug.error(
    source,
    in: path,
    from: #(pos.row_start, pos.col_start),
    to: #(pos.row_end, pos.col_end),
    message: message,
    hint: hint,
  )
}

fn lex_error_to_string(lexeme, pos) {
  let hint = case lexeme {
    "'" ->
      "\n\n> Strings are surrounded by double quotes (\"), not single quotes (')"
    _ -> ""
  }

  #(
    "lexical error",
    "I'm not sure what this character means: "
      <> lexeme
      <> "\nIt is not part of Spark's syntax so I don't know how to handle it"
      <> hint,
    pos,
  )
}

fn parse_error_to_string(error, pos: Span, ctx_stack) {
  let ctx = case ctx_stack {
    [] -> ""
    _ -> "\n\nI found a problem " <> ctx.stack_to_string(ctx_stack) <> "\n"
  }

  let hint =
    case error {
      chomp.EndOfInput ->
        "I wanted to continue parsing but ran into the end of the file"

      chomp.Expected(expected, got) ->
        "I expected this: "
        <> ansi.green(token.to_string(expected))
        <> " but I got this: "
        <> ansi.red(token.to_string(got))

      chomp.Unexpected(unexpected) ->
        "I wasn't expecting this: " <> token.to_string(unexpected)

      chomp.Custom(message) -> message

      chomp.BadParser(_) -> panic as "there should be no bad parsers"
    }
    <> "\n\n> This is a "
    <> ansi.italic("syntax error")
    <> ", which means something is wrong with the structure of your code. Maybe something is missing or in the wrong place."

  let pos = case error {
    chomp.EndOfInput ->
      lexer.Span(pos.row_end, pos.col_end, pos.row_end, pos.col_end + 1)
    _ -> pos
  }

  #("syntax error" <> ctx, hint, pos)
}
