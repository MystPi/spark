import filepath
import gleam/dict
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
import tom

// ---- TYPES ------------------------------------------------------------------

pub type Project {
  Project(
    config: Config,
    modules: List(Module),
    extra_files: List(String),
    dir: String,
  )
}

pub type Config {
  Config(name: String, dependencies: List(#(String, String)))
}

// ---- CONSTRUCTOR ------------------------------------------------------------

pub fn from(dir: String) -> Result(Project, String) {
  use config_file <- try(
    file.read(filepath.join(dir, "spark.toml"))
    |> result.replace_error(error.simple_error(
      "`spark.toml` config file is missing",
    )),
  )
  use config <- try(parse_config(config_file))
  use #(modules, extra_files) <- try(
    scan_project_files(filepath.join(dir, "src")),
  )
  Ok(Project(config, modules, extra_files, dir))
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

fn parse_config(config_file: String) -> Result(Config, String) {
  use parsed <- try(
    tom.parse(config_file)
    |> result.replace_error(error.simple_error(
      "I was unable to parse the config file as valid TOML",
    )),
  )
  use name <- try(
    tom.get_string(parsed, ["name"])
    |> result.replace_error(error.simple_error(
      "Config is missing the `name` field or it is not a string",
    )),
  )
  use dependencies <- try(get_dependencies(parsed))
  Ok(Config(name, dependencies))
}

fn get_dependencies(
  toml: dict.Dict(String, tom.Toml),
) -> Result(List(#(String, String)), String) {
  case tom.get_table(toml, ["dependencies"]) {
    Error(tom.NotFound(_)) -> Ok([])

    Error(tom.WrongType(..)) ->
      Error(error.simple_error(
        "`dependencies` must be a table of module names and URLs",
      ))

    Ok(deps) ->
      deps
      |> dict.to_list
      |> list.try_map(fn(dep) {
        let #(key, value) = dep

        case util.is_valid_module_name(key), value {
          True, tom.String(s) -> Ok(#(key, s))
          False, _ ->
            Error(error.simple_error(
              "`" <> key <> "` is not a valid module name",
            ))
          _, _ ->
            Error(error.simple_error("`dependencies` URLs must be strings"))
        }
      })
  }
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

/// Create an entrypoint file that runs the project's `main` function. If the
/// entrypoint was created successfully, the path to the file is returned for
/// convenience.
///
pub fn create_entrypoint(
  project: Project,
  in build_dir: String,
) -> Result(String, String) {
  let path = filepath.join(build_dir, "index.mjs")
  let contents =
    "import { main } from './" <> project.config.name <> ".mjs';\n\nmain();"

  file.write_all(path, contents)
  |> result.replace(path)
}
