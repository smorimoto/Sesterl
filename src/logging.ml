
open MyUtil
open Syntax
open Errors


let warn_val_not_used (rng : Range.t) (x : identifier) =
  Format.printf "* [Warning] %a: variable '%s' is unused.\n"
    Range.pp rng
    x


let output_written (fpath : string) =
  Format.printf "  output written on '%s'.\n"
    fpath


let begin_to_parse (abspath : absolute_path) =
  Format.printf "  parsing '%s' ...\n"
    abspath


let begin_to_typecheck (abspath : absolute_path) =
  Format.printf "  type checking '%s' ...\n"
    abspath


let report_unsupported_feature (msg : string) =
  Format.printf "! [Unsupported] \"%s\"\n" msg


let report_system_error (msg : string) =
  Format.printf "! [Error] system error: %s\n" msg


let report_parser_error (rng : Range.t) =
  Format.printf "%a: syntax error\n" Range.pp rng


let report_lexer_error (e : lexer_error) : unit =
  Format.printf "! [Syntax error] ";
  match e with
  | UnidentifiedToken(rng, s) ->
      Format.printf "%a: unidentified token '%s'\n"
        Range.pp rng
        s

  | SeeEndOfFileInComment(rngL) ->
      Format.printf "%a: an unclosed comment begins here\n"
        Range.pp rngL

  | SeeEndOfFileInStringLiteral(rngL) ->
      Format.printf "%a: an unclosed string literal begins here\n"
        Range.pp rngL

  | SeeBreakInStringLiteral(rngL) ->
      Format.printf "%a: a string literal that contains a break begins here\n"
        Range.pp rngL

  | BlockClosedWithTooManyBackQuotes(rngR) ->
      Format.printf "%a: a string block ends with too many back quotes\n"
        Range.pp rngR

  | NotASingleCodePoint(rng) ->
      Format.printf "%a: not a single code point\n"
        Range.pp rng


let report_config_error (e : config_error) : unit =
  Format.printf "! [Build error] ";
  match e with
  | ConfigFileError(e) ->
      Format.printf "malformed config file; %a\n"
        YamlDecoder.pp_error e

  | CyclicFileDependencyFound(cycle) ->
      begin
        match cycle with
        | Loop(abspath) ->
            Format.printf "file '%s' is dependent on itself.\n"
              abspath

        | Cycle(abspaths) ->
            Format.printf "cyclic file dependency found among:\n";
            abspaths |> List2.to_list |> List.iter (fun abspath ->
              Format.printf "  - '%s'\n" abspath
            )
      end

  | MultipleModuleOfTheSameName(modnm, abspath1, abspath2) ->
      Format.printf "multiple module bound with the same name '%s':\n  - %s\n  - %s\n"
        modnm abspath1 abspath2

  | ModuleNotFound(rng, modnm) ->
      Format.printf "%a: module '%s' not found\n"
        Range.pp rng
        modnm

  | InvalidPackageName(s) ->
      Format.printf "invalid package name '%s'\n"
        s

  | CannotSpecifyDependency ->
      Format.printf "cannot specify dependency at standalone file\n"

  | MainModuleNotFound(pkgname, modnm) ->
      Format.printf "main module '%s' not found in package '%s'\n"
        modnm pkgname

  | UnrecognizableExtension(ext) ->
      Format.printf "unrecognizable extension '%s' for a source file\n"
        ext

  | ConfigFileNotFound(abspath) ->
      Format.printf "config file '%s' not found\n"
        abspath


let report_package_error (e : package_error) : unit =
  Format.printf "! [Build error] ";
  match e with
  | DuplicatedPackageName(pkgname, abspath1, abspath2) ->
      Format.printf "multiple package have the same name '%s':\n  - %s\n  - %s\n"
        pkgname abspath1 abspath2

  | PackageDirNotFound(absdir) ->
      Format.printf "package directory '%s' not found\n"
        absdir


