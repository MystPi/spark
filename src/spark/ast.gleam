//// This module contains the AST of spark. Everything representable in spark
//// is represented here in some way.
////

import gleam/option.{type Option}

/// A module contains multiple imports and top-level declarations.
///
pub type Module {
  Module(imports: List(Import), declarations: List(Declaration))
}

/// An import consists of the following:
///
///   import foo/bar/baz as blah
///
/// - The base module name: "foo"
/// - Any paths: ["bar", "baz"]
/// - An optional rename: Some("blah")
///
pub type Import {
  Import(base: String, path: List(String), rename: Option(String))
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
  ModuleAccess(module: String, field: String)
  List(values: List(Expression))
  Record(fields: List(#(String, Expression)), update: Option(Expression))
  RecordAccess(record: Expression, field: String)
  Lambda(parameters: List(String), body: Expression)
  Call(function: Expression, arguments: List(Expression))
  Let(name: String, value: Expression, body: Expression)
  Binop(op: Binop, left: Expression, right: Expression)
  Unop(op: Unop, operand: Expression)
  Case(subject: Expression, clauses: List(CaseClause))
  External(javascript_code: String)
  Atom(name: String, payload: List(Expression))
}

/// Binary operators have two operands.
///
pub type Binop {
  // Math: +, -, *, /, ^
  Add
  Sub
  Mul
  Div
  Pow
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
  Neg
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
  RecordPattern(fields: List(#(String, Pattern)))
  VariablePattern(name: String)
  NamedPattern(pattern: Pattern, name: String)
  IgnorePattern
  NumberPattern(value: Float)
  StringPattern(value: String)
  AtomPattern(name: String, payload: List(Pattern))
}
