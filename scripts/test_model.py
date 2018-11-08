#!/usr/bin/env python

from __future__ import division
import os, sys, argparse
import datetime
import gzip
import model

# TODO: dump some info?

def myPrint (msg, verbose):
    if verbose > 0:
        print msg;

def dumpInst (inst, pred, true, feature_names, targets, verbose):
    if verbose > 1:
        inst_str = ""
        pred_str = ""
        true_str = ""
        for tar in targets:
            pred_str = pred_str + " " + tar + ":"
            if pred[tar] != "":
                pred_str = pred_str + pred[tar]
            true_str = true_str + " " + tar + ":"
            if true[tar] != "":
                true_str = true_str + true[tar]
        for name in feature_names:
            if "new" not in name and inst[name] != "" and not name in features_ignore:
                inst_str = inst_str + " " + name + ":" + inst[name] 
        print("%s\t%s -> %s\t%s" % (inst["old_node_id"], pred_str, true_str, inst_str))
        

# Parse command line arguments
parser = argparse.ArgumentParser(description="Test scikit-learn model accuracy.")
parser.add_argument('model_file', metavar='model_file', type=str)
parser.add_argument('data_file', metavar='test_data', type=str)
parser.add_argument('verbose', metavar='verbose', nargs='?', type=int, default=0)
args = parser.parse_args()

verbose = args.verbose
features_ignore = [ "old_node_id", "wrong_form_1", "wrong_form_2" ]

fh = gzip.open(args.data_file, 'rb', "UTF-8")
line = fh.readline().rstrip("\n")
feature_names = line.split("\t")

m = model.loadModel(args.model_file)
targets = m.get_classes()[0].keys()

base_targets = [x.replace("new", "old") for x in targets]

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
    target_row = {key:"" for key in targets}
    base_row = {key:"" for key in base_targets}
    for i in range(len(feature_names)):
        if feature_names[i] in targets:
            target_row.update({feature_names[i]:feat_values[i]})
        elif feature_names[i] in base_targets:
            if "wrong_form" in feature_names[i]:
                base_row.update({feature_names[i]:0});
            else:
                base_row.update({feature_names[i]:feat_values[i]})
        if "new" not in feature_names[i]: # and feat_values[i] != "":
            feat_row.update({feature_names[i]:feat_values[i]})
    test_X.append(feat_row)
    test_Y.append(target_row)
    base_Y.append(base_row)

# predict classes and compare results
good = 0
true_positive = 0
true_negative = 0
false_positive = 0
false_negative = 0
wrong_positive = 0

iter_size = 2000

#sys.stderr.write("# Test samples: " + str(len(test_X)) + "\n")

# we cannot classify all test cases at once due to the limited memory
for iteration in range(int( (len(test_X) - 1) / iter_size) + 1):

    idx_first = iteration * iter_size
    idx_last = ((iteration + 1) * iter_size) - 1
    if idx_last > len(test_X) - 1:
        idx_last = len(test_X) - 1

#    try:
#        sys.stderr.write(str(datetime.datetime.now().time()) + ": started predicting\n")
#        scores_all = m.predict_proba(test_X[idx_first:idx_last])
#        sys.stderr.write(str(datetime.datetime.now().time()) + ": stopped predicting (predict_proba)\n")
#        res = [sorted(zip(m.get_classes(), line), key=(lambda x: x[1]), reverse=True) for line in scores_all]
#    except (NotImplementedError, AttributeError):
#        scores_all = m.predict(test_X[idx_first:idx_last])
#        sys.stderr.write(str(datetime.datetime.now().time()) + ": stopped predicting (predict))\n")
#        res = [zip([line], [1]) for line in scores_all]

    scores_all = m.predict(test_X[idx_first:idx_last])
    sys.stderr.write(str(datetime.datetime.now().time()) + ": stopped predicting (predict))\n")
    res = [zip([line], [1]) for line in scores_all]


    res = [filter(lambda x: x[1] != 0, line) for line in res]

    for i in range(len(res)):
        lemma = test_X[idx_first + i]["old_node_lemma"]
        pred = res[i][0][0]
        base = base_Y[idx_first + i]
        true = test_Y[idx_first + i]
        base_str = ";".join([base[x] for x in base_targets])
        pred_str = ";".join([pred[x] for x in targets])
        true_str = ";".join([true[x] for x in targets])

        dumpInst(test_X[idx_first + i], pred, true, feature_names, targets, verbose)

        if pred_str == true_str:
            good = good + 1
            if pred_str == base_str:
                true_negative = true_negative + 1
                myPrint("%s\tTRUENEG %s" % (lemma, pred_str), verbose)
            else:
                true_positive = true_positive + 1
                myPrint("%s\tTRUEPOS %s -> %s" % (lemma, base_str, pred_str), verbose)
        else:
            if pred_str == base_str:
                false_negative = false_negative + 1
                myPrint("%s\tFALSENEG %s -> %s" % (lemma, base_str, true_str), verbose)
            elif true_str == base_str:
                false_positive = false_positive + 1
                myPrint("%s\tFALSEPOS %s -> %s" % (lemma, base_str, pred_str), verbose)
            else:
                wrong_positive = wrong_positive + 1
                myPrint("%s\tWRONGPOS %s -> %s !-> %s" % (lemma, base_str, pred_str, true_str), verbose)

accuracy = good / len(test_X)
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
print "%9d %8.2f %9.2f %6.2f %10.2f %7d %7d %8d %8d %8d" % (len(test_X), accuracy, precision, recall, f_measure, true_positive, true_negative, false_positive, false_negative, wrong_positive)
