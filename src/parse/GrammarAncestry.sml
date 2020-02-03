structure GrammarAncestry :> GrammarAncestry =
struct

open HolKernel HOLsexp

fun ERR f s = HOL_ERR {origin_structure = "GrammarAncestry",
                       origin_function = f, message = s}
val tag = "GrammarAncestry"

val (write, read) =
    Theory.LoadableThyData.new {
      thydataty = tag, merge = op @,
      read = Lib.K (list_decode string_decode),
      terms = Lib.K [],
      pp = fn sl => "[" ^ String.concatWith ", " sl ^ "]",
      write = Lib.K (list_encode String)
    }

fun ancestry {thy} =
  case Theory.LoadableThyData.segment_data{thy=thy, thydataty=tag} of
      NONE => []
    | SOME t => case read t of
                    NONE => raise ERR "ancestry" "Badly encoded data"
                  | SOME sl => sl

fun set_ancestry sl =
  Theory.LoadableThyData.set_theory_data{thydataty = tag, data = write sl}


end
