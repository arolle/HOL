(* ----------------------------------------------------------------------
              HOL configuration script


   DO NOT EDIT THIS FILE UNLESS YOU HAVE TRIED AND FAILED WITH

     smart-configure

   AND

     config-override.

   ---------------------------------------------------------------------- *)


(* Uncomment these lines and fill in correct values if smart-configure doesn't
   get the correct values itself.  Then run

      poly < tools/configure.sml

   If you are specifying directories under Windows, we recommend you
   use forward slashes (the "/" character) as a directory separator,
   rather than the 'traditional' backslash (the "\" character).

   The problem with the latter is that you have to double them up
   (i.e., write "\\") in order to 'escape' them and make the string
   valid for SML.  For example, write "c:/dir1/dir2/mosml", rather
   than "c:\\dir1\\dir2\\mosml", and certainly DON'T write
   "c:\dir1\dir2\mosml".
*)

(*
val poly : string         =
val polymllibdir : string =
val holdir :string        =
val OS :string            =
                           (* Operating system; choices are:
                                "linux", "solaris", "unix", "macosx",
                                "winNT"   *)
*)

val _ = PolyML.print_depth 0;

val CC:string       = "gcc";      (* C compiler                       *)
val GNUMAKE:string  = "make";     (* for bdd library and SMV          *)
val DEPDIR:string   = ".HOLMK";   (* where Holmake dependencies kept  *)


fun compile systeml exe obj =
  (systeml [CC, "-o", exe, obj, "-L" ^ polymllibdir,
            "-lpolymain", "-lpolyml"];
   OS.FileSys.remove obj);

(*---------------------------------------------------------------------------
          END user-settable parameters
 ---------------------------------------------------------------------------*)

val version_number = 6
val release_string = "Kananaskis"

(*
val _ = Meta.quietdec := true;
app load ["OS", "Substring", "BinIO", "Lexing", "Nonstdio"];
*)
structure FileSys = OS.FileSys
structure Process = OS.Process
structure Path = OS.Path

fun check_is_dir role dir =
    (FileSys.isDir dir handle e => false) orelse
    (print "\n*** Bogus directory ("; print dir; print ") given for ";
     print role; print "! ***\n";
     Process.exit Process.failure)

val _ = check_is_dir "polymllibdir" polymllibdir
val _ = check_is_dir "holdir" holdir
val _ =
    if List.exists (fn s => s = OS)
                   ["linux", "solaris", "unix", "winNT", "macosx"]
    then ()
    else (print ("\n*** Bad OS specified: "^OS^" ***\n");
          Process.exit Process.failure)

fun normPath s = Path.toString(Path.fromString s)
fun itstrings f [] = raise Fail "itstrings: empty list"
  | itstrings f [x] = x
  | itstrings f (h::t) = f h (itstrings f t);

fun fullPath slist = normPath
   (itstrings (fn chunk => fn path => Path.concat (chunk,path)) slist);

fun quote s = String.concat ["\"",String.toString s,"\""]

val holmakedir = fullPath [holdir, "tools-poly", "Holmake"];

(*---------------------------------------------------------------------------
      File handling. The following implements a very simple line
      replacement function: it searchs the source file for a line that
      contains "redex" and then replaces the whole line by "residue". As it
      searches, it copies lines to the target. Each replacement happens
      once; the replacements occur in order. After the last replacement
      is done, the rest of the source is copied to the target.
 ---------------------------------------------------------------------------*)

fun processLinesUntil (istrm,ostrm) (redex,residue) =
 let open TextIO
     fun loop () =
       case inputLine istrm
        of NONE => ()
          | SOME ""   => ()
         | SOME line =>
            let val ssline = Substring.full line
                val (pref, suff) = Substring.position redex ssline
            in
              if Substring.size suff > 0
              then output(ostrm, residue)
              else (output(ostrm, line); loop())
            end
 in
   loop()
 end;

fun fill_holes (src,target) repls =
 let open TextIO
     val istrm = openIn src
     val ostrm = openOut target
  in
     List.app (processLinesUntil (istrm, ostrm)) repls;
     output(ostrm, inputAll istrm);
     closeIn istrm; closeOut ostrm
  end;

infix -->
fun (x --> y) = (x,y);

fun text_copy src dest = fill_holes(src, dest) [];

fun bincopy src dest = let
  val instr = BinIO.openIn src
  val outstr = BinIO.openOut dest
  fun loop () = let
    val v = BinIO.inputN(instr, 1024)
  in
    if Word8Vector.length v = 0 then (BinIO.flushOut outstr;
                                      BinIO.closeOut outstr;
                                      BinIO.closeIn instr)
    else (BinIO.output(outstr, v); loop())
  end
in
  loop()
end;


(*---------------------------------------------------------------------------
     Generate "Systeml" file in tools-poly/Holmake and then load in that file,
     thus defining the Systeml structure for the rest of the configuration
     (with OS-specific stuff available).
 ---------------------------------------------------------------------------*)

(* default values ensure that later things fail if Systeml doesn't compile *)
fun systeml x = (print "Systeml not correctly loaded.\n";
                 Process.exit Process.failure);
val mk_xable = systeml;
val xable_string = systeml;

val OSkind = if OS="linux" orelse OS="solaris" orelse OS="macosx" then "unix"
             else OS
val _ = let
  (* copy system-specific implementation of Systeml into place *)
  val srcfile = fullPath [holmakedir, OSkind ^"-systeml.sml"]
  val destfile = fullPath [holmakedir, "Systeml.sml"]
  val sigfile = fullPath [holmakedir, "Systeml.sig"]
in
  print "\nLoading system specific functions\n";
  use sigfile;
  fill_holes (srcfile, destfile)
  ["val HOLDIR ="   --> ("val HOLDIR = "^quote holdir^"\n"),
   "val POLYMLLIBDIR =" --> ("val POLYMLLIBDIR = "^quote polymllibdir^"\n"),
   "val POLY =" --> ("val POLY = "^quote poly^"\n"),
   "val CC =" --> ("val CC = "^quote CC^"\n"),
   "val OS ="       --> ("val OS = "^quote OS^"\n"),
   "val DEPDIR ="   --> ("val DEPDIR = "^quote DEPDIR^"\n"),
   "val GNUMAKE ="  --> ("val GNUMAKE = "^quote GNUMAKE^"\n"),
   "val DYNLIB ="   --> ("val DYNLIB = "^Bool.toString dynlib_available^"\n"),
   "val version ="  --> ("val version = "^Int.toString version_number^"\n"),
   "val ML_SYSNAME =" --> "val ML_SYSNAME = \"poly\"\n",
   "val release ="  --> ("val release = "^quote release_string^"\n")];
  use destfile
end;

open Systeml;

(*---------------------------------------------------------------------------
     Now compile Systeml.sml in tools-poly/Holmake/
 ---------------------------------------------------------------------------*)

let
  val _ = print "Compiling system specific functions ("
  (*val modTime = FileSys.modTime*)
  val dir_0 = FileSys.getDir()
  val sigfile = fullPath [holmakedir, "Systeml.sig"]
  val sigfile_newer = true
  val uifile = fullPath [holmakedir, "Systeml.ui"]
  fun die () = (print ")\nFailed to compile system-specific code\n";
                Process.exit Process.failure)
  val systeml = fn l => if not (Process.isSuccess (systeml l)) then die() else ()
  fun to_sigobj s = bincopy s (fullPath [holdir, "sigobj", s])
in
  FileSys.chDir holmakedir;
  let val oo = TextIO.openOut uifile
  in
    TextIO.output (oo, fullPath [holdir, "sigobj", "Systeml.sig"] ^ "\n");
    TextIO.closeOut oo
  end;
  app to_sigobj ["Systeml.sig", "Systeml.ui"];
  print "sig ";
  let val oo = TextIO.openOut (fullPath [holmakedir, "Systeml.uo"])
  in
    TextIO.output (oo, fullPath [holdir, "sigobj", "Systeml.sml"] ^ "\n");
    TextIO.closeOut oo
  end;
  app to_sigobj ["Systeml.sml", "Systeml.uo"];
  print "sml)\n";
  FileSys.chDir dir_0
end;



(*---------------------------------------------------------------------------
          String and path operations.
 ---------------------------------------------------------------------------*)

fun echo s = (TextIO.output(TextIO.stdOut, s^"\n");
              TextIO.flushOut TextIO.stdOut);

val _ = echo "Beginning configuration.";

(* ----------------------------------------------------------------------
    remove the quotation filter from the bin directory, if it exists
  ---------------------------------------------------------------------- *)

val _ = let
  val unquote = fullPath [holdir, "bin", xable_string "unquote"]
in
  if FileSys.access(unquote, [FileSys.A_READ]) then
    (print "Removing old quotation filter from bin/\n";
     FileSys.remove unquote
     handle Thread.Thread.Interrupt => raise Thread.Thread.Interrupt
          | _ => print "*** Tried to remove quotation filter from bin/ but \
                       \couldn't!  Proceeding anyway.\n")
  else ()
end



fun die s = (print s; print "\n"; Process.exit Process.failure)

local
  val cdir = FileSys.getDir()
  val systeml = fn clist => if not (Process.isSuccess (systeml clist)) then
                              raise (Fail "")
                            else ()
  val toolsdir = fullPath [holdir, "tools-poly"]
  val lexdir = fullPath [holdir, "tools", "mllex"]
  val yaccdir = fullPath [holdir, "tools", "mlyacc"]
  val qfdir = fullPath [holdir, "tools", "quote-filter"]
  val hmakedir = fullPath [toolsdir, "Holmake"]
  val hmakebin = fullPath [holdir, "bin", "Holmake"]
  val buildbin = fullPath [holdir, "bin", "build"]
  val qfbin = fullPath [holdir, "bin", "unquote"]
  val lexer = fullPath [lexdir, "mllex.exe"]
  val yaccer = fullPath [yaccdir, "src", "mlyacc.exe"]
  fun copyfile from to =
    let val instrm = BinIO.openIn from
        val ostrm = BinIO.openOut to
        val v = BinIO.inputAll instrm
    in
      BinIO.output(ostrm, v);
      BinIO.closeIn instrm;
      BinIO.closeOut ostrm
    end;
  fun remove f = (FileSys.remove f handle OS.SysErr _ => ())
in

(* Remove old files *)

val _ = remove hmakebin;
val _ = remove buildbin;
val _ = remove lexer;
val _ = remove yaccer;
val _ = remove qfbin;
val _ = remove (fullPath [hmakedir, "Lexer.lex.sml"]);
val _ = remove (fullPath [hmakedir, "Parser.grm.sig"]);
val _ = remove (fullPath [hmakedir, "Parser.grm.sml"]);


(* ----------------------------------------------------------------------
    Compile our local copy of mllex
   ---------------------------------------------------------------------- *)
val _ =
  (echo "Making tools/mllex/mllex.exe.";
   FileSys.chDir lexdir;
   system_ps (POLY ^ " < poly-mllex.ML");
   compile systeml "mllex.exe" "mllex.o";
   mk_xable "../../tools/mllex/mllex.exe";
   FileSys.chDir cdir)
   handle _ => die "Failed to build mllex.";

(* ----------------------------------------------------------------------
    Compile our local copy of mlyacc
   ---------------------------------------------------------------------- *)
val _ =
  (echo "Making tools/mlyacc/mlyacc.exe.";
   FileSys.chDir yaccdir;
   FileSys.chDir "src";
   systeml [lexer, "yacc.lex"];
   FileSys.chDir yaccdir;
   system_ps (POLY ^ " < poly-mlyacc.ML");
   compile systeml yaccer "mlyacc.o";
   mk_xable "../../tools/mlyacc/src/mlyacc.exe";
   FileSys.chDir cdir)
   handle _ => die "Failed to build mlyacc.";

(* ----------------------------------------------------------------------
    Compile quote-filter
   ---------------------------------------------------------------------- *)
val _ =
  (echo "Making bin/unquote.";
   FileSys.chDir qfdir;
   systeml [lexer, "filter"];
   system_ps (POLY ^  " < poly-unquote.ML");
   compile systeml qfbin "unquote.o";
   FileSys.chDir cdir)
   handle _ => die "Failed to build unquote.";

(*---------------------------------------------------------------------------
    Compile Holmake (bypassing the makefile in directory Holmake), then
    put the executable bin/Holmake.
 ---------------------------------------------------------------------------*)
val _ =
  (echo "Making bin/Holmake";
   FileSys.chDir hmakedir;
   systeml [lexer, "Lexer.lex"];
   systeml [yaccer, "Parser.grm"];
   FileSys.chDir toolsdir;
   system_ps (POLY ^ " < " ^ fullPath ["Holmake", "poly-Holmake.ML"]);
   compile systeml hmakebin (fullPath ["Holmake", "Holmake.o"]);
   FileSys.chDir cdir)
   handle _ => die "Failed to build Holmake.";

(*---------------------------------------------------------------------------
    Compile build.sml, and put it in bin/build.
 ---------------------------------------------------------------------------*)
val _ =
  (echo "Making bin/build.";
   FileSys.chDir toolsdir;
   system_ps (POLY ^ " < poly-build.ML");
   compile systeml buildbin "build.o";
   FileSys.chDir cdir)
   handle _ => die "Failed to build build.";


end;

(*---------------------------------------------------------------------------
    Instantiate tools-poly/hol-mode.src, and put it in tools-poly/hol-mode.el
 ---------------------------------------------------------------------------*)

val _ =
 let open TextIO
     val _ = echo "Making hol-mode.el (for Emacs/XEmacs)"
     val src = fullPath [holdir, "tools", "hol-mode.src"]
    val target = fullPath [holdir, "tools", "hol-mode.el"]
 in
    fill_holes (src, target)
      ["(defvar hol-executable HOL-EXECUTABLE\n"
        -->
       ("(defvar hol-executable \n  "^
        quote (fullPath [holdir, "bin", "hol"])^"\n")]
 end;


(*---------------------------------------------------------------------------
      Generate shell scripts for running HOL.
 ---------------------------------------------------------------------------*)

val _ =
 let val _ = echo "Generating bin/hol."
     val target      = fullPath [holdir, "bin", "hol.bare"]
     val target_boss = fullPath [holdir, "bin", "hol"]
 in
   (* "unquote" scripts use the unquote executable to provide nice
      handling of double-backquote characters *)
   emit_hol_unquote_script target "hol.builder0"
     ["prelude.ML"];
   emit_hol_unquote_script target_boss "hol.builder"
     ["prelude.ML", "prelude2.ML"];
   emit_hol_script (target ^ ".noquote") "hol.builder0"
     ["prelude.ML"];
   emit_hol_script (target_boss ^ ".noquote") "hol.builder"
     ["prelude.ML", "prelude2.ML"]
 end;

 (*

(*---------------------------------------------------------------------------
    Configure the muddy library.
 ---------------------------------------------------------------------------*)

local val CFLAGS =
        case OS
         of "linux"   => SOME " -Dunix -O3 -fPIC $(CINCLUDE)"
          | "solaris" => SOME " -Dunix -O3 $(CINCLUDE)"
          | "macosx"  => SOME " -Dunix -O3 $(CINCLUDE)"
          |     _     => NONE
      val DLLIBCOMP =
        case OS
         of "linux"   => SOME "ld -shared -o $@ $(COBJS) $(LIBS)"
          | "solaris" => SOME "ld -G -B dynamic -o $@ $(COBJS) $(LIBS)"
          | "macosx"  => SOME "gcc -bundle -flat_namespace -undefined suppress\
                              \ -o $@ $(COBJS) $(LIBS)"
          |    _      => NONE
      val ALL =
        if OS="linux" orelse OS="solaris" orelse OS="macosx"
        then SOME " muddy.so"
        else NONE
in
val _ =
 let open TextIO
     val _ = echo "Setting up the muddy library Makefile."
     val src    = fullPath [holdir, "tools-poly/makefile.muddy.src"]
     val target = fullPath [holdir, "examples/muddy/muddyC/Makefile"]
     val mosmlhome = Path.getParent polymldir
 in
   case (CFLAGS, DLLIBCOMP, ALL) of
     (SOME s1, SOME s2, SOME s3) => let
       val (cflags, dllibcomp, all) = (s1, s2, s3)
     in
       fill_holes (src,target)
       ["MOSMLHOME=\n"  -->  String.concat["MOSMLHOME=", mosmlhome,"\n"],
        "CC=\n"         -->  String.concat["CC=", CC, "\n"],
        "CFLAGS="       -->  String.concat["CFLAGS=",cflags,"\n"],
        "all:\n"        -->  String.concat["all: ",all,"\n"],
        "DLLIBCOMP"     -->  String.concat["\t", dllibcomp, "\n"]]
     end
   | _ =>  print (String.concat
                  ["   Warning! (non-fatal):\n    The muddy package is not ",
                   "expected to build in OS flavour ", quote OS, ".\n",
                   "   On winNT, muddy will be installed from binaries.\n",
                   "   End Warning.\n"])
 end
end; (* local *)
*)

val _ = print "\nFinished configuration!\n";
