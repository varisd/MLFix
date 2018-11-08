#!/usr/bin/env python

from __future__ import division
import os, sys, argparse
import datetime
import gzip
import model

# TODO: dump some info

# Parse command line arguments
parser = argparse.ArgumentParser(description="Test scikit-learn WrongForm model accuracy.")
parser.add_argument('model_file', metavar='model_file', type=str)
parser.add_argument('data_file', metavar='test_data', type=str)
args = parser.parse_args()

fh = gzip.open(args.data_file, 'rb', "UTF-8")
line = fh.readline().rstrip("\n")
feature_names = line.split("\t")

m = model.loadModel(args.model_file)
targets = m.get_classes()[0].keys()

# Read the data
test_X = []
test_Y = []
base_Y = []
while True:
    line = fh.readline().rstrip("\n")
    if not line:
        break
    feat_values = line.split("\t")
    feat_row = dict()
    target_row = dict()    

#    old_form_idx = feat_names.index("old_node_form")
#    new_form_idx = feat_names.index("new_node_form")
#    incorrect = (feat_values[old_form_idx] != feat_values[new_form_idx])

    for i in range(len(feature_names)):
        if feature_names[i] in targets:
            target_row.update({feature_names[i]:feat_values[i]})
        if "new" not in feature_names[i]:
            feat_row.update({feature_names[i]:feat_values[i]})
    test_X.append(feat_row)
    test_Y.append({"wrong_pos" : incorrect})
    # We assume that there are no wordform errors as a baseline
    base_Y.append({"wrong_form": 0})

# predict classes and compare results
good = 0
true_positive = 0
true_negative = 0
false_positive = 0
false_negative = 0
wrong_positive = 0

try:
    sys.stderr.write(str(datetime.datetime.now().time()) + ": started predicting\n")
    scores_all = m.predict_proba(test_X)
    sys.stderr.write(str(datetime.datetime.now().time()) + ": stopped predicting (predict_proba)\n")
    res = [sorted(zip(m.get_classes(), line), key=(lambda x: x[1]), reverse=True) for line in scores_all]
except (NotImplementedError, AttributeError):
    scores_all = m.predict(test_X)
    sys.stderr.write(str(datetime.datetime.now().time()) + ": stopped predicting (predict))\n")
    res = [zip([line], [1]) for line in scores_all]
res = [filter(lambda x: x[1] != 0, line) for line in res]
#print "\n\n".join(['##'.join([';'.join([str(key) + ':' + str(item) for key, item in pred[0].iteritems()]) + '#' + str(pred[1]) for pred in line]) for line in res])
#print "\n\n".join(["\n".join([';'.join([ + ": " + str(item) for key, item in pred[0].iteritems()]) + ' : ' + str(pred[1]) for pred in line]) for line in res])

for i in range(len(res)):
    print test_X[i]["old_node_lemma"] + ": " + "\n".join([';'.join([str(item) for key, item in pred[0].iteritems()]) + ' : ' + str(pred[1]) for pred in res[i]])
    print "\n"

for i in range(len(res)):
    lemma = test_X[i]["old_node_lemma"]
    pred = res[i][0][0]
    base = base_Y[i]
    true = test_Y[i]
    base_str = ";".join([base[x] for x in base_targets])
    pred_str = ";".join([pred[x] for x in targets])
    true_str = ";".join([true[x] for x in targets])

    if pred_str == true_str:
        good = good + 1
        if pred_str == base_str:
            true_negative = true_negative + 1
            print "%s\tTRUENEG %s" % (lemma, pred_str)
        else:
            true_positive = true_positive + 1
            print "%s\tTRUEPOS %s -> %s" % (lemma, base_str, pred_str)
    else:
        if pred_str == base_str:
            false_negative = false_negative + 1
            print "%s\tFALSENEG %s -> %s" % (lemma, base_str, true_str)
        elif true_str == base_str:
            false_positive = false_positive + 1
            print "%s\tFALSEPOS %s -> %s" % (lemma, base_str, pred_str)
        else:
            wrong_positive = wrong_positive + 1
            print "%s\tWRONGPOS %s -> %s !-> %s" % (lemma, base_str, pred_str, true_str)

accuracy = good / len(res)
precision = 0
recall = 0
f_measure = 0
if true_positive != 0:
    precision = true_positive / (true_positive + false_positive)
    recall = true_positive / (true_positive + false_negative)
if precision != 0 or recall != 0:
    f_measure = (5 * ((precision * recall) / (4 * precision + recall)))
print "\n---- RESULTS ----"

print "Instances Accuracy Precision Recall F2-Measure TruePos TrueNeg FalsePos FalseNeg WrongPos"
print "%9d %8.2f %9.2f %6.2f %10.2f %7d %7d %8d %8d %8d" % (len(res), accuracy, precision, recall, f_measure, true_positive, true_negative, false_positive, false_negative, wrong_positive)
