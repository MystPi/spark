import filepath
import gleam/result.{try}
import simplifile
import spark/error

/// Write a file, creating directories as needed.
///
pub fn write_all(path: String, contents: String) -> Result(Nil, String) {
  use _ <- try(create_directory_all(filepath.directory_name(path)))
  simplifile.write(path, contents)
  |> result.replace_error(file_error("write to this file", path))
}

/// Write a file, creating directories as needed. Returns an error if the file
/// already exists.
///
pub fn safe_write_all(path: String, contents: String) -> Result(Nil, String) {
  use _ <- try(create_directory_all(filepath.directory_name(path)))
  use _ <- try(
    simplifile.create_file(path)
    |> result.map_error(fn(error) {
      case error {
        simplifile.Eexist ->
          file_error("create this file since it already exists", path)
        _ -> file_error("create this file", path)
      }
    }),
  )
  simplifile.write(path, contents)
  |> result.replace_error(file_error("write to this file", path))
}

/// Create a directory, creating directories as needed.
///
pub fn create_directory_all(path: String) -> Result(Nil, String) {
  simplifile.create_directory_all(path)
  |> result.replace_error(file_error("create this directory", path))
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
  use _ <- try(create_directory_all(filepath.directory_name(to)))
  simplifile.copy_file(from, to)
  |> result.replace_error(file_error("copy this file", from))
}

/// List files in a directory.
///
pub fn get_files(dir: String) -> Result(List(String), String) {
  simplifile.get_files(dir)
  |> result.replace_error(file_error("read this directory", dir))
}

/// Check if a directory exists.
///
pub fn directory_exists(dir: String) -> Bool {
  simplifile.verify_is_directory(dir)
  |> result.unwrap(False)
}

/// Delete a file or directory recursively.
///
pub fn delete(path: String) -> Result(Nil, String) {
  simplifile.delete(path)
  |> result.replace_error(file_error("delete this file or directory", path))
}

fn file_error(message, path) -> String {
  error.simple_error("I was unable to " <> message <> ": " <> path)
}
