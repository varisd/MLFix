#!/usr/bin/env python

import os, sys, argparse
import gzip
import model

# "Constants"
features_ignore_regex = [ "lemma", "form", "tag" ]
features_ignore = [ "old_node_id", "wrong_form_1", "wrong_form_2" ]

def ignored_field (feature_name):
    #features_ignore_regex = [ "lemma", "form", "tag" ]
    ignored = False;
    for regex in features_ignore_regex:
        if regex in feature_name:
            ignored = True
    return ignored 

## Main Program ##

# Parse command line arguments
parser = argparse.ArgumentParser(description="Train a Scikit-Learn classification model.")
parser.add_argument('train', metavar='training_data', type=str)
parser.add_argument('target', metavar='predicted_category', type=str)
parser.add_argument('model_type', metavar='model_type', type=str)
parser.add_argument('model_params', metavar='model_parameters', type=str)
parser.add_argument('output', metavar='output_file', type=str)
parser.add_argument('feat_ratio', metavar='feat_ratio', nargs='?', type=float, default=1.0)
args = parser.parse_args()

fh = gzip.open(args.train, 'rb', 'UTF-8')
line = fh.readline().rstrip("\n")
feature_names =  line.split("\t")
targets = args.target.split('|')
model_type = args.model_type
feat_ratio= args.feat_ratio

registered_feat_names = dict()

# some models doesn't support sparse matrices
dense_models = ["extra_trees", "random_forest"]
sparse = True
if model_type in dense_models:
    sparse = False

# Prepare the data
train_X = []
train_Y = []
while True:
    line = fh.readline().rstrip("\n")
    if not line:
        break
    feat_values = line.split("\t")
    feat_row = dict()
    target_row = dict()
    
    for i in range(len(feature_names)):
        # Collect target values for the other classifiers
        if feature_names[i] in targets:
            target_row.update({feature_names[i]:feat_values[i]})
        elif "new" not in feature_names[i] and not feature_names[i] in features_ignore and not ignored_field(feature_names[i]) and feat_values[i] != "":
            feat_row.update({feature_names[i]:feat_values[i]})
            registered_feat_names.update({feature_names[i]:1})
    train_X.append(feat_row)
    train_Y.append(target_row)

# Train and save model
n_features = int(feat_ratio * len(registered_feat_names.keys()))
if n_features > len(feature_names):
    raise ValueError(n_features)

m = model.Model(model_type, args.model_params, sparse, n_features)
m.fit(train_X, train_Y)
model.saveModel(m, args.output)
