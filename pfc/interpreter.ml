use "parser.ml";


(* subst : term -> string -> term -> term *)

fun subst (AST_IF (e1, e2, e3)) x t = AST_IF ((subst e1 x t), (subst e2 x t), (subst e3 x t))
|   subst (AST_APP (e1, e2)) x t = AST_APP ((subst e1 x t), (subst e2 x t))
|   subst (AST_ID v) x t = if v=x then t else AST_ID v
|   subst (AST_FUN (v, e)) x t = AST_FUN (v, if v=x then e else (subst e x t)) 
|   subst (AST_REC (v, e)) x t = AST_REC (v, if v=x then e else (subst e x t)) 
|   subst e _ _ = e

(*  
  subst (AST_APP (AST_SUCC,AST_ID "x")) "x" (AST_NUM 1);
  val it = AST_APP (AST_SUCC,AST_NUM 1) : term
  subst (parsestr "(fn x => succ x) (pred x)") "x" (AST_NUM 3);
  val it =
    AST_APP
      (AST_FUN ("x",AST_APP (AST_SUCC,AST_ID "x")),AST_APP (AST_PRED,AST_NUM 3))
    : term
*)

(*  interp : term -> term *)

(* TODO: finish the interpreter up *)
fun interp (AST_IF (e1, e2, e3)) = AST_ERROR "rules (5) and (6) not implemented"
	| interp (AST_APP (e1, e2)) = (case (interp e1, interp e2) of (AST_ERROR s, _)	  => AST_ERROR s
																| (_, AST_ERROR s) => AST_ERROR s
                                | (AST_SUCC, AST_NUM n)   => AST_NUM (n+1)
                              	| (AST_SUCC, _)           => AST_ERROR "succ needs int argument"
                              	| (_, _) => AST_ERROR "other function applications not implemented")

(*  Once you have defined interp, you can try out simple examples by
      interp (parsestr "succ (succ 7)");
    and you can try out larger examples by
      interp (parsefile "factorial.pcf");
*)