let report_type_error (e : type_error) : unit =
  Format.printf "! [Type error] ";
  match e with
  | UnboundVariable(rng, x) ->
      Format.printf "%a:\n"
        Range.pp rng;
      Format.printf "  unbound variable '%s'\n"
        x

  | ContradictionError(ty1, ty2) ->
      let (rng1, _) = ty1 in
      Format.printf "%a:\n"
        Range.pp rng1;
      Format.printf "  this expression has type\n";
      Format.printf "    %a\n"
        TypeConv.pp_mono_type ty1;
      Format.printf "  but is expected of type\n";
      Format.printf "    %a\n"
        TypeConv.pp_mono_type ty2

  | InclusionError(fid, ty1, ty2) ->
      let (rng1, _) = ty1 in
      Format.printf "%a:"
        Range.pp rng1;
      Format.printf "  this expression has type\n";
      Format.printf "    %a\n"
        TypeConv.pp_mono_type ty1;
      Format.printf "  and type\n";
      Format.printf "    %a\n"
        TypeConv.pp_mono_type ty2;
      Format.printf "at the same time, but these types are inconsistent as to the occurrence of type variable %a\n"
        FreeID.pp fid

  | InclusionRowError(frid, ty1, ty2) ->
      let (rng1, _) = ty1 in
      Format.printf "%a:\n"
        Range.pp rng1;
      Format.printf "  this expression has type\n";
      Format.printf "    %a\n"
        TypeConv.pp_mono_type ty1;
      Format.printf "  and type\n";
      Format.printf "    %a\n"
        TypeConv.pp_mono_type ty2;
      Format.printf "at the same time, but these types are inconsistent as to the occurrence of row variable %a\n"
        FreeRowID.pp frid

  | BoundMoreThanOnceInPattern(rng, x) ->
      Format.printf "%a:\n"
        Range.pp rng;
      Format.printf "  this pattern binds '%s' more than once.\n"
        x

  | UnboundTypeParameter(rng, tyvar) ->
      Format.printf "%a:\n"
        Range.pp rng;
      Format.printf "  unbound type variable '$%s'\n"
        tyvar

  | UnboundRowParameter(rng, rowvar) ->
      Format.printf "%a:\n"
        Range.pp rng;
      Format.printf "  unbound row variable '?$%s'\n"
        rowvar

  | UndefinedConstructor(rng, ctor) ->
      Format.printf "%a:\n"
        Range.pp rng;
      Format.printf "  undefined constructor '%s'\n"
        ctor

  | InvalidNumberOfConstructorArguments(rng, ctor, len_expected, len_actual) ->
      Format.printf "%a:\n"
        Range.pp rng;
      Format.printf "  constructor '%s' expects %d argument(s), but is here applied to %d argument(s)\n"
        ctor
        len_expected
        len_actual

  | UndefinedTypeName(rng, tynm) ->
      Format.printf "%a:\n"
        Range.pp rng;
      Format.printf "  undefined type or type constructor '%s'\n"
        tynm

  | UndefinedKindName(rng, kdnm) ->
      Format.printf "%a:\n"
        Range.pp rng;
      Format.printf "  undefined kind '%s'\n"
        kdnm

  | InvalidNumberOfTypeArguments(rng, tynm, len_expected, len_actual) ->
      Format.printf "%a:\n"
        Range.pp rng;
      Format.printf "  type constructor '%s' expects %d argument(s), but is here applied to %d argument(s)\n"
        tynm
        len_expected
        len_actual

  | KindContradiction(rng, tynm, pkd_expected, pkd_actual) ->
      let (_, _, skd_actual) = TypeConv.show_poly_kind pkd_actual in
      let (_, _, skd_expected) = TypeConv.show_poly_kind pkd_expected in
      Format.printf "%a:\n"
        Range.pp rng;
      Format.printf "  type constructor '%s' has kind %s, but is expected of kind %s\n"
        tynm
        skd_actual
        skd_expected

  | TypeParameterBoundMoreThanOnce(rng, tyvar) ->
      Format.printf "%a:\n"
        Range.pp rng;
      Format.printf "  type variable '%s' is bound more than once\n"
        tyvar

  | RowParameterBoundMoreThanOnce(rng, rowvar) ->
      Format.printf "%a:\n"
        Range.pp rng;
      Format.printf "  row variable '%s' is bound more than once\n"
        rowvar

  | InvalidByte(rng) ->
      Format.printf "%a:\n"
        Range.pp rng;
      Format.printf "  invalid byte\n"

  | CyclicSynonymTypeDefinition(cycle) ->
      let tyidents =
        match cycle with
        | Loop((_, tyident)) -> [ tyident ]
        | Cycle(vs)          -> vs |> List2.to_list |> List.map (fun (_, tyident) -> tyident)
      in
      Format.printf "cyclic type definitions:\n";
      tyidents |> List.iter (fun (rng, tynm) ->
        Format.printf "  - %s (%a)\n" tynm Range.pp rng
      )

  | CyclicTypeParameter(rng, cycle, pty) ->
      let bbids =
        match cycle with
        | Loop(bbid)   -> [ bbid ]
        | Cycle(bbids) -> bbids |> List2.to_list
      in
      Format.printf "%a:\n"
        Range.pp rng;
      Format.printf "  cyclic type variables:\n";
      bbids |> List.iter (fun bbid ->
        Format.printf "  - %a\n"
          BoundBothID.pp bbid
      );
      Format.printf "  in:\n";
      let (sbids, sbrids, smain) = TypeConv.show_poly_type pty in
      let ss = List.append sbids sbrids in
      let sb = if List.length ss = 0 then "" else "<" ^ String.concat ", " ss ^ ">" in
      Format.printf "  %s %s\n" sb smain

  | UnboundModuleName(rng, modnm) ->
      Format.printf "%a:\n"
        Range.pp rng;
      Format.printf "  unbound module name '%s'\n"
        modnm

  | NotOfStructureType(rng, modsig) ->
      Format.printf "%a:\n"
        Range.pp rng;
      Format.printf "  this module expression is not of a structure signature\n"

  | NotOfFunctorType(rng, modsig) ->
      Format.printf "%a:\n"
        Range.pp rng;
      Format.printf "  this module expression is not of a functor signature\n"

  | NotAStructureSignature(rng, modsig) ->
      Format.printf "%a:\n"
        Range.pp rng;
      Format.printf "  this signature expression is not a structure\n"

  | NotAFunctorSignature(rng, modsig) ->
      Format.printf "%a:\n"
        Range.pp rng;
      Format.printf "  this signature expression is not a functor\n"

  | UnboundSignatureName(rng, signm) ->
      Format.printf "%a:\n"
        Range.pp rng;
      Format.printf "  unbound signature name '%s'\n"
        signm

  | CannotRestrictTransparentType(rng, _) ->
      Format.printf "%a:\n"
        Range.pp rng;
      Format.printf "  the specified type is already transparent\n"

  | PolymorphicContradiction(rng, x, pty1, pty2) ->
      Format.printf "%a:\n"
        Range.pp rng;
      Format.printf "  not a subtype; as to value '%s', type %a cannot be encapsulated by type %a\n"
        x
        TypeConv.pp_poly_type pty1
        TypeConv.pp_poly_type pty2

  | PolymorphicInclusion(rng, fid, pty1, pty2) ->
      Format.printf "%a:\n"
        Range.pp rng;
      Format.printf "  type %a is inconsistent with type %a as to type variable %a\n"
        TypeConv.pp_poly_type pty1
        TypeConv.pp_poly_type pty2
        FreeID.pp fid

  | MissingRequiredValName(rng, x, pty) ->
      Format.printf "%a:\n"
        Range.pp rng;
      Format.printf "  missing required value '%s' of type %a\n"
        x
        TypeConv.pp_poly_type pty

  | MissingRequiredTypeName(rng, tynm, (_, pkd)) ->
      Format.printf "%a:\n"
        Range.pp rng;
      Format.printf "  missing required type name '%s' of arity %d\n"
        tynm
        (TypeConv.arity_of_kind pkd)

  | MissingRequiredModuleName(rng, modnm, _modsign) ->
      Format.printf "%a:\n"
        Range.pp rng;
      Format.printf "  missing required module name '%s'\n"
        modnm

  | MissingRequiredSignatureName(rng, signm, _absmodsig) ->
      Format.printf "%a:\n"
        Range.pp rng;
      Format.printf "  missing required module name '%s'\n"
        signm

  | NotASubtype(rng, modsig1, modsig2) ->
      Format.printf "%a:\n"
        Range.pp rng;
      Format.printf "  not a subtype (TODO: detailed explanation)\n"

  | NotASubtypeTypeOpacity(rng, tynm, _tyopac1, _tyopac2) ->
      Format.printf "%a:\n"
        Range.pp rng;
      Format.printf "  not a subtype; type '%s' cannot be encapsulated (TODO: detailed explanation)\n"
        tynm

  | NotASubtypeVariant(rng, _vid1, _vid2, ctor) ->
      Format.printf "%a:\n"
        Range.pp rng;
      Format.printf "  not a subtype about constructor '%s' (TODO: detailed explanation)\n"
        ctor

  | NotASubtypeSynonym(rng, sid1, sid2) ->
      let (bids1, pty1) = TypeDefinitionStore.find_synonym_type sid1 in
      let (bids2, pty2) = TypeDefinitionStore.find_synonym_type sid2 in
      Format.printf "%a:\n"
        Range.pp rng;
      Format.printf "  type %a is not a subtype of %a;\n  - %a<%a> = %a\n  - %a<%a> = %a\n"
        TypeID.Synonym.pp sid1
        TypeID.Synonym.pp sid2
        TypeID.Synonym.pp sid1
        (Format.pp_print_list BoundID.pp) bids1
        TypeConv.pp_poly_type pty1
        TypeID.Synonym.pp sid2
        (Format.pp_print_list BoundID.pp) bids2
        TypeConv.pp_poly_type pty2

  | OpaqueIDExtrudesScopeViaValue(rng, _pty) ->
      Format.printf "%a:\n"
        Range.pp rng;
      Format.printf "  an abstract type extrudes its scope via value (TODO: detailed explanation)\n"

  | OpaqueIDExtrudesScopeViaType(rng, _tyopac) ->
      Format.printf "%a:\n"
        Range.pp rng;
      Format.printf "  an abstract type extrudes its scope via type (TODO: detailed explanation)\n"

  | OpaqueIDExtrudesScopeViaSignature(rng, _absmodsig) ->
      Format.printf "%a:\n"
        Range.pp rng;
      Format.printf "  an abstract type extrudes its scope via signature (TODO: detailed explanation)\n"

  | SupportOnlyFirstOrderFunctor(rng) ->
      Format.printf "%a:\n"
        Range.pp rng;
      Format.printf "  only first-order functors are supported\n"

  | RootModuleMustBeStructure(rng) ->
      Format.printf "%a:\n"
        Range.pp rng;
      Format.printf "  root modules must be structures\n"

  | InvalidIdentifier(rng, s) ->
      Format.printf "%a:\n"
        Range.pp rng;
      Format.printf "  invalid identifier '%s'\n"
        s

  | ConflictInSignature(rng, x) ->
      Format.printf "%a:\n"
        Range.pp rng;
      Format.printf "  '%s' is already defined in the signature\n"
        x

  | DuplicatedLabel(rng, label) ->
      Format.printf "%a:\n"
        Range.pp rng;
      Format.printf "  label '%s' is used more than once in a binding\n"
        label

  | BadArityOfOrderedArguments(info) ->
      Format.printf "%a:\n"
        Range.pp info.range;
      Format.printf "  the function expects %d ordered argument(s), but is applied to %d ordered argument(s) here\n"
        info.expected
        info.got

  | MissingMandatoryLabel(info) ->
      Format.printf "%a:\n"
        Range.pp info.range;
      Format.printf "  missing mandatory label '-%s' with an argument of type\n"
        info.label;
      Format.printf "    %a\n"
        TypeConv.pp_mono_type info.typ

  | UnexpectedMandatoryLabel(info) ->
      Format.printf "%a:\n"
        Range.pp info.range;
      Format.printf "  unexpected mandatory label '-%s'\n"
        info.label

  | UnexpectedOptionalLabel(info) ->
      Format.printf "%a:\n"
        Range.pp info.range;
      Format.printf "  unexpected optional label '?%s'\n"
        info.label

  | NullaryFormatString(rng) ->
      Format.printf "%a:\n"
        Range.pp rng;
      Format.printf "  nullary format string\n"

  | CannotFreezeNonGlobalName(rng, x) ->
      Format.printf "%a:\n"
        Range.pp rng;
      Format.printf "  cannot freeze non-top-level identifier '%s'\n"
        x
