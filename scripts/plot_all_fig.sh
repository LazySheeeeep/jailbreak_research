#!/bin/bash

cwd="$(dirname "$(readlink -f "$0")")"
repo_root=$cwd/..

for i in {1..8}; do
    python $repo_root/scripts/per_model_analysis_fig_gen.py -mid $i
done

python $repo_root/scripts/all_results_analysis_fig_gen.py
