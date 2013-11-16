open Theory
open Algebra
open Util

module EPR=Enum_predicate_relation

(* General helper functions for partitioning axioms. *)

(* Select axioms that refer only to unary operations and constants. *)
let part_axioms axioms =
  let rec no_binary = function
    | Binary _ -> false
    | Unary (_, t) -> no_binary t
    | Var _ | Const _ | Elem _ -> true in
  let no_binary_axiom (eq1, eq2) = no_binary eq1 && no_binary eq2 in
    List.partition (apply_to_snd no_binary_axiom) axioms

(*
  Partition unary axioms. In the first part are the axioms of the form
  f(a) = b, where a and b are constants, and the rest in the second one.
*)
let part_unary_axioms axioms =
  let is_simple = function
    | (Unary (_,Const _), Const _)
    | (Const _, Unary (_,Const _)) -> true
    | _ -> false
  in List.partition (apply_to_snd is_simple) axioms

(*
  Partition binary axioms into two parts. In the first are axioms of the form
  a + b = c, where a b and c are constants or unary applications, these are termed simple,
  and the rest are in the second part, these I call complicated.
*)
let part_binary_axioms axioms =
  let rec const_and_unary = function
    | (Unary (_,t)) -> const_and_unary t
    | (Const _ ) -> true
    | _ -> false in
  let is_simple = function
    | (Binary (_,t1,t2), Const _)
    | (Const _, Binary (_,t1,t2)) -> const_and_unary t1 && const_and_unary t2
    | _ -> false
  in List.partition (apply_to_snd is_simple) axioms

(*
  Partition binary axioms into two parts.
  The first:
  axioms f(a) * g(a) = h(a) or some of the expressions contain a constant
  The second:
  all the rest. :)
  We can immediately apply the first kind.
*)

let part_one_var_binary axioms =
  let rec const_var_unary = function
    | (Unary (_,t)) -> const_var_unary t
    | (Const c ) -> Some (Const c)
    | (Var v) -> Some (Var v)
    | _ -> None in
  let is_simple = function
    | (num_vars, (Binary (_,t1,t2), t3))
    | (num_vars, (t3, Binary (_,t1,t2))) ->
        let v1 = const_var_unary t1 in
        let v2 = const_var_unary t2 in
        let v3 = const_var_unary t3 in
          begin
            match (v1,v2,v3) with
              | (None,_,_) | (_,None,_) | (_,_,None) -> false
              | _ -> num_vars <= 1
          end
    | _ -> false
  in List.partition is_simple axioms

(* Select associativity axioms. *)
let partition_assoc axioms =
  let is_assoc = function
    | (Binary (op1, Binary (op2, Var a1, Var b1), Var c1), Binary (op3, Var a2, Binary (op4, Var b2, Var c2)))
    | (Binary (op3, Var a2, Binary (op4, Var b2, Var c2)), Binary (op1, Binary (op2, Var a1, Var b1), Var c1))
        when op1 = op2 && op2 = op3 && op3 = op4 && 
          a1 = a2 && b1 = b2 && c1 = c2 && 
          a1 <> b1 && a1 <> c1 && b1 <> c1 -> true
    | _ -> false
  in List.partition (apply_to_snd is_assoc) axioms

let make_3d_array x y z initial =
  Array.init x (fun _ -> Array.make_matrix y z initial)

(*
  List of distinct variables of a term.
*)
let rec eq_vars acc = function
  | Const _ | Elem _ -> acc
  | Var v -> if List.mem v acc then acc else (v :: acc)
  | Binary (_,t1,t2) -> let lv = eq_vars acc t1 in
      eq_vars lv t2
  | Unary (_,t) -> eq_vars acc t

(*
  List of distinct variables of an axiom.
*)
let dist_vars (_,(left, right)) =
  let lv = eq_vars [] left in eq_vars lv right

(*
  Number of distinct variables in an axiom.
  Could also look for maximum variable index.
*)
let num_dist_vars (num_vars,_) = num_vars

(* Amenable axioms are the ones where left and right terms have binary op
   as outermost operation and have exactly the same variables on left and right sides or
   one outermost operation is binary and variables of the other side are a subset of
   variables in binary operation. This restriction of variables is necessary as otherwise
   we never get any information out of evaluation of the other side. *)
let partition_amenable axioms =
  let is_amenable ((left, right) as axiom) =
    match axiom with
      | (Binary _, Binary _)->
          List.sort compare (eq_vars [] left) = List.sort compare (eq_vars [] right)
      | ((Binary _), _) -> Util.is_sublist (eq_vars [] right) (eq_vars [] left)
      | (_, (Binary _)) -> Util.is_sublist (eq_vars [] left) (eq_vars [] right)
      | _ -> false in
    List.partition (apply_to_snd is_amenable) axioms


