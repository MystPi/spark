//// This module contains the AST of spark. Everything representable in spark
//// is represented here in some way.
////

import gleam/option.{type Option}

/// A module contains multiple top-level declarations.
///
pub type Module {
  Module(declarations: List(Declaration))
}

/// A declaration is something at the top-level of a module.
///
pub type Declaration {
  Function(
    name: String,
    parameters: List(String),
    body: Expression,
    publicity: Publicity,
  )
  Constant(name: String, value: Expression, publicity: Publicity)
  TopLevelExternal(javascript_code: String)
}

/// Publicity determines whether a definition is exported from the module using
/// the JS `export` keyword. Only top-level definitions can have a publicity since
/// it doesn't make sense to export nested expressions.
///
pub type Publicity {
  Public
  Private
}

/// Expressions represent every possible value that can be expressed in the
/// language.
///
pub type Expression {
  Number(value: Float)
  String(value: String)
  Variable(name: String)
  List(values: List(Expression))
  Lambda(parameters: List(String), body: Expression)
  Call(function: Expression, arguments: List(Expression))
  Let(name: String, value: Expression, body: Expression)
  Binop(op: Binop, left: Expression, right: Expression)
  Unop(op: Unop, operand: Expression)
  Case(subject: Expression, clauses: List(CaseClause))
  External(javascript_code: String)
}

/// Binary operators have two operands.
///
pub type Binop {
  // Math: +, -, *, /
  Add
  Sub
  Mul
  Div
  // Equality: ==, !=
  Eq
  Ne
  // Comparison: >, <, >=, <=
  Gt
  Lt
  GtEq
  LtEq
  // Logical: and, or
  And
  Or
  // Lists: :
  Cons
  // Expressions
  Semicolon
}

/// Unary operators have one operand.
///
pub type Unop {
  // Math: -
  Neg
  // Logical: !
  Not
}

/// A case clause consists of a pattern and its body.
///
pub type CaseClause {
  CaseClause(pattern: Pattern, body: Expression)
}

/// Patterns are used to match against expressions.
///
pub type Pattern {
  ListPattern(list: List(Pattern), tail: Option(String))
  VariablePattern(name: String)
  NamedPattern(pattern: Pattern, name: String)
  IgnorePattern
  NumberPattern(value: Float)
  StringPattern(value: String)
}
