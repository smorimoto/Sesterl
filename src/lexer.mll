{
  open Syntax
  open Parser


  let raise_error e =
    raise (LexerError(e))
}

let space = [' ' '\t']
let break = ['\n' '\r']
let nzdigit = ['1'-'9']
let digit = (nzdigit | "0")
let hex   = (digit | ['A'-'F'])
let capital = ['A'-'Z']
let small = ['a'-'z']
let latin = (small | capital)
let identifier = (small (digit | latin | "_")*)
let constructor = (capital (digit | latin | "_")*)
let nssymbol = ['&' '|' '=' '/' '+' '-']

rule token = parse
  | space { token lexbuf }
  | break { Lexing.new_line lexbuf; token lexbuf }
  | identifier {
        let s = Lexing.lexeme lexbuf in
        let pos = Range.from_lexbuf lexbuf in
          match s with
          | "let"       -> LET(pos)
          | "letrec"    -> LETREC(pos)
          | "andrec"    -> ANDREC(pos)
          | "in"        -> IN(pos)
          | "fun"       -> LAMBDA(pos)
          | "if"        -> IF(pos)
          | "then"      -> THEN(pos)
          | "else"      -> ELSE(pos)
          | "true"      -> TRUE(pos)
          | "false"     -> FALSE(pos)
          | "do"        -> DO(pos)
          | "receive"   -> RECEIVE(pos)
          | "when"      -> WHEN(pos)
          | "end"       -> END(pos)
          | "case"      -> CASE(pos)
          | "of"        -> OF(pos)
          | "val"       -> VAL(pos)
          | "type"      -> TYPE(pos)
          | "module"    -> MODULE(pos)
          | "struct"    -> STRUCT(pos)
          | "signature" -> SIGNATURE(pos)
          | "sig"       -> SIG(pos)
          | "external"  -> EXTERNAL(pos)
          | "include"   -> INCLUDE(pos)
          | _           -> IDENT(pos, s)
      }
  | ("$" (identifier as s)) {
        let pos = Range.from_lexbuf lexbuf in
        TYPARAM(pos, s)
      }
  | constructor {
        let s = Lexing.lexeme lexbuf in
        let pos = Range.from_lexbuf lexbuf in
        CTOR(pos, s)
      }
  | ("." (constructor as s)) {
        let pos = Range.from_lexbuf lexbuf in
        DOTCTOR(pos, s)
      }
  | ("." (identifier as s)) {
        let pos = Range.from_lexbuf lexbuf in
        DOTIDENT(pos, s)
      }
  | ("0" | nzdigit (digit*) | ("0x" | "0X") hex+) {
        let s = Lexing.lexeme lexbuf in
        let rng = Range.from_lexbuf lexbuf in
          INT(rng, int_of_string s)
      }
  | "_"  { UNDERSCORE(Range.from_lexbuf lexbuf) }
  | ","  { COMMA(Range.from_lexbuf lexbuf) }
  | "("  { LPAREN(Range.from_lexbuf lexbuf) }
  | ")"  { RPAREN(Range.from_lexbuf lexbuf) }
  | "["  { LSQUARE(Range.from_lexbuf lexbuf) }
  | "]"  { RSQUARE(Range.from_lexbuf lexbuf) }

  | "::" { CONS(Range.from_lexbuf lexbuf) }
  | ":"  { COLON(Range.from_lexbuf lexbuf) }
  | ":>" { COERCE(Range.from_lexbuf lexbuf) }

  | ("&" (nssymbol*)) { BINOP_AMP(Range.from_lexbuf lexbuf, Lexing.lexeme lexbuf) }

  | "|"               { BAR(Range.from_lexbuf lexbuf) }
  | ("|" (nssymbol+)) { BINOP_BAR(Range.from_lexbuf lexbuf, Lexing.lexeme lexbuf) }

  | "="               { DEFEQ(Range.from_lexbuf lexbuf) }
  | ("=" (nssymbol+)) { BINOP_EQ(Range.from_lexbuf lexbuf, Lexing.lexeme lexbuf) }

  | "<-"                   { REVARROW(Range.from_lexbuf lexbuf) }
  | "<<"                   { LTLT(Range.from_lexbuf lexbuf) }
  | "<"                    { LT_EXACT(Range.from_lexbuf lexbuf) }
  | ("<" (nssymbol+))      { BINOP_LT(Range.from_lexbuf lexbuf, Lexing.lexeme lexbuf) }

  | (">" space)            { GT_SPACES(Range.from_lexbuf lexbuf) }
  | (">" break)            { Lexing.new_line lexbuf; GT_SPACES(Range.from_lexbuf lexbuf) }
  | ">"                    { GT_NOSPACE(Range.from_lexbuf lexbuf) }
  | (">" (nssymbol+))      { BINOP_GT(Range.from_lexbuf lexbuf, Lexing.lexeme lexbuf) }

  | ("*" (nssymbol*)) { BINOP_TIMES(Range.from_lexbuf lexbuf, Lexing.lexeme lexbuf) }

  | "/*"              { comment (Range.from_lexbuf lexbuf) lexbuf; token lexbuf }
  | ("/" (nssymbol*)) { BINOP_DIVIDES(Range.from_lexbuf lexbuf, Lexing.lexeme lexbuf) }

  | ("+" (nssymbol*)) { BINOP_PLUS(Range.from_lexbuf lexbuf, Lexing.lexeme lexbuf) }

  | "->"              { ARROW(Range.from_lexbuf lexbuf) }
  | ("-" (nssymbol*)) { BINOP_MINUS(Range.from_lexbuf lexbuf, Lexing.lexeme lexbuf) }

  | "\"" {
      let posL = Range.from_lexbuf lexbuf in
      let strbuf = Buffer.create 128 in
      string posL strbuf lexbuf
    }

  | ("`" +) {
      let posL = Range.from_lexbuf lexbuf in
      let num_start = String.length (Lexing.lexeme lexbuf) in
      let strbuf = Buffer.create 128 in
      string_block num_start posL strbuf lexbuf
    }

  | eof  { EOI }
  | _ as c { raise_error (UnidentifiedToken(Range.from_lexbuf lexbuf, String.make 1 c)) }

