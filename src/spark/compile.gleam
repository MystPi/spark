//// A name is appended with $ if...
//// - it conflicts with a JS reserved word
//// - it's a module name (so no unexpected behavior occurs, e.g. Object.keys is
//// changed to Object$.keys)
////
//// External variables should be prefixed with $ so they can't be accesed within
//// the program.
////
//// $ is the prelude module. $$ is used to avoid evaluating the subject multiple
//// times when pattern matching.
////

import dedent.{dedent}
import glam/doc.{type Document}
import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import spark/ast
import spark/compile/pattern
import spark/module
import spark/util

const max_width = 80

// ---- COMPILATION ------------------------------------------------------------

pub fn compile(module_ast: ast.Module, module: module.Module) -> String {
  module_ast
  |> compile_module(module)
  |> doc.to_string(max_width)
}

// -- Modules --

fn compile_module(module_ast: ast.Module, module: module.Module) -> Document {
  let ast.Module(imports, declarations) = module_ast

  let prelude =
    doc.from_string(
      "import * as $ from '"
      <> module.resolve_import(module, ["spark.prelude"])
      <> "';",
    )

  let imports =
    imports
    |> list.map(compile_import(_, module))
    |> list.prepend(prelude)
    |> doc.join(doc.line)

  let declarations =
    declarations
    |> list.map(compile_declaration)
    |> doc.join(doc.lines(2))

  doc.concat([imports, doc.lines(2), declarations])
}

fn compile_import(i: ast.Import, module: module.Module) -> Document {
  let ast.Import(import_segments, rename) = i

  let path = module.resolve_import(module, import_segments)

  let name =
    case rename {
      Some(rename) -> rename
      None -> {
        let assert Ok(last) = list.last(import_segments)
        last
      }
    }
    <> "$"

  doc.from_string("import * as " <> name <> " from '" <> path <> "';")
}

// -- Declarations --

fn compile_declaration(declaration: ast.Declaration) -> Document {
  case declaration {
    ast.Function(name, parameters, body, publicity) ->
      compile_function(name, parameters, body, publicity)
    ast.Constant(name, value, publicity) ->
      compile_constant(name, value, publicity)
    ast.TopLevelExternal(javascript_code) -> gen_javascript(javascript_code)
  }
}

fn compile_function(
  name: String,
  parameters: List(ast.Pattern),
  body: ast.Expression,
  publicity: ast.Publicity,
) -> Document {
  let #(checks, bindings) =
    pattern.traverse_list(parameters, doc.from_string("arguments"))

  let publicity = case publicity {
    ast.Public -> doc.from_string("export ")
    ast.Private -> doc.empty
  }

  let body =
    [
      doc.line,
      gen_arguments_check(name, list.length(parameters), checks),
      doc.line,
      gen_bindings(bindings),
      gen_return(compile_expression(body)),
    ]
    |> doc.nest_docs(by: 2)

  doc.concat([
    publicity,
    doc.from_string("function " <> util.legalize(name) <> "()"),
    doc.from_string(" {"),
    body,
    doc.line,
    doc.from_string("}"),
  ])
}

fn gen_arguments_check(
  name: String,
  num_params: Int,
  checks: List(pattern.Check),
) -> Document {
  [
    doc.from_string("'" <> name <> "'"),
    doc.from_string("arguments"),
    doc.from_string(int.to_string(num_params)),
    ..case checks {
      [] -> []
      _ -> [
        [doc.from_string("() =>"), doc.space, pattern.compile_checks(checks)]
        |> doc.nest_docs(by: 2)
        |> doc.group,
      ]
    }
  ]
  |> list("$.checkArgs(", ");")
}

fn compile_constant(
  name: String,
  value: ast.Expression,
  publicity: ast.Publicity,
) -> Document {
  gen_const(util.legalize(name), compile_expression(value))
  |> doc.prepend(case publicity {
    ast.Public -> doc.from_string("export ")
    ast.Private -> doc.empty
  })
}

// -- Expressions --

