
open HolKernel Parse boolLib bossLib finite_mapTheory;
open recfunsTheory;
open recursivefnsTheory;
open prnlistTheory;
open primrecfnsTheory;
open listTheory;
open arithmeticTheory;

val _ = new_theory "turing_machine";

val _ = intLib.deprecate_int()


(*
Li and Vitayi book
Turing mahines consist of
    Finite program
    Cells
    List of cells called tape
    Head, on one of the cells
    Tape has left and right
    Each cell is either 0,1 or Blank
    Finite program can be in a finite set of states Q
    Time, which is in the set {0,1,2,...}
    Head is said to 'scan' the cell it is currently over
    At time 0 the cell the head is over is called the start cell
    At time 0 every cell is Blank except
        a finite congituous sequence from the strat cell to the right, containing only 0' and 1's
    This sequence is called the input

    We have two operations
        We can write A = {0,1,B} in the cell being scanned
        The head can shift left or right
    There is one operation per time unit (step)
    After each step, the program takes on a state from Q

    The machine follows a set of rules
    The rules are of the form (p,s,a,q)
        p is the current state of the program
        s is the symbol under scan
        a is the next operation to be exectued, in S = {0,1,B,L,R}
        q is the next state of the program
    For any two rules, the first two elements must differ
    Not every possible rule (in particular, combination of first two rules) is in the set of rules
    This way the device can perform the 'no' operation, if this happens the device halts

    We define a turing machine as a mapping from a finite subset of QxA to SxQ

    We can associate a partial function to each Turing machine
        The input to the machine is presented as an n-tuple (x1,...xn) of binary strings
        in the form of a single binary string consisting of self-deliminating versions of xi's
        The integer repesented by the maxiaml binary string of which some bit is scanned
        or '0' if Blank is scanned by the time the machine halts is the output


    This all leads to this definition
    Each turing machine defines a partial function from n-tuples of integers into inetgers n>0
    Such a function is called 'partially recursive' or 'computable'
    If total then just recursive
                           *)


val _ = remove_termtok {term_name = "O", tok = "O"}

val _ = Datatype `action = Wr0 | Wr1 | L | R`;


val _ = Datatype `cell = Z | O `;

val _ = Datatype `state = <| n : num |>`;

val _ = Datatype `TM = <| state : state;
                  prog : ((state # cell) |->  (state # action));
                  tape_l : cell list;
                  tape_h : cell;
                  tape_r : cell list;
                  time : num
                       |>`;

val INITIAL_TM_def = Define `(INITIAL_TM tm [] = tm) ∧
  (INITIAL_TM tm (h::t) = tm with <|tape_l := [] ; tape_h := h ; tape_r := t|>)`;

val UPDATE_STATE_TIME = Define `UPDATE_STATE_TIME tm =
  if(((tm.state),(tm.tape_h)) IN FDOM tm.prog)
  then tm with
    <|time := SUC(tm.time);
    state := (FST (tm.prog ' ((tm.state) ,(tm.tape_h)) )) |>
    else (tm)
                               `;

val UPDATE_TAPE = Define `UPDATE_TAPE tm =
  if (((tm.state),(tm.tape_h)) IN FDOM tm.prog)
  then let tm' = tm with
    <|time := SUC(tm.time);
    state := (FST (tm.prog ' ((tm.state) ,(tm.tape_h)) )) |> in
      case (SND (tm.prog ' ((tm.state) ,(tm.tape_h)) )) of
        Wr0 => tm' with tape_h := Z
      | Wr1 => tm' with tape_h := O
      | L   => if (tm.tape_l = [])
        then tm' with <| tape_l := [];
                        tape_h := Z ;
                        tape_r := tm.tape_h::tm.tape_r |>
        else tm' with <| tape_l := TL tm.tape_l;
           tape_h := HD tm.tape_l ;
           tape_r := tm.tape_h::tm.tape_r |>
       | R   => if (tm.tape_r = [])
         then tm' with <| tape_l := tm.tape_h::tm.tape_l;
           tape_h := Z ;
           tape_r := [] |>
         else tm' with <| tape_l := tm.tape_h::tm.tape_l;
           tape_h := HD tm.tape_r;
           tape_r := TL tm.tape_r |>
  else (tm)
                                  `;

val STEP = Define `STEP tm = UPDATE_TAPE tm `;

val STEPS = Define `STEPS n tm = FUNPOW STEP n tm`;

val RUN = Define `RUN t tm input = STEPS t (INITIAL_TM tm input)`;


val DECODE_def = tDefine "DECODE" `
(DECODE 0 = []) ∧
(DECODE n = if (ODD n)
            then [O] ++ (DECODE ((n-1) DIV 2))
            else [Z] ++ (DECODE (n DIV 2)))`
(WF_REL_TAC `$<` >> rw[] >> intLib.ARITH_TAC)


val ENCODE_def = Define `(ENCODE [] = 0) ∧
(ENCODE (h::t) = case h of
                     Z => 0 + (2 * (ENCODE t))
                   | O => 1 + (2 * (ENCODE t))
                   | _ => 0)`;


EVAL `` (DECODE (ENCODE [O;O;Z;O;Z;O;Z;O;O;O]) )``;

EVAL `` ENCODE (DECODE 99999999999)``;

EVAL ``ENCODE [O;Z;Z;Z;Z]``;

(* Change TO simpler def of DECODE*)

(* Lemmas for ENCODE/DECODE*)

val SUC_CANCEL_lem = Q.store_thm(
        "SUC_CANCEL_lem",
`! n m. (SUC n = SUC m) ==> (m = n)`,
Induct_on `n` >- fs[]
          >> Induct_on `m`
>- fs[]
>- fs[]
    );

val DIV_3_lem = Q.store_thm(
        "DIV_3_lem",
    `∀ n.(n DIV 3 = 0) ==> (n<3) `,
    Induct_on `n` >- fs[] >> strip_tac
              >> `SUC 0 DIV 3 = 0` by fs[]
              >> `SUC 1 DIV 3 = 0` by fs[]
              >> Cases_on `n`
              >- fs[]
              >> Cases_on `n'`
                >- fs[]
                >> Cases_on `n`
                  >- fs[]
                  >> `n'>= 0` by fs[]
                  >> `SUC (SUC (SUC (SUC n'))) >= 3` by fs[]
                  >> `~(SUC (SUC (SUC (SUC n'))) < 3)` by fs[]
                  >> fs[]
                  >> `SUC (SUC (SUC (SUC n'))) = n' + 4` by fs[]
                  >> `SUC (SUC (SUC n')) = n' + 3` by fs[]
                  >> `n' + 3 DIV 3 ≠ 0` by fs[]
                  >> `(n' + 4 DIV 3 = 0) <=> F` by fs[]
                  >> rw[]
                  >> `SUC (SUC (SUC (SUC n'))) DIV 3 <= n' + 4 DIV 3` by fs[]
                  >> `(SUC (SUC (SUC (SUC n')))) DIV 3 = (n' + 4) DIV 3` by prove_tac[]
                  >> `(n'+4) DIV 3 = 0` by fs[]
                  >> `n'+4 = (n'+4)` by fs[]
                  >> `n'>=0` by fs[]
                  >> `4 <= n'+4` by fs[]
                  >> `0<3` by fs[]
                  >> `4 DIV 3 = 1` by fs[]
                  >> `4 DIV 3 <= (n' +4) DIV 3` by metis_tac[DIV_LE_MONOTONE]
                  >> `1 <=0` by fs[]
                  >> fs[]
    );


