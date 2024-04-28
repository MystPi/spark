import filepath
import gleam/result.{try}
import simplifile
import spark/error

/// Write a file, creating directories as needed.
///
pub fn write_all(path: String, contents: String) -> Result(Nil, String) {
  let dir = filepath.directory_name(path)
  use _ <- try(
    simplifile.create_directory_all(dir)
    |> result.replace_error(file_error("create this directory", dir)),
  )
  simplifile.write(path, contents)
  |> result.replace_error(file_error("write to this file", path))
}

/// Read a file.
///
pub fn read(path: String) -> Result(String, String) {
  simplifile.read(path)
  |> result.replace_error(file_error("read this file", path))
}

/// Copy a file at the first path to the second path.
///
pub fn copy(from: String, to: String) -> Result(Nil, String) {
  simplifile.copy_file(from, to)
  |> result.replace_error(file_error("copy this file", from))
}

/// List files in a directory.
///
pub fn get_files(dir: String) -> Result(List(String), String) {
  simplifile.get_files(dir)
  |> result.replace_error(file_error("read this directory", dir))
}

fn file_error(message, path) -> String {
  error.simple_error("I was unable to " <> message <> ": " <> path)
}
