import chomp/lexer
import gleam/string

pub type Tokens =
  List(lexer.Token(TokenType))

pub type Token =
  lexer.Token(TokenType)

pub type Span =
  lexer.Span

pub type TokenType {
  // Literals
  String(String)
  Number(Float)
  // Identifiers
  Ident(String)
  Atom(String)
  Module(String)
  // Pairs
  LParen
  RParen
  LBracket
  RBracket
  LBrace
  RBrace
  // Double characters
  EqEq
  Ne
  GtEq
  LtEq
  ArrowRight
  ArrowLeft
  PipeRight
  DotDot
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
  Exclamation
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

pub fn to_string(tok: TokenType) -> String {
  case tok {
    String(x) -> string.inspect(x)
    Number(x) -> string.inspect(x)
    Ident(x) -> x
    Atom(x) -> x
    Module(x) -> x
    LParen -> "("
    RParen -> ")"
    LBracket -> "["
    RBracket -> "]"
    LBrace -> "{"
    RBrace -> "}"
    EqEq -> "=="
    Ne -> "!="
    GtEq -> ">="
    LtEq -> "<="
    ArrowRight -> "->"
    ArrowLeft -> "<-"
    PipeRight -> "|>"
    DotDot -> ".."
    Comma -> ","
    Dot -> "."
    Colon -> ":"
    Semicolon -> ";"
    Backslash -> "\\"
    Bar -> "|"
    Eq -> "="
    Plus -> "+"
    Minus -> "-"
    Star -> "*"
    Slash -> "/"
    Caret -> "^"
    Exclamation -> "!"
    Gt -> ">"
    Lt -> "<"
    Def -> "def"
    Pub -> "pub"
    Const -> "const"
    Of -> "of"
    As -> "as"
    Any -> "any"
    And -> "and"
    Or -> "or"
    Case -> "case"
    Let -> "let"
    In -> "in"
    Import -> "import"
    External -> "external"
    Comment(x) -> x
  }
}

pub fn is_keyword(tok: TokenType) -> Bool {
  case tok {
    Def
    | Pub
    | Const
    | Of
    | As
    | Any
    | And
    | Or
    | Case
    | Let
    | In
    | Import
    | External -> True
    _ -> False
  }
}
