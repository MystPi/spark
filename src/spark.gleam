import gleam/io
import spark/lexer
import spark/parser
import pprint

pub fn main() {
  let assert Ok(tokens) =
    lexer.lex("
      const math = 1 + 2 * 3 + 4 / 5 : 2 : 3
      const pub test = [1, 2, [3], 4]

      external \"import fs from 'node:fs';\"

      const foo = external \"blah blah\"

      def add\\a, b =
        a + b

      const test = blah(1, (), 2)")

  parser.parse(tokens)
  |> pprint.debug
  io.println("Hello from spark!")
}
