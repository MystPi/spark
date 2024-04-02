import nibble/lexer

// ---- TYPES ------------------------------------------------------------------

pub type Error {
  SyntaxError(message: String, hint: String, location: lexer.Span)
}