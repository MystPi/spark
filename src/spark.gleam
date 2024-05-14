import argv
import filepath
import gleam/dict
import gleam/io
import gleam/list
import gleam/result
import glint
import glint/flag
import spark/build
import spark/error
import spark/file
import spark/project
import spark/util

pub fn main() {
  glint.new()
  |> glint.with_name("spark")
  |> glint.with_pretty_help(glint.default_pretty_help())
  |> glint.add(at: ["build"], do: build_command())
  |> glint.add(at: ["clean"], do: clean_command())
  |> glint.add(at: ["new"], do: new_project_command())
  |> glint.run_and_handle(argv.load().arguments, print_result)
}

fn print_result(result: Result(Nil, String)) -> Nil {
  case result {
    Ok(_) -> Nil
    Error(e) -> io.println_error(e)
  }
}

// ---- FLAGS ------------------------------------------------------------------

const root = "root"

fn root_flag() -> flag.FlagBuilder(String) {
  flag.string()
  |> flag.default("./")
  |> flag.description("Change project root directory; default is ./")
}

fn get_root_flag(input: glint.CommandInput) -> String {
  let assert Ok(root) = flag.get_string(input.flags, root)
  root
}

// ---- COMMANDS ---------------------------------------------------------------

// -- Build --

fn build_command() {
  glint.command(fn(input) {
    input
    |> get_root_flag
    |> build
  })
  |> glint.description("Build a project")
  |> glint.flag(root, root_flag())
  |> glint.unnamed_args(glint.EqArgs(0))
}

fn build(root: String) {
  project.from(root)
  |> result.then(build.build)
}

// -- Clean --

fn clean_command() {
  glint.command(fn(input) {
    input
    |> get_root_flag
    |> clean
  })
  |> glint.description("Delete a project's build directory")
  |> glint.flag(root, root_flag())
  |> glint.unnamed_args(glint.EqArgs(0))
}

fn clean(root: String) {
  filepath.join(root, "build")
  |> file.delete
}

// -- New Project --

fn new_project_command() {
  glint.command(fn(input) {
    let assert Ok(name) = dict.get(input.named_args, "name")
    case util.is_valid_module_name(name) {
      True -> new_project(name)
      False ->
        Error(error.simple_error(
          "`"
          <> name
          <> "` is not a valid module name. Module names start with an uppercase letter and contain only letters and numbers",
        ))
    }
  })
  |> glint.description("Create a new spark project")
  |> glint.named_args(["name"])
  |> glint.unnamed_args(glint.EqArgs(0))
}

fn new_project(name: String) {
  let files = [
    #(".gitignore", "/build\n"),
    #("README.md", new_project_readme(name)),
    #("spark.toml", new_project_config(name)),
    #("src/" <> name <> ".spark", new_project_code(name)),
  ]

  use _ <- result.try(
    list.try_each(files, fn(file) {
      let #(path, contents) = file
      file.safe_write_all(filepath.join(name, path), contents)
    }),
  )

  Ok(io.println("Created project in ./" <> name))
}

fn new_project_readme(name: String) -> String {
  "# " <> name <> "

A spark project.

```sh
# build
spark build

# run with Bun
bun run ./build/index.mjs

# run with Deno
deno run ./build/index.mjs

# run with Node
node ./build/index.mjs
```
"
}

fn new_project_config(name: String) -> String {
  "name = \"" <> name <> "\"

[dependencies]
Spark = \"https://github.com/MystPi/spark_stdlib/archive/refs/heads/main.tar.gz\"
"
}

fn new_project_code(name: String) -> String {
  "import Spark/IO

def pub main =
  IO.println(\"Hello from " <> name <> "!\")
"
}
