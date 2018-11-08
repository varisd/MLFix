from sklearn.svm import SVC
from sklearn.svm import LinearSVC
from sklearn.neighbors import KNeighborsClassifier
from sklearn.naive_bayes import MultinomialNB
from sklearn.naive_bayes import GaussianNB
from sklearn.tree import DecisionTreeClassifier
from sklearn.linear_model import RidgeClassifier
from sklearn.linear_model import Ridge
from sklearn.linear_model import RidgeCV
from sklearn.linear_model import Lasso
from sklearn.linear_model import LassoCV
from sklearn.linear_model import LogisticRegression
from sklearn.linear_model import LinearRegression
from sklearn.linear_model import BayesianRidge
from sklearn.linear_model import Perceptron
from sklearn.linear_model import RandomizedLogisticRegression
from sklearn.linear_model import SGDClassifier
from sklearn.feature_extraction import DictVectorizer
from sklearn.feature_extraction import FeatureHasher
from sklearn.preprocessing import LabelEncoder
from sklearn.preprocessing import StandardScaler
from sklearn.ensemble import ExtraTreesClassifier
from sklearn.ensemble import RandomForestClassifier
from sklearn.ensemble import AdaBoostClassifier
from sklearn.dummy import DummyClassifier
from sklearn.decomposition import TruncatedSVD

from sklearn.feature_selection import SelectFromModel
from sklearn.feature_selection import SelectPercentile
from sklearn.feature_selection import VarianceThreshold
from sklearn.feature_selection import RFECV
from sklearn.feature_selection import RFE
from sklearn.feature_selection import SelectKBest
from sklearn.feature_selection import chi2
from sklearn.feature_selection import f_classif

from sklearn.pipeline import Pipeline, FeatureUnion
from sklearn import tree
from sklearn.externals import joblib
import sys, gzip
import numpy


def saveModel(model, file_path):
    joblib.dump(model, file_path, compress = 3)

def loadModel(file_path):
    return joblib.load(file_path)

class EmptyModel(object):
    def fit(self, X, y=None):
        pass
    def fit_transform(self, X, y=None):
        return self.transform(X)
    def transform(self, X, y=None):
        return X

# basic sklearn model wrapper
class Model:

    # model related attribute
    model = None
    feat_transformer =None
    label_encoder = None
    selector = None
    pipeline = None

    # other parameters
    classification = True
    binarize = False;
    verbose = False

    # params for cloning
    params = dict()

    def __init__(self, model_type=None, \
                    model_params="", \
                    f_select=None, \
                    f_select_params="", \
                    sparse=True, \
                    n_features=100, \
                    n_components=10):
        self.params = {"model_type": model_type, "model_params": model_params, "f_select": f_select, "f_select_params": f_select_params, "sparse": sparse, "n_features": n_features, "n_components": n_components}

        if (model_type == None):
            return

        # initialize "default" values
        # models specific values should be set in model-specific if-else branch
        self.feat_transformer = DictVectorizer(sparse=sparse)
        self.label_encoder = LabelEncoder()

        # selector to remove zero-variance features
        self.var_selector = VarianceThreshold()

        #scaler = StandardScaler(with_mean=False)
        #selector = SelectKBest(chi2, k=n_features)
        #combined_features = FeatureUnion([('selector', selector)])
        #self.pipeline = Pipeline([('vectorizer', feat_vectorizer), ('features', combined_features), ('scaler', scaler), ('model', self.model)])

        # Choose model type
        if (model_type == "linear_svm"):
            self.model = eval("LinearSVC(" + model_params + ")")
        elif (model_type == "svm"):
            self.model = eval("SVC(" + model_params + ")")
        elif (model_type == "knn"):
            self.model = eval("KNeighborsClassifier(" + model_params + ")")
        elif (model_type == "ridge_classifier"):
            self.model = eval("RidgeClassifier(" + model_params + ")")
        elif (model_type == "ridge_regression"):
            self.classification = False
            self.model = eval("Ridge(" + model_params + ")")
        elif (model_type == "lasso"):
            self.classification = False
            self.model = eval("Lasso(" + model_params + ")")
        elif (model_type == "bayesian_ridge"):
            self.classification = False
            self.model = eval("BayesianRidge(" + model_params + ")")
        elif (model_type == "gaussian_bayes"):
            self.model = GaussianNB()
        elif (model_type == "decision_trees"):
            self.model = DecisionTreeClassifier(random_state=0)
        elif (model_type == "log_regression"):
            self.model = eval("LogisticRegression(" + model_params + ")")
        elif (model_type == "linear_regression"):
            self.classification = False
            self.model = eval("LinearRegression(" + model_params + ")")
        elif (model_type == "perceptron"):
            self.model = eval("Perceptron(" + model_params + ")")
        elif (model_type == "extra_trees"):
            self.feat_transformer = DictVectorizer(sparse=False)
            self.model = eval("ExtraTreesClassifier(" + model_params + ")")
        elif (model_type == "random_forest"):
            self.feat_transformer = DictVectorizer(sparse=False)
            self.model = eval("RandomForestClassifier(" + model_params + ")")
        elif (model_type == "ada_boost"):
