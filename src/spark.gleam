import gleam/io
import gleam/result
import spark/compile
import spark/error
import spark/lex
import spark/parse

pub fn main() {
  let source =
    "
    import Spark/IO

    external \"let $id = 0;\"

    def pub fresh_id =
      external \"return $id++\"

    def pub map\\over, fn =
      case over
      | [] as list = list
      | [x : xs] = fn(x) : map(xs, fn)

    const squares = map([1, 2, 3], \\x -> x * x)

    const foo =
      \\sum <- add_with_cb(5, 6)
      sum * (2 + 3 * external \"return 5\")

    const bar =
      [1, 2, 3]
      |> baz
      |> map(\\x -> x * x)

    def pub main =
      IO.println(\"Hello, world!\") ;

      \"Isn't this language nice?\"
      |> IO.println ;

      2 * 3

    const dsf =
      case { x: 3, y: 5, z: 5 }
      | { x, y, z } = x + y + z
      | { x, y } = x + y

    def println\\text =
      @IO {
        perform: \\ -> external \"
          console.log(text);
          return $.nil;
        \"
      }

    def then\\@IO { perform }, f =
      @IO {
        perform: \\ -> f(perform()).perform()
      }

    def test =
      \\_ <- println(\"Hello!\") |> then
      println(\"Goodbye, now.\")

    # Atoms don't need a name! Unnamed atoms are basically tuples.
    const me = @(\"Joe\", 30)

    def pub first\\@(a, _) = a
    def pub second\\@(_, b) = b
    "

  let result = {
    use tokens <- result.try(lex.lex(source))
    use ast <- result.try(parse.parse(tokens))
    let compiled = compile.compile(ast)
    Ok(compiled)
  }

  case result {
    Ok(js) -> {
      io.println(js)
      Nil
    }
    Error(e) ->
      error.to_string(e, source, "file.spark")
      |> io.println_error
  }
}