(*
  Enumerate all algebras of a given size for the given theory
  and pass them to the given continuation.
*)
let enum n ({th_const=const;
             th_unary=unary;
	         th_binary=binary;
	         th_relations=relations;
	         th_predicates=predicates;
	         th_equations=axioms} as th) k =
  if n >= Array.length const then
    try begin
      let lc = Array.length const in
      let lu = Array.length unary in
      let lb = Array.length binary in
      let lp = Array.length predicates in
      let lr = Array.length relations in

      (* empty algebra *)

      (* Main operation tables for unary operations. *)
      let unary_arr = Array.make_matrix lu n (-1) in
      (*
        Main operation tables for binary operations.
      *)
      let binary_arr = make_3d_array lb n n (-1) in

      (* Main operation tables for predicates. *)
      let pred_arr = Array.make_matrix lp n (-1) in
      (*
        Main operation tables for relations.
      *)
      let rel_arr = make_3d_array lr n n (-1) in
      
      let alg = {alg_size = n;
                 alg_name = None;
                 alg_prod = None;
                 alg_const = Array.init lc (fun k -> k);
                 alg_unary = unary_arr;
                 alg_binary = binary_arr;
                 alg_predicates = pred_arr;
                 alg_relations = rel_arr
                } in
                 
      (* Auxiliary variables for generation of unary operations. *)
      (* ******************************************************* *)
      let (unary_axioms, binary_axioms) = part_axioms axioms in
        (*
          Simple and complicated unary axioms. Simple are the
          ones of the form f(c) = d or f(d) = c for c and d constants. These
          can be easily applied.
          TODO: Axioms of the form f(x) = c for x variable and c constant
          are also easily dispatched with.

          Complicated are the complement of simple and cannot be so easily applied.
        *)
      let (simple', complicated') = part_unary_axioms unary_axioms in
      let simple = List.map snd simple' in
      let complicated = List.map snd complicated' in

      let normal_axioms = Enum_unary.get_normal_axioms complicated in
        
      let (unary_dos, unary_undos) = Enum_unary.get_unary_actions normal_axioms alg in
        
        Enum_unary.apply_simple simple alg ;

        for o=0 to lu - 1 do
          for i=0 to n-1 do
            if unary_arr.(o).(i) <> -1 && not (unary_dos (o,i)) then
              Error.runtime_error "All of the axioms cannot be met." (* TODO: raise exception and catch it in main loop. *)
          done
        done ;

        (* Auxiliary variables for generation of binary operations. *)
        (* ******************************************************* *)
        let (simple_binary, complicated_binary) = part_binary_axioms binary_axioms in

        (*
          left are the axioms which cannot be immediately applied
          These include axioms of depth > 1 and those with more variables.
        *)
        let (one_var_shallow, left) = part_one_var_binary complicated_binary in

        (*
          Partition axioms. Assoc and amenable are naturally associativity and amenable axioms.
          zippep_axioms are the rest that have to be checked differently than amenable.
          Zipped means in the form (number of distinct variables, axioms)
        *)
        let (assoc, amenable, stubborn) =
          let (assoc, rest) = partition_assoc left in
          let (amenable, rest) = partition_amenable rest in
            (assoc,
             amenable,
             (* Check axioms with fewer free variables first. *)
             List.sort (fun (n,_) (m,_) -> compare n m) rest
            )
        in

        (*
          Maximum distinct variables in any of the axioms left. This is needed so we can cache
          all the ntuples.
        *)
        let max_vars = List.fold_left max 0 (List.map (fun (v,_) -> v) stubborn) in

        (* This could potentially gobble up memory. TODO *)
        let all_tuples = Array.init (max_vars + 1) (fun i -> ntuples n i) in


        let check = Enum_binary.get_checks all_tuples alg stubborn in
        
        let (binary_dos, binary_undos, reset_stack) = Enum_binary.get_binary_actions alg assoc amenable in

        let reset_binary_arr () =
          for o=0 to lb-1 do
            for i=0 to n-1 do
              for j=0 to n-1 do
                binary_arr.(o).(i).(j) <- -1
              done
            done
          done in
          
        let check_after_add () =
          for o=0 to lb-1 do
            for i=0 to n-1 do
              for j=0 to n-1 do
                if binary_arr.(o).(i).(j) <> -1 && not (binary_dos (o,i,j) o i j) then
                  raise Enum_binary.Contradiction
              done
            done
          done in
        let reset_predicates () =
          for o=0 to lp-1 do
            for i=0 to n-1 do
              pred_arr.(o).(i) <- -1
            done
          done in
        let reset_relations () =
          for o=0 to lr-1 do
            for i=0 to n-1 do
              for j=0 to n-1 do
                rel_arr.(o).(i).(j) <- -1
              done
            done
          done in
        let cont_rel_pred () = 
          reset_predicates () ;
          reset_relations () ;
          EPR.gen_predicate th alg 
            (fun () -> EPR.gen_relation th alg (fun () -> k alg)) in
        let cont_binary () =
          try
            reset_binary_arr () ;
            reset_stack () ;
            Enum_binary.apply_simple_binary simple_binary alg ;
            Enum_binary.apply_one_var_shallow one_var_shallow alg ;
            check_after_add () ; (* TODO: Move this into the above functions. *)
            if not (check ()) then raise Enum_binary.Contradiction ; (* We might be lucky and fill everything already. *)
            Enum_binary.gen_binary th alg binary_dos binary_undos check cont_rel_pred
          with Enum_binary.Contradiction -> () in
          
          Enum_unary.gen_unary th unary_dos unary_undos alg cont_binary
    end
    with InconsistentAxioms -> ()