val MOD_3_lem = Q.store_thm (
        "MOD_3_lem",
`∀ n. (n MOD 3 = 0) ∨ (n MOD 3 = 1) ∨ (n MOD 3 = 2)`,
Induct_on `n` >- fs[] >> rw[] >> `SUC n MOD 3 < 3` by fs[] >> `1 < SUC n MOD 3` by fs[]
          >> `2 <=  SUC n MOD 3` by fs[]
          >> `0<3` by fs[] >> `SUC n MOD 3 <= SUC n` by metis_tac[MOD_LESS_EQ]
          >> `SUC n MOD 3 < 2 + 1` by fs[]
          >> `SUC n MOD 3 <= 2` by metis_tac[LE_LT1]
          >> fs[]
    );


val MOD_DIV_3_lem = Q.store_thm(
        "MOD_DIV_3_lem",
`∀ n. ((n DIV 3 = 0) ∧ (n MOD 3 = 0)) ==> (n = 0)`,
Induct_on `n` >- fs[]
          >> rw[] >> `SUC n = n+1` by fs[] >> CCONTR_TAC >> fs[] >> rw[]
          >> `SUC n DIV 3 = SUC n MOD 3` by fs[]
          >> `SUC n < 3` by metis_tac[DIV_3_lem]
          >> `SUC n = 0` by fs[]
          >> fs[]
    );


(* Examples *)

EVAL ``LENGTH (TL [h])``;


EVAL ``2 MOD 3``;


(*
val ENCODE_DECODE_lem_Z = Q.store_thm(
    "ENCODE_DECODE_lem1[simp]",
    `!n. ENCODE_tern (2*(3**(LENGTH n)) + DECODE n) = Z::n`,
    strip_tac >> completeInduct_on `LENGTH n` >> strip_tac
    >> strip_tac >> Cases_on `LENGTH n` >- fs[] >> EVAL_TAC >>
    >> strip_tac >> strip_tac
    );
*)

val ENCODE_DECODE_thm = store_thm(
    "ENCODE_DECODE_thm",
    ``!n. ENCODE (DECODE n) = n``,
    completeInduct_on `n` >> Cases_on `n` >- EVAL_TAC >> rw[DECODE_def] >- (rw[ENCODE_def]
    >> `0<2` by fs[] >> `n' DIV 2 <= n'` by metis_tac[DIV_LESS_EQ]
    >> `n' < SUC n'` by fs[] >> `n' DIV 2 < SUC n'` by fs[]
    >> `ENCODE (DECODE (n' DIV 2)) = n' DIV 2` by fs[] >> rw[]
    >> `~ODD n'` by metis_tac[ODD]
    >> `EVEN n'` by metis_tac[EVEN_OR_ODD]
    >> `n' MOD 2 =0` by metis_tac[EVEN_MOD2]
    >> `2 * (n' DIV 2) = n'` by metis_tac[MULT_EQ_DIV]
    >> rw[])
    >> rw[ENCODE_def]
    >> `EVEN (SUC n')` by metis_tac[EVEN_OR_ODD]
    >> `(SUC n') MOD 2 =0` by metis_tac[EVEN_MOD2]
    >> `2 * ((SUC n') DIV 2) = SUC n'` by fs[MULT_EQ_DIV]
 );

val DECODE_EMPTY_lem = Q.store_thm (
        "DECODE_EMPTY_lem",
`∀ n. (DECODE n = []) ==> (n=0)`,
    Induct_on `n` >- EVAL_TAC >> fs[] >> rw[DECODE_def]  );

(*
Not a theorem

val DECODE_ENCODE_thm = store_thm(
    "DECODE_ENCODE_thm",
    `!l. DECODE (ENCODE l) = l`,
    completeInduct_on `ENCODE l` >> rpt  strip_tac >>  Cases_on `DECODE (ENCODE l)` >-
        (`DECODE 0 = []` by fs[DECODE_def]
      >> Cases_on `l` >- fs[] >> fs[] >> `ENCODE (h::t) = 0` by fs[DECODE_EMPTY_lem]
      >> rw[])
      >> rw[] >> Cases_on `h` >- ( rw[DECODE_def,ENCODE_def] )

    );
*)

EVAL ``7 DIV 3``;

val ENCODE_TM_TAPE_def = Define `ENCODE_TM_TAPE tm =
       if tm.tape_h = Z then
           ((ENCODE tm.tape_l) *,  (2 * (ENCODE tm.tape_r)))
       else
           ((ENCODE tm.tape_l) *, ( (2 * (ENCODE tm.tape_r)) + 1 ))`;

val DECODE_TM_TAPE_def = Define `DECODE_TM_TAPE n =
       if EVEN (nsnd n) then
           (DECODE (nfst n), Z , DECODE ( (nsnd n) DIV 2))
       else
           (DECODE (nfst n), O , DECODE ( ((nsnd n) - 1) DIV 2))`;

(* Halted definition and TM examples *)


val HALTED_def = Define `HALTED tm = ~(((tm.state),(tm.tape_h)) IN FDOM tm.prog)`;

