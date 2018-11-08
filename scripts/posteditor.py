#!/usr/bin/env python

from __future__ import division
from __future__ import print_function

import datetime
import numpy as np
import sys
import tensorflow as tf
import tensorflow.contrib.metrics as tf_metrics
import tensorflow.contrib.layers as tf_layers
import tensorflow.contrib.seq2seq as tf_seq2seq

import morpho_dataset
#import contrib_seq2seq

#class CharEncoder():

#class WordEncoder():

#class Decoder:

class Network:

    MAX_GEN_LEN = 99
    EMBEDDING_SIZE = 100
    ALIGNMENT_SIZE = 100

    def __init__(self,
                 encoder, decoder,
                 rnn_cell, rnn_cell_dim,
                 chars_size, words_size, tags_size,
                 bow_char, eow_char,
                 logdir, expname,
                 threads=1, seed=42):
        # Create an empty graph and a session
        graph = tf.Graph()
        graph.seed = seed
        self.session = tf.Session(
                        graph=graph,
                        config=tf.ConfigProto(
                                    inter_op_parallelism_threads=threads,
                                    intra_op_parallelism_threads=threads))

        timestamp = datetime.datetime.now().strftime("%Y-%m-%d_%H%M%S")
        self.summary_writer = tf.summary.FileWriter("{}/{}-{}".format(logdir, timestamp, expname), flush_secs=10)

        # Construct the graph
        with self.session.graph.as_default():
            if rnn_cell == "LSTM":
                rnn_cell = tf.contrib.rnn.LSTMCell(rnn_cell_dim)
            elif rnn_cell == "GRU":
                rnn_cell = tf.contrib.rnn.GRUCell(rnn_cell_dim)
            else:
                raise ValueError("Unknown rnn_cell {}".format(rnn_cell))

            self.global_step = tf.Variable(0, dtype=tf.int64, trainable=False, name="global_step")
            self.sentence_lens = tf.placeholder(tf.int32, [None], name="sent_lens")
            self.lemma_ids = tf.placeholder(tf.int32, [None, None], name="lemma_ids")
            self.lemmas = tf.placeholder(tf.int64, [None, None], name="lemmas")
            self.lemma_lens = tf.placeholder(tf.int32, [None], name="lemma_lens")
            self.tag_ids = tf.placeholder(tf.int32, [None, None], name="tag_ids")
            self.tags = tf.placeholder(tf.int64, [None, None], name="tags")
            self.tag_lens = tf.placeholder(tf.int32, [None], name="tag_lens")
            self.form_ids = tf.placeholder(tf.int32, [None, None], name="form_ids")
            self.forms = tf.placeholder(tf.int64, [None, None], name="forms")
            self.form_lens = tf.placeholder(tf.int32, [None], name="form_lens")

            self.alphabet_len = chars_size
            self.word_vocab_len = words_size
            self.tag_vocab_len = tags_size

            self.dummy_inputs = tf.zeros([tf.shape(self.sentence_lens)[0], self.MAX_GEN_LEN], name="inference_shape")

            self.char_embedding_matrix = tf.get_variable(
                                            "char_embeddings",
                                            [self.alphabet_len, self.EMBEDDING_SIZE],
                                            initializer=tf.random_normal_initializer(stddev=0.01),
                                            dtype=tf.float32)
            self.we_lookup_matrix = tf.get_variable(
                                        "we_lookup_matrix",
                                        [self.word_vocab_len, self.EMBEDDING_SIZE],
                                        initializer=tf.random_normal_initializer(stddev=0.01),
                                        dtype=tf.float32,
                                        trainable=True)
            self.tag_lookup_matrix = tf.get_variable(
                                        "tag_lookup_matrix",
                                        [self.tag_vocab_len, self.EMBEDDING_SIZE],
                                        initializer=tf.random_normal_initializer(stddev=0.01),
                                        dtype=tf.float32,
                                        trainable=True)
           
            # Encode words
            with tf.variable_scope("encoder"):
                self.char_embeddings = tf.nn.embedding_lookup(self.char_embedding_matrix, self.lemmas)
                ch_rnn_cell = tf.contrib.rnn.GRUCell(rnn_cell_dim)
                hidden_states, final_states = tf.nn.bidirectional_dynamic_rnn(
                                                    cell_fw=ch_rnn_cell,
                                                    cell_bw=ch_rnn_cell,
                                                    inputs=self.char_embeddings,
                                                    sequence_length=self.lemma_lens,
                                                    dtype=tf.float32,
                                                    scope="char_BiRNN")

            self.sentence_mask = tf.sequence_mask(self.sentence_lens)

            # Create decoder input
            self.we_encoder_matrix = tf_layers.linear(
                                        tf.concat(axis=1, values=final_states),
                                        self.EMBEDDING_SIZE,
                                        scope="we_encoder_matrix")
            self.encoder_output = tf.nn.embedding_lookup(self.we_encoder_matrix, self.lemma_ids)
            self.encoder_output = tf.reshape(
                                    tf.boolean_mask(self.encoder_output, self.sentence_mask),
                                    [-1, self.EMBEDDING_SIZE],
                                    name="encoder_output_flat")

            # Encode tags
            self.tags_embedded = tf.nn.embedding_lookup(self.tag_lookup_matrix, self.tag_ids)
            self.tags_embedded = tf.reshape(
                                    tf.boolean_mask(self.tags_embedded, self.sentence_mask),
                                    [-1, self.EMBEDDING_SIZE],
                                    name="tag_embeddings_flat")

            # Combine encoder_output with tag embedding
            self.encoder_output = tf_layers.linear(
                                    tf.concat(axis=1, values=[self.encoder_output, self.tags_embedded]),
                                    self.EMBEDDING_SIZE,
                                    scope="encoder_output_with_tags")

            # Create annotations for attention
            self.annot_matrix = tf_layers.linear(
                                    tf.concat(axis=2, values=hidden_states),
                                    self.EMBEDDING_SIZE,
                                    scope="annot_matrix")
            self.annotations = tf.nn.embedding_lookup(self.annot_matrix, self.lemma_ids)
            self.annotations = tf.reshape(
                                tf.boolean_mask(self.annotations, self.sentence_mask),
                                [-1, tf.shape(self.annot_matrix)[1], self.EMBEDDING_SIZE],
                                name="annotations_flat")

            # Reshape form values
            self.forms_flat = tf.nn.embedding_lookup(self.forms, self.form_ids)
            self.forms_flat = tf.reshape(
                                    tf.boolean_mask(self.forms_flat, self.sentence_mask),
                                    [-1, tf.shape(self.forms)[1]],
                                    name="forms_flat")
            self.forms_flat_lens = tf.nn.embedding_lookup(self.form_lens, self.form_ids)
            self.forms_flat_lens = tf.reshape(
                                        tf.boolean_mask(self.forms_flat_lens, self.sentence_mask),
                                        [-1],
                                        name="lemmas_flat_lens")

            self.attention_fn = None
            if decoder in ["individual", "individual_attention", "combined_attention", "combined_attention_birnn"]:
                if decoder in ["individual_attention", "combined_attention", "combined_attention_birnn"]:
                    #self.attention_fn = self.attention_fn_builder(self.annotations)
                if decoder == "combined_attention":
                    word_embeddings = tf.nn.embedding_lookup(self.we_lookup_matrix, self.lemma_ids)
                    word_embeddings = tf.reshape(
                                        tf.boolean_mask(word_embeddings, self.sentence_mask),
                                        [-1, self.EMBEDDING_SIZE],
                                        name="word_embeddings_flat")
                    self.encoder_output = tf_layers.linear(
                                            tf.concat(axis=1, values=[self.encoder_output, word_embeddings]),
                                            self.EMBEDDING_SIZE,
                                            scope="combined_encoder_output")
                if decoder == "combined_attention_rnn":
            else:
                raise ValueError("Unknown decoder ({}).".format(decoder))

            # Decoder training
            with tf.variable_scope("decoder"):
                if decoder == "individual":
                    self.training_logits, states = tf_seq2seq.rnn_decoder(
                                                    decoder_inputs=self.forms_flat,
                                                    initial_state=self.encoder_output,
                                                    cell=rnn_cell)
                else:
                    self.training_logits, states = tf_seq2seq.attention_decoder(
                                                    decoder_inputs=self.forms_flat,
                                                    initial_state=self.encoder_output,
                                                    attention_states=self.annotations,
                                                    cell=rnn_cell)
                                                

                
                #self.training_logits, states = tf_seq2seq.dynamic_rnn_decoder(
                                                #cell=rnn_cell,
                                                #decoder_fn=self.decoder_fn_train(
                                                #    self.encoder_output,
                                                #    self.output_fn_builder(),
                                                #    self.input_fn_builder(self.char_embedding_matrix, self.attention_fn)),
                                                #inputs=tf.expand_dims(self.forms_flat, -1),
                                                #sequence_length=self.forms_flat_lens)

            
            # Decoder inference
            with tf.variable_scope("decoder", reuse=True):
                if decoder == "individual":
                    self.training_logits, states = tf_seq2seq.rnn_decoder(
                                                    decoder_inputs=self.dummy_inputs,
                                                    initial_state=self.encoder_output,
                                                    cell=rnn_cell,
                                                    loop_function=decoder_fn)
                else:
                    self.training_logits, states = tf_seq2seq.attention_decoder(
                                                    decoder_inputs=self.dummy_inputs,
                                                    initial_state=self.encoder_output,
                                                    attention_states=self.annotations,
                                                    cell=rnn_cell,
                                                    loop_function=decoder_fn)

                #self.inference_logits, states = tf_seq2seq.dynamic_rnn_decoder(
                                                    #cell=rnn_cell,
                                                    #decoder_fn=self.decoder_fn_inference(
                                                    #    self.encoder_output,
                                                    #    self.output_fn_builder(),
                                                    #    self.input_fn_builder(self.char_embedding_matrix, self.attention_fn),
                                                    #bow_char,
                                                    #eow_char,
                                                    #self.MAX_GEN_LEN))

            self.predictions = tf.argmax(self.inference_logits, 2)
            loss = tf.reduce_mean(tf.nn.sparse_softmax_cross_entropy_with_logits(logits=self.training_logits, labels=self.forms_flat[:,1:]))
            self.training = tf.train.AdamOptimizer().minimize(loss, global_step=self.global_step)

            self.forms_flat = tf.cond(
                                tf.reduce_max(self.forms_flat_lens) > self.MAX_GEN_LEN,
                                lambda: tf.slice(self.forms_flat, [0, 0], [-1, self.MAX_GEN_LEN]),
                                lambda: self.forms_flat)

            self.pred_padded = tf.pad(
                            self.predictions,
                            [[0,0],[0, self.MAX_GEN_LEN - tf.shape(self.predictions)[1]]],
                            mode="CONSTANT")
            self.forms_padded = tf.pad(
                                self.forms_flat,
                                [[0,0],[0, self.MAX_GEN_LEN - tf.shape(self.forms_flat)[1] + 1]],
                                mode="CONSTANT")

            self.char_accuracy = tf_metrics.accuracy(self.pred_padded, self.forms_padded[:,1:])
            self.word_accuracy = tf.reduce_mean(tf.reduce_min(tf.cast(tf.equal(self.pred_padded, self.forms_padded[:,1:]), tf.float32), axis=1))


            self.summary = {}
            for dataset_name in ["train", "dev"]:
                self.summary[dataset_name] = tf.summary.merge([tf.summary.scalar(dataset_name+"/loss", loss),
                                             tf.summary.scalar(dataset_name+"/char_accuracy", self.char_accuracy),
                                             tf.summary.scalar(dataset_name+"/word_accuracy", self.word_accuracy)])

            # Initialize variables
            self.session.run(tf.global_variables_initializer())
            if self.summary_writer:
                self.summary_writer.add_graph(self.session.graph)


    # Simple decoder for training
    def decoder_fn_train(self, encoder_state, output_fn, input_fn, name=None):
        def decoder_fn(time, cell_state, next_id, cell_output, context_state):
            cell_output = output_fn(cell_output)
            reuse = True
            if cell_state is None:  # first call, return encoder_state
                cell_state = encoder_state
                reuse = None
            next_input = input_fn(tf.squeeze(next_id, [1]), cell_state, reuse)
            
            return (None, cell_state, next_input, cell_output, context_state)

        return decoder_fn

    # TODO: Beam search
    # Simple decoder for inference
    def decoder_fn_inference(self, encoder_state, output_fn, input_fn,
                         beginning_of_word="<bow>", end_of_word="<eow>", maximum_length=MAX_GEN_LEN):
        batch_size = tf.shape(encoder_state)[0]
        def decoder_fn(time, cell_state, cell_input, cell_output, context_state):
            cell_output = output_fn(cell_output)
            if cell_state is None:
                cell_state = encoder_state
                next_id = tf.tile([beginning_of_word], [batch_size])
                done = tf.zeros([batch_size], dtype=tf.bool)
            else:
                next_id = tf.argmax(cell_output, 1)
                done = tf.equal(next_id, end_of_word)
                done = tf.cond(
                        tf.greater_equal(time, maximum_length), # return true if time >= maxlen
                        lambda: tf.ones([batch_size], dtype=tf.bool),
                        lambda: done)
            next_input = input_fn(next_id, cell_state, True)

            return (done, cell_state, next_input, cell_output, context_state)

        return decoder_fn

    def decoder_fn_builder(self, encoder_state, output_fn, input_fn,
                        beginning_of_word="<bow>", end_of_word="<eow>", maximum_length=MAX_GEN_LEN):
        def decoder_fn(cell_output, i):
            cell_output = output_fn(cell_output)
            next_input = tf.argmax(cell_output, 1)
            next_input = input_fn(next_input)

        return decoder_fn

    # TODO: dropout
    def attention_fn_builder(self, annotations):
        def attention_fn(state):
            batch_size = tf.shape(state)[0]
            annot_len = tf.shape(annotations)[1]

            annot_dim = annotations.get_shape().as_list()[2]
            state_dim = state.get_shape().as_list()[1]
            e_dim = self.ALIGNMENT_SIZE

            a = tf.reshape(annotations, [-1, annot_dim])

            U = tf.get_variable(
                    "annot_weight",
                    shape=[annot_dim, e_dim],
                    initializer=tf.random_normal_initializer(stddev=0.1),
                    trainable=True)
            U_b = tf.get_variable(
                    "annot_bias",
                    shape=[e_dim],
                    initializer=tf.constant_initializer(0.1)) 

            W = tf.get_variable(
                    "state_weight",
                    shape=[state_dim, e_dim],
                    initializer=tf.random_normal_initializer(stddev=0.1),
                    trainable=True)
            W_b = tf.get_variable(
                    "state_bias",
                    shape=[e_dim],
                    initializer=tf.constant_initializer(0.1))

            v = tf.get_variable(
                    "lin_combo",
                    shape=[e_dim, 1],
                    initializer=tf.random_normal_initializer(stddev=0.1),
                    trainable=True)

            w_res = tf.matmul(state, W) + W_b
            w_res = tf.tile(tf.reshape(w_res, [-1, 1]), [1, annot_len])

            u_res = tf.matmul(a, U) + U_b
            u_res = tf.reshape(u_res, [-1, annot_len])

            e = tf.matmul(tf.tanh(tf.reshape(w_res + u_res, [-1, e_dim])), v)
            e = tf.reshape(e, [batch_size, -1])

            alpha = tf.nn.softmax(e)
            alpha = tf.tile(tf.reshape(alpha, [-1, 1]), [1, annot_dim])
            c = tf.multiply(alpha, a)
            c = tf.reduce_sum(tf.reshape(c, [batch_size, -1, annot_dim]), 1)

            C = tf.get_variable(
                    "attention_weight",
                    shape=[state_dim, state_dim],
                    initializer=tf.random_normal_initializer(stddev=0.1),
                    trainable=True)
            C_b = tf.get_variable(
                    "attention_bias",
                    shape=[state_dim],
                    initializer=tf.constant_initializer(0.1))

            return tf.add(tf.matmul(c, C), C_b)

        return attention_fn


    # Output function builder (makes logits out of rnn outputs)
    def output_fn_builder(self):
        def output_fn(cell_output):
            if cell_output is None:
                return tf.zeros([self.alphabet_len], tf.float32) # only used for shape inference
            else:
                return tf_layers.linear(
                            cell_output,
                            num_outputs=self.alphabet_len,
                            scope="decoder_output")

        return output_fn

    # Input function builder (makes rnn input from word id and cell state)
    def input_fn_builder(self, embeddings):
        def input_fn(next_id):
            return tf.nn.embedding_lookup(embeddings, next_id)
    
        return input_fn


    # Input function builder (makes rnn input from word id and cell state)
    #def input_fn_builder(self, embeddings, attention_fn=None):
    #    def input_fn(next_id, cell_state, reuse=True):
    #        if attention_fn is not None:
    #            with tf.variable_scope("attention", reuse=reuse):
    #                return tf.add(
    #                            tf.nn.embedding_lookup(embeddings, next_id),
    #                            attention_fn(cell_state))
    #        else:
    #            return tf.nn.embedding_lookup(embeddings, next_id)
    #
    #    return input_fn

    @property
    def training_step(self):
        return self.session.run(self.global_step)

    def train(self,
              sentence_lens,
              forms, form_ids, form_lens,
              tags, tag_ids, tag_lens,
              lemmas, lemma_ids, lemma_lens):
        try:
            _, summary, pred = self.session.run([self.training, self.summary, self.predictions],
                                      {self.sentence_lens: sentence_lens,
                                       self.forms: forms,
                                       self.form_ids: form_ids,
                                       self.form_lens: form_lens,
                                       self.tags: tags,
                                       self.tag_ids: tag_ids,
                                       self.tag_lens: tag_lens,
                                       self.lemmas: lemmas,
                                       self.lemma_ids: lemma_ids,
                                       self.lemma_lens: lemma_lens})
        except Exception as e:
            import pdb; pdb.set_trace()
            raise e

        self.summary_writer.add_summary(summary["train"], self.training_step)

    def evaluate(self,
                 sentence_lens,
                 forms, form_ids, form_lens,
                 tags, tag_ids, tag_lens,
                 lemmas, lemma_ids, lemma_lens):
        try:
            ch_acc, w_acc, summary, pred = self.session.run([self.char_accuracy, self.word_accuracy, self.summary, self.predictions],
                                             {self.sentence_lens: sentence_lens,
                                              self.forms: forms,
                                              self.form_ids: form_ids,
                                              self.form_lens: form_lens,
                                              self.tags: tags,
                                              self.tag_ids: tag_ids,
                                              self.tag_lens: tag_lens,
                                              self.lemmas: lemmas,
                                              self.lemma_ids: lemma_ids,
                                              self.lemma_lens: lemma_lens})
        except Exception as e:
            import pdb; pdb.set_trace()
            raise e

        self.summary_writer.add_summary(summary["dev"], self.training_step)
        return ch_acc, w_acc

    def predict(self,
                sentence_lens,
                lemmas, lemma_ids, lemma_lens,
                tags, tag_ids, tag_lens):
        predictions = self.session.run([self.predictions],
                                {self.sentence_lens: sentence_lens,
                                 self.lemmas: lemmas,
                                 self.lemma_ids: lemma_ids,
                                 self.lemma_lens: lemma_lens,
                                 self.tags: tags,
                                 self.tag_ids: tag_ids,
                                 self.tag_lens: tag_lens})
        return predictions

