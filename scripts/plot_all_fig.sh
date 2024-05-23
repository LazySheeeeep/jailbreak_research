#!/bin/bash

cwd="$(dirname "$(readlink -f "$0")")"
repo_root=$cwd/..

for i in {1..8}; do
    python $repo_root/scripts/analysis_fig_gen.py -mid $i
done
python $repo_root/scripts/analysis_fig_gen.py -mid 10
