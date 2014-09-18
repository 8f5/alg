(* Options for command-line arguments. *)

type config = {
  mutable sizes : int list;
  mutable indecomposable_only : bool;
  mutable count_only : bool;
  mutable products : bool;
  mutable source : bool;
  mutable input_filename : string;
  mutable output_filename : string;
  mutable format : string;
  mutable paranoid : bool;
  mutable use_sat : bool;
  mutable load_file : string option;
  mutable save_file : string option;
  mutable location : string option;
  mutable groups : int list;
  mutable counter_example_to : string option;
}

let default = {
  sizes = [];
  indecomposable_only = false;
  count_only = false;
  products = true;
  source = true;
  input_filename = "";
  output_filename = "";
  format = "";
  paranoid = false;
  use_sat = false;
  load_file = None;
  save_file = None;
  location = None;
  groups = [];
  counter_example_to = None; 
}
