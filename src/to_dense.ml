
(* read a molenc output file (.txt) and output it in dense csv format for R *)

open Printf

module CLI = Minicli.CLI
module Log = Dolog.Log

let main () =
  Log.color_on ();
  Log.set_log_level Log.INFO;
  Log.info "start";
  let argc, args = CLI.init () in
  let show_help = CLI.get_set_bool ["-h";"--help"] args in
  if argc = 1 || show_help then
    (eprintf "usage:\n\
              %s -i <molecules.txt>\n"
       Sys.argv.(0);
     exit 1);
  let input_fn = CLI.get_string ["-i"] args in
  Oplsr.Utls.iter_on_lines_of_file input_fn (fun line ->
      try
        Scanf.sscanf line "%s,%f,%s" (fun _name pIC50 fp_str ->
            printf "%f %s\n" pIC50 fp_str
          )
      with exn ->
        (Log.error "cannot parse: %s" line;
         raise exn)
    )

let () = main ()
