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
# WRITE_SENTENCES_SCEN=write_sentences_no_detok.scen
#
# There are several settings that you might want to use for better performance
# of Depfix, but are turned off by default:
#
# The parser used by default for Czech is a version of MST parser adapted for
# Czech, but for standard treebank Czech, not SMT outputs:
CS_ANALYSIS_2_SCEN=cs_analysis_2_boost_model_025.scen
# If you have at least 30 GB RAM, you should use the parser adapted for SMT
# outputs instead of the basic parser:
# CS_ANALYSIS_2_SCEN=cs_analysis_2_boost_model_025.scen
#
# By default, only rule-based corrections are used even on t-layer:
TFIX_SCEN=tfix_cut_ChgCase2.scen
# If you have at least 15 GB RAM, you may want to turn on the Deepfix
# statistical fixing module:
# TFIX_SCEN=tfix_cut_ChgCase2.scen
#
# By default, Treex is not run in parallel:
#TREEXP=treex
# However, if you have an SGE cluster, you can uncomment the following
# settings (and adjust them to your needs) to run Treex parallelly:
# JOBS=10
# MEM=30G
# WORKDIR=$$(mktemp -d --tmpdir=$(DIRNAME))
# TREEXP=treex -p --survive --jobs=$(JOBS) --mem=$(MEM) --workdir=$(WORKDIR)
#
