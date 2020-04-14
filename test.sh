#!/bin/bash

set -x

make

_build/default/src/test.exe --train data/solubility_train_std_01.csv \
                            --test data/solubility_test_std_01.csv -v
