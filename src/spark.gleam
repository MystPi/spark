import filepath
import gleam/io
import gleam/result.{try}
import gleam/string
import spark/file
import spark/project
import gleam_community/ansi

pub fn main() {
  let result = {
    use project <- try(project.from("TestProject", "examples/TestProject"))
    build(project)
  }

  case result {
    Ok(_) -> Nil
    Error(e) -> io.println_error(e)
  }
}

/// Build a project, with the stdlib and prelude included, to the /build directory.
///
fn build(project: project.Project) -> Result(Nil, String) {
  let build_dir = filepath.join(project.dir, "build")

  report("Compiling", "Spark")
  use template <- try(project.from("Spark", "./templates"))
  use _ <- try(project.compile(template, to: build_dir))

  report("Compiling", project.name)
  use _ <- try(project.compile(project, to: build_dir))

  report("Creating", "index file")
  let path = filepath.join(project.dir, "build/index.mjs")
  let contents = "import { main } from './" <> project.name <> ".mjs';\nmain();"
  use _ <- try(file.write_all(path, contents))

  report("Compiled", "successfully")
  report("Entry", path)
  Ok(Nil)
}

fn report(status: String, message: String) {
  let padding = string.repeat(" ", 9 - string.length(status))
  io.println(padding <> ansi.bold(ansi.blue(status)) <> " " <> message)
}
