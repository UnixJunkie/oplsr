
open Printf

module CLI = Minicli.CLI
module L = BatList
module Log = Dolog.Log
module PLS = Oplsr.PLS

let main () =
  Log.(set_log_level DEBUG);
  Log.color_on ();
  let _argc, args = CLI.init () in
  let verbose = CLI.get_set_bool ["-v"] args in
  let train_fn = CLI.get_string ["--train"] args in
  let test_fn = CLI.get_string ["--test"] args in
  let nb_features = CLI.get_int ["-n"] args in
  let nfolds = CLI.get_int_def ["--NxCV"] args 10 in
  let ncomp_best, val_R2 = PLS.optimize verbose nb_features train_fn nfolds in
  Log.info "ncomp_best: %d trainR2: %f" ncomp_best val_R2;
  let model_fn = PLS.train verbose nb_features train_fn ncomp_best in
  let preds = PLS.predict verbose ncomp_best model_fn nb_features test_fn in
  let actual_fn = Filename.temp_file "PLS_test_" ".txt" in
  ignore(Sys.command (sprintf "cut -d' ' -f1 %s > %s" test_fn actual_fn));
  let actual = Oplsr.Utls.float_list_of_file actual_fn in
  Sys.remove actual_fn;
  let test_R2 = Cpm.RegrStats.r2 actual preds in
  Log.info "testR2: %f" test_R2

let () = main ()