if __name__ == "__main__":
    # Fix random seed
    np.random.seed(42)

    # Parse arguments
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--batch_size", default=64, type=int, help="Batch size.")
    parser.add_argument("--data_train", default="data/en-train-gen.txt", type=str, help="Training data file.")
    parser.add_argument("--data_dev", default="data/en-dev.txt", type=str, help="Development data file.")
    parser.add_argument("--data_test", default="data/en-test-gen.txt", type=str, help="Testing data file.")
    parser.add_argument("--epochs", default=10, type=int, help="Number of epochs.")
    parser.add_argument("--logdir", default="logs", type=str, help="Logdir name.")
    parser.add_argument("--rnn_cell", default="GRU", type=str, help="RNN cell type.")
    parser.add_argument("--rnn_cell_dim", default=100, type=int, help="RNN cell dimension.")
    parser.add_argument("--encoder", default="simple", type=str, help="Which encoder should we use.")
    parser.add_argument("--decoder", default="individual", type=str, help="Which decoder should we use.")
    parser.add_argument("--threads", default=1, type=int, help="Maximum number of threads to use.")
    args = parser.parse_args()

    # Load the data
    print("Loading the data.", file=sys.stderr)
    data_train = morpho_dataset.MorphoDataset(args.data_train, add_bow_eow=True)
    data_dev = morpho_dataset.MorphoDataset(args.data_dev, add_bow_eow=True, train=data_train)
    data_test = morpho_dataset.MorphoDataset(args.data_test, add_bow_eow=True, train=data_train)
    bow_char = data_train.alphabet.index("<bow>")
    eow_char = data_train.alphabet.index("<eow>")

    # Construct the network
    print("Constructing the network.", file=sys.stderr)
    expname = "generator-{}{}-bs{}-epochs{}".format(args.rnn_cell, args.rnn_cell_dim, args.batch_size, args.epochs)
    network = Network(rnn_cell=args.rnn_cell,
                      encoder=args.encoder,
                      decoder=args.decoder,
                      rnn_cell_dim=args.rnn_cell_dim,
                      chars_size=len(data_train.alphabet),
                      words_size=len(data_train.factors[data_train.FORMS]['words']),
                      tags_size=len(data_train.factors[data_train.TAGS]['words']),
                      bow_char=bow_char,
                      eow_char=eow_char,
                      logdir=args.logdir,
                      expname=expname,
                      threads=args.threads)

    # Train
    best_dev_ch_acc = 0
    best_dev_w_acc = 0
    test_predictions = None

    for epoch in range(args.epochs):
        print("Training epoch {}".format(epoch + 1), file=sys.stderr)
        while not data_train.epoch_finished():
            sentence_lens, form_ids, charseq_ids, charseqs, charseq_lens = \
                data_train.next_batch(args.batch_size, including_charseqs=True)

            network.train(
                sentence_lens,
                charseqs[data_train.FORMS],
                charseq_ids[data_train.FORMS],
                charseq_lens[data_train.FORMS],
                charseqs[data_train.TAGS],
                charseq_ids[data_train.TAGS],
                charseq_lens[data_train.TAGS],
                charseqs[data_train.LEMMAS],
                charseq_ids[data_train.LEMMAS],
                charseq_lens[data_train.LEMMAS])

        sentence_lens, form_ids, charseq_ids, charseqs, charseq_lens = data_dev.whole_data_as_batch(including_charseqs=True)
        dev_ch_acc, dev_w_acc = network.evaluate(
                                    sentence_lens,
                                    charseqs[data_train.FORMS],
                                    charseq_ids[data_train.FORMS],
                                    charseq_lens[data_train.FORMS],
                                    charseqs[data_train.TAGS],
                                    charseq_ids[data_train.TAGS],
                                    charseq_lens[data_train.TAGS],
                                    charseqs[data_train.LEMMAS],
                                    charseq_ids[data_train.LEMMAS],
                                    charseq_lens[data_train.LEMMAS])

        print("Development ch_acc after epoch {} is {:.2f}, w_acc is {:.2f}.".format(epoch + 1, 100. * dev_ch_acc, 100. * dev_w_acc), file=sys.stderr)

        if dev_w_acc > best_dev_w_acc or (dev_w_acc == best_dev_w_acc and dev_ch_acc > best_dev_ch_acc):
            best_dev_w_acc = dev_w_acc
            best_dev_ch_acc = dev_ch_acc

            sentence_lens, form_ids, charseq_ids, charseqs, charseq_lens = data_test.whole_data_as_batch(including_charseqs=True)
            test_predictions = network.predict(
                                    sentence_lens,
                                    charseqs[data_train.LEMMAS],
                                    charseq_ids[data_train.LEMMAS],
                                    charseq_lens[data_train.LEMMAS],
                                    charseqs[data_train.TAGS],
                                    charseq_ids[data_train.TAGS],
                                    charseq_lens[data_train.TAGS])

    # Print test predictions
    test_forms = data_test.factors[data_test.FORMS]['strings'] # We use strings instead of words, because words can be <unk>
    test_predictions = list(test_predictions)
    for i in range(len(data_test.sentence_lens)):
        for j in range(data_test.sentence_lens[i]):
            form = ''
            pred = test_predictions.pop(0)
            for k in range(len(pred)):
                if pred[k] == eow_char:
                    break
                form += data_test.alphabet[pred[k]]
            print("{}\t{}\t_".format(test_forms[i][j], form))
        print()

    print("Final best dev set accuracy: {:.2f}".format(100. * best_dev_w_acc))
