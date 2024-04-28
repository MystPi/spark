import glam/doc.{type Document}
import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/pair
import gleam/string
import spark/ast
import spark/util

// ---- TYPES ------------------------------------------------------------------

pub type Check {
  ListCheck(subject: Document, length: Int, has_tail: Bool)
  LiteralCheck(subject: Document, should_be: Document)
  AtomCheck(subject: Document, name: String, payload_length: Int)
  RecordCheck(subject: Document, fields: List(String))
}

type Ctx {
  Ctx(checks: List(Check), bindings: Dict(String, Document))
}

// ---- TRAVERSING PATTERNS ----------------------------------------------------

pub fn traverse(
  pattern: ast.Pattern,
  subject: Document,
) -> #(List(Check), Dict(String, Document)) {
  initial_ctx()
  |> do_traverse(pattern, subject)
  |> ctx_to_tuple
}

pub fn traverse_list(
  patterns: List(ast.Pattern),
  subject: Document,
) -> #(List(Check), Dict(String, Document)) {
  initial_ctx()
  |> traverse_list_patterns(patterns, subject)
  |> ctx_to_tuple
}

fn initial_ctx() -> Ctx {
  Ctx([], dict.new())
}

fn ctx_to_tuple(ctx: Ctx) -> #(List(Check), Dict(String, Document)) {
  #(list.reverse(ctx.checks), ctx.bindings)
}

fn do_traverse(ctx: Ctx, pattern: ast.Pattern, subject: Document) -> Ctx {
  case pattern {
    ast.VariablePattern(name) -> insert_binding(ctx, name, subject)
    ast.IgnorePattern -> ctx
    ast.NamedPattern(pattern, name) ->
      ctx
      |> do_traverse(pattern, subject)
      |> insert_binding(name, subject)
    ast.IntPattern(x) ->
      push_check(ctx, LiteralCheck(subject, doc.from_string(string.inspect(x))))
    ast.FloatPattern(x) ->
      push_check(ctx, LiteralCheck(subject, doc.from_string(string.inspect(x))))
    ast.StringPattern(x) ->
      push_check(ctx, LiteralCheck(subject, doc.from_string("\"" <> x <> "\"")))
    ast.AtomPattern(name, payload) ->
      ctx
      |> push_check(AtomCheck(subject, name, list.length(payload)))
      |> traverse_atom_payload(payload, subject)
    ast.ListPattern(list, tail) -> {
      let ctx =
        ctx
        |> push_check(ListCheck(
          subject,
          list.length(list),
          option.is_some(tail),
        ))
        |> traverse_list_patterns(list, subject)

      case tail {
        None -> ctx
        Some(name) ->
          insert_binding(
            ctx,
            name,
            doc.concat([subject, doc.from_string(".slice(1)")]),
          )
      }
    }
    ast.RecordPattern(fields) ->
      ctx
      |> push_check(RecordCheck(subject, list.map(fields, pair.first)))
      |> traverse_record_fields(fields, subject)
  }
}

fn traverse_list_patterns(
  ctx: Ctx,
  patterns: List(ast.Pattern),
  subject: Document,
) -> Ctx {
  use ctx, pattern, index <- list.index_fold(patterns, ctx)

  let new_subject =
    doc.concat([subject, doc.from_string("[" <> int.to_string(index) <> "]")])

  do_traverse(ctx, pattern, new_subject)
}

fn traverse_atom_payload(
  ctx: Ctx,
  payload: List(ast.Pattern),
  subject: Document,
) -> Ctx {
  use ctx, pattern, index <- list.index_fold(payload, ctx)

  let new_subject =
    doc.concat([
      subject,
      doc.from_string(".payload[" <> int.to_string(index) <> "]"),
    ])

  do_traverse(ctx, pattern, new_subject)
}

fn traverse_record_fields(
  ctx: Ctx,
  fields: List(#(String, ast.Pattern)),
  subject: Document,
) -> Ctx {
  use ctx, #(field, pattern) <- list.fold(fields, ctx)

  let new_subject =
    doc.concat([
      subject,
      doc.from_string(".get('" <> util.legalize(field) <> "')"),
    ])

  do_traverse(ctx, pattern, new_subject)
}

// ---- GENERATING CHECKS ------------------------------------------------------

pub fn compile_check(check: Check) -> Document {
  case check {
    LiteralCheck(subject, should_be) ->
      doc.concat([subject, doc.from_string(" === "), should_be])

    ListCheck(subject, length, has_tail) ->
      doc.concat([
        doc.from_string("Array.isArray("),
        subject,
        doc.from_string(") &&"),
        doc.space,
        subject,
        doc.from_string(
          ".length"
          <> case has_tail {
            True -> " >= "
            False -> " == "
          }
          <> int.to_string(length),
        ),
      ])

    AtomCheck(subject, name, payload_length) ->
      doc.concat([
        subject,
        doc.from_string(" instanceof $.Atom &&"),
        doc.space,
        subject,
        doc.from_string(".name == '" <> name <> "' &&"),
        doc.space,
        subject,
        doc.from_string(".payload.length == " <> int.to_string(payload_length)),
      ])

    RecordCheck(subject, fields) ->
      doc.concat([
        subject,
        doc.from_string(" instanceof $.Record &&"),
        doc.space,
        fields
          |> list.map(fn(field) {
          doc.concat([
            subject,
            doc.from_string(".has('" <> util.legalize(field) <> "')"),
          ])
        })
          |> doc.concat_join([doc.from_string(" &&"), doc.space]),
      ])
  }
}

pub fn compile_checks(checks: List(Check)) -> Document {
  checks
  |> list.map(compile_check)
  |> doc.concat_join([doc.from_string(" &&"), doc.space])
}

// ---- HELPERS ----------------------------------------------------------------

fn push_check(ctx: Ctx, check: Check) -> Ctx {
  Ctx(..ctx, checks: [check, ..ctx.checks])
}

fn insert_binding(ctx: Ctx, name: String, value: Document) -> Ctx {
  Ctx(..ctx, bindings: dict.insert(ctx.bindings, util.legalize(name), value))
}
