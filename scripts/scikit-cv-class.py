#!/usr/bin/env python

from __future__ import division
import os, sys, argparse
import datetime
import gzip
import model
import neural
import scorer
import numpy as np
from sklearn.feature_extraction import DictVectorizer
from sklearn.preprocessing import LabelEncoder
from sklearn.model_selection import train_test_split
from sklearn.model_selection import KFold
from sklearn.cross_validation import StratifiedKFold
from sklearn.metrics import accuracy_score
from sklearn.metrics import average_precision_score
from sklearn.metrics import precision_score
from sklearn.metrics import recall_score
from sklearn.metrics import f1_score

from sklearn.model_selection import RandomizedSearchCV
from sklearn.model_selection import GridSearchCV

from scipy.stats import randint

# TMP selector-related imports
from sklearn.svm import SVC
from sklearn.feature_selection import RFECV


# "Constants"
seed=123
dense_models=["gaussian_bayes"]
#features_ignore_regex = [ "agr", "new", "src", "sibling", "lemma", "form", "tag", "old_node_id", "wrong_form_1", "wrong_form_2", "wrong_form_3" ]
features_ignore_regex = [ "agr", "old_node_lemma", "new", "form", "tag", "old_node_id", "wrong_form_1", "wrong_form_2", "wrong_form_3" ]
avg_method = "weighted"

def chunks (l, n):
    """Yield successive n-sized chunks from l."""
    for i in range(0, len(l), n):
        yield l[i:i+n]

def downsample(X, Y, n):
    X1 = []
    Y1 = []
    print(len(X))
    data = zip(X,Y)
    i = 0
    for inst in data:
        if inst[1]["wrong_form_3"] == 1 or i == 0:
            X1.append(inst[0])
            Y1.append(inst[1])
        i = (i + 1) % n
    print(len(X1))
    return X1,Y1

def ignored_field (feature_name):
    ignored = False;
    for regex in features_ignore_regex:
        if regex in feature_name:
            ignored = True
    return ignored 

def targets2numpy (input_dict, targets):
    target_arr = []
    for line in input_dict:
        arr = []
        for t in targets:
            arr.append(line[t])
        target_arr.append(arr)
    return np.array(target_arr)

def line2dict (feat_names, feat_vals, ignore_blank):
    """ Create dictionary from the input line."""
    result = dict()
    if len(feat_names) != len(feat_vals):
        raise ValueError("Feature vector length does not match: expected=%s got=%s" % (len(feat_names),len(feat_vals)))
    for i in range(len(feat_names)):
        if ignore_blank and feat_vals[i] == "":
            continue
        result[feat_names[i]] = feat_vals[i]
    return result

def split_targets_feats (input_dict, targets):
    target_dict = dict()
    feat_dict = dict()
    for key,item in input_dict.items():
        if key in targets:
            target_dict[key] = item
        elif ignored_field(key) != True:
            feat_dict[key] = item
    return target_dict, feat_dict

def line2base (targets, values):
    result = dict()
    if len(targets) != len(values):
        raise ValueError("Number of targets between baseline and predicted does not match: expected=%s got=%s" % (len(targets),len(values)))
    for i in range(len(targets)):
        result[targets[i]] = values[i]
    return result

