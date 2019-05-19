(* ========================================================================= *)
(* FILE          : rlEnv.sml                                                 *)
(* DESCRIPTION   : Environnement for reinforcement learning                  *)
(* AUTHOR        : (c) Thibault Gauthier, University of Innsbruck            *)
(* DATE          : 2018                                                      *)
(* ========================================================================= *)

structure rlEnv :> rlEnv =
struct

open HolKernel Abbrev boolLib aiLib rlLib psMCTS mlTreeNeuralNetwork 
smlParallel

val ERR = mk_HOL_ERR "rlEnv"

type ('a,'b) gamespec =
  {
  movel : 'b list,
  string_of_move : 'b -> string,
  filter_sit : 'a psMCTS.sit -> (('b * real) list -> ('b * real) list),
  status_of : ('a psMCTS.sit -> psMCTS.status),
  apply_move : ('b -> 'a psMCTS.sit -> 'a psMCTS.sit),
  operl : (term * int) list,
  nntm_of_sit: 'a psMCTS.sit -> term,
  mk_targetl: int -> int -> 'a psMCTS.sit list,
  write_targetl: 'a psMCTS.sit list -> unit,
  read_targetl: unit -> 'a psMCTS.sit list 
  }

(* -------------------------------------------------------------------------
   Log
   ------------------------------------------------------------------------- *)

val logfile_glob = ref "rlEnv"
val eval_dir = HOLDIR ^ "/src/AI/reinforcement_learning/eval"
fun log_eval file s =
  let val path = eval_dir ^ "/" ^ file in
    mkDir_err eval_dir;
    append_endline path s
  end
fun summary s = (log_eval (!logfile_glob) s; print_endline s)

fun bts b = if b then "true" else "false"

(* -------------------------------------------------------------------------
   Hard-coded parameters
   ------------------------------------------------------------------------- *)

val ngen_glob = ref 20
val ntarget_compete = ref 400
val ntarget_explore = ref 400

val exwindow_glob = ref 40000
val uniqex_flag = ref false
val dim_glob = ref 8
val batchsize_glob = ref 64
val nepoch_glob = ref 100
val lr_glob = ref 0.1
val ncore_train_glob = ref 4

val nsim_glob = ref 1600
val decay_glob = ref 0.99
val ncore_mcts_glob = ref 8

val level_glob = ref 1

fun summary_param () =
  let
    val file  = "  file: " ^ (!logfile_glob)
    val para  = "parallel_dir: " ^ (!parallel_dir)
    val gen1  = "gen max: " ^ its (!ngen_glob)
    val gen2  = "target_compete: " ^ its (!ntarget_compete)
    val gen3  = "target_explore: " ^ its (!ntarget_explore)
    val gen4  = "starting level: " ^ its (!level_glob)
    val nn0   = "uniqex_flag: " ^ bts (!uniqex_flag)
    val nn1   = "example_window: " ^ its (!exwindow_glob)
    val nn2   = "nn dim: " ^ its (!dim_glob)
    val nn3   = "nn batchsize: " ^ its (!batchsize_glob)
    val nn4   = "nn epoch: " ^ its (!nepoch_glob)
    val nn6   = "nn lr: " ^ rts (!lr_glob)
    val nn5   = "nn ncore: " ^ its (!ncore_train_glob)
    val mcts2 = "mcts simulation: " ^ its (!nsim_glob)
    val mcts3 = "mcts decay: " ^ rts (!decay_glob)
    val mcts4 = "mcts ncore: " ^ its (!ncore_mcts_glob)
    val mcts5 = "mcts exploration coeff: " ^ rts (!psMCTS.exploration_coeff)
  in
    summary "Global parameters";
    summary (String.concatWith "\n  " 
     ([file,para] @ [gen1,gen2,gen3,gen4] @ [nn0,nn1,nn2,nn3,nn4,nn6,nn5] @ 
      [mcts2,mcts3,mcts4,mcts5])
     ^ "\n")
  end

(* -------------------------------------------------------------------------
   Additional communication files
   ------------------------------------------------------------------------- *)

fun dhtnn_file () = !parallel_dir ^ "/dhtnn"
fun widexl_file (wid,job) = wid_dir wid ^ "/exl" ^ its job
fun widwin_file (wid,job) = wid_dir wid ^ "/win" ^ its job

(* -------------------------------------------------------------------------
   Evaluation and policy
   ------------------------------------------------------------------------- *)

fun mk_fep_dhtnn startb gamespec dhtnn sit =
  let
    val movel = #movel gamespec
    val filter_sit = (#filter_sit gamespec) sit
    val {opdict,headeval,headpoli,dimin,dimout} = dhtnn
    val etnn = {opdict=opdict,headnn=headeval,dimin=dimin,dimout=1}
    val ptnn = {opdict=opdict,headnn=headpoli,dimin=dimin,dimout=dimout}
    val nntm = (#nntm_of_sit gamespec) sit
  in
    (*
    if startb 
    then (0.0, filter_sit (map (fn x => (x,1.0)) movel))
    else
    *)
    (only_hd (infer_tnn etnn nntm),
      filter_sit (combine (movel, infer_tnn ptnn nntm)))
  end

(* -------------------------------------------------------------------------
   Examples
   ------------------------------------------------------------------------- *)

val emptyallex = []

(* fun complete_pol movel mrl =
  let fun f move = assoc move mrl handle HOL_ERR _ => 0.0 in
    map f movel
  end
*)
fun add_rootex gamespec tree allex =
  let  
    val root = dfind [0] tree
    val sit  = #sit root
    val nntm = (#nntm_of_sit gamespec) sit
    val movel = #movel gamespec
  in
    case evalpoli_example tree of
      NONE    => allex
    | SOME (e,p) => (nntm,[e],(* complete_pol movel *) map snd p) :: allex
  end

(* -------------------------------------------------------------------------
   MCTS big steps. Ending the search when there is no move available.
   ------------------------------------------------------------------------- *)

val verbose_flag = ref false (* for demo/debugging *)

fun n_bigsteps_loop (n,nmax) gamespec mctsparam (allex,allroot) tree =
  if n >= nmax then (allex,allroot) else
  let
    val nntm_of_sit = #nntm_of_sit gamespec
    val sit = #sit (dfind [0] tree)
    val newtree = mcts mctsparam tree
    val root = dfind [0] newtree
    val filter_sit = (#filter_sit gamespec) sit
    val _ = if !verbose_flag then print_endline (tts (nntm_of_sit sit)) else ()
    val movel = #movel gamespec
  in
   (* if null (filter_sit (map_assoc (fn x => 0.0) movel))
      then (allex, root :: allroot) (* stop because no valid move *)
      else *)
   let val (dis,cido) = select_bigstep newtree [0] in
     case cido of
       NONE => (allex, root :: allroot)
     | SOME cid =>
        let
          val _ = if !verbose_flag 
                  then print_distrib (#string_of_move gamespec) dis
                  else ()
          val cuttree = cut_tree newtree cid
          val newallex = add_rootex gamespec newtree allex
        in
          n_bigsteps_loop (n+1,nmax) gamespec mctsparam
          (newallex, root :: allroot) cuttree
        end
    end
  end

val max_bigsteps = 100

fun n_bigsteps gamespec mctsparam target =
  let val tree = starttree_of mctsparam target in
    n_bigsteps_loop (0,max_bigsteps) gamespec mctsparam (emptyallex,[]) tree
  end

(* -------------------------------------------------------------------------
   Exploration functions
   ------------------------------------------------------------------------- *)

fun explore_test gamespec dhtnn target =
  let
    val (noise,bstart) = (false,false)
    val status_of = #status_of gamespec
    val mctsparam =
      (!nsim_glob, !decay_glob, noise,
       #status_of gamespec, #apply_move gamespec, 
       mk_fep_dhtnn bstart gamespec dhtnn)
  in
    verbose_flag := true;
    ignore (n_bigsteps gamespec mctsparam target);
    verbose_flag := false 
  end

fun bstatus_to_string b = if b then "win" else "lose"
fun string_to_bstatus s = assoc s [("win",true),("lose",false)]
  handle HOL_ERR _ => raise ERR "string_to_bstatus" ""

fun explore_extern gamespec (wid,job) flags dhtnn target =
  let
    val (noise,bstart) = flags
    val mctsparam =
      (!nsim_glob, !decay_glob, noise,
       #status_of gamespec, #apply_move gamespec, 
       mk_fep_dhtnn bstart gamespec dhtnn)
    val (exl,rootl) = n_bigsteps gamespec mctsparam target
    val endroot = hd rootl
    val bstatus = #status_of gamespec (#sit endroot) = Win
  in
    write_dhex (widexl_file (wid,job)) exl;
    writel_atomic (widwin_file (wid,job)) [bstatus_to_string bstatus];
    writel_atomic (widout_file wid) ["done"] 
  end

(* -------------------------------------------------------------------------
   Training
   ------------------------------------------------------------------------- *)

fun epex_stats epex =
  let  
    val d = count_dict (dempty Term.compare) (map #1 epex)
    val r = average_real (map (Real.fromInt o snd) (dlist d))
  in
    summary ("examples: " ^ its (length epex));
    summary ("average duplicates: " ^ rts r)
  end

fun random_dhtnn_gamespec gamespec =
  random_dhtnn (!dim_glob, length (#movel gamespec)) (#operl gamespec)

fun train_dhtnn gamespec epex =
  let
    val _ = epex_stats epex
    val schedule = [(!nepoch_glob, !lr_glob / Real.fromInt (!batchsize_glob))]
    val bsize = 
      if length epex < !batchsize_glob then 1 else !batchsize_glob
    val dhtnn = random_dhtnn_gamespec gamespec
  in
    train_dhtnn_schedule (!ncore_train_glob) dhtnn bsize epex schedule
  end

fun train_f gamespec allex =
  let val (dhtnn,t) = add_time (train_dhtnn gamespec) allex in
    summary ("Training time : " ^ rts t); dhtnn
  end

(* -------------------------------------------------------------------------
   External parallelization of competition/exploration calls
   ------------------------------------------------------------------------- *)

(* todo : print out targets *)
fun flags_to_string (b1,b2) = "(" ^ bts b1 ^ "," ^  bts b2 ^ ")"

fun codel_of_flags flags wid = 
    [
     "open rlGameCopy mlTreeNeuralNetwork smlParallel rlEnv;",
     "val _ = parallel_dir := " ^ quote (!parallel_dir) ^ ";",
     "val _ = nsim_glob := " ^ its (!nsim_glob) ^ ";",
     "val _ = decay_glob := " ^ rts (!decay_glob) ^ ";",
     "val _ = dim_glob := " ^ its (!dim_glob) ^ ";",
     "val dhtnn = read_dhtnn (dhtnn_file ())",
     "val l = #read_targetl gamespec ();",
     "val flags = " ^ flags_to_string flags ^ ";",  
     "fun f widjob target =",
     "  explore_extern gamespec widjob flags dhtnn target",
     "val _ = worker_start " ^ (its wid) ^ " (f,l);"
    ]

fun read_result_extern (wid,job) =
  let 
    val win = string_to_bstatus (hd (readl (widwin_file (wid,job))))
    val dhex = read_dhex (widexl_file (wid,job))
  in
    app remove_file [widwin_file (wid,job),widexl_file (wid,job)];
    (win,dhex)
  end

fun init_extern write_targetl targetl dhtnn = 
  (
  write_dhtnn (dhtnn_file ()) dhtnn;
  write_targetl targetl
  )

val attrib = [Thread.InterruptState Thread.InterruptAsynch, Thread.EnableBroadcastInterrupt true]

fun explore_parallel gamespec ncore flags dhtnn targetl =
  let
    val write_targetl = #write_targetl gamespec 
    fun boss_write () = init_extern write_targetl targetl dhtnn
    fun codel_of wid = codel_of_flags flags wid
    val boss_read = read_result_extern
  in
    parmap_queue_extern ncore codel_of (boss_write,boss_read) targetl
  end

(* -------------------------------------------------------------------------
   Competition: comparing n dhtnn
   ------------------------------------------------------------------------- *)

fun compete_one gamespec dhtnn targetl =
  let 
    val (l,t) = add_time 
      (explore_parallel gamespec (!ncore_mcts_glob) (false,false) dhtnn) targetl
    val nwin = length (filter (I o fst) l)
  in
    summary ("Competition time : " ^ rts t); nwin
  end

fun summary_compete (w_old,w_new) =
  let val s = if w_new > w_old then "Passed" else "Failed" in
    summary (s ^ ": " ^ its w_old ^ " " ^ its w_new)
  end

fun compete gamespec dhtnn_old dhtnn_new =
  let
    val targetl = #mk_targetl gamespec (!level_glob) (!ntarget_compete)
    val w_old = compete_one gamespec dhtnn_old targetl
    val w_new = compete_one gamespec dhtnn_new targetl
    val levelup = int_div (Int.max (w_new,w_old)) (length targetl) > 0.75
  in
    summary_compete (w_old,w_new);
    if levelup 
    then (incr level_glob; summary ("Level up: " ^ its (!level_glob))) 
    else ();
    if w_new > w_old then dhtnn_new else dhtnn_old
  end

(* -------------------------------------------------------------------------
   Exploration.
   ------------------------------------------------------------------------- *)

fun explore_f startb gamespec allex dhtnn =
  let
    val targetl = #mk_targetl gamespec (!level_glob) (!ntarget_explore)
    val (l,t) = add_time
      (explore_parallel gamespec 
       (!ncore_mcts_glob) (true,startb) dhtnn) targetl 
    val nwin = length (filter (I o fst) l)
    val exll = map snd l
    val _ = summary ("Exploration time: " ^ rts t)
    val _ = summary ("Exploration wins: " ^ its nwin)
    fun cmp ((a,_,_),(b,_,_)) = Term.compare (a,b)
    val exl1 = List.concat exll @ allex
    val exl2 = if !uniqex_flag then mk_sameorder_set cmp exl1 else exl1
  in
    first_n (!exwindow_glob) exl2
  end

(* -------------------------------------------------------------------------
   Reinforcement learning loop
   ------------------------------------------------------------------------- *)

fun rl_start gamespec =
  let
    val _ = remove_file (eval_dir ^ "/" ^ (!logfile_glob))
    val _ = summary_param ()
    val _ = summary "Generation 0"
    val dhtnn_random = random_dhtnn_gamespec gamespec
    val allex = explore_f true gamespec emptyallex dhtnn_random
    val dhtnn = train_f gamespec allex
  in
    (allex, dhtnn)
  end

fun rl_one n gamespec (allex,dhtnn) =
  let
    val _ = summary ("\nGeneration " ^ its n)
    val dhtnn_new = train_f gamespec allex
    val dhtnn_best = compete gamespec dhtnn dhtnn_new 
    val newallex = explore_f false gamespec allex dhtnn_new
  in
    (newallex,dhtnn_new)
  end

fun rl_loop (n,nmax) gamespec rldata =
  if n >= nmax then rldata else
    let val rldata_new = rl_one n gamespec rldata in
      rl_loop (n+1, nmax) gamespec rldata_new
    end

fun start_rl_loop gamespec =
  let val (allex,dhtnn) = rl_start gamespec in
    rl_loop (1,!ngen_glob) gamespec (allex,dhtnn)
  end

end (* struct *)

(*
load "rlEnv"; load "rlGameCopy";
open smlParallel rlEnv;

logfile_glob := "may1_dim6";
parallel_dir := HOLDIR ^ "/src/AI/sml_inspection/parallel_" ^ (!logfile_glob);

ncore_mcts_glob := 2;
ncore_train_glob := 2;
ngen_glob := 20;
ntarget_compete := 100;
ntarget_explore := 100;
exwindow_glob := 40000;
uniqex_flag := false;
dim_glob := 6;
batchsize_glob := 16;
nepoch_glob := 20;
lr_glob := 0.1;
nsim_glob := 1600;
decay_glob := 1.0;
level_glob := 10;
psMCTS.exploration_coeff := 2.0;


val (allex,dhtnn) = start_rl_loop rlGameCopy.gamespec;
mlTreeNeuralNetwork.write_dhtnn "save" dhtnn;

(* test *)
val dhtnn = random_dhtnn_gamespec rlGameCopy.gamespec;
val target = (true,(``0 + (0 + SUC 0 + 0 + SUC 0)``,``active_var:num``));
explore_test rlGameCopy.gamespec dhtnn target;

(* evaluate missmatch between PriorPoliicy and DerivedPolicy to see
   if there is still something to learn. *)

*)