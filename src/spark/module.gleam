import filepath
import gleam/list
import gleam/string
import spark/util

// ---- TYPES ------------------------------------------------------------------

pub type Module {
  Module(segments: List(String), path: String)
}

// ---- CONSTRUCTOR ------------------------------------------------------------

pub fn from_path(path: String, inside_dir: String) -> Result(Module, Nil) {
  let stripped_path =
    path
    |> util.remove_prefix(inside_dir <> "/")

  let segments = filepath.split(stripped_path)

  let all_valid =
    segments
    |> list.all(fn(segment) {
      let without_extension = filepath.strip_extension(segment)

      case util.is_valid_module_name(without_extension) {
        False -> False
        True ->
          filepath.extension(segment) == Ok("spark")
          || without_extension == segment
      }
    })

  case all_valid {
    False -> Error(Nil)
    True ->
      segments
      |> list.map(filepath.strip_extension)
      |> Module(path)
      |> Ok
  }
}

// ---- FUNCTIONS --------------------------------------------------------------

/// Resolves an import from the given module to an import path, from the root of
/// the project.
///
pub fn resolve_import(module: Module, import_segments: List(String)) -> String {
  let prefix = case module.segments {
    [_] | [] -> "./"
    [_, ..rest] ->
      rest
      |> list.map(fn(_) { ".." })
      |> string.join("/")
      <> "/"
  }

  prefix <> string.join(import_segments, with: "/") <> ".mjs"
}
