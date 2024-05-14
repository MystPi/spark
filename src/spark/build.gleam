import filepath
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/result.{try}
import gleam/string
import gleam_community/ansi
import spark/file
import spark/prelude
import spark/project

/// Build a project with its dependencies to the build directory.
///
pub fn build(project: project.Project) -> Result(Nil, String) {
  let build_dir = filepath.join(project.dir, "build")

  let start_time = now()
  use _ <- try(build_dependencies(project, to: build_dir))

  report("Compiling", project.config.name)
  use _ <- try(project.compile(project, to: build_dir))

  use path <- try(project.create_entrypoint(project, in: build_dir))
  use _ <- try(prelude.create(in: build_dir))
  let end_time = now()

  report(
    "Compiled",
    "in " <> float.to_string(round(end_time -. start_time)) <> "ms",
  )
  report("Entry", path)
  Ok(Nil)
}

@external(javascript, "../ffi.mjs", "now")
fn now() -> Float

fn round(f: Float) -> Float {
  int.to_float(float.round(f *. 100.0)) /. 100.0
}

fn build_dependencies(
  project: project.Project,
  to build_dir: String,
) -> Result(Nil, String) {
  list.try_each(project.config.dependencies, fn(dep) {
    let #(name, url) = dep
    let path = filepath.join(build_dir, "deps/" <> name)

    use _ <- try({
      case file.directory_exists(path) {
        True -> Ok(Nil)
        False -> {
          report("Downloading", name)
          download_dependency(from: url, to: path)
        }
      }
    })

    report("Compiling", name)
    use dep_project <- try(project.from(path))
    use _ <- try(project.compile(dep_project, to: build_dir))

    build_dependencies(dep_project, to: build_dir)
  })
}

@external(javascript, "../ffi.mjs", "downloadTar")
fn download_tar(from url: String, to dir: String) -> Result(Nil, String)

fn download_dependency(from url: String, to dir: String) -> Result(Nil, String) {
  use _ <- try(file.create_directory_all(dir))
  download_tar(from: url, to: dir)
}

fn report(status: String, message: String) {
  let padding = string.repeat(" ", 11 - string.length(status))
  io.println(
    padding <> ansi.blue(status) <> ansi.dim(": ") <> ansi.bold(message),
  )
}