val st_def= Define`st n : state = <| n := n  |>`;
val _ = add_numeral_form(#"s", SOME "st");

EVAL ``INITIALIZE_TM tm [Z]``;

EVAL ``(RUN 3
   <| state := 0;
      prog := FEMPTY |++ [((0,Z),(0,R)); ((0,O),(0,R)); ((1,O),(1,Wr0))] ;
      tape_l := [];
      tape_h := Z;
      tape_r := [Z];
      time := 1 |>
      [Z])``;


(* unary addition machine *)
EVAL ``(RUN 10
   <| state := 0;
        prog := FEMPTY |++ [((0,Z),(1,Wr1)); ((0,O),(0,R));
                            ((1,Z),(2,L)); ((1,O),(1,R));
                            ((2,O),(3,Wr0)) ] ;
      tape_l := [];
      tape_h := Z;
      tape_r := [];
      time := 1 |>
      [O;O;O;Z;O;O])``;


type_of ``(SET_TO_LIST (FDOM (<| state := 0;
       prog := FEMPTY |++ [((0,Z),(0,R)); ((0,O),(1,Wr0)); ((1,Z),(1,R)); ((1,O),(2,Wr1)) ] ;
       tape_l := [];
       tape_h := Z;
       tape_r := [Z];
       time := 1 |>.prog)))
       ``;


(*

The set of Partial Recursive Functions is identical to the set of
Turing Machines computable functions

Total Recursive Function correspond to Turing Machine computable functions that always halt

One can enumerate the Valid Turing Machines (by enumerating programs)

*)

val NUM_CELL_def = Define `(NUM_CELL Z = 0:num) ∧
  (NUM_CELL O = 1:num) `;

val CELL_NUM_def = Define `(CELL_NUM 0n = Z) ∧
  (CELL_NUM 1 = O) `;

val ACT_TO_NUM_def = Define `(ACT_TO_NUM Wr0 = 0:num) ∧
  (ACT_TO_NUM Wr1 = 1:num) ∧
  (ACT_TO_NUM L   = 2:num) ∧
  (ACT_TO_NUM R   = 3:num) `;

val NUM_TO_ACT_def = Define `(NUM_TO_ACT 0n = Wr0 ) ∧
  (NUM_TO_ACT 1 = Wr1) ∧
  (NUM_TO_ACT 2 = L) ∧
  (NUM_TO_ACT 3 = R) `;

EVAL ``ACT_TO_NUM (NUM_TO_ACT 2)``;


(* Definition of a Turing complete function, not working atm *)

(*
val TURING_COMPLETE_def = Define `TURING_COMPLETE f = ∃ tm. ∀ n. ∃ t. DECODE_TM_TAPE (RUN t tm (ENCODE n)) = f `
*)

(*
Previous idea, using enumeration over program set
*)

EVAL ``HD (ncons_inv 88)``;

EVAL ``HD (TL (ncons_inv 88))``;

EVAL `` ncons (HD (ncons_inv 88)) (HD (TL (ncons_inv 88)))``;

(*
Previous diea of enumerating programs

val NCONS_INVERSE_def = Define `(ncons_inv 1 = []) ∧ (ncons_inv c = [nfst (c-1) ; nsnd (c-1)] )`;

EVAL `` MIN_SET {1:num;2:num;3:num;5:num;10:num}``;

val LEAST_IN_SET_def = Define `
LEAST_IN_SET s = let nconsset = { ncons (STATE_TO_NUM (FST c)) (NUM_CELL (SND c)) | c IN s } in
  ncons_inv (MIN_SET nconsset) `;

val LEAST_SET_TO_LIST_def = Define `
LEAST_SET_TO_LIST s =
if FINITE s then
  if s={} then []
  else let k = (NUM_TO_STATE (HD (LEAST_IN_SET s)), CELL_NUM (HD (TL (LEAST_IN_SET s))))  in
    k :: LEAST_SET_TO_LIST (s DELETE k)
else ARB`;

val tcons_def = Define `
tcons a b tm = (ncons (STATE_TO_NUM a) (NUM_CELL b)) *,
                                                     (ncons (STATE_TO_NUM (FST (FAPPLY tm.prog ((a),(b)) ))) (NUM_ACT (SND (FAPPLY tm.prog ((a),(b)) )))) + 1`;

val tlist_of = Define `
(tlist_of [] tm = 0) ∧
(tlist_of (h::t) tm = ncons (tcons (FST h) (SND h) tm)  (tlist_of t tm))`;

val TURING_MACHINE_P_ENCODING_def = Define `
TURING_MACHINE_P_ENCODING tm = tlist_of (SET_TO_LIST (FDOM tm.prog)) tm`;

val FULL_ENCODE_TM_with_P_def = Define `FULL_ENCODE_TM_with_P tm =
nlist_of [TURING_MACHINE_P_ENCODING tm; STATE_TO_NUM tm.state ; DECODE_TM_TAPE tm] `;


*)

(*
Idea is, for each instruction in the program, which is an (a,b,c,d)
val tcons_def = Define `
(tcons (a,b,c,d) = (ncons a (NUM_CELL b)) *, (ncons c (NUM_ACT d)) + 1)`;
*)

val STATE_TO_NUM_def = Define `STATE_TO_NUM a = a.n`;

val NUM_TO_STATE_def = Define `NUM_TO_STATE n = <| n:=n |>`;


EVAL ``STATE_TO_NUM (NUM_TO_STATE 10)``;

val FULL_ENCODE_TM_def = Define `FULL_ENCODE_TM tm =
 STATE_TO_NUM tm.state *, ENCODE_TM_TAPE tm `;


val FULL_DECODE_TM_def = Define `FULL_DECODE_TM n =
<|state:=  NUM_TO_STATE (nfst n);  tape_l := FST (DECODE_TM_TAPE (nsnd n));
tape_h := FST (SND (DECODE_TM_TAPE (nsnd n)));
tape_r := SND (SND (DECODE_TM_TAPE (nsnd n)))|> `;





(* EVAL and type checks *)

(*
num_step tm (takes tm as number and does step, purely arithmetic)
*)

EVAL ``FULL_ENCODE_TM <| state := 0;
prog := FEMPTY |++ [((0,Z),(0,R)); ((0,Z),(1,Wr0)); ((1,Z),(1,R)); ((1,Z),(2,Wr0)) ] ;
tape_l := [];
tape_h := Z;
tape_r := [Z;O;O];
time := 1 |>``;

EVAL `` FULL_DECODE_TM 4185``;

type_of ``recfn f 1``;


val updn_def = Define `(updn [] = 0) ∧ (updn [x] = tri x) ∧
   (updn [x;y] = if y = 0 then tri x
                 else if y = 1 then tri (x + 2) + 2
                 else if y = 2 then tri x
                 else nB (y = 3) * tri x) ∧
 (updn [s;actn;tmn] =
  let tape = (nsnd tmn) in
  let tl = (nfst tape) in
  let th = ((nsnd tape) MOD 2) in
  let tr = ((nsnd tape) DIV 2) in
      if actn = 0 then (* Write 0 *)
          s *, (tl *, ((2 * tr)))
      else if actn = 1 then (* Write 1 *)
          s *, (tl *, ((2 * tr) + 1 ))
      else if actn = 2 then (* Move left *)
          if tl MOD 2 = 1 then
              s *, (((tl-1) DIV 2) *, ((2 * (th + (2 * tr))) + 1))
          else
              s *, ((tl DIV 2) *, (2 * (( th + (2 * tr)))))
      else if actn = 3 then  (* Move right *)
          if tr MOD 2 = 1 then
              s *, ((th + (2 * tl)) *, ((2 * ((tr-1) DIV 2)) + 1))
          else
              s *, ((th + (2 * tl)) *, (2 * (tr DIV 2)))
      else tmn) ∧
       (updn (s::actn::tmn::a::b) = updn [s;actn;tmn])
`;

(* Perform action an move to state *)
val UPDATE_ACT_S_TM_def = Define `UPDATE_ACT_S_TM s act tm =
           let tm' = tm with
                        <|time := SUC(tm.time);
               state := s |> in
               case act of
                   Wr0 => tm' with tape_h := Z
                 | Wr1 => tm' with tape_h := O
                 | L   => if (tm.tape_l = [])
                          then tm' with <| tape_l := [];
                               tape_h := Z ;
                               tape_r := tm.tape_h::tm.tape_r |>
                          else tm' with <| tape_l := TL tm.tape_l;
               tape_h := HD tm.tape_l ;
               tape_r := tm.tape_h::tm.tape_r |>
               | R   => if (tm.tape_r = [])
                        then tm' with <| tape_l := tm.tape_h::tm.tape_l;
                             tape_h := Z ;
                             tape_r := [] |>
                        else tm' with <| tape_l := tm.tape_h::tm.tape_l;
               tape_h := HD tm.tape_r;
               tape_r := TL tm.tape_r |>`;

(* EVAL checks *)

EVAL ``FULL_ENCODE_TM (UPDATE_ACT_S_TM 0 Wr1 <| state := 0;
               prog := FEMPTY |++ [((0,Z),(0,R)); ((0,Z),(1,Wr0)); ((1,Z),(1,R)); ((1,Z),(2,Wr0)) ] ;
               tape_l := [];
               tape_h := Z;
               tape_r := [Z;O;O];
               time := 1 |>)``;

EVAL ``FULL_DECODE_TM 5564``;

EVAL ``updn[0;1;4185]``;

EVAL `` 0 *, nsnd 10``;

val ODD_DIV_2_lem = Q.store_thm ("ODD_DIV_2_lem",
`∀ y. ODD y ==> (y DIV 2 = (y-1) DIV 2)`,
Induct_on `y` >- EVAL_TAC >> rw[] >> `SUC y = y+1` by fs[] >> rw[] >>
`~(ODD y)` by fs[ODD] >>
`1 DIV 2 = 0` by EVAL_TAC >> `0<2` by fs[] >> `EVEN y` by metis_tac[EVEN_OR_ODD] >>
`y MOD 2 = 0` by metis_tac[EVEN_MOD2] >>
`(y+1) DIV 2 = (y DIV 2) + (1 DIV 2)` by fs[ADD_DIV_RWT] >> rw[]
);

val WRITE_0_HEAD_lem = Q.store_thm("WRITE_0_HEAD_lem",
`∀ tm s. (UPDATE_ACT_S_TM s Wr0 tm).tape_h = Z`,
rpt strip_tac >> rw[UPDATE_ACT_S_TM_def] );


val WRITE_1_HEAD_lem = Q.store_thm("WRITE_1_HEAD_lem",
`∀ tm s. (UPDATE_ACT_S_TM s Wr1 tm).tape_h = O`,
rpt strip_tac >> rw[UPDATE_ACT_S_TM_def] );


val TMN_Z_MOD_1_lem = Q.store_thm ("TMN_Z_MOD_1_lem",
`∀ tmn. ((nfst (nsnd tmn) MOD 2 = 1) ∧ (HD (FST (DECODE_TM_TAPE (nsnd tmn))) = Z)) <=> F`,
strip_tac >> rw[]  >> `~(nfst (nsnd tmn) MOD 2 = 0)` by fs[] >>
`~EVEN (nfst (nsnd tmn))` by metis_tac[EVEN_MOD2] >>
`ODD (nfst (nsnd tmn))` by metis_tac[EVEN_OR_ODD] >>
`EVEN 0` by fs[] >>
`~((nfst (nsnd tmn)) = 0)` by metis_tac[EVEN_OR_ODD] >>
Cases_on `nfst (nsnd tmn)` >- fs[] >> 
`DECODE (SUC n) = [O] ++ (DECODE (((SUC n) - 1) DIV 2))` by fs[DECODE_def] >>
`TL (DECODE (SUC n)) = (DECODE ((SUC n -1) DIV 2))` by fs[DECODE_def] >>
rw[] >> rw[DECODE_TM_TAPE_def] );


val ODD_TL_DECODE_lem = Q.store_thm ("ODD_TL_DECODE_lem",
`∀ n. (ODD n) ==> (TL (DECODE n) = DECODE ((n-1) DIV 2))`,
rpt strip_tac >> `EVEN 0` by EVAL_TAC >> `~(n = 0)` by metis_tac[EVEN_AND_ODD]>>
rw[DECODE_def] >> Cases_on `DECODE n` >- `n=0` by fs[DECODE_EMPTY_lem] >>
EVAL_TAC >> Cases_on `n` >- fs[] >> fs[DECODE_def] >> rfs[] );


val EVEN_TL_DECODE_lem = Q.store_thm ("EVEN_TL_DECODE_lem",
`∀ n. ((EVEN n) ∧ (n > 0)) ==> (TL (DECODE n) = DECODE (n DIV 2))`,
rpt strip_tac >> Cases_on `n` >- fs[]  >>
    rw[DECODE_def] >> metis_tac[EVEN_AND_ODD] );


val EVEN_ENCODE_Z_DECODE_lem = Q.store_thm ("EVEN_ENCODE_Z_DECODE_lem",
`∀ n. (EVEN n) ==> (n = ENCODE (Z::DECODE (n DIV 2)))`,
rpt strip_tac >> Cases_on `n` >- EVAL_TAC >> rfs[DECODE_def,ENCODE_def] >>
 rw[ENCODE_DECODE_thm] >> `(SUC n') MOD 2 = 0` by metis_tac[EVEN_MOD2] >>
`2*(SUC n' DIV 2) = SUC n'` by fs[MULT_EQ_DIV] >> rw[] );

val ODD_ENCODE_O_DECODE_lem = Q.store_thm ("EVEN_ENCODE_Z_DECODE_lem",
`∀ n. (ODD n) ==> (n = ENCODE (O::DECODE ((n-1) DIV 2)))`,
rpt strip_tac >> Cases_on `n` >- fs[] >> rfs[DECODE_def,ENCODE_def] >>
    rw[ENCODE_DECODE_thm] >> `~(ODD n')` by fs[ODD] >> `EVEN n'` by metis_tac[EVEN_OR_ODD] >>
`n' MOD 2 = 0` by metis_tac[EVEN_MOD2] >>
`2*( n' DIV 2) =  n'` by fs[MULT_EQ_DIV] >> rw[] );


val ODD_MINUS_1_lem = Q.store_thm ("ODD_MINUS_1_lem",
`∀ n. (ODD n) ==> (~ODD (n-1))`,
rpt strip_tac >> Cases_on `n` >- fs[] >> `SUC n' - 1 = n'` by fs[SUC_SUB1] >>
`ODD n'` by fs[] >> fs[ODD] )


val ONE_LE_ODD_lem = Q.store_thm ("ONE_LE_ODD_lem",
`∀n. (ODD n) ==> (1 <= n)`,
rpt strip_tac >> Cases_on `n` >-  fs[] >> `SUC n' = 1+n'` by fs[SUC_ONE_ADD] >>
rw[])


val ODD_MOD_TWO_lem = Q.store_thm ("ODD_MOD_TWO_lem",
`∀n. (ODD n) ==> (n MOD 2 = 1)`,
rpt strip_tac  >> fs[MOD_2] >> `~(EVEN n)` by metis_tac[EVEN_AND_ODD] >> rw[] );


val UPDATE_TM_NUM_act0_lem = Q.store_thm ("UPDATE_TM_NUM_act0_lem",
`∀ s tmn actn. (actn = 0) ==>  (updn [s;actn;tmn] =
FULL_ENCODE_TM (UPDATE_ACT_S_TM (NUM_TO_STATE s) (NUM_TO_ACT actn) (FULL_DECODE_TM tmn)))`,
REWRITE_TAC [updn_def] >> rpt strip_tac >>
 (* actn = 0*)
    simp[NUM_TO_ACT_def] >>
        rw[FULL_DECODE_TM_def,FULL_ENCODE_TM_def]
        >- ( rw[UPDATE_ACT_S_TM_def] >> EVAL_TAC)
        >> rw[ENCODE_TM_TAPE_def]
        >- ( rw[UPDATE_ACT_S_TM_def] >> rw[DECODE_TM_TAPE_def]
               >> simp[ENCODE_DECODE_thm ]  )
        >-  ( rw[UPDATE_ACT_S_TM_def] >> rw[DECODE_TM_TAPE_def] >>
                simp[ENCODE_DECODE_thm ] >>
`ODD (nsnd (nsnd tmn))` by metis_tac[EVEN_OR_ODD] >>
fs[ODD_DIV_2_lem] )
        >> (`(UPDATE_ACT_S_TM (NUM_TO_STATE s) Wr0
                             <|state := NUM_TO_STATE (nfst tmn);
             tape_l := FST (DECODE_TM_TAPE (nsnd tmn));
             tape_h := FST (SND (DECODE_TM_TAPE (nsnd tmn)));
             tape_r := SND (SND (DECODE_TM_TAPE (nsnd tmn)))|>).tape_h = Z` by fs[WRITE_0_HEAD_lem] >> rfs[])
);


val UPDATE_TM_NUM_act1_lem = Q.store_thm ("UPDATE_TM_NUM_act1_lem",
`∀ s tmn actn. (actn = 1) ==>  (updn [s;actn;tmn] =
FULL_ENCODE_TM (UPDATE_ACT_S_TM (NUM_TO_STATE s) (NUM_TO_ACT actn) (FULL_DECODE_TM tmn)))`,
REWRITE_TAC [updn_def] >> rpt strip_tac >>
simp[NUM_TO_ACT_def] >>
     rw[FULL_DECODE_TM_def] >> rw[FULL_ENCODE_TM_def]
     >- ( rw[UPDATE_ACT_S_TM_def] >> EVAL_TAC)
     >> rw[ENCODE_TM_TAPE_def]
     >- ( rw[UPDATE_ACT_S_TM_def] >> rw[DECODE_TM_TAPE_def]
            >> simp[ENCODE_DECODE_thm ]  )
     >-  ( `(UPDATE_ACT_S_TM (NUM_TO_STATE s) Wr1
                             <|state := NUM_TO_STATE (nfst tmn);
             tape_l := FST (DECODE_TM_TAPE (nsnd tmn));
             tape_h := FST (SND (DECODE_TM_TAPE (nsnd tmn)));
             tape_r := SND (SND (DECODE_TM_TAPE (nsnd tmn)))|>).tape_h = O` by fs[WRITE_1_HEAD_lem] >> `O=Z` by fs[] >> fs[])
     >- (rw[UPDATE_ACT_S_TM_def] >> rw[DECODE_TM_TAPE_def] >>
           simp[ENCODE_DECODE_thm ])
     >> (rw[UPDATE_ACT_S_TM_def] >> rw[DECODE_TM_TAPE_def] >>
           simp[ENCODE_DECODE_thm ]
           >> `ODD (nsnd (nsnd tmn))` by metis_tac[EVEN_OR_ODD]
           >> fs[ODD_DIV_2_lem] )
);

val FST_DECODE_TM_TAPE = Q.store_thm(
  "FST_DECODE_TM_TAPE[simp]",
  `FST (DECODE_TM_TAPE tp) = DECODE (nfst tp)`,
  rw[DECODE_TM_TAPE_def])

val DECODE_EQ_NIL = Q.store_thm(
  "DECODE_EQ_NIL[simp]",
  `(DECODE n = []) ⇔ (n = 0)`,
  metis_tac[DECODE_EMPTY_lem, DECODE_def]);

val STATE_TO_NUM_TO_STATE = Q.store_thm ("STATE_TO_NUM_TO_STATE[simp]",
`STATE_TO_NUM (NUM_TO_STATE n) = n`,
simp[STATE_TO_NUM_def,NUM_TO_STATE_def])

val ODD_HD_DECODE = Q.store_thm(
  "ODD_HD_DECODE",
  `ODD n ==> (HD (DECODE n) = O)`,
  Cases_on `n` >> simp[DECODE_def]);

val EVEN_HD_DECODE = Q.store_thm(
 "EVEN_HD_DECODE",
`EVEN n ∧ (n ≠ 0)  ==> (HD (DECODE n) = Z)`,
Cases_on `n` >> simp[DECODE_def] >> metis_tac[EVEN_AND_ODD,listTheory.HD]);

val UPDATE_TM_NUM_act2_lem = Q.store_thm ("UPDATE_TM_NUM_act2_lem",
`∀ s tmn actn.
    (actn = 2) ==>
    (updn [s;actn;tmn] =
       FULL_ENCODE_TM (UPDATE_ACT_S_TM (NUM_TO_STATE s) (NUM_TO_ACT actn) (FULL_DECODE_TM tmn)))`,
REWRITE_TAC [updn_def] >> rpt strip_tac >>
simp[NUM_TO_ACT_def, FULL_DECODE_TM_def, FULL_ENCODE_TM_def, UPDATE_ACT_S_TM_def] >>
rw[] >- (fs[])
>- (`~EVEN (nfst (nsnd tmn))` by metis_tac[MOD_2, DECIDE ``0n <> 1``] >>
    `ODD (nfst (nsnd tmn))` by metis_tac[EVEN_OR_ODD] >>
    simp[ENCODE_TM_TAPE_def, ODD_TL_DECODE_lem, ENCODE_DECODE_thm] >> 
    rw[ENCODE_def, ENCODE_DECODE_thm,DECODE_TM_TAPE_def] >> rfs[ODD_HD_DECODE]
    >- metis_tac[MOD_2]
    >- (rw[MOD_2] >> metis_tac[ODD_DIV_2_lem, EVEN_OR_ODD]))
>- (simp[ENCODE_TM_TAPE_def, ODD_TL_DECODE_lem, ENCODE_DECODE_thm] >> 
    rw[ENCODE_def,DECODE_TM_TAPE_def,ENCODE_DECODE_thm,MOD_2] >>
    metis_tac[ODD_DIV_2_lem, EVEN_OR_ODD])
>- (`EVEN (nfst (nsnd tmn))` by metis_tac[MOD_2, DECIDE ``0n <> 1``] >>
    `~ODD (nfst (nsnd tmn))` by metis_tac[EVEN_AND_ODD] >>
    simp[ENCODE_TM_TAPE_def, EVEN_TL_DECODE_lem, ENCODE_DECODE_thm] >>
    rw[ENCODE_def,DECODE_TM_TAPE_def, ENCODE_DECODE_thm] >> rfs[EVEN_HD_DECODE]
    >- simp[MOD_2]
    >- (rw[MOD_2] >> metis_tac[ODD_DIV_2_lem, EVEN_OR_ODD]))
 );


val SND_SND_DECODE_TM_TAPE = Q.store_thm("SND_SND_DECODE_TM_TAPE",
`SND (SND (DECODE_TM_TAPE (nsnd tmn))) = DECODE (nsnd (nsnd tmn) DIV 2)`,
rw[DECODE_TM_TAPE_def] >> `ODD (nsnd (nsnd tmn))` by metis_tac[EVEN_OR_ODD] >>
  rw[ODD_DIV_2_lem]);

val FST_SND_DECODE_TM_TAPE = Q.store_thm("FST_SND_DECODE_TM_TAPE",
`ODD (nsnd (nsnd tmn)) ==> (FST (SND (DECODE_TM_TAPE (nsnd tmn))) = O)`,
rw[DECODE_TM_TAPE_def] >> metis_tac[EVEN_AND_ODD]);

val FST_SND_DECODE_TM_TAPE_EVEN = Q.store_thm("FST_SND_DECODE_TM_TAPE",
`EVEN (nsnd (nsnd tmn)) ==> (FST (SND (DECODE_TM_TAPE (nsnd tmn))) = Z)`,
rw[DECODE_TM_TAPE_def]);

val UPDATE_TM_NUM_act3_lem = Q.store_thm ("UPDATE_TM_NUM_act3_lem",
`∀ s tmn actn.
    (actn = 3) ==>
    (updn [s;actn;tmn] =
       FULL_ENCODE_TM (UPDATE_ACT_S_TM (NUM_TO_STATE s) (NUM_TO_ACT actn) (FULL_DECODE_TM tmn)))`,
REWRITE_TAC [updn_def] >> rpt strip_tac >>
simp[NUM_TO_ACT_def, FULL_DECODE_TM_def, FULL_ENCODE_TM_def, UPDATE_ACT_S_TM_def] >>
rw[] >- (fs[SND_SND_DECODE_TM_TAPE])
>- (simp[ENCODE_TM_TAPE_def, ENCODE_DECODE_thm] >>
    `~EVEN (nsnd (nsnd tmn) DIV 2)` by metis_tac[MOD_2, DECIDE ``0n <> 1``] >>
    `ODD (nsnd (nsnd tmn) DIV 2)` by metis_tac[EVEN_OR_ODD] >>
    rfs[SND_SND_DECODE_TM_TAPE] >> simp[ENCODE_def] >> fs[ODD_TL_DECODE_lem,ENCODE_DECODE_thm] >>
    `HD (DECODE (nsnd (nsnd tmn) DIV 2)) = O` by fs[ODD_HD_DECODE] >> simp[] >>
    rw[ENCODE_def,DECODE_TM_TAPE_def,ENCODE_DECODE_thm,MOD_2] )
>- ( simp[ENCODE_TM_TAPE_def, ENCODE_DECODE_thm] >>
    `EVEN (nsnd (nsnd tmn) DIV 2)` by metis_tac[MOD_2, DECIDE ``0n <> 1``] >>
    `~ODD (nsnd (nsnd tmn) DIV 2)` by metis_tac[EVEN_AND_ODD] >>
    rfs[SND_SND_DECODE_TM_TAPE]  >>
    rw[ENCODE_def,DECODE_TM_TAPE_def, ENCODE_DECODE_thm,MOD_2] )
>- (simp[ENCODE_TM_TAPE_def, ENCODE_DECODE_thm] >>
    `EVEN (nsnd (nsnd tmn) DIV 2)` by metis_tac[MOD_2, DECIDE ``0n <> 1``] >>
    fs[SND_SND_DECODE_TM_TAPE,EVEN_HD_DECODE] >>
    rw[ENCODE_def,DECODE_TM_TAPE_def, ENCODE_DECODE_thm,MOD_2] >>
    fs[EVEN_TL_DECODE_lem,ENCODE_DECODE_thm])
 );


val UPDATE_TM_NUM_thm = Q.store_thm ("UPDATE_TM_NUM_Theorem",
`∀ s tmn actn. (actn < 4) ==>  (updn [s;actn;tmn] =
 FULL_ENCODE_TM (UPDATE_ACT_S_TM (NUM_TO_STATE s) (NUM_TO_ACT actn) (FULL_DECODE_TM tmn)))`,
 rpt strip_tac >>
`(actn = 0) ∨ (actn = 1) ∨ (actn = 2) ∨ (actn = 3)` by simp[]
>- (* actn = 0*)
   fs[UPDATE_TM_NUM_act0_lem]
>-  (* actn = 1*)
   fs[UPDATE_TM_NUM_act1_lem]
>- (* actn = 2*)
    fs[UPDATE_TM_NUM_act2_lem]
>- (* actn = 3*)
    fs[UPDATE_TM_NUM_act3_lem]);


val pr3_def = Define`
(pr3 f [] = f 0 0 0 : num) ∧
(pr3 f [x:num] = f x 0 0) ∧
(pr3 f [x;y] = f x y 0) ∧
(pr3 f (x::y::z::t) = f x y z)
`;

val GENLIST1 = prove(``GENLIST f 1 = [f 0]``,
                     SIMP_TAC bool_ss [ONE, GENLIST, SNOC]);

val GENLIST2 = prove(
``GENLIST f 2 = [f 0; f 1]``,
SIMP_TAC bool_ss [TWO, ONE, GENLIST, SNOC]);

val GENLIST3 = prove(
``GENLIST f 3 = [f 0; f 1; f 2]``,
EVAL_TAC );

val ternary_primrec_eq = store_thm(
        "ternary_primrec_eq",
``primrec f 3 ∧ (∀n m p. f [n; m; p] = g n m p) ⇒ (f = pr3 g)``,
SRW_TAC [][] >> SIMP_TAC (srw_ss()) [FUN_EQ_THM] >>
Q.X_GEN_TAC `l` >>
`(l = []) ∨ ∃n ns. l = n :: ns` by (Cases_on `l` >> SRW_TAC [][]) THENL [
SRW_TAC [][] >>
`f [] = f (GENLIST (K 0) 3)` by METIS_TAC [primrec_nil] >>
SRW_TAC [][GENLIST3,pr3_def] ,
`(ns = []) ∨ ∃m ms. ns = m::ms` by (Cases_on `ns` THEN SRW_TAC [][]) >>
SRW_TAC [][] THENL [
IMP_RES_THEN (Q.SPEC_THEN `[n]` MP_TAC) primrec_short >>
              SRW_TAC [][GENLIST1] >> EVAL_TAC,
`(ms = []) ∨ ∃p ps. ms = p::ps` by (Cases_on `ms` THEN SRW_TAC [][]) THENL [
    fs[pr3_def] >> `f [n;m] = f ([n;m] ++ GENLIST (K 0) (3 - LENGTH [n;m]))` by fs[primrec_short] >>
      `GENLIST (K 0) (3 - LENGTH [n;m]) = [0]` by EVAL_TAC >> rfs[], IMP_RES_THEN (Q.SPEC_THEN `(n::m::p::ps)` MP_TAC) primrec_arg_too_long >>
        SRW_TAC [ARITH_ss][] >> fs[pr3_def]  ] ] ])


val primrec_pr3 = store_thm(
        "primrec_pr3",
``(∃g. primrec g 3 ∧ (∀m n p. g [m; n; p] = f m n p)) ⇒ primrec (pr3 f) 3``,
METIS_TAC [ternary_primrec_eq]);

(*
Prim Rec theorems
primrec_pr_add,primrec_pr_mult,
primrec_pr_div,primrec_pr_cond,primrec_pr_sub,
primrec_pr_mod,primrec_tri,primrec_pr_eq,
primrec_nfst,primrec_nsnd
*)


val primrec_updn_lem1 = Q.store_thm("primrec_updn_lem1",
`s ⊗ ((tl − 1) DIV 2) ⊗ (2 * (th + 2 * tr) + 1) =
s ⊗ (pr_div [((pr2 $-) [tl; 1]); 2]) ⊗ ( (pr2 (+)) [(pr2 $*) [2; ((pr2 (+)) [th;((pr2 $*) [2; tr])])] ;1] )`,
EVAL_TAC)


val MULT2_def = Define `MULT2 x = 2*x`;


val pr_up_case1_def = Define`pr_up_case1 x =
        Cn (pr2 $*,) [ proj 0;Cn (pr2 $*,) [proj 2;Cn (pr1 MULT2) [proj 4]] ] x`

val pr_up_case1_thm = Q.store_thm("pr_up_case1_thm",
`∀ x. ((proj 0 x) *, (proj 2 x) *, (2 * (proj 4 x)) ) = (Cn (pr2 $*,) [ proj 0;Cn (pr2 $*,) [proj 2;Cn (pr1 MULT2) [proj 4]] ] x)`,
strip_tac >> rfs[MULT2_def] )

val pr_up_case2_def = Define`pr_up_case2 x =
        Cn (pr2 $*,) [ proj 0;Cn (pr2 $*,) [proj 2;Cn (succ) [Cn (pr1 MULT2) [proj 4]] ] ] x`

val pr_up_case3_def = Define`pr_up_case3 x =
        Cn (pr2 $*,) [ proj 0;Cn (pr2 $*,) [Cn (pr1 DIV2) [Cn (pr1 PRE) [proj 2]];
        Cn (succ) [Cn (pr1 MULT2) [Cn (pr2 (+)) [proj 3; Cn (pr1 MULT2) [proj 4]]]] ] ] x`

val pr_up_case4_def = Define`pr_up_case4 x =
        Cn (pr2 $*,) [ proj 0;Cn (pr2 $*,) [Cn (pr1 DIV2) [proj 2];
        Cn (pr1 MULT2) [Cn (pr2 (+)) [proj 3; Cn (pr1 MULT2) [proj 4]]] ] ] x`

val pr_up_case5_def = Define`pr_up_case5 x =
        Cn (pr2 $*,) [ proj 0;Cn (pr2 $*,) [Cn (pr2 (+)) [proj 3;Cn (pr1 MULT2) [proj 2]];
        Cn (succ) [Cn (pr1 MULT2) [Cn (pr1 DIV2) [Cn (pr1 PRE) [proj 4]]]] ] ] x`

val pr_up_case6_def = Define`pr_up_case6 x =
        Cn (pr2 $*,) [ proj 0;Cn (pr2 $*,) [Cn (pr2 (+)) [proj 3;Cn (pr1 MULT2) [proj 2]];
       Cn (pr1 MULT2) [Cn (pr1 DIV2) [proj 4]]]  ] x`




EVAL ``6 *, 4 *, 22``;

EVAL ``pr_up_case1 [6;1;4;1;11]``;

EVAL ``tri 0``;

LET_THM;

updn_def;

npair_def;

val _ = overload_on ("onef", ``K 1 : num list -> num``)

val _ = overload_on ("twof", ``K 2 : num list -> num``)

val _ = overload_on ("threef", ``K 3 : num list -> num``)

val nB_cond_elim = prove(
``nB p * x + nB (~p) * y = if p then x else y``,
Cases_on `p` >> simp[]);



EVAL `` Cn
           (pr_cond (Cn pr_eq [proj 1;zerof] ) (pr_up_case1) (
                 pr_cond (Cn pr_eq [proj 1; onef] ) (pr_up_case2) (
                     pr_cond (Cn pr_eq [proj 1; twof] ) (
                         pr_cond (Cn pr_eq [Cn (pr_mod) [proj 2;twof];onef]) (pr_up_case3) (pr_up_case4) ) (
                         pr_cond (Cn pr_eq [proj 1;threef]) (
                             pr_cond (Cn pr_eq [Cn (pr_mod) [proj 4;twof];onef]) (pr_up_case5) (pr_up_case6) )
                                 (Cn (pr2 npair) [proj 2; Cn (pr2 (+)) [proj 3;Cn (pr1 MULT2) [proj 4] ] ] )  ) )  )  )
           [proj 0;proj 1; Cn (pr1 nfst) [Cn (pr1 nsnd) [proj 2]] ;
            Cn (pr_mod) [Cn (pr1 nsnd) [ Cn (pr1 nsnd) [proj 2]];twof];
            Cn (pr1 DIV2) [Cn (pr1 nsnd) [ Cn (pr1 nsnd) [proj 2]]] ] [x;y]`` 
      |> SIMP_RULE (srw_ss()) [DECIDE ``x <= y /\ y <= x <=> (x:num = y)``, nB_cond_elim]


val updn_zero_thm = Q.store_thm ("updn_zero_thm",
`∀ x. updn [x;0] = updn [x]`,
strip_tac >> fs[updn_def])

val updn_two_lem_1 = Q.store_thm("updn_two_lem_1",
`∀ x. ((x <> []) ∧ (LENGTH x <= 2)) ==> ( ∃ h. (x = [h])) ∨  (∃ h t. (x = [h;t]))`,
rpt strip_tac >>  Cases_on `x` >- fs[] >> Cases_on `t` >- fs[] >> Cases_on `t'` >- fs[] >> rfs[] );

EVAL ``10::[]``;

val updn_three_lem_1 = Q.store_thm("updn_three_lem_1",
`∀ x.  ¬(LENGTH x <= 2) ==> (∃ a b c. (x = [a;b;c]) ) ∨ (∃ a b c d e. (x = (a::b::c::d::e) ) )`,
rpt strip_tac >>  Cases_on `x` >- fs[] >> Cases_on `t` >- fs[] >> Cases_on `t'` >- fs[] >> rfs[] >> strip_tac >> Cases_on `t` >- fs[] >> fs[] );

(*

val prim_rec_updn = Q.store_thm ("prim_rec_updn",
 `updn  = Cn
   (pr_cond (Cn pr_eq [proj 1;zerof] ) (pr_up_case1) (
    pr_cond (Cn pr_eq [proj 1; onef] ) (pr_up_case2) (
    pr_cond (Cn pr_eq [proj 1; twof] ) (
      pr_cond (Cn pr_eq [Cn (pr_mod) [proj 2;twof];onef]) (pr_up_case3) (pr_up_case4) ) (
    pr_cond (Cn pr_eq [proj 1;threef]) (
      pr_cond (Cn pr_eq [Cn (pr_mod) [proj 4;twof];onef]) (pr_up_case5) (pr_up_case6) )
    (Cn (pr2 npair) [proj 2; Cn (pr2 (+)) [proj 3;Cn (pr1 MULT2) [proj 4] ] ] )  ) )  )  )
 [proj 0;proj 1; Cn (pr1 nfst) [Cn (pr1 nsnd) [proj 2]] ;
  Cn (pr_mod) [Cn (pr1 nsnd) [ Cn (pr1 nsnd) [proj 2]];twof];
  Cn (pr1 DIV2) [Cn (pr1 nsnd) [ Cn (pr1 nsnd) [proj 2]]] ]  `,
rw[Cn_def,FUN_EQ_THM]
  >>  fs[pr_up_case1_def,pr_up_case2_def,pr_up_case3_def,pr_up_case4_def,pr_up_case5_def,pr_up_case6_def] >> rw[]
  >- ( rw[proj_def,updn_def,updn_zero_thm,updn_three_lem_1]
    >- EVAL_TAC
    >- rfs[]
    >-( EVAL_TAC >> `(∃h. x = [h]) ∨ (∃h t. x = [h;t])` by simp[updn_two_lem_1]
      >- (rw[updn_def])
      >- (rfs[updn_def,updn_zero_thm] >> `proj 1 x = t` by fs[] >> fs[] )
           )
    >- (`(∃ a b c. x = [a;b;c]) ∨ (∃ a b c d e. x = (a::b::c::d::e))` by simp[updn_three_lem_1]
      >- (`proj 1 x = b` by fs[] >> fs[] >> fs[updn_def,MULT2_def,DIV2_def] )
      >-  fs[updn_def,MULT2_def,DIV2_def] )
     )
  >- ( fs[proj_def,updn_def,updn_zero_thm,pr_up_case2_def] >> rw[]
    >- (rfs[])
    >- (rfs[])
    >- (EVAL_TAC >> `(∃h. x = [h]) ∨ (∃h t. x = [h;t])` by simp[updn_two_lem_1]
      >-(fs[])
      >-(rfs[updn_def,updn_zero_thm] >> fs[])
            )
    >- (`(∃ a b c. x = [a;b;c]) ∨ (∃ a b c d e. x = (a::b::c::d::e))` by simp[updn_three_lem_1]
      >-(fs[updn_def,MULT2_def,DIV2_def])
      >-(fs[updn_def,MULT2_def,DIV2_def])
            )
     )
  >- ( fs[proj_def,updn_def,updn_zero_thm,pr_up_case3_def] >> rw[]
    >-(rfs[])
    >-(rfs[])
    >-(EVAL_TAC >> `(∃h. x = [h]) ∨ (∃h t. x = [h;t])` by simp[updn_two_lem_1]
      >-(fs[])
      >-(rfs[updn_def,updn_zero_thm] >> fs[] >> `nfst (nsnd 0) = 0 ` by EVAL_TAC >> fs[])
      )
    >-(`(∃ a b c. x = [a;b;c]) ∨ (∃ a b c d e. x = (a::b::c::d::e))` by simp[updn_three_lem_1]
      >-(fs[updn_def,MULT2_def,DIV2_def])
      >-(fs[updn_def,MULT2_def,DIV2_def]))
     )
  >- (fs[proj_def,updn_def,updn_zero_thm,pr_up_case4_def] >> rw[]
    >- (rfs[])
    >- (rfs[])
    >- (EVAL_TAC >> `(∃h. x = [h]) ∨ (∃h t. x = [h;t])` by simp[updn_two_lem_1]
      >-(fs[])
      >- (rfs[updn_def,updn_zero_thm] >> fs[] ) )
    >- (`(∃ a b c. x = [a;b;c]) ∨ (∃ a b c d e. x = (a::b::c::d::e))` by simp[updn_three_lem_1]
      >-(fs[updn_def,MULT2_def,DIV2_def])
      >-(fs[updn_def,MULT2_def,DIV2_def])))
  >- (fs[proj_def,updn_def,updn_zero_thm,pr_up_case4_def] >> rw[]
    >- (rfs[])
    >- (rfs[])
    >- (EVAL_TAC >> `(∃h. x = [h]) ∨ (∃h t. x = [h;t])` by simp[updn_two_lem_1]
      >- (fs[updn_def])
      >- (fs[] >> `nsnd (nsnd 0) = 0` by EVAL_TAC >> fs[]))
    >- ())
  >- ()
  >- ()
  )


val UPDATE_TM_NUM_PRIMREC = store_thm("UPDATE_TM_NUM_PRIMREC",
`primrec updn 3`,
SRW_TAC [][updn_def,primrec_rules] );

*)

(*   TODO   *)

(*
val STEP_NUM_def = Define `STEP_NUM tmn = updn [s;actn;tmn]`;

val STEPS_NUM_def = Define `STEPS_NUM tm = FUNPOW tmstepf n tm`;

val TMSTEP_F_def = Define `tmstepf tm =
case OLEAST n. (NUM_TO_STATE (nfst n), CELL_NUM (nsnd n)) ∈ FDOM tm.prog of
   NONE => done
 | SOME n => let s = nfst n in
             let sym = nsnd n in
     (λ args. case args of
        tmn =>
        if ((nfst tmn) = s) ∧ ((nfst (nsnd (nsnd tmn))) = sym)
        then updn [s'; actn; tmn]
        else tmstepf (p \\ (s,sym)) [tm]
      | x => 0)`;



primerec (tmstepf tm) 1

∀tm ∃f ∀n

val TM_EQIV_REC_FUN = store_thm(
  "TM_EQIV_REC_FUN",
  `∀ tm. ∃f.  ∀ n. ∃ t. (recfn f 1) ∧  (DECODE_TM_TAPE (RUN t tm (ENCODE n)) = f [n]) `,
  completeInduct_on `TURING_MACHINE_P_ENCODING tm` >> EVAL_TAC >>
`recfn (recPhi o CONS i) 1` by metis_tac[prtermTheory.recfn_recPhi_applied] 
>> REPEAT strip_tac >> FULL_SIMP_TAC (srw_ss()) [] >> EXISTS_TAC `(recPhi o CONS i)`
rw[] >>

  strip_tac >> exists_tac `recPhi` >> conj_tac >> simp[]
  >-
  >-
);

val REC_FUN_EQUIV_TM = store_thm(
    "REC_FUN_EQUIV_TM",
`∀ f. ∃ tm. ∀ n.  ∃ t. (recfn f 1)  ( f[n] = DECODE_TM_TAPE (RUN t tm (ENCODE n)) )`,
    );


val UNIVERSAL_TM_EXIST = store_thm (
        "UNIVERSAL_TM_EXIST",
        `!T:TM. ?U:TM. !input:TM_input. ?u_input:TM_input. (INITIAL_TM U (u_input++input))=(INITIAL_TM T input)`,
        insert_proof_here
    );
*)













(*TO DO LATER*)

(*
val ENUMERABLE_FUN_def = Define `ENUMERABLE_FUN f = (realfn f) ∧ (∃ g. (recfn g 2) ∧
  (∀ n k. g(n,k) >= g(n,SUC(k))) ∧ (lim g k = f))`;

val COENUMERABLE_FUN_def = Define `COENUMERABLE_FUN f = (ENUMERABLE_FUN (-f))`;

val REAL_RECURSIVE_FUN_def = Define `REAL_RECURSIVE_FUN f = (realfun f) ∧ (∃ g. (recfn g 2) ∧
  (∀ x k. (abs (f(x) - g(x,k))) < (1 DIV k)))`;

val SPACE_COMPLEXITY_def = Define `SPACE_COMPLEXITY tm = ∀ l. LENGTH l `

val TIME_COMPLEXITY_def = Define `TIME_COMPLEXITY tm = `

(* Can go into P,NP,PSPACE,etc if time permits*)

val ENUMERATION_def = Define `ENUMERATION x S = if (x IN S)
                                                then (x POS LISTIZE S)
                                                else ?`;

val COMPLEXITY_1_def = Define `COMPLEXITY_1 x f =
  if (∃ p. f(p) = (ENUMERATION x S))
  then (MIN {LENGTH p | f(p) = (ENUMERATION x S)}  )
  else infinity`;

(* Invariance Theorem?*)

val ANG_BRA_def = Define `ANG_BRA x y = `;

val COND_COMPLEXITY_1_def = Define `COND_COMPLEXITY_1 x f y =
  if (∃ p. f(ANG_BRA y p) = (ENUMERATION x S))
  then (MIN {LENGTH p | f(ANG_BRA y p) = (ENUMERATION x S)}  )
  else infinity`;

val COND_COMPLEXITY_2_def = Define `COND_COMPLEXITY_2 x phi y =
  if (∃ p. phi(ANG_BRA y p) = x
  then (MIN {LENGTH p | phi(ANG_BRA y p) = x}  )
  else infinity`;

val COND_COMPLEXITY_3_def = Define `COND_COMPLEXITY_3 x y = COND_COMPLEXITY_2 x uniphi y`;

val COMPLEXITY_3_def = Define `COMPLEXITY_3 x = COND_COMPLEXITY_3 x empty_string`;

val COMPLEXITY_UPPER_BOUNDS = store_thm (
    "COMPLEXITY_UPPER_BOUNDS",
    `∃ c. ∀ x y. (COMPLEXITY_3 x <= (LENGTH x) + c) ∧ (COND_COMPLEXITY_3 x y <= (LENGTH x) + c)`,
    CHEAT)

val COMPLEXITY_EQUIV_def = Define `COMPLEXITY_EQUIV phi1 phi2 =
  ∀ x. ∃ c. (abs (phi1 x - phi2 x)) <= c`;
*)




(*
What is needed for Solomonoff Theorem
Recursive semi measure
K complexity
mu-expected value
M-probability
Def Semi-measure
Def Measure
Def Universal enumerable continuous semi-measure
Def Reference prefix machine
THM Exists a unique universal enumerable continuous semi-measure

*)



val _ = export_theory();






