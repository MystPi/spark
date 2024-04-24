import chomp.{do, do_in, return, throw}
import chomp/lexer
import chomp/pratt
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import spark/ast
import spark/error
import spark/lex/token.{type TokenType}
import spark/parse/ctx

// ---- TYPES ------------------------------------------------------------------

type Parser(a) =
  chomp.Parser(a, String, TokenType, ctx.Ctx)

// ---- PARSER -----------------------------------------------------------------

pub fn parse(
  tokens: List(lexer.Token(TokenType)),
) -> Result(ast.Module, error.Error) {
  case chomp.run(tokens, module()) {
    Ok(module) -> Ok(module)
    Error(#(e, pos, ctx)) -> Error(error.ParseError(e, pos, ctx))
  }
}

fn module() -> Parser(ast.Module) {
  use imports <- do(chomp.many(import_()))
  use declarations <- do(chomp.until_end(declaration()))
  return(ast.Module(imports, declarations))
}

fn import_() -> Parser(ast.Import) {
  use _ <- do(chomp.token(token.Import))
  use base <- do(module_name())
  use path <- do(
    chomp.or(
      {
        use _ <- do(separator(token.Slash))
        series_of(module_name(), token.Slash)
      },
      [],
    ),
  )
  use rename <- do(
    chomp.optional({
      use _ <- do(chomp.token(token.As))
      module_name()
    }),
  )

  return(ast.Import([base, ..path], rename))
}

// -- Declarations --

fn declaration() -> Parser(ast.Declaration) {
  chomp.one_of([function(), constant(), toplevel_external(), import_hint()])
  |> chomp.or_error(
    "I expected a declaration (function, constant, or external)",
  )
}

fn function() -> Parser(ast.Declaration) {
  use _ <- do(chomp.token(token.Def))
  use publicity <- do(publicity())
  use name <- do(ident())
  use parameters <- do_in(
    ctx.InFunction(name),
    {
      use _ <- do(chomp.token(token.Backslash))
      sequence1(ident(), separator(token.Comma))
    }
      |> chomp.or([]),
  )
  use _ <- do(chomp.token(token.Eq))
  use body <- do(expression())
  return(ast.Function(name, parameters, body, publicity))
}

fn constant() -> Parser(ast.Declaration) {
  use _ <- do(chomp.token(token.Const))
  use publicity <- do(publicity())
  use name <- do(ident())
  use _ <- do_in(ctx.InConstant(name), chomp.token(token.Eq))
  use value <- do(expression())
  return(ast.Constant(name, value, publicity))
}

fn toplevel_external() -> Parser(ast.Declaration) {
  use _ <- do(chomp.token(token.External))
  use javascript_code <- do(string())
  return(ast.TopLevelExternal(javascript_code))
}

/// This parser isn't really meant to parse anything! It provides a nice error
/// message when the `import` keyword is found instead of a declaration.
///
fn import_hint() -> Parser(a) {
  use _ <- do(chomp.token(token.Import))
  throw(
    "All imports must come first in a module: try moving this to the top of the file",
  )
}

// -- Expressions --

fn expression() -> Parser(ast.Expression) {
  chomp.one_of([operator(), lambda_like(), let_(), case_()])
  |> chomp.or_error("I expected an expression")
}

fn operator() -> Parser(ast.Expression) {
  pratt.expression(
    one_of: [
      fn(_) { call() },
      pre(11, token.Minus, ast.Neg),
      pre(11, token.Exclamation, ast.Not),
    ],
    or_error: "I expected an operand value",
    and_then: [
      ir(10, token.Caret, binop(ast.Pow)),
      il(9, token.Star, binop(ast.Mul)),
      il(9, token.Slash, binop(ast.Div)),
      il(8, token.Plus, binop(ast.Add)),
      il(8, token.Minus, binop(ast.Sub)),
      il(7, token.Lt, binop(ast.Lt)),
      il(7, token.Gt, binop(ast.Gt)),
      il(7, token.LtEq, binop(ast.LtEq)),
      il(7, token.GtEq, binop(ast.GtEq)),
      il(6, token.EqEq, binop(ast.Eq)),
      il(6, token.Ne, binop(ast.Ne)),
      il(5, token.And, binop(ast.And)),
      il(4, token.Or, binop(ast.Or)),
      ir(3, token.Colon, binop(ast.Cons)),
      il(2, token.PipeRight, pipe_op),
      il(1, token.Semicolon, binop(ast.Semicolon)),
    ],
  )
}

fn binop(op: ast.Binop) -> fn(ast.Expression, ast.Expression) -> ast.Expression {
  fn(a, b) { ast.Binop(op, a, b) }
}

fn pipe_op(left: ast.Expression, right: ast.Expression) -> ast.Expression {
  // When piping to a function call, the value is placed as the first argument.
  // This isn't quite as smart as Gleam's pipe operator since we can't tell the
  // function's signature, but it's probably good enough for most cases.
  case right {
    ast.Call(function, arguments) -> ast.Call(function, [left, ..arguments])
    _ -> ast.Call(right, [left])
  }
}

fn call() -> Parser(ast.Expression) {
  use callee <- do(primary())
  use callee <- chomp.loop(callee)
  chomp.one_of([
    {
      use _ <- do_in(ctx.InCall, chomp.token(token.LParen))
      use args <- do(series_of(expression(), token.Comma))
      use _ <- do(chomp.token(token.RParen))
      return(chomp.Continue(ast.Call(callee, args)))
    },
    {
      use _ <- do(chomp.token(token.Dot))
      use field <- do(ident())
      return(chomp.Continue(ast.RecordAccess(callee, field)))
    },
  ])
  |> chomp.or(chomp.Break(callee))
}

fn primary() -> Parser(ast.Expression) {
  chomp.one_of([
    int()
      |> chomp.map(ast.Int),
    float()
      |> chomp.map(ast.Float),
    string()
      |> chomp.map(ast.String),
    ident()
      |> chomp.map(ast.Variable),
    atom(),
    module_access(),
    list(),
    record(),
    external(),
    group(),
  ])
}

fn atom() -> Parser(ast.Expression) {
  use name <- do(atom_name())
  use payload <- do_in(
    ctx.InAtom,
    chomp.one_of([
      {
        use _ <- do(chomp.token(token.LParen))
        use payload <- do(series_of(expression(), token.Comma))
        use _ <- do(chomp.token(token.RParen))
        return(payload)
      },
      {
        use payload <- do(record())
        return([payload])
      },
    ])
      |> chomp.or([]),
  )
  return(ast.Atom(name, payload))
}

fn module_access() -> Parser(ast.Expression) {
  use name <- do(module_name())
  use _ <- do(
    chomp.token(token.Dot)
    |> chomp.or_error(
      "I expected a module access using a dot: modules cannot be used as values",
    ),
  )
  use field <- do(ident())
  return(ast.ModuleAccess(name, field))
}

fn list() -> Parser(ast.Expression) {
  use _ <- do(chomp.token(token.LBracket))
  use items <- do_in(ctx.InList, series_of(expression(), token.Comma))
  use _ <- do(chomp.token(token.RBracket))
  return(ast.List(items))
}

fn record() -> Parser(ast.Expression) {
  use _ <- do(chomp.token(token.LBrace))
  use update <- do_in(
    ctx.InRecord,
    chomp.optional({
      use _ <- do(chomp.token(token.DotDot))
      use expr <- do(expression())
      use _ <- do(separator(token.Comma))
      return(expr)
    }),
  )
  use fields <- do(series_of(record_field(), token.Comma))

  chomp.one_of([
    {
      use _ <- do(chomp.token(token.DotDot))
      throw("Spreads must occur at the beginning of a record")
    },
    {
      use _ <- do(chomp.token(token.RBrace))
      return(ast.Record(fields, update))
    },
  ])
}

fn record_field() -> Parser(#(String, ast.Expression)) {
  use field_name <- do(ident())
  use value <- do(chomp.or(
    {
      use _ <- do(chomp.token(token.Colon))
      expression()
    },
    ast.Variable(field_name),
  ))
  return(#(field_name, value))
}

fn external() -> Parser(ast.Expression) {
  use _ <- do(chomp.token(token.External))
  string()
  |> chomp.map(ast.External)
}

fn group() -> Parser(ast.Expression) {
  use _ <- do(chomp.token(token.LParen))
  use expression <- do(expression())
  use _ <- do(chomp.token(token.RParen))
  return(ast.Group(expression))
}

fn lambda_like() -> Parser(ast.Expression) {
  // Since lambdas (->) and backpasses (<-) both start with a backslash and list
  // of parameters, we have this intermediate parser so we don't have to use
  // backtracking.
  use _ <- do(chomp.token(token.Backslash))
  use parameters <- do(chomp.sequence(ident(), separator(token.Comma)))

  chomp.one_of([do_lambda(parameters), do_backpass(parameters)])
  |> chomp.or_error("I expected a lambda or backpass (-> or <-)")
}

fn do_lambda(parameters: List(String)) -> Parser(ast.Expression) {
  use _ <- do(chomp.token(token.ArrowRight))
  use body <- do_in(ctx.InLambda, expression())
  return(ast.Lambda(parameters, body))
}

fn do_backpass(parameters: List(String)) -> Parser(ast.Expression) {
  use _ <- do(chomp.token(token.ArrowLeft))
  use pass_to <- do_in(ctx.InBackpass, expression())
  use body <- do(
    expression()
    |> chomp.or_error("I expected a body expression"),
  )

  let lambda = ast.Lambda(parameters, body)

  // If the expression we are passing to is a call, we pass to its last argument,
  // just like in Gleam.
  let result = case pass_to {
    ast.Call(function, arguments) ->
      ast.Call(function, list.append(arguments, [lambda]))
    _ -> ast.Call(pass_to, [lambda])
  }

  return(result)
}

fn let_() -> Parser(ast.Expression) {
  use _ <- do(chomp.token(token.Let))
  use name <- do(ident())
  use _ <- do_in(ctx.InLet(name), chomp.token(token.Eq))
  use value <- do(expression())
  use _ <- do(chomp.token(token.In))
  use body <- do(expression())
  return(ast.Let(name, value, body))
}

fn case_() -> Parser(ast.Expression) {
  use _ <- do(chomp.token(token.Case))
  use subject <- do_in(ctx.InCase, expression())
  use clauses <- do(chomp.many1(case_clause()))
  return(ast.Case(subject, clauses))
}

fn case_clause() -> Parser(ast.CaseClause) {
  use _ <- do(chomp.token(token.Bar))
  use pattern <- do_in(ctx.InCaseClause, pattern())
  use _ <- do(chomp.token(token.Eq))
  use body <- do(expression())
  return(ast.CaseClause(pattern, body))
}

// -- Patterns --

fn pattern() -> Parser(ast.Pattern) {
  use pattern <- do(
    chomp.one_of([
      int()
        |> chomp.map(ast.IntPattern),
      float()
        |> chomp.map(ast.FloatPattern),
      string()
        |> chomp.map(ast.StringPattern),
      variable_pattern(),
      list_pattern(),
      record_pattern(),
      atom_pattern(),
    ])
    |> chomp.or_error("I expected a pattern"),
  )
  chomp.or(
    {
      use _ <- do(chomp.token(token.As))
      use name <- do(ident())
      return(ast.NamedPattern(pattern, name))
    },
    pattern,
  )
}

fn variable_pattern() -> Parser(ast.Pattern) {
  use name <- do(ident())

  case name {
    "_" -> return(ast.IgnorePattern)
    _ -> return(ast.VariablePattern(name))
  }
}

fn list_pattern() -> Parser(ast.Pattern) {
  use _ <- do(chomp.token(token.LBracket))
  use patterns <- do_in(ctx.InListPattern, series_of(pattern(), token.Comma))
  use tail <- do(
    chomp.optional({
      use _ <- do(chomp.token(token.Colon))
      ident()
    }),
  )
  use _ <- do(chomp.token(token.RBracket))
  return(ast.ListPattern(patterns, tail))
}

fn record_pattern() -> Parser(ast.Pattern) {
  use _ <- do(chomp.token(token.LBrace))
  use fields <- do_in(
    ctx.InRecordPattern,
    series_of(record_pattern_field(), token.Comma),
  )
  use _ <- do(chomp.token(token.RBrace))
  return(ast.RecordPattern(fields))
}

fn record_pattern_field() -> Parser(#(String, ast.Pattern)) {
  use field_name <- do(ident())
  use pattern <- do(chomp.or(
    {
      use _ <- do(chomp.token(token.Colon))
      pattern()
    },
    ast.VariablePattern(field_name),
  ))
  return(#(field_name, pattern))
}

fn atom_pattern() -> Parser(ast.Pattern) {
  use name <- do(atom_name())
  use payload <- do(
    chomp.one_of([
      {
        use _ <- do(chomp.token(token.LParen))
        use payload <- do(series_of(pattern(), token.Comma))
        use _ <- do(chomp.token(token.RParen))
        return(payload)
      },
      {
        use payload <- do(record_pattern())
        return([payload])
      },
    ])
    |> chomp.or([]),
  )
  return(ast.AtomPattern(name, payload))
}

// ---- HELPERS ----------------------------------------------------------------

fn publicity() -> Parser(ast.Publicity) {
  chomp.or(
    chomp.token(token.Pub)
      |> chomp.replace(ast.Public),
    ast.Private,
  )
}

fn ident() -> Parser(String) {
  use tok <- do(chomp.backtrackable(chomp.any()))

  case tok {
    token.Ident(x) -> return(x)
    token.Module(_) ->
      throw(
        "I expected an identifier, but found this module name (all identifiers should begin with a lowercase letter except for module names, which must start with an uppercase letter)",
      )
    _ ->
      case token.is_keyword(tok) {
        True -> throw("I expected an identifier, but found this keyword")
        False -> throw("I expected an identifier")
      }
  }
}

fn module_name() -> Parser(String) {
  chomp.take_map(fn(tok) {
    case tok {
      token.Module(x) -> Some(x)
      _ -> None
    }
  })
  |> chomp.or_error(
    "I expected a module name (module names begin with an uppercase letter)",
  )
}

fn atom_name() -> Parser(String) {
  chomp.take_map(fn(tok) {
    case tok {
      token.Atom(x) -> Some(string.drop_left(x, 1))
      _ -> None
    }
  })
  |> chomp.or_error("I expected an atom")
}

fn string() -> Parser(String) {
  chomp.take_map(fn(tok) {
    case tok {
      token.String(s) -> Some(s)
      _ -> None
    }
  })
  |> chomp.or_error("I expected a string literal")
}

fn int() -> Parser(Int) {
  chomp.take_map(fn(tok) {
    case tok {
      token.Int(n) -> Some(n)
      _ -> None
    }
  })
  |> chomp.or_error("I expected a int literal")
}

fn float() -> Parser(Float) {
  chomp.take_map(fn(tok) {
    case tok {
      token.Float(n) -> Some(n)
      _ -> None
    }
  })
  |> chomp.or_error("I expected a float literal")
}

fn series_of(parser: Parser(a), sep: token.TokenType) -> Parser(List(a)) {
  use xs <- chomp.loop([])

  let break_with = fn(xs) {
    use <- chomp.lazy
    return(chomp.Break(list.reverse(xs)))
  }

  let continue = {
    use x <- do(parser)
    chomp.one_of([
      separator(sep)
        |> chomp.replace(chomp.Continue([x, ..xs])),
      break_with([x, ..xs]),
    ])
  }

  chomp.one_of([continue, break_with(xs)])
}

fn separator(sep: token.TokenType) -> Parser(Nil) {
  use _ <- do(chomp.token(sep))
  {
    use _ <- do(chomp.token(sep))
    throw("I found an extra delimiter, try removing it?")
  }
  |> chomp.or(Nil)
}

fn sequence1(parser: Parser(a), sep: Parser(b)) -> Parser(List(a)) {
  use x <- do(parser)
  use xs <- do(
    {
      use _ <- do(sep)
      sequence1(parser, sep)
    }
    |> chomp.or([]),
  )
  return([x, ..xs])
}

fn il(
  precedence: Int,
  token: TokenType,
  apply: fn(ast.Expression, ast.Expression) -> ast.Expression,
) {
  pratt.infix_left(precedence, chomp.token(token), apply)
}

fn ir(
  precedence: Int,
  token: TokenType,
  apply: fn(ast.Expression, ast.Expression) -> ast.Expression,
) {
  pratt.infix_right(precedence, chomp.token(token), apply)
}

fn pre(precedence: Int, token: TokenType, op: ast.Unop) {
  pratt.prefix(precedence, chomp.token(token), fn(a) { ast.Unop(op, a) })
}
