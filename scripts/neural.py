from __future__ import division
from __future__ import print_function

from sklearn.feature_extraction import DictVectorizer
from sklearn.preprocessing import LabelEncoder

import datetime
import sys, gzip
import numpy as np

import tensorflow as tf
import tensorflow.contrib.metrics as tf_metrics
import tensorflow.contrib.layers as tf_layers

def highway_layer(x, num_outputs, activation_fn=tf.nn.relu, carry_bias=-1.0, scope=""):
    with tf.variable_scope(str(scope)):
        x = tf_layers.flatten(x)

        w_shape = [num_outputs, num_outputs]
        b_shape = [num_outputs]

        W_H = tf.get_variable(
                "weight",
                shape=w_shape,
                initializer=tf.random_normal_initializer(stddev=0.1),
                trainable=True)
        b_H = tf.get_variable(
                "bias",
                shape=b_shape,
                initializer=tf.constant_initializer(carry_bias))

        W_T = tf.get_variable(
                "weight_transform",
                shape=w_shape,
                initializer=tf.random_normal_initializer(stddev=0.1),
                trainable=True)
        b_T = tf.get_variable(
                "bias_transform",
                shape=b_shape,
                initializer=tf.constant_initializer(0.1))

        T = tf.sigmoid(
            tf.add(tf.matmul(x, W_T), b_T),
            name="transform_gate")
        H = activation_fn(
            tf.add(tf.matmul(x, W_H), b_H),
            name="activation")
        C = tf.subtract(1.0, T, name="carry_gate")

        y = tf.add(
            tf.multiply(H, T),
            tf.multiply(x, C),
            "y")
        return y


def saveModel(model, file_path):
    saver = tf.train.Saver()
    saver.save(model.session, "{}_sess".format(file_path))
    joblib.dump(model, file_path, compress = 3)

def loadModel(file_path):
    model = joblib.load(file_path)
    saver = tf.train.Saver()
    saver.restore(model.session, "{}_sess".format(file_path))
    return model

