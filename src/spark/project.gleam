import filepath
import gleam/list
import gleam/result.{try}
import gleam/string
import spark/compile
import spark/error
import spark/file
import spark/lex
import spark/module.{type Module}
import spark/parse
import spark/util

// ---- TYPES ------------------------------------------------------------------

pub type Project {
  Project(name: String, modules: List(Module), extra_files: List(String), dir: String)
}

// ---- CONSTRUCTOR ------------------------------------------------------------

pub fn from(name: String, dir: String) -> Result(Project, String) {
  use #(modules, extra_files) <- try(
    scan_project_files(filepath.join(dir, "src")),
  )
  Ok(Project(name, modules, extra_files, dir))
}

fn scan_project_files(
  dir: String,
) -> Result(#(List(Module), List(String)), String) {
  use files <- try(file.get_files(dir))

  files
  |> list.fold(#([], []), fn(acc, path) {
    case module.from_path(path, dir) {
      Ok(module) -> #([module, ..acc.0], acc.1)
      Error(_) -> #(acc.0, [path, ..acc.1])
    }
  })
  |> Ok
}

// ---- FUNCTIONS --------------------------------------------------------------

/// Compile a project to the given build directory.
///
pub fn compile(project: Project, to build_dir: String) -> Result(Nil, String) {
  use _ <- try(
    project.modules
    |> list.try_each(fn(module) {
      use contents <- try(file.read(module.path))

      let result = {
        use lexed <- try(lex.lex(contents))
        use parsed <- try(parse.parse(lexed))
        Ok(compile.compile(parsed, module))
      }

      case result {
        Ok(compiled) -> {
          let path =
            filepath.join(
              build_dir,
              string.join(module.segments, "/") <> ".mjs",
            )
          file.write_all(path, compiled)
        }
        Error(e) -> Error(error.to_string(e, contents, module.path))
      }
    }),
  )

  project.extra_files
  |> list.try_each(fn(path) {
    let new_path = util.remove_prefix(path, filepath.join(project.dir, "src"))
    file.copy(path, filepath.join(build_dir, new_path))
  })
}
