import nibble.{type Parser, do, return, throw}
import nibble/pratt
import spark/ast
import spark/lexer.{type Token}

// ---- PARSER -----------------------------------------------------------------

pub fn parse(tokens: lexer.Tokens) {
  tokens
  |> nibble.run(module())
}

fn module() -> Parser(ast.Module, Token, Nil) {
  use declarations <- do(nibble.many(declaration()))
  use _ <- do(nibble.eof())
  return(ast.Module(declarations))
}

// -- Declarations --

fn declaration() -> Parser(ast.Declaration, Token, Nil) {
  nibble.one_of([function(), constant(), toplevel_external()])
}

fn function() -> Parser(ast.Declaration, Token, Nil) {
  use _ <- do(nibble.token(lexer.Def))
  use publicity <- do(publicity())
  use name <- do(ident())
  use _ <- do(nibble.token(lexer.Backslash))
  use parameters <- do(nibble.sequence(ident(), nibble.token(lexer.Comma)))
  use _ <- do(nibble.token(lexer.Eq))
  use body <- do(expression())
  return(ast.Function(name, parameters, body, publicity))
}

fn constant() -> Parser(ast.Declaration, Token, Nil) {
  use _ <- do(nibble.token(lexer.Const))
  use publicity <- do(publicity())
  use name <- do(ident())
  use _ <- do(nibble.token(lexer.Eq))
  use value <- do(expression())
  return(ast.Constant(name, value, publicity))
}

fn toplevel_external() -> Parser(ast.Declaration, Token, Nil) {
  use _ <- do(nibble.token(lexer.External))
  use javascript_code <- do(string())
  return(ast.TopLevelExternal(javascript_code))
}

// -- Expressions --

fn expression() -> Parser(ast.Expression, Token, Nil) {
  pratt.expression(
    one_of: [fn(_) { call() }],
    and_then: [
      //
      il(7, lexer.Star, ast.Mul),
      il(7, lexer.Slash, ast.Div),
      //
      il(6, lexer.Plus, ast.Add),
      il(6, lexer.Minus, ast.Sub),
      //
      il(5, lexer.Lt, ast.Lt),
      il(5, lexer.Gt, ast.Gt),
      il(5, lexer.LtEq, ast.LtEq),
      il(5, lexer.GtEq, ast.GtEq),
      //
      il(4, lexer.EqEq, ast.Eq),
      il(4, lexer.Ne, ast.Ne),
      //
      ir(3, lexer.Colon, ast.Cons)
    ],
    dropping: return(Nil),
  )
}

fn il(precedence: Int, token: lexer.Token, op: ast.Binop) {
  pratt.infix_left(precedence, nibble.token(token), fn(a, b) {
    ast.Binop(op, a, b)
  })
}

fn ir(precedence: Int, token: lexer.Token, op: ast.Binop) {
  pratt.infix_right(precedence, nibble.token(token), fn(a, b) {
    ast.Binop(op, a, b)
  })
}

fn call() -> Parser(ast.Expression, Token, Nil) {
  use callee <- do(primary())
  use callee <- nibble.loop(callee)
  {
    use _ <- do(nibble.token(lexer.LParen))
    use args <- do(nibble.sequence(expression(), nibble.token(lexer.Comma)))
    use _ <- do(nibble.token(lexer.RParen))
    return(nibble.Continue(ast.Call(callee, args)))
  }
  |> nibble.or(nibble.Break(callee))
}

fn primary() -> Parser(ast.Expression, Token, Nil) {
  nibble.one_of([
    number()
      |> nibble.map(ast.Number),
    string()
      |> nibble.map(ast.String),
    ident()
      |> nibble.map(ast.Variable),
    list(),
    external(),
    group(),
  ])
}

fn list() -> Parser(ast.Expression, Token, Nil) {
  use _ <- do(nibble.token(lexer.LBracket))
  use items <- do(nibble.sequence(expression(), nibble.token(lexer.Comma)))
  use _ <- do(nibble.token(lexer.RBracket))
  return(ast.List(items))
}

fn external() -> Parser(ast.Expression, Token, Nil) {
  use _ <- do(nibble.token(lexer.External))
  use javascript_code <- do(string())
  return(ast.External(javascript_code))
}

fn group() -> Parser(ast.Expression, Token, Nil) {
  use _ <- do(nibble.token(lexer.LParen))
  use expression <- do(expression())
  use _ <- do(nibble.token(lexer.RParen))
  return(expression)
}

// ---- HELPERS ----------------------------------------------------------------

/// Attempt to parse the `pub` keyword returning `ast.Public`, otherwise
/// returning `ast.Private`.
///
fn publicity() -> Parser(ast.Publicity, Token, Nil) {
  nibble.or(
    nibble.token(lexer.Pub)
      |> nibble.replace(ast.Public),
    ast.Private,
  )
}

/// Parse an identifier and return its name.
///
fn ident() -> Parser(String, Token, Nil) {
  use tok <- do(nibble.any())

  case tok {
    lexer.Ident(ident) -> return(ident)
    _ -> throw("I expected an identifier")
  }
}

/// Parse a string literal.
///
fn string() -> Parser(String, Token, Nil) {
  use tok <- do(nibble.any())

  case tok {
    lexer.String(string) -> return(string)
    _ -> throw("I expected a string literal")
  }
}

/// Parse a number literal.
///
fn number() -> Parser(Float, Token, Nil) {
  use tok <- do(nibble.any())

  case tok {
    lexer.Number(number) -> return(number)
    _ -> throw("I expected a number literal")
  }
}
