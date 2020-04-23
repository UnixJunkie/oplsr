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

let train_test_dump csv_header train test =
  let train_fn = Filename.temp_file "oplsr_train_" ".csv" in
  let test_fn = Filename.temp_file "oplsr_test_" ".csv" in
  Utls.lines_to_file train_fn (csv_header :: train);
  Utls.lines_to_file test_fn (csv_header :: test);
  (train_fn, test_fn)

let shuffle_then_cut seed p train_fn =
  match Utls.lines_of_file train_fn with
  | [] | [_] -> assert(false) (* no lines or header line only?! *)
  | (csv_header :: csv_payload) ->
    let rng = BatRandom.State.make [|seed|] in
    let rand_lines = L.shuffle ~state:rng csv_payload in
    let train, test = Utls.train_test_split p rand_lines in
    train_test_dump csv_header train test

let shuffle_then_nfolds seed n train_fn =
  match Utls.lines_of_file train_fn with
  | [] | [_] -> assert(false) (* no lines or header line only?! *)
  | (csv_header :: csv_payload) ->
    let rng = BatRandom.State.make [|seed|] in
    let rand_lines = L.shuffle ~state:rng csv_payload in
    let train_tests = Utls.cv_folds n rand_lines in
    L.rev_map (fun (x, y) -> train_test_dump csv_header x y) train_tests

let csv_nb_features csv_fn =
  match Utls.unix_head 1 csv_fn with
  | [csv_header] -> BatString.count_char csv_header ' '
  | _ -> assert(false)

type mode = Load of string
          | Save of string
          | Discard

let train_test verbose save_or_load maybe_ncomp nfolds train_fn test_fn =
  let nb_features = csv_nb_features train_fn in
  let nb_features' = csv_nb_features test_fn in
  assert(nb_features = nb_features');
  let ncomp_best = match maybe_ncomp with
    | Some ncomp ->
      begin
        Log.info "ncomp: %d/%d" ncomp nb_features;
        assert(ncomp < nb_features);
        ncomp
      end
    | None ->
      let ncomp_best, train_R2 = PLS.optimize verbose train_fn nfolds in
      Log.info "ncomp_best: %d/%d trainR2: %f" ncomp_best nb_features train_R2;
      ncomp_best in
  let model_fn = match save_or_load with
    | Discard | Save _ -> PLS.train verbose train_fn ncomp_best
    | Load fn -> (assert(BatOption.is_some maybe_ncomp); fn) in
  (match save_or_load with
   | Discard | Load _ -> ()
   | Save fn -> (* copy model *)
     Utls.run_command true (sprintf "cp %s %s" model_fn fn));
  let preds = PLS.predict verbose ncomp_best model_fn test_fn in
  let actual_fn = Filename.temp_file "PLS_test_" ".txt" in
  (* NR > 1: skip CSV header line *)
  let cmd = sprintf "awk '(NR > 1){print $1}' %s > %s" test_fn actual_fn in
  Utls.run_command verbose cmd;
  let actual = Oplsr.Utls.float_list_of_file actual_fn in
  (* filesystem cleanup *)
  (if not verbose then Sys.remove actual_fn);
  (if save_or_load = Discard then Sys.remove model_fn);
  (actual, preds)

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
               [--ncomp <int>]: optimal number of PLS components\n  \
               [-np <int>]: max CPU cores\n  \
               [--NxCV <int>]: number of folds of cross validation\n  \
               [-s|--save <filename>]: save model to file\n  \
               [-l|--load <filename>]: restore model from file\n  \
               [-v]: verbose/debug mode\n  \
               [-h|--help]: show this message\n"
        Sys.argv.(0) train_portion_def;
      exit 1
    end;
  let verbose = CLI.get_set_bool ["-v"] args in
  let train_fn' = CLI.get_string ["--train"] args in
  let seed = match CLI.get_int_opt ["--seed"] args with
    | Some i -> i (* perfect reproducibility *)
    | None -> (* some randomness *)
      let () = Random.self_init () in
      Random.int 0x3FFFFFFF (* 0x3FFFFFFF = 2^30 - 1 *) in
  let maybe_test_fn = CLI.get_string_opt ["--test"] args in
  let ncores = CLI.get_int_def ["-np"] args 1 in
  let maybe_ncomp = CLI.get_int_opt ["--ncomp"] args in
  let maybe_save_model_fn = CLI.get_string_opt ["-s";"--save"] args in
  let maybe_load_model_fn = CLI.get_string_opt ["-l";"--load"] args in
  let train_portion = CLI.get_float_def ["-p"] args train_portion_def in
  let nfolds = CLI.get_int_def ["--NxCV"] args 1 in
  CLI.finalize ();
  let save_or_load = match maybe_save_model_fn, maybe_load_model_fn with
    | None, None -> Discard
    | Some fn, None -> Save fn
    | None, Some fn -> Load fn
    | Some _, Some _ -> failwith "Model: -s AND -l provided?!" in
  let actual, preds =
    if train_portion = 1.0 || nfolds <= 1 then
      (* (p = 1.0 && nfolds > 1) --> we use R pls NxCV mechanism
         to train the model without overfiting to the data *)
      let train_fn, test_fn = match maybe_test_fn with
        | None -> shuffle_then_cut seed train_portion train_fn'
        | Some test_fn' -> (train_fn', test_fn') in
      train_test verbose save_or_load maybe_ncomp nfolds train_fn test_fn
    else
      let train_test_fns = shuffle_then_nfolds seed nfolds train_fn' in
      let actual_pred_pairs =
        Parany.Parmap.parmap ~ncores (fun (x, y) ->
            (* we disable R pls NxCV here.
               Also, we don't save the model since several are build in // *)
            train_test verbose Discard maybe_ncomp 1 x y
          ) train_test_fns in
      let xs, ys = L.split actual_pred_pairs in
      (L.concat xs, L.concat ys) in
  let test_R2 = Cpm.RegrStats.r2 actual preds in
  Log.info "testR2: %f" test_R2

let () = main ()
