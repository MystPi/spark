The following is the current grammar specification of Spark. Since it's a specification, the implementation may not be completely up to speed with it.

> todo: atoms, atom patterns, of operator, named patterns, module imports, dot notation for modules, backpassing

```ebnf
(* Module *)

module = declaration* -> Module ;

(* Declarations *)

declaration
  = function -> Function
  | constant -> Const
  | external -> TopLevelExternal
  ;

function = "def" ["pub"] IDENT "\\" [comma_sep<IDENT>] "=" expression ;

constant = "const" ["pub"] IDENT "=" expression ;

(* Expressions *)

expression
  = ops
  | lambda  -> Lambda
  | let     -> Let
  | case    -> Case
  ;

ops
  = nibble.pratt<
    one_of = call ;
    and_then
      = ?prefix 9?      ("-" | "!")
      | ?infix_right 8? "^"
      | ?infix_left 7?  ("*" | "/")
      | ?infix_left 6?  ("+" | "-")
      | ?infix_left 5?  ("<" | ">" | "<=" | ">=")
      | ?infix_left 4?  ("==" | "!=")
      | ?infix_left 3?  "and"
      | ?infix_left 2?  "or"
      | ?infix_right 1? ":"
      | ?infix_left 0?  ";"
      ;
  >
  ;

(* calls have the highest precedence but are not in the pratt parser since they aren't really operators *)
call = primary {"(" [comma_sep<expression>] ")"} ;

primary
  =
  | NUMBER              -> Number
  | STRING              -> String
  | IDENT               -> Variable
  | list                -> List
  | external            -> External
  | "(" expression ")"
  ;

list = "[" [comma_sep<expression>]  "]" ;

external = "external" STRING ;

lambda = "\\" comma_sep<IDENT> "->" expression ;

let = "let" Ident "=" expression "in" expression ;

case = "case" expression ("|" pattern "=" expression)+ ;

(* Patterns *)

pattern
  = list_pattern  -> ListPattern
  | "_"           -> IgnorePattern
  | IDENT         -> VariablePattern
  | NUMBER        -> NumberPattern
  | STRING        -> StringPattern
  ;

list_pattern
  = "[" [comma_sep<pattern>] "]"
  | "[" comma_sep<pattern> [":" IDENT] "]"
  ;

(* Helpers *)

comma_sep<rule> = rule {"," rule} ;
```
