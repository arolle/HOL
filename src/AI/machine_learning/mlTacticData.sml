(* ========================================================================= *)
(* FILE          : mlTacticData.sml                                          *)
(* DESCRIPTION   : Tactic calls from TacticToe recording                     *)
(* AUTHOR        : (c) Thibault Gauthier, University of Innsbruck            *)
(* DATE          : 2018                                                      *)
(* ========================================================================= *)

structure mlTacticData :> mlTacticData =
struct

open HolKernel boolLib Abbrev aiLib smlLexer mlFeature

val ERR = mk_HOL_ERR "mlTacticData"

(* -------------------------------------------------------------------------
   Tactictoe database data type
   ------------------------------------------------------------------------- *)

type stac = string

type call = {stac : stac, ogl: int list, loc: string * int * int, fea : fea}

fun call_compare (c1,c2) =
  cpl_compare String.compare fea_compare
    ((#stac c1,#fea c1),(#stac c2,#fea c2))

type tacdata =
  {
  calls : call list,
  taccov : (stac, int) Redblackmap.dict,
  symfreq : (int, int) Redblackmap.dict
  }

val empty_tacdata : tacdata =
  {
  calls = [],
  taccov = dempty String.compare,
  symfreq = dempty Int.compare
  }

(* -------------------------------------------------------------------------
   Exporting tactic data
   ------------------------------------------------------------------------- *)

fun loc_to_string (s,i1,i2) = 
  String.concatWith " " [s, its i1, its i2]

fun ilts il = String.concatWith " " (map its il)

fun call_to_string {stac,ogl,loc,fea} =
  [stac, ilts ogl, loc_to_string loc, ilts fea]

fun export_calls file calls =
  let
    val _ = debug ("export_calls: " ^ its (length calls) ^ " calls")
    val calls1 = calls
    fun is_local stac = mem "tttRecord.local_tag" (partial_sml_lexer stac)
    fun test call = not (is_local (#stac call))
    val calls2 = filter test calls1
    val calls3 = mk_sameorder_set call_compare (rev calls2)
    val _ = debug ("export_calls: " ^ its (length calls3) ^ " filtered calls")
  in
    writel file (List.concat (map call_to_string calls3))
  end

fun export_tacdata thy file tacdata =
  let 
    fun test (x,_,_) = (x = thy)
    val calls = filter (test o #loc) (#calls tacdata)
  in
    print_endline ("Exporting tactic data to: " ^ file);
    export_calls file calls
  end

(* -------------------------------------------------------------------------
   Importing tactic data
   ------------------------------------------------------------------------- *)

fun loc_from_string s =
  let val (a,b,c) = triple_of_list (String.tokens Char.isSpace s) in
    (a, string_to_int b, string_to_int c)
  end

fun string_to_il s = map string_to_int (String.tokens Char.isSpace s)

fun call_from_string (s1,s2,s3,s4) =
  {
  stac = s1,
  ogl = string_to_il s2,
  loc = loc_from_string s3,
  fea = string_to_il s4
  }

fun import_calls file =
  let val l = mk_batch_full 4 (readl file) in
    map (call_from_string o quadruple_of_list) l
  end

fun init_taccov calls =
  count_dict (dempty String.compare) (map #stac calls)

fun init_symfreq calls =
  count_dict (dempty Int.compare) (List.concat (map #fea calls))

fun init_tacdata calls =
  {
  calls = calls,
  taccov = init_taccov calls,
  symfreq = init_symfreq calls
  }

fun import_tacdata filel =
  let val calls = List.concat (map import_calls filel) in
    init_tacdata calls
  end

(* -------------------------------------------------------------------------
   Tactictoe database management
   ------------------------------------------------------------------------- *)

val ttt_tacdata_dir = HOLDIR ^ "/src/tactictoe/ttt_tacdata"

fun exists_tacdata_thy thy =
  let val file = ttt_tacdata_dir ^ "/" ^ thy in
    exists_file file andalso (not o null o readl) file
  end

fun create_tacdata () =
  let
    fun test file = exists_file file andalso (not o null o readl) file
    val thyl = ancestry (current_theory ())
    fun f x = ttt_tacdata_dir ^ "/" ^ x
    val filel = filter test (map f thyl)
    val thyl1 = map OS.Path.file filel
    val thyl2 = list_diff thyl thyl1
    val thyl3 = filter (fn x => not (mem x ["bool","min"])) thyl2
    val _ = if null thyl3 then () else
      (
      print_endline ("Missing tactic data: " ^  String.concatWith " " thyl3);
      print_endline "Run tttUnfold.ttt_record ()"
      )
    val tacdata = import_tacdata filel
  in
    print_endline ("Loading " ^ its (length (#calls tacdata)) ^
      " tactic calls");
    tacdata
  end

fun ttt_update_tacdata (call,{calls,taccov,symfreq}) =
  {
  calls = call :: calls,
  taccov = count_dict taccov [#stac call],
  symfreq = count_dict symfreq (#fea call)
  }

fun ttt_export_tacdata thy tacdata =
  let
    val _ = mkDir_err ttt_tacdata_dir
    val file = ttt_tacdata_dir ^ "/" ^ thy
  in
    export_tacdata thy file tacdata
  end


end (* struct *)
