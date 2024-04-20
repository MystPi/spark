The following is the current grammar specification of Spark. Since it's a specification, the implementation may not be completely up to speed with it.

```ebnf
(* Module *)

module = {import} {declaration} -> Module ;

import = "import" MODULE {"/" MODULE} ["as" MODULE] ;

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
  = operator
  | lambda    -> Lambda
  | backpass  -> Call (* backpassing *)
  | let       -> Let
  | case      -> Case
  ;

operator = call ?pratt ...? ; (* see operator fn in parse.gleam *)

(* calls have the highest precedence but are not in the pratt parser since they aren't really operators *)
call = primary {"(" [comma_sep<expression>] ")" | "." IDENT} ;

primary
  =
  | NUMBER              -> Number
  | STRING              -> String
  | IDENT               -> Variable
  | atom                -> Atom
  | MODULE "." IDENT    -> ModuleAccess
  | list                -> List
  | record              -> Record
  | external            -> External
  | "(" expression ")"
  ;

atom
  = ATOM
  | ATOM "(" [comma_sep<expression>] ")"
  | ATOM record
  ;

list = "[" [comma_sep<expression>]  "]" ;

record = "{" (".." expression "," comma_sep<record_field> | [comma_sep<record_fields>]) "}" ;
record_field = IDENT [":" expression] ;

external = "external" STRING ;

lambda = "\\" [comma_sep<IDENT>] "->" expression ;

backpass = "\\" [comma_sep<IDENT>] "<-" expression expression ;

let = "let" Ident "=" expression "in" expression ;

case = "case" expression ("|" pattern "=" expression)+ ;

(* Patterns *)

pattern
  = list_pattern        -> ListPattern
  | record_pattern      -> RecordPattern
  | "_"                 -> IgnorePattern
  | IDENT               -> VariablePattern
  | NUMBER              -> NumberPattern
  | STRING              -> StringPattern
  | atom_pattern        -> AtomPattern
  | pattern "as" IDENT  -> NamedPattern
  ;

list_pattern
  = "[" [comma_sep<pattern>] "]"
  | "[" comma_sep<pattern> [":" IDENT] "]"
  ;

record_pattern = "{" {comma_sep<IDENT [":" pattern]>} "}" ;

atom_pattern
  = ATOM
  | ATOM "(" [comma_sep<pattern>]  ")"
  | ATOM record_pattern
  ;

(* Helpers *)

comma_sep<rule> = rule {"," rule} ;
```
