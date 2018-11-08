# This is an example of a settings file
#
# The Makefile specifies many default values -- you can look into it and look
# for CAPITALIZED_VALUE_NAMES followed by '=' and the default value.
# Most of these specify scenarios to use in Depfix (the scenarios themselves are
# in the "scenarios" directory).
# You can specify alternative values on command line when running depfix, e.g.:
# > make write_sentences WRITE_SENTENCES_SCEN=write_sentences_no_detok.scen
# to obtained tokenized output sentences instead of detokenized.
# Or, you can put them into this file, which is always processed before
# running anything -- so uncommenting the following line will have the same
# effect as the above given example if you run "make write_sentences":

# You can use "${WD}" variable to refer to the MLFix directory

#(TODO) comment everything


### INITIALIZATION ONLY ###

#DATA_SRC=data/src_en.txt
#DATA_MT=data/mt_cs.txt
#DATA_REF=data/ref_cs.txt

#DIRLABEL=label

### MAIN SETTINGS ###

LANG_SRC=en
LANG_TGT=cs

DIRROOT=/tmp
#DIRNAME=some-experiment-dir

#JOBS=40
#MEM=30G
#WORKDIR=$$(mktemp -d --tmpdir=$(DIRNAME))

TREEX=treex
#TREEXP=treex -p --survive --jobs=$(JOBS) --mem=$(MEM) --workdir=$(WORKDIR) --name $@ --queue=troja-all.q

# Taggers (see Treex:Scen::MLFix::Analysis_1)
TAGGER_SRC=morphodita
TAGGER_TGT=morphodita
# Training only
#TAGGER_REF=$(TAGGER_TGT)

# Interset drivers (see Treex:Scen::MLFix::Analysis_1)
ISET_DRIVER_SRC=en::penn
ISET_DRIVER_TGT=cs::pdt

# NER model file (set by default)
#NER_MODEL_SRC=ner-eng-ie.crf-3-all2008.ser.gz

# Parsers (see Treex::Scen::MLFix::Analysis_2)
PARSER_SRC=mst
PARSER_TGT=
# Training only
#PARSER_REF=mst

# MLFix config files
MARK_CONFIG_FILE=""
FIX_CONFIG_FILE=""

# MLFix error detection "hyperparameters"
VOTING_METHOD="majority"
MARK2FIX_THRESHOLD="0.5"

# Detokenize MLFix output
#DETOKENIZE=0


###  EVALUATION ###

#SAMPLES=1000 #(TO EVAL SETTINGS)
#ALPHA=0.05 #(TO EVAL SETTINGS

#ANNOT_LINES=3003 #(TO EVAL SETTINGS)
#ANNOT_NUM=20 #(TO EVAL SETTINGS)

#MAN_SUFFIX=mlfix_maneval #(TO EVAL SETTINGS)
#MAN_DIR=$(DIRNAME)_$(MAN_SUFFIX) #(TO EVAL SETTINGS)