and string posL strbuf = parse
  | "\\\"" { Buffer.add_char strbuf '"'; string posL strbuf lexbuf }
  | break  { raise_error (SeeBreakInStringLiteral(posL)) }
  | "\""   { let posR = Range.from_lexbuf lexbuf in STRING(Range.unite posL posR, Buffer.contents strbuf) }
  | eof    { raise_error (SeeEndOfFileInStringLiteral(posL)) }
  | _ as c { Buffer.add_char strbuf c; string posL strbuf lexbuf }

and string_block num_start posL strbuf = parse
  | ("`" +) {
      let posR = Range.from_lexbuf lexbuf in
      let s = Lexing.lexeme lexbuf in
      let num_end = String.length s in
      if num_end > num_start then
        raise_error (BlockClosedWithTooManyBackQuotes(posR))
      else if num_end = num_start then
        STRING_BLOCK(Range.unite posL posR, Buffer.contents strbuf)
      else begin
        Buffer.add_string strbuf s;
        string_block num_start posL strbuf lexbuf
      end
    }
  | break {
      let s = Lexing.lexeme lexbuf in
      Lexing.new_line lexbuf;
      Buffer.add_string strbuf s;
      string_block num_start posL strbuf lexbuf
    }
  | eof    { raise_error (SeeEndOfFileInStringLiteral(posL)) }
  | _ as c { Buffer.add_char strbuf c; string_block num_start posL strbuf lexbuf }

and comment rng = parse
  | "/*"  { comment (Range.from_lexbuf lexbuf) lexbuf; comment rng lexbuf }
  | "*/"  { () }
  | break { Lexing.new_line lexbuf; comment rng lexbuf }
  | eof   { raise_error (SeeEndOfFileInComment(rng)) }
  | _     { comment rng lexbuf }