fn compile_expression(expression: ast.Expression) -> Document {
  case expression {
    ast.Int(x) -> doc.from_string(string.inspect(x))
    ast.Float(x) -> doc.from_string(string.inspect(x))
    ast.String(x) -> doc.from_string("\"" <> x <> "\"")
    ast.Variable(name) -> doc.from_string(util.legalize(name))
    ast.Atom(name, payload) -> compile_atom(name, payload)
    ast.Group(expression) -> compile_group(expression)
    ast.ModuleAccess(module, field) ->
      doc.from_string(module <> "$." <> util.legalize(field))
    ast.List(elements) -> compile_list(elements)
    ast.Record(fields, update) -> compile_record(fields, update)
    ast.RecordAccess(record, field) -> compile_record_access(record, field)
    ast.Lambda(parameters, body) -> compile_lambda(parameters, body)
    ast.Call(function, arguments) -> compile_call(function, arguments)
    ast.Let(name, value, body) -> compile_let(name, value, body)
    ast.Binop(op, left, right) -> compile_binop(op, left, right)
    ast.Unop(op, operand) -> compile_unop(op, operand)
    ast.Case(subject, clauses) -> compile_case(subject, clauses)
    ast.External(code) ->
      code
      |> gen_javascript
      |> wrap_with_iife
  }
}

fn compile_atom(name: String, payload: List(ast.Expression)) -> Document {
  [
    doc.from_string("'" <> name <> "'"),
    ..payload
      |> list.map(compile_expression)
  ]
  |> list("(", ")")
  |> doc.prepend(doc.from_string("new $.Atom"))
}

fn compile_group(expression: ast.Expression) -> Document {
  doc.concat([
    doc.from_string("("),
    compile_expression(expression),
    doc.from_string(")"),
  ])
}

fn compile_list(elements: List(ast.Expression)) -> Document {
  elements
  |> list.map(compile_expression)
  |> list("[", "]")
}

fn compile_record(
  fields: List(#(String, ast.Expression)),
  update: Option(ast.Expression),
) -> Document {
  let fields =
    fields
    |> list.map(fn(field) {
      let #(name, value) = field
      doc.concat([
        doc.from_string("'" <> util.legalize(name) <> "',"),
        doc.space,
        compile_expression(value),
      ])
      |> wrap("[", "]", trailing: ",")
    })
    |> list("[", "]")

  case update {
    None ->
      doc.concat([
        doc.from_string("new $.Record("),
        fields,
        doc.from_string(")"),
      ])
    Some(update) ->
      doc.concat([
        doc.from_string("$.Record.update"),
        [compile_expression(update), fields]
          |> list("(", ")"),
      ])
  }
}

fn compile_record_access(record: ast.Expression, field: String) -> Document {
  [
    compile_expression(record),
    doc.from_string("'" <> util.legalize(field) <> "'"),
  ]
  |> list("$.Record.access(", ")")
}

fn compile_lambda(
  parameters: List(ast.Pattern),
  body: ast.Expression,
) -> Document {
  let #(checks, bindings) =
    pattern.traverse_list(parameters, doc.from_string("arguments"))

  let body =
    [
      doc.line,
      gen_arguments_check("ANON", list.length(parameters), checks),
      doc.line,
      gen_bindings(bindings),
      gen_return(compile_expression(body)),
    ]
    |> doc.nest_docs(by: 2)

  doc.concat([
    doc.from_string("function() {"),
    body,
    doc.line,
    doc.from_string("}"),
  ])
  |> doc.force_break
}

fn compile_call(
  function: ast.Expression,
  arguments: List(ast.Expression),
) -> Document {
  arguments
  |> list.map(compile_expression)
  |> list("(", ")")
  |> doc.prepend(compile_expression(function))
}

fn compile_let(
  name: String,
  value: ast.Expression,
  body: ast.Expression,
) -> Document {
  doc.concat([
    gen_const(util.legalize(name), compile_expression(value)),
    doc.line,
    gen_return(compile_expression(body)),
  ])
  |> wrap_with_iife
}

fn compile_binop(
  op: ast.Binop,
  left: ast.Expression,
  right: ast.Expression,
) -> Document {
  case op {
    ast.Cons -> compile_cons(left, right)
    ast.Semicolon -> compile_semicolon(left, right)
    ast.Eq -> compile_eq(left, right)
    ast.Ne -> compile_ne(left, right)

    _ -> {
      let string_op = case op {
        ast.Add -> "+"
        ast.Sub -> "-"
        ast.Mul -> "*"
        ast.Div -> "/"
        ast.Pow -> "**"
        ast.Lt -> "<"
        ast.Gt -> ">"
        ast.LtEq -> "<="
        ast.GtEq -> ">="
        ast.And -> "&&"
        ast.Or -> "||"
        _ -> ""
      }

      doc.concat([
        compile_expression(left),
        doc.from_string(" " <> string_op <> " "),
        compile_expression(right),
      ])
    }
  }
}

fn compile_cons(left: ast.Expression, right: ast.Expression) -> Document {
  doc.concat([
    compile_expression(left),
    doc.from_string(","),
    doc.space,
    doc.from_string("..."),
    compile_expression(right),
  ])
  |> wrap("[", "]", trailing: ",")
}

fn compile_semicolon(left: ast.Expression, right: ast.Expression) -> Document {
  doc.concat([
    compile_expression(left),
    doc.from_string(";"),
    doc.line,
    gen_return(compile_expression(right)),
  ])
  |> wrap_with_iife
}

fn compile_eq(left: ast.Expression, right: ast.Expression) -> Document {
  [compile_expression(left), compile_expression(right)]
  |> list("(", ")")
  |> doc.prepend(doc.from_string("$.eq"))
}

fn compile_ne(left: ast.Expression, right: ast.Expression) -> Document {
  compile_eq(left, right)
  |> doc.prepend(doc.from_string("!"))
}

fn compile_unop(op: ast.Unop, operand: ast.Expression) -> Document {
  let string_op = case op {
    ast.Not -> "!"
    ast.Neg -> "-"
  }

  doc.concat([doc.from_string(string_op), compile_expression(operand)])
}

fn compile_case(
  subject: ast.Expression,
  clauses: List(ast.CaseClause),
) -> Document {
  let #(new_subject, subject_assignment) = case subject {
    ast.Variable(name) -> #(doc.from_string(util.legalize(name)), doc.empty)
    _ -> #(
      doc.from_string("$$"),
      gen_const("$$", compile_expression(subject))
        |> doc.append(doc.line),
    )
  }

  let #(clauses_reversed, has_catch_all) =
    clauses
    |> list.fold_until(#([], False), fn(acc, clause) {
      case compile_case_clause(new_subject, clause) {
        #(doc, True) -> list.Stop(#([doc, ..acc.0], True))
        #(doc, False) -> list.Continue(#([doc, ..acc.0], False))
      }
    })

  let clauses =
    clauses_reversed
    |> list.reverse
    |> doc.join(doc.line)

  let throw_statement = case has_catch_all {
    True -> doc.empty
    False ->
      doc.concat([
        doc.line,
        doc.from_string("throw new Error('Non-exhastive case clauses');"),
      ])
  }

  doc.concat([subject_assignment, clauses, throw_statement])
  |> wrap_with_iife
}