def evaluate (model, true, base, pred, targets):
    g = 0
    tp = 0
    tn = 0
    fp = 0
    fn = 0
    wp = 0
    for i in range(len(pred)):
        p1 = pred[i]
        b1 = base[i]
        t1 = true[i]
        base_str = ";".join([b1[x] for x,_ in enumerate(targets)])
        pred_str = ";".join([p1[x] for x,_ in enumerate(targets)])
        true_str = ";".join([t1[x] for x,_ in enumerate(targets)])

        if pred_str == true_str:
            g = g + 1
            if pred_str == base_str:
                tn = tn + 1
                #print "TRUENEG %s" % (pred_str)
            else:
                tp = tp + 1
                #print "TRUEPOS %s -> %s" % (base_str, pred_str)
        else:
            if pred_str == base_str:
                fn = fn + 1
                #print "FALSENEG %s -> %s" % (base_str, true_str)
            elif true_str == base_str:
                fp = fp + 1
                #print "FALSEPOS %s -> %s" % (base_str, pred_str)
            else:
                wp = wp + 1
                #print "WRONGPOS %s -> %s !-> %s" % (base_str, pred_str, true_str)

    
    acc = accuracy_score(global_encoder.transform(true), global_encoder.transform(pred))
    prec = 0
    recall = 0
    if tp != 0:
        prec = tp / (tp + fp)
        recall = tp / (tp + fn)
    f1 = 0
    if prec != 0 or recall != 0:
        f1 = 2 * (prec * recall) / (prec + recall)
    sys.stdout.write("Instances Accuracy Precision Recall F1-Measure TruePos TrueNeg FalsePos FalseNeg WrongPos Classifier Selector\n")
    sys.stdout.write("%9d %8.2f %9.2f %6.2f %10.2f %7d %7d %8d %8d %8d %s %s\n" % (len(pred), acc, prec, recall, f1, tp, tn, fp, fn, wp, model_type, f_select))

    

## Main Program ##

# Parse command line arguments
parser = argparse.ArgumentParser(description="Train and crossvalidate Scikit-Learn classifier.")
parser.add_argument('--input_file', metavar='input_data', type=str)
parser.add_argument('--base_file', metavar='baseline_results', type=str)
parser.add_argument('--target', metavar='predicted_category', type=str)
parser.add_argument('--model_type', metavar='model_type', type=str)
parser.add_argument('--model_params', metavar='model_parameters', type=str)
parser.add_argument('--feat_selector', metavar='feature_selector', type=str)
parser.add_argument('--feat_selector_params', metavar='feature_selector_parameters', type=str)
parser.add_argument('--save_model', metavar='model_save_destination', nargs='?', type=str)
parser.add_argument('--load_model', metavar='model_location', nargs='?', type=str)
args = parser.parse_args()

fh = gzip.open(args.input_file, 'rt', 'UTF-8')
line = fh.readline().rstrip("\n")
feature_names =  line.split("\t")
targets = args.target.split('|')
model_type = args.model_type

f_select = args.feat_selector
if f_select == "":
    f_select = None

registered_feat_names = dict()
multiclass = False
if len(targets) > 1:
     multiclass = True

sparse = True
if model_type in dense_models:
    sparse = False

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
    tdict, fdict = split_targets_feats(line_dict, targets)
    for key,item in fdict.items():
        registered_feat_names[key] = 1

    data_X.append(fdict)
    data_Y.append(tdict)

fh.close()

sys.stderr.write("# of initial features: %d\n" % (len(registered_feat_names)))

fh = gzip.open(args.base_file, 'rt', 'UTF-8')
line = fh.readline().rstrip("\n")

baseline = []
while True:
    line = fh.readline()
    if not line:
        break
    line = line.rstrip("\n")
    values = line.split("\t")
    line_dict = line2base(targets, values)
    baseline.append(line_dict)

fh.close()

# Load model, predict targets and exit
if args.load_model != None:
    sys.stderr.write("Loading model from: %s\n" % (args.load_model))
    m = model.loadModel(args.load_model)
    res = m.predict(data_X)
    for r in res:
        print(r)
    sys.exit()

data_X = np.array(data_X)

# Model cross validation
if model_type in ["FeedForward", "Highway"]:
    baseline = targets2numpy(baseline, targets)
    data_Y = targets2numpy(data_Y, targets)
    m = eval("neural.FeedForwardNetwork({}, layer_type='{}')".format(args.model_params, model_type))
else:
    baseline = np.array(baseline)
    data_Y = np.array(data_Y)
    m = model.Model(model_type, args.model_params, f_select, args.feat_selector_params, sparse=sparse)
pred = data_Y

predicted = np.reshape(baseline, [-1])
tr_pred = np.reshape(baseline, [-1])

sys.stderr.write("Starting crossvalidation\n")
#cv = cross_validation.StratifiedKFold(data_X, n_folds=10, shuffle=True, random_state=seed)
#scores = cross_validation.cross_val_score(m, data_X, data_Y, cv=10)
#print "10-fold cross validation: %s" % scores.mean()

