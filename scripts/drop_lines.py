#!/usr/bin/env python

import os, sys, argparse
import gzip
import numpy as np

## Main Program ##

# Parse command line arguments
parser = argparse.ArgumentParser(description="Drop lines satisfiing the condition.")
parser.add_argument('input_file', metavar='input_data', type=str)
parser.add_argument('condition', metavar='condition for drop', type=str)
args = parser.parse_args()

fh = gzip.open(args.input_file, 'rb', 'UTF-8')
line = fh.readline().rstrip("\n")
print line
feature_names =  line.split("\t")

name,value = args.condition.split('=')
inverted = False
if "!=" in args.condition:
    name,value = args.condition.split('!=') 
    inverted = True   

index = -1

for i in range(len(feature_names)):
    if feature_names[i] == name:
        index = i
        break

if index == -1:
    sys.stderr.write("Input file does not contain feature '%s'." % (name))
    sys.exit()

# Process the file
while True:
    line = fh.readline().rstrip("\n")
    if not line:
        break
    feat_values = line.split("\t")
    if (feat_values[index] != value and not inverted) or (feat_values[index] == value and inverted):
        print line