class Network:
    EMBEDDING_SIZE = 256

    feature_encoder = DictVectorizer(sparse=False)
    target_encoder = LabelEncoder()
    char_vocabulary = LabelEncoder()
    batch_size = 64

    def __init__(self, logdir="logs-nn", expname="basic-nn", threads=1, seed=42):
        # Create an empty graph and a session
        tf.set_random_seed(seed)
        self.session = tf.Session(
            config=tf.ConfigProto(
                inter_op_parallelism_threads=threads,
                intra_op_parallelism_threads=threads))

        timestamp = datetime.datetime.now().strftime("%Y-%m-%d_%H%M%S")
        self.summary_writer = tf.summary.FileWriter(
            "{}/{}-{}".format(logdir, timestamp, expname))

        self.global_step = None

    def _build_network(self, input_width):
        raise ValueError("Abstract Method Not Implemented.")

    def _initialize_variables(self):
        # Initialize variables
        with self.session.graph.as_default():
            self.session.run(tf.global_variables_initializer())
            if self.summary_writer:
                self.summary_writer.add_graph(self.session.graph)
            

    @property
    def training_step(self):
        return self.session.run(self.global_step)

    def _train(self, tokens, tok_lens, features, targets):
        raise ValueError("Abstract Method Not Implemented.")

    def _predict(self, tokens, features):
        raise ValueError("Abstract Method Not Implemented.")

    def _create_vocabulary(self, X):
        voc = {"<pad>" : 1, "<unk>" : 1}

        for line in X:
            for key, token in line.items():
                for letter in token:
                    voc[letter] = 1
        self.char_vocabulary.fit(list(voc.keys()))

    def _encode_tokens(self, X):
        tok_lens = []
        tok_enc = []
        pad_value = self.char_vocabulary.transform(['<pad>'])[0]

        for line in X:
            lens = []
            enc = []
            for key in sorted(line):
                tok = list(line[key])
                for i, _ in enumerate(tok):
                    if not tok[i] in self.char_vocabulary.classes_:
                        tok[i] = '<unk>'
                if len(tok) > 0:
                    enc.append(list(self.char_vocabulary.transform(tok)))
                else:
                    enc.append([])
                lens.append(len(enc[-1]))
            tok_lens.append(np.array(lens))
            tok_enc.append(np.array(enc))

        # padding
        max_len = np.max(tok_lens)
        for i, _ in enumerate(tok_enc):
            tok = [np.pad(x, (0, max_len - len(x)), 'constant', constant_values=pad_value) for x in tok_enc[i]]
            tok_enc[i] = tok

        return tok_enc, tok_lens

    def fit(self, X, y):
        tokens, features = self._split_features(X)

        self._create_vocabulary(tokens)
        tokens_tr, token_lens = self._encode_tokens(tokens)
        features_tr = self.feature_encoder.fit_transform(features)
        
        y_tr = self.target_encoder.fit_transform(y)

        assert (len(tokens_tr) == len(features_tr)), "Tokens_len does not match Features_len"
        assert (len(features_tr) == len(y_tr)), "Tokens_len does not match Y_len"

        tf.reset_default_graph()
        self._build_network((len(tokens_tr[1]) * self.EMBEDDING_SIZE) + len(features_tr[1]))

        for i in range((len(tokens_tr) // self.batch_size) + 1):
            start_idx = i * self.batch_size
            end_idx = (i + 1) * self.batch_size
            self._train(
                tokens_tr[start_idx : end_idx],
                token_lens[start_idx : end_idx],
                features_tr[start_idx : end_idx],
                y_tr[start_idx : end_idx])

        return None

    def predict(self, X):
        tokens, features = self._split_features(X)
        
        tokens_tr, token_lens = self._encode_tokens(tokens)
        features_tr =self.feature_encoder.transform(features)

        pred = self._predict(tokens_tr, token_lens, features_tr)
        return self.target_encoder.inverse_transform(pred[0])

    def predict_proba(self, X):
        tokens, features = self._split_features(X)

        tokens_tr, token_lens = self._encode_tokens(tokens)
        features_tr =self.feature_encoder.transform(features)

        pred = self._predict(tokens_tr, token_lens, features_tr)
        return pred[1]

    def _split_features(self, X):
        # Split the data X to a tuple of dictionaries (form_lemmas, attributes)
        # The first is to be embedded, the second to be one hot encoded

        tokens = []
        attributes = []
        for line in X:
            t = {}
            attr = {}
            for key, value in line.items():
                if "form" in key or "lemma" in key:
                    t[key] = value
                else:
                    attr[key] = value
            tokens.append(t)
            attributes.append(attr)

        return (tokens, attributes)

    

class FeedForwardNetwork(Network):    
    layer_type = "FeedForward"

    def __init__(
        self,
        network_width,
        network_depth,
        dropout,
        rnn_cell_dim,
        rnn_cell="GRU",
        layer_type="FeedForward",
        logdir="logs-nn",
        expname="basic-nn",
        threads=1,
        seed=42):

        Network.__init__(self, logdir, expname, threads, seed)
        self.h_width = network_width
        self.h_depth = network_depth
        self.rnn_cell_dim = rnn_cell_dim
        self.rnn_cell_type = rnn_cell
        self.dropout = dropout
        self.layer_type = layer_type

    def _build_network(self, input_width):
        with self.session.graph.as_default():
            if self.rnn_cell_type == "LSTM":
                self.rnn_cell = tf.contrib.rnn.LSTMCell(self.rnn_cell_dim)
            elif self.rnn_cell_type == "GRU":
                self.rnn_cell = tf.contrib.rnn.GRUCell(self.rnn_cell_dim)
            else:
                raise ValueError("Unknown rnn_cell {}".format(rnn_cell))

            self.global_step = tf.Variable(0, dtype=tf.int64, trainable=False, name='global_step')
            self.tokens = tf.placeholder(tf.int32, [None, None, None], name="tokens")
            self.token_lens = tf.placeholder(tf.int32, [None, None], name="token_lens")
            self.features = tf.placeholder(tf.float32, [None, None], name="features")            
            self.labels = tf.placeholder(tf.int64, [None], name="labels")
            self.alphabet_size = len(self.char_vocabulary.classes_)

            self.dropout_keep = tf.placeholder(tf.float32)
            self.input_width = input_width

            char_embedding_matrix = tf.get_variable(
                "char_embeddings",
                [self.alphabet_size, self.EMBEDDING_SIZE],
                initializer=tf.random_normal_initializer(stddev=0.01),
                dtype=tf.float32)
            
            with tf.variable_scope("token_encoder"):
                tokens_flat = tf.reshape(self.tokens, [-1, tf.shape(self.tokens)[-1]])
                token_lens_flat = tf.reshape(self.token_lens, [-1])
                char_embeddings = tf.nn.embedding_lookup(char_embedding_matrix, tokens_flat)

                hidden_states, final_states = tf.nn.bidirectional_dynamic_rnn(
                    cell_fw=self.rnn_cell,
                    cell_bw=self.rnn_cell,
                    inputs=char_embeddings,
                    sequence_length=token_lens_flat,
                    dtype=tf.float32,
                    scope="char_BiRNN")

            tokens_encoded = tf_layers.linear(
                tf.concat(final_states, 1),
                self.EMBEDDING_SIZE,
                scope="tokens_encoded")
            tokens_encoded = tf.reshape(tokens_encoded, [tf.shape(self.features)[0], -1])
           
            self.input_layer = tf.concat((tokens_encoded, self.features), 1)
            self.input_layer = tf.reshape(self.input_layer, [-1, self.input_width])

            # input transform
            self.hidden_layer = tf.nn.dropout(tf_layers.fully_connected(
                self.input_layer,
                num_outputs=self.h_width,
                activation_fn=None,
                scope="input_layer"), self.dropout_keep)

            # hidden layers
            for i in range(self.h_depth):
                if self.layer_type == "FeedForward":
                    self.hidden_layer = tf.nn.dropout(tf_layers.fully_connected(
                        self.hidden_layer,
                        num_outputs=self.h_width,
                        activation_fn=tf.nn.relu,
                        scope="ff_layer_{}".format(i)), self.dropout_keep)
                elif self.layer_type == "Highway":
                    self.hidden_layer = tf.nn.dropout(highway_layer(
                        self.hidden_layer,
                        num_outputs=self.h_width,
                        activation_fn=tf.nn.relu,
                        scope="highway_layer_{}".format(i)), self.dropout_keep)
                else:
                    raise ValueError("Unknown hidden layer type.")

            self.output_layer =  tf_layers.fully_connected(
                self.hidden_layer,
                num_outputs=len(self.target_encoder.classes_),
                activation_fn=None,
                scope="output_layer")

            self.predictions = tf.argmax(self.output_layer, 1)
            self.loss = tf.reduce_mean(tf.nn.sparse_softmax_cross_entropy_with_logits(logits=self.output_layer, labels=self.labels), name="loss")

            self.training = tf.train.AdamOptimizer().minimize(self.loss, global_step=self.global_step)
            self.accuracy = tf_metrics.accuracy(self.predictions, self.labels)

            self.summary = tf.summary.merge([
                tf.summary.scalar("train/loss", self.loss),
                tf.summary.scalar("train/accuracy", self.accuracy)])

            self._initialize_variables()

    def _train(self, tokens, token_lens, features, labels):
        try:
            _, summary, pred = self.session.run([self.training, self.summary, self.predictions],
                {self.tokens: tokens,
                self.token_lens: token_lens,
                self.features: features,
                self.labels: labels,
                self.dropout_keep: self.dropout})
        except Exception as e:
            import pdb; pdb.set_trace()
            raise e

        self.summary_writer.add_summary(summary, self.training_step)

    def _predict(self, tokens, token_lens, features):
        try:
            pred, logits = self.session.run([self.predictions, self.output_layer],
                {self.tokens: tokens,
                self.token_lens: token_lens,
                self.features: features,
                self.dropout_keep: 1.0})
        except Exception as e:
            import pdb; pdb.set_trace()
            raise e
        return (pred, logits)
