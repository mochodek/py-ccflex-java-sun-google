#!/bin/sh

LOCATIONS_CONFIG="./locations_mo.json"
CLASSES_CONFIG="./block_classes.json"
FILES_FORMAT_CONFIG="./files_format.json"
MANUAL_FEATURES_CONFIG="./manual_features.json"
CLASSIFIERS_CONFIG="./classifiers_options.json"
FEATURE_SELECTORS_CONFIG="./feature_selectors_options.json"


active_learning  --input_files "train-manual-and-bow.csv" "classify-manual-and-bow.csv" --output_file "comments-input.csv" --max_lines 500000 --use_existing_labels  --base_learner "RandomForest" --add_contents --locations_config $LOCATIONS_CONFIG --files_format_config $FILES_FORMAT_CONFIG --classifiers_options $CLASSIFIERS_CONFIG --classes_config $CLASSES_CONFIG