fn compile_case_clause(
  subject: Document,
  clause: ast.CaseClause,
) -> #(Document, Bool) {
  let ast.CaseClause(pattern, body) = clause
  let #(checks, bindings) = pattern.traverse(pattern, subject)

  let bindings = gen_bindings(bindings)
  let return = gen_return(compile_expression(body))

  case checks {
    [] -> #(doc.concat([bindings, return]), True)
    _ -> {
      let checks = pattern.compile_checks(checks)

      #(
        doc.concat([
          doc.from_string("if "),
          checks
            |> wrap("(", ")", trailing: ""),
          doc.from_string(" {"),
          [doc.line, bindings, return]
            |> doc.nest_docs(by: 2),
          doc.line,
          doc.from_string("}"),
        ]),
        False,
      )
    }
  }
}

fn gen_bindings(bindings: Dict(String, Document)) -> Document {
  case dict.to_list(bindings) {
    [] -> doc.empty
    bindings ->
      bindings
      |> list.map(fn(bindings) {
        let #(name, value) = bindings
        gen_const(name, value)
      })
      |> doc.join(doc.line)
      |> doc.append(doc.line)
  }
}

// ---- HELPERS ----------------------------------------------------------------

fn gen_return(value: Document) -> Document {
  doc.concat([doc.from_string("return "), value, doc.from_string(";")])
}

fn gen_const(name: String, value: Document) -> Document {
  doc.concat([
    doc.from_string("const " <> name <> " = "),
    value,
    doc.from_string(";"),
  ])
}

fn gen_javascript(code: String) -> Document {
  code
  |> dedent
  |> string.split("\n")
  |> list.map(doc.from_string)
  |> doc.join(doc.line)
}

fn wrap_with_iife(inner: Document) -> Document {
  [doc.from_string("(() => {"), doc.line, inner]
  |> doc.nest_docs(by: 2)
  |> doc.append_docs([doc.line, doc.from_string("})()")])
  |> doc.force_break
}

fn wrap(
  inner: Document,
  left: String,
  right: String,
  trailing trailing: String,
) -> Document {
  inner
  |> doc.prepend_docs([doc.from_string(left), doc.soft_break])
  |> doc.nest(by: 2)
  |> doc.append_docs([doc.break("", trailing), doc.from_string(right)])
  |> doc.group
}

fn list(inner: List(Document), left: String, right: String) -> Document {
  inner
  |> doc.concat_join([doc.from_string(","), doc.space])
  |> wrap(left, right, trailing: ",")
}
