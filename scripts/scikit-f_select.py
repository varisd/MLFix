#!/usr/bin/env python

import os, sys, argparse
import gzip
import model
import numpy as np
from sklearn.feature_extraction import DictVectorizer
from sklearn.preprocessing import StandardScaler
from sklearn.preprocessing import LabelEncoder
from sklearn.svm import LinearSVC
from sklearn.linear_model import RandomizedLogisticRegression
from sklearn.ensemble import ExtraTreesClassifier
from sklearn.ensemble import RandomForestClassifier

from sklearn.feature_selection import VarianceThreshold
from sklearn.feature_selection import SelectFromModel
from sklearn.feature_selection import SelectKBest
from sklearn.feature_selection import chi2
from sklearn.feature_selection import f_classif
from sklearn.feature_selection import RFECV

from sklearn.linear_model import LassoCV

# "Constants"
seed=123
features_ignore_regex = ["tag","lemma","form", "node_id"]
avg_method = "weighted"

def ignored_field (feature_name):
    ignored = False;
    for regex in features_ignore_regex:
        if regex in feature_name:
            ignored = True
    return ignored 

def line2dict (feat_names, feat_vals, ignore_blank):
    """ Create dictionary from the input line."""
    result = dict()
    if len(feat_names) != len(feat_vals):
        raise ValueError("Feature vector length does not match: expected=" + len(feat_names) + " got=" + len(feat_vals))
    for i in range(len(feat_names)):
        if ignore_blank and feat_vals[i] == "":
            continue
        result[feat_names[i]] = feat_vals[i]
    return result

def split_targets_feats (input_dict, targets):
    target_dict = dict()
    feat_dict = dict()
    for key,item in input_dict.iteritems():
        if key in targets:
            target_dict[key] = item
        elif ignored_field(key) != True:
            feat_dict[key] = item
    return target_dict, feat_dict

def line2base (targets, values):
    result = dict()
    if len(targets) != len(values):
        raise ValueError("Number of targets between baseline and predicted does not match: expected=" + len(targets) + " got=" + len(values))
    for i in range(len(targets)):
        result[targets[i]] = values[i]
    return result

## Main Program ##

# Parse command line arguments
parser = argparse.ArgumentParser(description="Train and crossvalidate Scikit-Learn classifier.")
parser.add_argument('--input_file', metavar='input_data', type=str)
parser.add_argument('--target', metavar='predicted_category', type=str)
parser.add_argument('--selector', metavar='feature_selector', type=str)
parser.add_argument('--selector_params', metavar='feature_selector_parameters', type=str)
args = parser.parse_args()

fh = gzip.open(args.input_file, 'rb', 'UTF-8')
line = fh.readline().rstrip("\n")
feature_names =  line.split("\t")
targets = args.target.split('|')
selector = args.selector


registered_feat_names = dict()
multiclass = False
if len(targets) > 1:
     multiclass = True

# Prepare the data
data_X = []
data_Y = []
while True:
    line = fh.readline().rstrip("\n")
    if not line:
        break
    feat_values = line.split("\t")

    line_dict = line2dict(feature_names, feat_values, False)  
    tdict, fdict = split_targets_feats(line_dict, targets)
    for key,item in fdict.iteritems():
        registered_feat_names[key] = 1

    data_X.append(fdict)
    data_Y.append(tdict)

fh.close()

vectorizer = DictVectorizer(sparse=True)
encoder = LabelEncoder()
scaler = StandardScaler(with_mean=False)
var_sel = VarianceThreshold()

#Xtr = scaler.fit_transform(vectorizer.fit_transform(data_X))
Xtr = vectorizer.fit_transform(data_X)
Xtr = var_sel.fit_transform(Xtr)
Ytr = encoder.fit_transform(data_Y)

sys.stderr.write("# of initial features: %d\n" % (len(registered_feat_names)))
sys.stderr.write("# of transformed features: %d\n" % (len(Xtr.toarray()[0])))

sel = None
n = len(feature_names)

if (selector == "kbest"):
    sel = SelectKBest(chi2, k=n)
elif (selector == "kbest_anova"):
    sel = SelectKBest(f_classif, k=n)
elif (selector == "rfecv"):
    sel = RFECV()
elif (selector == "lasso"):
    sel = SelectFromModel(LassoCV(), threshold=0.005)
elif (selector == "rlregr"):
    sel = RandomizedLogisticRegression()
elif (selector == "svm"):
    sel = eval( "SelectFromModel(LinearSVC(%s))" % (args.selector_params) )
elif (selector == "extra_trees"):
    sel = SelectFromModel(ExtraTreesClassifier())
elif (selector == "random_forest"):
    sel = SelectFromModel(RandomForestClassifier())

print sel.estimator
if (type(sel) == SelectFromModel and type(sel.estimator) == LassoCV):
    sel.fit(Xtr, Ytr)
    top_ranked = sorted(enumerate(sel.estimator_.coef_), key=lambda x:x[1], reverse=True)
    top_indices = map(list,zip(*top_ranked))[0]
    for feat,pval in zip(np.asarray(vectorizer.get_feature_names())[top_indices],sel.estimator_.coef_[top_indices]):
        print "%s\t%s" % (feat, pval)
elif (type(sel) == SelectFromModel and (type(sel.estimator) == ExtraTreesClassifier or type(sel.estimator) == RandomForestClassifier)):
    sel.fit(Xtr, Ytr)
    top_ranked = sorted(enumerate(sel.estimator_.feature_importances_), key=lambda x:x[1], reverse=True)
    top_indices = map(list,zip(*top_ranked))[0]
    for feat,pval in zip(np.asarray(vectorizer.get_feature_names())[top_indices],sel.estimator_.feature_importances_[top_indices]):
        print "%s\t%s" % (feat, pval)
elif (sel != None):
    sel.fit(Xtr, Ytr)
    top_ranked = sorted(enumerate(sel.scores_), key=lambda x:x[1], reverse=True)
    top_indices = map(list,zip(*top_ranked))[0]
    for feat,pval in zip(np.asarray(vectorizer.get_feature_names())[top_indices],sel.pvalues_[top_indices]):
        print "%s\t%s" % (feat, pval)
else:
    # default: print the features sorted by variance
    top_ranked = sorted(enumerate(var_sel.variances_), key=lambda x:x[1], reverse=True)
    top_indices = map(list,zip(*top_ranked))[0]
    for feat,pval in zip(np.asarray(vectorizer.get_feature_names())[top_indices],var_sel.variances_[top_indices]):
        print "%s\t%s" % (feat, pval)
