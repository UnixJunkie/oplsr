(* Copyright (C) 2020, Francois Berenger

   Yamanishi laboratory,
   Department of Bioscience and Bioinformatics,
   Faculty of Computer Science and Systems Engineering,
   Kyushu Institute of Technology,
   680-4 Kawazu, Iizuka, Fukuoka, 820-8502, Japan.

   Train and test a PLS regressor *)

open Printf

module CLI = Minicli.CLI
module L = BatList
module Log = Dolog.Log
module PLS = Oplsr.PLS
module Utls = Oplsr.Utls

let shuffle_then_cut seed p train_fn =
  match Utls.lines_of_file train_fn with
  | [] | [_] -> assert(false) (* no lines or header line only?! *)
  | (csv_header :: csv_payload) ->
    let state = BatRandom.State.make [|seed|] in
    let rand_lines = L.shuffle ~state csv_payload in
    let train, test = Utls.train_test_split p rand_lines in
    let train_fn = Filename.temp_file "oplsr_train_" ".csv" in
    let test_fn = Filename.temp_file "oplsr_test_" ".csv" in
    Utls.lines_to_file train_fn (csv_header :: train);
    Utls.lines_to_file test_fn (csv_header :: test);
    (train_fn, test_fn)

let main () =
  Log.(set_log_level DEBUG);
  Log.color_on ();
  Log.info "start";
  let argc, args = CLI.init () in
  let train_portion_def = 0.8 in
  let show_help = CLI.get_set_bool ["-h";"--help"] args in
  if argc = 1 || show_help then
    begin
      eprintf "usage:\n\
               %s\n  \
               --train <train.txt>: training set\n  \
               [-p <float>]: train portion; default=%f\n  \
               [--seed <int>]: RNG seed\n  \
               [--test <test.txt>]: test set\n  \
               [--NxCV <int>]: number of folds of cross validation\n  \
               [-v]: verbose/debug mode\n  \
               [-h|--help]: show this message\n"
        Sys.argv.(0) train_portion_def;
      exit 1
    end;
  let verbose = CLI.get_set_bool ["-v"] args in
  let train_fn' = CLI.get_string ["--train"] args in
  let seed = CLI.get_int_def ["--seed"] args 31415 in
  let maybe_test_fn = CLI.get_string_opt ["--test"] args in
  let train_portion = CLI.get_float_def ["-p"] args train_portion_def in
  let nfolds = CLI.get_int_def ["--NxCV"] args 5 in
  CLI.finalize ();
  let train_fn, test_fn = match maybe_test_fn with
    | None -> shuffle_then_cut seed train_portion train_fn'
    | Some test_fn' -> train_fn', test_fn' in
  let ncomp_best, train_R2 = PLS.optimize verbose train_fn nfolds in
  Log.info "ncomp_best: %d trainR2: %f" ncomp_best train_R2;
  let model_fn = PLS.train verbose train_fn ncomp_best in
  let preds = PLS.predict verbose ncomp_best model_fn test_fn in
  let actual_fn = Filename.temp_file "PLS_test_" ".txt" in
  (* NR > 1: skip CSV header line *)
  let cmd = sprintf "awk '(NR > 1){print $1}' %s > %s" test_fn actual_fn in
  Utls.run_command verbose cmd;
  let actual = Oplsr.Utls.float_list_of_file actual_fn in
  if not verbose then Sys.remove actual_fn;
  let test_R2 = Cpm.RegrStats.r2 actual preds in
  Log.info "testR2: %f" test_R2

let () = main ()
