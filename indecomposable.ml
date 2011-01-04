open Algebra
open Theory
open Util

(* It is assumed that the two algebras correspond to the same signature. Furthermore, an error
   occurs if there are predicates or relations. *)
let product {alg_size=n1; alg_name=a1; alg_prod=p1; alg_const=c1; alg_unary=u1; alg_binary=b1; alg_predicates=pr1; alg_relations=r1}
            {alg_size=n2; alg_name=a2; alg_prod=p2; alg_const=c2; alg_unary=u2; alg_binary=b2; alg_predicates=pr2; alg_relations=r2} =
  if Array.length pr1 <> 0 || Array.length r1 <> 0 || Array.length pr2 <> 0 || Array.length r2 <> 0
  then Error.fatal "cannot form products of structures with predicates and relations"
  else begin
    let size = n1 * n2 in
    let mapping i j = n2 * i + j in
      (* IMPORTANT: combine_unary and combine_binary assume that algebras are "synced". *)
    let combine_unary arr1 arr2 =
      let arr = Array.make size 0 in
        for k = 0 to n1 - 1 do
          for l = 0 to n2 - 1 do
            arr.(mapping k l) <- mapping arr1.(k) arr2.(l)
          done
        done ;
        arr
    in
    let combine_binary arr1 arr2 =
      let arr = Array.make_matrix size size 0 in
        for k = 0 to n1 - 1 do
          for l = 0 to n2 - 1 do
            for i = 0 to n1 - 1 do
              for j = 0 to n2 - 1 do
                arr.(mapping k l).(mapping i j) <- mapping arr1.(k).(i) arr2.(l).(j)
              done
            done
          done
        done ;
        arr
    in
    let const = Util.array_map2 mapping c1 c2 in
    let unary = Util.array_map2 combine_unary u1 u2 in
    let binary = Util.array_map2 combine_binary b1 b2 in
      { alg_size = size;
        alg_name = None;
        alg_prod = Util.alg_prod a1 a2 p1 p2;
        alg_const=const;
        alg_unary=unary;
        alg_binary=binary;
        alg_predicates=pr1;
        alg_relations=r1;
      }
  end

(* factors is a map of possible factors (algebras paired with invariants) *)
let gen_decomposable theory n factors output = 
  let algebras = ref [] in
    
  (* Generate all products of algebras which partition into algebras of sizes in partition.
     partition is assumed to be in some order (descending or ascending). *)
  let gen_product partition = 
    (* last is size of last algebra added to product, start is where to start
       with current algebras (this is only used if we have to multiply two consecutive 
       algebras of the same size), part is the tail of partition *)
    let rec gen_p last start acc = function
      | [] ->
          if First_order.check_axioms theory acc then
            let a = with_invariant acc in
              if not (Iso.seen theory a !algebras)
              then begin
                algebras := a :: !algebras ;
                output acc
              end
      | (p::ps) -> 
          let start = if last = p then start else 0 in
          let last = p in
            Util.iter_enum
              (fun i (a,_) -> if i >= start then gen_p last i (product acc a) ps)
              (IntMap.find last factors)
    in
      match partition with
        | [] -> ()
        | p::ps -> List.iter (fun (a,_) -> gen_p p 0 a ps) (IntMap.find p factors)
  in (* end of gen_product *)
    List.iter gen_product (Util.partitions n) ;
    !algebras
