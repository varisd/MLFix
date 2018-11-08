from sklearn.pipeline import Pipeline, FeatureUnion
from sklearn import tree
from sklearn.externals import joblib
import sys, gzip
import numpy

class MyScorer:

    def __init__(self, baseline):
        self.baseline = baseline

    def precision(self, estimator, X, y=None):
        res = estimator.predict(X)
        tp = 0
        fp = 0
        for i in range(len(X)):
            pred = res[i]
            base = self.baseline[i]
            true = y[i]
            if pred == true:
                if pred != base:
                    tp = tp + 1
            else:
                if pred != base:
                    fp = fp + 1
        if tp != 0:
            return tp / (tp + fp)
        else:
            return 0.0

    def recall(self, estimator, X, y=None):
        res = estimator.predict(X)
        tp = 0
        fn = 0
        for i in range(len(X)):
            pred = res[i]
            base = self.baseline[i]
            true = y[i]
            if pred == true:
                if pred != base:
                    tp = tp + 1
            else:
                if pred == base:
                    fn = fn + 1
        if tp != 0:
            return tp / (tp + fn)
        else:
            return 0.0

    def f_measure(self, estimator, X, y=None):
        res = estimator.predict(X)
        tp = 0
        fp = 0
        fn = 0
        for i in range(len(X)):
            pred = res[i]
            base = self.baseline[i]
            true = y[i]
            if pred == true:
                if pred != base:
                    tp = tp + 1
            else:
                if pred == base:
                    fn = fn + 1
                else:
                    fp = fp + 1
        if tp != 0:
            prec = tp / (tp + fp)
            recall = tp / (tp + fn)
            return 1.25 * (prec * recall) / (0.25 * prec + recall)
        else:
            return 0.0

