open Type

(* Generate names for a given size and signature. *)
let names n {th_const=const; th_unary=unary; th_binary=binary} =
  let forbidden_names = Array.to_list const @ Array.to_list unary @ Array.to_list binary in
  let default_names = 
    List.filter (fun x -> not (List.mem x forbidden_names))
      ["a"; "b"; "c"; "d"; "e"; "f"; "g"; "h"; "i"; "j"; "k"; "l"; "m";
       "n"; "o"; "p"; "q"; "e"; "r"; "s"; "t"; "u"; "v"; "x"; "y"; "z";
       "A"; "B"; "C"; "D"; "E"; "F"; "G"; "H"; "I"; "J"; "K"; "L"; "M";
       "N"; "O"; "P"; "Q"; "R"; "S"; "T"; "U"; "V"; "W"; "X"; "Y"; "Z"]
  in
  let i = Array.length const in
  let j = List.length default_names in
    Array.init n (fun k -> 
                    if k < i then const.(k)
                    else if k - i < j then List.nth default_names (k-i)
                    else "x" ^ string_of_int (k-i-j))

(* Print an algebra to standard output, with given names that were
   precomputed earlier. It would be better to use the Format module here. *)
let algebra names
    {th_unary=unary_names; th_binary=binary_names}
    {alg_size=n; alg_const=const; alg_unary=unary; alg_binary=binary} =
  Printf.printf "\n\n=======================================================================\n\n";
  Array.iteri (fun op t -> 
                 Printf.printf " %s " unary_names.(op) ;
                 for i = 0 to n-1 do
                   Printf.printf "| %s " names.(i)
                 done ;
                 Printf.printf "\n---" ;
                 for i = 0 to n-1 do
                   Printf.printf "+---"
                 done;
                 Printf.printf "\n   " ;
                 for i = 0 to n-1 do
                   Printf.printf "| %s " names.(t.(i))
                 done ;
                 Printf.printf "\n\n"
              ) unary ;
  Array.iteri (fun op t -> 
                 Printf.printf "\n\n %s " binary_names.(op) ;
                 for i = 0 to n-1 do
                   Printf.printf "| %s " names.(i)
                 done ;
                 for i = 0 to n-1 do
                   Printf.printf "\n---" ;
                   for j = 0 to n-1 do
                     Printf.printf "+---"
                   done ;
                   Printf.printf "\n %s " names.(i) ;
                   for j = 0 to n-1 do
                     Printf.printf "| %s " names.(t.(i).(j))
                   done
                 done ;
                 Printf.printf "\n"
              ) binary ;
  Printf.printf "%!" (* flush *)
