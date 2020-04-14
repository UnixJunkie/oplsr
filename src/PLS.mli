(* Copyright (C) 2020, Francois Berenger

   Yamanishi laboratory,
   Department of Bioscience and Bioinformatics,
   Faculty of Computer Science and Systems Engineering,
   Kyushu Institute of Technology,
   680-4 Kawazu, Iizuka, Fukuoka, 820-8502, Japan. *)

(** [(nb_comp_opt, r2) = optimize debug nb_features train_csv_fn nb_folds]
    Optimize a Partial Least Square (PLS) model.
    Especially, the optimal number of components is found,
    as well as the corresponding R^2 (a model regression performance metric
    in [0:1]; near zero is dangerous, near one is good).
    [debug] is a verbosity flag.
    [nb_features] is the number of features of each data item.
    [train_csv_fn] is the name of the CSV file holding your data.
    This file must have the value to model in the first column (Y),
    all other columns are feature values (X_i).
    This file must be in space-separated dense format.
    Its first line is a CSV header (column numbers are fine).
    [nb_folds] is the number of folds of cross validation;
    five or ten is standard for this one. *)
val optimize: bool -> int -> string -> int -> int * float

(** [trained_model_fn = train debug nb_features train_csv_fn nb_comp_opt]
    train a model using the given (optimal) number of components.
    The filename where the model is stored is returned. *)
val train: bool -> int -> string -> int -> string

(** [predictions = \
    predict debug nb_comp_opt trained_model_fn nb_features test_csv_fn]
    predict using a trained model stored in [trained_model_fn],
    given the optimal number of components [nb_comp_opt] and
    the number of features in each data element [nb_features], reading
    data to predict from [test_csv_fn].
    The raw list of predicted values is returned. *)
val predict: bool -> int -> string -> int -> string -> float list
