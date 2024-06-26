import chomp/span
import gleam/int
import gleam/list
import gleam_community/ansi

// ---- TYPES ------------------------------------------------------------------

pub type Ctx {
  InFunction(String)
  InConstant(String)
  InLet
  InList
  InRecord
  InAtom
  InLambda
  InBackpass
  InCase
  InCaseClause
  InCall
  InListPattern
  InRecordPattern
}

pub type Stack =
  List(#(span.Span, Ctx))

// ----

pub fn stack_to_string(stack: Stack) -> String {
  case stack {
    [] -> ""
    [first] -> ctx_to_string(first)
    [first, ..rest] -> {
      // The latest ctx (first) and the first ctx (technically last) are considered
      // most relevant.
      let assert Ok(last) = list.last(rest)
      ctx_to_string(first) <> " " <> ctx_to_string(last)
    }
  }
}

fn ctx_to_string(pair: #(span.Span, Ctx)) -> String {
  let #(pos, ctx) = pair

  case ctx {
    InFunction(name) -> "in the function `" <> ansi.blue(name) <> "`"
    InConstant(name) -> "in the constant `" <> ansi.blue(name) <> "`"
    InLet -> "in a let expression"
    InList -> "inside a list"
    InRecord -> "inside a record"
    InAtom -> "inside an atom"
    InLambda -> "inside a lambda"
    InBackpass -> "inside a backpass"
    InCase -> "inside a case expression"
    InCaseClause -> "inside a case clause"
    InCall -> "inside a function call"
    InListPattern -> "inside a list pattern"
    InRecordPattern -> "inside a record pattern"
  }
  <> " "
  <> ansi.dim(pos_to_string(pos))
}

fn pos_to_string(pos: span.Span) -> String {
  "("
  <> int.to_string(pos.row_start)
  <> ":"
  <> int.to_string(pos.col_start)
  <> ")"
}
