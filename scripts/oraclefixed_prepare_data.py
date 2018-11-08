#!/usr/bin/env python3

"""
Take original MT sentence and MLFixOracle generated
output and mark changed words.
"""

# tests: lint

import argparse
import re
import numpy as np


def load_tokenized(text_file, preprocess=None):
    if not preprocess:
        preprocess = lambda x: x
    return [preprocess(re.split(r"[ ]", l.rstrip())) for l in text_file]


def convert_to_edits(source, target):
    keep = '<keep>'
    delete = '<fix>'

    if len(source) != len(target):
        raise ValueError("Source and target sentence length do not match:\n\
            {}\n\
            {}".format(" ".join(source), " ".join(target)))

    edits = []
    for i in range(len(source)):
        if source[i] == target[i]:
            edits.append("<keep>")
        else:
            edits.append("<fix>")

    return edits


def main():
    parser = argparse.ArgumentParser(
        description="Convert postediting target data to sequence of edits")
    parser.add_argument("--translated-sentences",
                        type=argparse.FileType('r'), required=True)
    parser.add_argument("--target-sentences",
                        type=argparse.FileType('r'), required=True)
    args = parser.parse_args()

    preprocess = None

    trans_sentences = load_tokenized(
        args.translated_sentences, preprocess=preprocess)
    tgt_sentences = load_tokenized(
        args.target_sentences, preprocess=preprocess)

    for trans, tgt in zip(trans_sentences, tgt_sentences):
        edits = convert_to_edits(trans, tgt)
        print(" ".join(edits))

if __name__ == '__main__':
    main()
