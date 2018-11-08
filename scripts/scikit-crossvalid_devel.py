#!/usr/bin/env python

import os, sys, argparse
import gzip
import model
import numpy as np
from sklearn.feature_extraction import DictVectorizer
from sklearn.preprocessing import LabelEncoder
from sklearn import cross_validation
from sklearn.cross_validation import train_test_split
from sklearn.cross_validation import KFold

# "Constants"
#features_ignore_regex = [ "lemma", "form", "tag" ]
#features_ignore = [ "old_node_id", "wrong_form_1", "wrong_form_2" ]

def ignored_field (feature_name):
    ignored = False;
    for regex in features_ignore_regex:
        if regex in feature_name:
            ignored = True
    return ignored 

## Main Program ##

# Parse command line arguments
parser = argparse.ArgumentParser(description="Train and crossvalidate Scikit-Learn model.")
parser.add_argument('--input_file', metavar='input_data', type=str)
parser.add_argument('--target', metavar='predicted_category', type=str)
parser.add_argument('--model_type', metavar='model_type', type=str)
parser.add_argument('--model_params', metavar='model_parameters', type=str)
parser.add_argument('--save_model', metavar='model_save_destination', nargs='?', type=str)
parser.add_argument('--load_model', metavar='model_location', nargs='?', type=str)
args = parser.parse_args()

fh = gzip.open(args.input_file, 'rb', 'UTF-8')
line = fh.readline().rstrip("\n")
feature_names =  line.split("\t")
targets = args.target.split('|')
model_type = args.model_type

#registered_feat_names = dict()

# Prepare the data
data_X = []
data_Y = []
while True:
    line = fh.readline().rstrip("\n")
    if not line:
        break
    feat_values = line.split("\t")
#    feat_row = dict()
    feat_row = []
    target_row = dict()
   
    for i in range(len(feature_names)):
        # Collect target values for the other classifiers
        if len(targets) == 1 and feature_names[i] in targets[0]:
            target_row = feat_values[i]
        elif feature_names[i] in targets:
            target_row.update({feature_names[i]:feat_values[i]})
        else:
            feat_row.append(feat_values[i])
        #elif feat_values[i] != "":
        #    feat_row.update({feature_names[i]:feat_values[i]})
    if "nan" in feat_row or "nan" in target_row:
        continue
    data_X.append(feat_row)
    data_Y.append(target_row)

Xtr = np.array(data_X, dtype=float)
Ytr = np.array(data_Y, dtype=float)
res = Ytr

# Load model, predict targets and exit
if args.load_model != None:
    m = model.loadModel(args.load_model)
    res = m.model.predict(Xtr)
    for r in res:
        print r
    sys.exit()

# Model cross validation
m = model.Model(model_type, args.model_params)
Xtr = np.array(data_X, dtype=float)
Ytr = np.array(data_Y, dtype=float)
res = Ytr

cv = cross_validation.ShuffleSplit(len(data_X), n_iter=10, test_size=0.11, random_state=123)
scores = cross_validation.cross_val_score(m.model, Xtr, Ytr, cv=cv)

print "10-fold cross validation: %s" % scores.mean()
#m = model.ModelCV(model_type, args.model_params)

# Leave one out prediction
kf = KFold(len(data_X), n_folds=10)
for train_index, test_index in kf:
    X_train, X_test = Xtr[train_index], Xtr[test_index]
    Y_train = Ytr[train_index]
    a = m.model.fit(X_train, Y_train).predict(X_test)
#    print m.model.coef_
    res[test_index] = a

for r in res:
    print r

# Train model and save it
if args.save_model != None:
    m.model.fit(Xtr, Ytr)
    model.saveModel(m, args.save_model)
