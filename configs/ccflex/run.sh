#!/bin/sh

LOCATIONS_CONFIG="./locations.json"
CLASSES_CONFIG="./classes.json"
BLOCK_CLASSES_CONFIG="./block_classes.json"
FILES_FORMAT_CONFIG="./files_format.json"
MANUAL_FEATURES_CONFIG="./manual_features.json"
CLASSIFIERS_CONFIG="./classifiers_options.json"
FEATURE_SELECTORS_CONFIG="./feature_selectors_options.json"

TRAIN_LOCATION="train"
CLASSIFY_LOCATION="classify"

# Processing options
CREATE_WORKSPACE=false
LINES=true
FEATURES=true
CONTEXT=true
CLASSIFY=false
REPORT=false
TEAR_DOWN=false

# MAX_GRAM could be 1, 2 or 3 used for bag of words
MIN_NGRAM=1
MAX_NGRAM=3

# If CONTEXT set to true how many lines
CONTEXT_LINES_PREV=1
CONTEXT_LINES_FRWD=1

# Available extractors "PatternSubstringExctractor PatternWordExtractor WholeLineCommentFeatureExtraction CommentStringExtractor NoWordsExtractor NoCharsExtractor"
MANUAL_FEATURE_EXTRACTORS="PatternSubstringExctractor PatternWordExtractor WholeLineCommentFeatureExtraction NoWordsExtractor NoCharsExtractor"

CLASSIFIERS=( "CART" "RandomForest")


$FEATURES  && vocabulary_extractor "${TRAIN_LOCATION}-lines.csv"  "java-vocabulary.csv" \
	--skip_generating_base_vocabulary \
	--top_words_threshold 200 \
	--token_signature_for_missing \
	--min_ngrams $MIN_NGRAM --max_ngrams $MAX_NGRAM \
	--locations_config $LOCATIONS_CONFIG \
	--files_format_config $FILES_FORMAT_CONFIG

# Manual features
$FEATURES  && predefined_manual_features "$TRAIN_LOCATION" \
	--extractors $MANUAL_FEATURE_EXTRACTORS \
	--add_decision_class \
	--add_contents \
	--locations_config $LOCATIONS_CONFIG \
	--manual_features_config $MANUAL_FEATURES_CONFIG

# Bag of words
$FEATURES && bag_of_words "${TRAIN_LOCATION}" "java-vocabulary.csv" \
	--min_ngrams $MIN_NGRAM --max_ngrams $MAX_NGRAM \
	--token_signature_for_missing \
	--add_decision_class --add_contents \
	--locations_config $LOCATIONS_CONFIG \
	--files_format_config $FILES_FORMAT_CONFIG \
	--chunk_size 10000


$FEATURES && merge_inputs --input_files  "${TRAIN_LOCATION}-manual.csv" "${TRAIN_LOCATION}-bag-of-words.csv" \
	--output_file "${TRAIN_LOCATION}-features.csv" \
	--add_decision_class \
	--add_contents \
	--locations_config $LOCATIONS_CONFIG \
	--files_format_config $FILES_FORMAT_CONFIG

$FEATURES && copy_feature_file "${TRAIN_LOCATION}-features.csv" "${TRAIN_LOCATION}-features-tmp.csv" \
   --locations_config $LOCATIONS_CONFIG
	
# Block comments
$FEATURES && extract_block_features_from_features "${TRAIN_LOCATION}-features.csv" "${TRAIN_LOCATION}-comments.csv" "block_comment" --feature_start "/ *"  --feature_end "* /"  \
	--add_contents \
	--locations_config $LOCATIONS_CONFIG \
	--files_format_config $FILES_FORMAT_CONFIG
	
$FEATURES && merge_inputs --input_files "${TRAIN_LOCATION}-features-tmp.csv" "${TRAIN_LOCATION}-comments.csv" \
	--output_file "${TRAIN_LOCATION}-features.csv" \
	--add_decision_class \
	--add_contents \
	--locations_config $LOCATIONS_CONFIG \
	--files_format_config $FILES_FORMAT_CONFIG

$FEATURES && copy_feature_file "${TRAIN_LOCATION}-features.csv" "${TRAIN_LOCATION}-features-tmp.csv" \
    --locations_config $LOCATIONS_CONFIG
	
# Blocks
$FEATURES && extract_block_features_from_features "${TRAIN_LOCATION}-features.csv" "${TRAIN_LOCATION}-blocks.csv" "block_code" --feature_start "{"  --feature_end "}"  \
	--add_contents \
	--locations_config $LOCATIONS_CONFIG \
	--forbidding_features "block_comment" "whole_line_comment" \
	--files_format_config $FILES_FORMAT_CONFIG

