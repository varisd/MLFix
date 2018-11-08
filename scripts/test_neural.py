#!/usr/bin/env python

from __future__ import division
import os, sys, argparse
import csv
import datetime
import gzip
import numpy as np
import neural

seed=42
#features_ignore_regex = [ "agr", "new", "src", "sibling", "lemma", "form", "tag", "old_node_id", "wrong_form_1", "wrong_form_2", "wrong_form_3" ]
features_ignore_regex = [ "agr", "old_node_lemma", "new", "form", "tag", "old_node_id", "wrong_form_1", "wrong_form_2", "wrong_form_3" ]

def ignored_field (feature_name):
    ignored = False;
    for regex in features_ignore_regex:
        if regex in feature_name:
            ignored = True
    return ignored

def line2dict (feat_names, feat_vals, ignore_blank):
    """ Create dictionary from the input line."""
    result = {}
    if len(feat_names) != len(feat_vals):
        raise ValueError("Feature vector length does not match: expected=%s got=%s" % (len(feat_names),len(feat_vals)))
    for i in range(len(feat_names)):
        if ignore_blank and feat_vals[i] == "":
            continue
        result[feat_names[i]] = feat_vals[i]
    return result

def split_targets_feats (input_dict, targets):
    target_dict = {}
    feat_dict = {}
    for key,item in input_dict.items():
        if key in targets:
            target_dict[key] = item
        elif ignored_field(key) != True:
            feat_dict[key] = item
    target_arr = []
    for t in targets:
        target_arr.append(target_dict[t])
    return target_arr, feat_dict


## Main Program ##

# Parse command line arguments
parser = argparse.ArgumentParser(description="Train and crossvalidate Scikit-Learn classifier.")
parser.add_argument('--input_file', metavar='input_data', type=str)
parser.add_argument('--target', metavar='predicted_category', type=str)
#parser.add_argument('--model_type', metavar='model_type', type=str)
#parser.add_argument('--model_params', metavar='model_parameters', type=str)
#parser.add_argument('--feat_selector', metavar='feature_selector', type=str)
#parser.add_argument('--feat_selector_params', metavar='feature_selector_parameters', type=str)
parser.add_argument('--save_model', metavar='model_save_destination', nargs='?', type=str)
parser.add_argument('--load_model', metavar='model_location', nargs='?', type=str)
args = parser.parse_args()

fh = gzip.open(args.input_file, 'rt', 'UTF-8')
line = str(fh.readline()).rstrip("\n")
feature_names =  line.split("\t")
targets = args.target.split('|')
#model_type = args.model_type

#f_select = args.feat_selector
#if f_select == "":
#    f_select = None

registered_feat_names = {}
multiclass = False
if len(targets) > 1:
     multiclass = True

#sparse = True
#if model_type in dense_models:
#    sparse = False

# Prepare the data
data_X = []
data_Y = []
weights = []
while True:
    line = fh.readline().rstrip("\n")
    if not line:
        break
    feat_values = line.split("\t")

    line_dict = line2dict(feature_names, feat_values, False)  
    tarr, fdict = split_targets_feats(line_dict, targets)
    for key,item in fdict.items():
        registered_feat_names[key] = 1

    data_X.append(fdict)
    data_Y.append(tarr)

fh.close()

data_X = np.array(data_X)
data_Y = np.squeeze(np.array(data_Y))

m = neural.FeedForwardNetwork(network_width=10, network_depth=10, dropout=0.6, rnn_cell_dim=256, layer_type="Highway")
print("inited")
m.fit(data_X, data_Y)
print("fitted")
m.predict(data_X)
print("predicted")
m.predict_proba(data_X)
print("proba_predicted")