global_encoder = LabelEncoder()
global_encoder.fit(np.concatenate((data_Y,baseline)))
print("10-fold cross validation (baseline): {}".format(accuracy_score(global_encoder.transform(data_Y), global_encoder.transform(baseline))))
#scores = cross_validation.cross_val_score(model.Model("baseline", "strategy='most_frequent',random_state=%d" % seed), data_X, data_Y, cv=cv)
#print "10-fold cross validation (most_frequent): %s" % scores.mean()
#scores = cross_validation.cross_val_score(model.Model("baseline", "strategy='uniform',random_state=%d" % seed), data_X, data_Y, cv=cv)
#print "10-fold cross validation (uniform): %s" % scores.mean()
#scores = cross_validation.cross_val_score(model.Model("baseline", "strategy='stratified',random_state=%d" % seed), data_X, data_Y, cv=cv)
#print "10-fold cross validation (stratified): %s" % scores.mean()


#btr = global_encoder.transform(baseline)
#sc = scorer.MyScorer(btr)
#grid = GridSearchCV(estimator=m.model, param_grid={"n_neighbors" : randint.rvs(1,15,size=5)}, scoring=sc.recall, cv=10)
#grid.fit(data_X,data_Y)
#print grid
#print grid.estimator.model
#print sc.precision(grid, data_X, data_Y)


# Leave one out prediction
sys.stderr.write("Starting 10-fold leave-one-out crossvalidation\n")
count = 1
n_chunks = (len(data_X) // 10) // 2000 + 1
#n_chunks = len(data_X) // 10 + 1
print(n_chunks)
#kf = KFold(len(data_X), n_folds=10)
kf = KFold(10)
#skf = StratifiedKFold(y=global_encoder.transform(data_Y), n_folds=10)
#for train_index, test_index in kf:
for k, (train_index, test_index) in enumerate(kf.split(data_X, data_Y)):
    sys.stderr.write("KFold iteration: %d\n" % (count))
    X_train, X_test = data_X[train_index], data_X[test_index]
    Y_train, Y_test, base = data_Y[train_index], data_Y[test_index], baseline[test_index]
    if model_type in ["FeedForward", "Highway"]:
        m = eval("neural.FeedForwardNetwork({}, layer_type='{}')".format(args.model_params, model_type))
    else:
        m = model.Model(model_type, args.model_params, f_select, args.feat_selector_params, sparse=sparse)
    m.fit(X_train, Y_train)
    
    sys.stderr.write(str(datetime.datetime.now().time()) + ": started predicting (predict))\n")
    predicted[test_index] = m.predict(X_test)
    sys.stderr.write(str(datetime.datetime.now().time()) + ": stopped predicting (predict))\n")
#    for inst in test_index.tolist():
#        sys.stderr.write(str(datetime.datetime.now().time()) + ": started predicting (predict))\n")
#        print len(data_X[inst])
#        predicted[inst] = m.predict([data_X[inst]])
#        sys.stderr.write(str(datetime.datetime.now().time()) + ": stopped predicting (predict))\n")
    evaluate(m, Y_test, base, predicted[test_index], targets)
    count = count + 1

print("Training set Evaluation:")
if model_type in ["FeedForward", "Highway"]:
    m = eval("neural.FeedForwardNetwork({}, layer_type='{}')".format(args.model_params, model_type))
else:
    m = model.Model(model_type, args.model_params, f_select, args.feat_selector_params, sparse=sparse)
m.fit(data_X, data_Y)

sys.stderr.write(str(datetime.datetime.now().time()) + ": started predicting (predict))\n")
tr_pred = m.predict(data_X)
sys.stderr.write(str(datetime.datetime.now().time()) + ": stopped predicting (predict))\n")
evaluate(m, data_Y, baseline, tr_pred, targets)

print("Final Evaluation:")
evaluate(m, data_Y, baseline, predicted, targets)

# Train model and save it
if args.save_model != None:
    sys.stderr.write("Saving model to: " + args.save_model + "\n")
    model.saveModel(m, args.save_model)