$FEATURES && merge_inputs --input_files "${TRAIN_LOCATION}-features-tmp.csv" "${TRAIN_LOCATION}-blocks.csv" \
	--output_file "${TRAIN_LOCATION}-features.csv" \
	--add_decision_class \
	--add_contents \
	--locations_config $LOCATIONS_CONFIG \
	--files_format_config $FILES_FORMAT_CONFIG
$FEATURES && copy_feature_file "${TRAIN_LOCATION}-features.csv" "${TRAIN_LOCATION}-features-tmp.csv" \
   --locations_config $LOCATIONS_CONFIG

# Feature selection low variance
$FEATURES && select_features "${TRAIN_LOCATION}-features.csv" "low_var_features.csv" \
	--feature_selector "VarianceThreshold" \
	--locations_config $LOCATIONS_CONFIG \
	--files_format_config $FILES_FORMAT_CONFIG \
	--feature_selectors_options $FEATURE_SELECTORS_CONFIG \
	--classifiers_options $CLASSIFIERS_CONFIG

$FEATURES && apply_features_selection "${TRAIN_LOCATION}-features-tmp.csv" "${TRAIN_LOCATION}-features-low-var.csv" "low_var_features.csv" \
	--locations_config $LOCATIONS_CONFIG \
	--files_format_config $FILES_FORMAT_CONFIG \
	--chunk_size 10000

# Feature selection
select_features "${TRAIN_LOCATION}-features-low-var.csv" "selected_features.csv" \
	--feature_selector "SelectFpr" \
	--locations_config $LOCATIONS_CONFIG \
	--files_format_config $FILES_FORMAT_CONFIG \
	--feature_selectors_options $FEATURE_SELECTORS_CONFIG \
	--classifiers_options $CLASSIFIERS_CONFIG

apply_features_selection "${TRAIN_LOCATION}-features-low-var.csv" "${TRAIN_LOCATION}-features-lv-fpr.csv" "selected_features.csv" \
	--locations_config $LOCATIONS_CONFIG \
	--files_format_config $FILES_FORMAT_CONFIG \
	--chunk_size 10000
	
	
# Conext
$FEATURES && $CONTEXT && add_seq_context  "${TRAIN_LOCATION}-features-tmp.csv" "ctx-${TRAIN_LOCATION}-features.csv" \
	--prev_cases $CONTEXT_LINES_PREV --next_cases $CONTEXT_LINES_FRWD \
	--add_decision_class \
	--add_contents \
	--locations_config $LOCATIONS_CONFIG \
	--files_format_config $FILES_FORMAT_CONFIG
$FEATURES && $CONTEXT && copy_feature_file "ctx-${TRAIN_LOCATION}-features.csv" "ctx-${TRAIN_LOCATION}-features-tmp.csv" \
    --locations_config $LOCATIONS_CONFIG


# Feature selection low variance
$FEATURES && select_features "ctx-${TRAIN_LOCATION}-features.csv" "ctx-low_var_features.csv" \
	--feature_selector "VarianceThreshold" \
	--locations_config $LOCATIONS_CONFIG \
	--files_format_config $FILES_FORMAT_CONFIG \
	--feature_selectors_options $FEATURE_SELECTORS_CONFIG \
	--classifiers_options $CLASSIFIERS_CONFIG

$FEATURES && apply_features_selection "ctx-${TRAIN_LOCATION}-features-tmp.csv" "ctx-${TRAIN_LOCATION}-features-low-var.csv" "ctx-low_var_features.csv" \
	--locations_config $LOCATIONS_CONFIG \
	--files_format_config $FILES_FORMAT_CONFIG \
	--chunk_size 10000

# Feature selection
select_features "ctx-${TRAIN_LOCATION}-features-low-var.csv" "ctx-selected_features.csv" \
	--feature_selector "SelectFpr" \
	--locations_config $LOCATIONS_CONFIG \
	--files_format_config $FILES_FORMAT_CONFIG \
	--feature_selectors_options $FEATURE_SELECTORS_CONFIG \
	--classifiers_options $CLASSIFIERS_CONFIG

apply_features_selection "ctx-${TRAIN_LOCATION}-features-low-var.csv" "ctx-${TRAIN_LOCATION}-features-lv-fpr.csv" "ctx-selected_features.csv" \
	--locations_config $LOCATIONS_CONFIG \
	--files_format_config $FILES_FORMAT_CONFIG \
	--chunk_size 10000


	
	