#            self.feat_transformer = DictVectorizer(sparse=False)
            self.model = eval("AdaBoostClassifier(" + model_params + ")")
        elif (model_type == "sgd_classifier"):
            self.model = eval("SGDClassifier(" + model_params + ")")
        elif (model_type == "baseline"):
            self.model = eval("DummyClassifier(" + model_params + ")")
        else:
            print >> sys.stderr, "Model of type " + model_type + " is not supported."

        # Choose feature selector
        if (f_select == None):
            self.selector = EmptyModel()
        elif (f_select == "kbest"):
            # params: score_func, k
            self.selector = eval("SelectKBest(" + f_select_params + ")")
        elif (f_select == "percentile"):
            self.selector = eval("SelectPercentile(" + f_select_params + ")")
        elif (f_select == "kbest_anova"):
            #self.selector = SelectKBest(f_classif, k=n)
            self.selector = eval("SelectKBest(" + "f_classif," + f_select_params + ")")
        elif (f_select == "lassocv"):
            self.selector = eval("SelectFromModel(LassoCV()," + f_select_params + ")")
        elif (f_select == "rfe_svm"):
            self.selector = eval("RFE(LinearSVC()," + f_select_params + ")")
        elif (f_select == "rfecv"):
            self.selector = eval("RFECV(" + f_select_params + ")")
        elif (f_select == "rlregr"):
            self.selector = eval("RandomizedLogisticRegression(" + f_select_params + ")")
        elif (f_select == "svm"):
            print "SelectFromModel(LinearSVC(" + f_select_params + "))"
            self.selector = eval("SelectFromModel(LinearSVC(" + f_select_params + "))")
        elif (f_select == "extra_trees"):
            self.selector = eval("SelectFromModel(ExtraTreesClassifier(" + f_select_params + "))")
        elif (f_select == "random_forest"):
            self.selector = eval("SelectFromModel(RandomForestClassifier(" + f_select_params + "))")
        elif (f_select == "from_model"):
            self.selector = eval("SelectFromModel(" + f_select_params + ")")

    def fit(self, X, Y):
        Xtr = X
        if (self.classification):
            Xtr = [self.transform_features(i) for i in X]
            Xtr = self.feat_transformer.fit_transform(Xtr)
            Xtr = self.var_selector.fit_transform(Xtr)
            Y = self.label_encoder.fit_transform(Y)
            Xtr = self.selector.fit_transform(Xtr, Y)
        self.model.fit(Xtr,Y)

    def transform(self, Y):
        """ For evaluation, we want transformed predicted values. """
        return self.label_encoder.transform(Y)

    def predict(self, X):
        if not isinstance(X, list) and not isinstance(X, numpy.ndarray):
            sys.stderr.write("Warning: X is not a list (type=%s)\n" % (str(type(X))))
            #raise ValueError(X)
        if (self.classification):
            Xtr = [self.transform_features(i) for i in X]
            Xtr = self.feat_transformer.transform(Xtr)
            Xtr = self.var_selector.transform(Xtr)
            Xtr = self.selector.transform(Xtr)
            return self.label_encoder.inverse_transform(self.model.predict(Xtr))
        else:
            return self.model.predict(Xtr)
    
    def predict_proba(self, X):
        if not isinstance(X, list) and not isinstance(X, numpy.ndarray):
            sys.stderr.write("Warning: X is not a list (type=%s)\n" % (str(type(X))))
            #raise ValueError(X)
        if (self.classification):
            Xtr = [self.transform_features(i) for i in X]
            Xtr = self.feat_transformer.transform(Xtr)
            Xtr = self.var_selector.transform(Xtr)
            Xtr = self.selector.transform(Xtr)
            return self.model.predict_proba(Xtr)
        else:
            return self.model.predict_proba(Xtr)

    def score(self, X, Y):
        if (self.classification):
            Xtr = [self.transform_features(i) for i in X]
            Xtr = self.feat_transformer.transform(Xtr)
            Xtr = self.var_selector.transform(Xtr)
            Xtr = self.selector.transform(Xtr)
            Y = self.label_encoder.transform(Y)
        return self.model.score(Xtr, Y)

    def get_classes(self):
        return self.label_encoder.inverse_transform(self.model.classes_)

    def set_params(self, **params):
        self.model = self.model.set_params(**params)
        return self

    def get_params(self, deep=True):
        return self.params
 
    def print_params(self, file_path):
        f = open(file_path, "w")
        if (self.model.__class__.__name__ == "DecisionTreeClassifier"):
            f = tree.export_graphviz(self.model, out_file=f)
        f.close()

    def transform_features(self, features):
        """ Transform features with string values into new sets of features. """
        transformed = dict()
        if not self.binarize:
            return features
        for name, value in features.iteritems():
            if isinstance(value, basestring):
                name = "%s_%s" % (name,value)
                value = 1.
            transformed[name] = float(value)
        return transformed

    def setVerbose(self):
        self.verbose = True

# extension of Model class for cross-validated tuning
class ModelCV(Model):
   
    def __init__(self, model_type=None, \
                    model_params="", \
                    sparse_vectorizer=True, \
                    alphas=None, \
                    n_features=100, \
                    n_comps=10):

        # Initialize the inherited attributes (expept for model, which is initialized by ModelCV itself)
        Model.__init__(self, None, model_params, sparse_vectorizer, n_features, n_comps)

        # set default alphas
        if (alphas == None):
            alphas = [round(x * 0.05, 2) for x in range(1, 20)]

        if (model_type == "ridge_regression"):
            self.model = eval("RidgeCV(fit_intercept=True, scoring=None, cv=None, alphas=" + str(alphas) + ","  + model_params +")")
        elif (model_type == "lasso"):
            self.model = eval("LassoCV(fit_intercept=True, alphas=" + str(alphas) + ","  + model_params +")")
        else:
            print >> sys.stderr, "Model of type " + model_type + " is not supported."
        
