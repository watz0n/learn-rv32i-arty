#!/bin/bash
# Remove generated meta-data
find -maxdepth 1 | grep -E '.*[0-9](.in|.out|.cmd)$' | xargs rm -rf
# Remove tester directory
rm -rf test_run_dir
rm -rf ./project/project
rm -rf ./project/target
rm -rf ./target
