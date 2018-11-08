SHELL := /bin/bash

################################
# Setting some basic variables #
################################

# Source and target languages (with default values)
LANG_SRC=en
LANG_TGT=cs

# Input data (with default values)
DATA_SRC=data/src_en.txt
DATA_MT=data/mt_cs.txt
DATA_REF=data/ref_cs.txt


### WORKDIR VARIABLES ###

# Directory containing individual experiments (default = workdir)
DIRROOT=$(shell pwd)
# Base name of the new experiment directory (default is date_time_randseed)
DIRBASE:=$(shell echo `date +%Y-%m-%d_%H-%M-%S_``printf %05d $$RANDOM``printf %05d $$RANDOM`)
# User defined label of the experiment (needed during init)
DIRLABEL=$(NEWDIR_NAME)
# Experiment directory name
DIRNAME=$(DIRBASE)_$(DIRLABEL)
# Full path to the experiment directory
DIRPATH=$(DIRROOT)/$(DIRNAME)

TMPDIR=/tmp

### ENVIRONMENT VARIABLES ###

# Working directory (containing scripts, scenarios etc.)
# Do not change this if not necessary!
WD=$(shell pwd)

# job control
DOC_IDS=*

# Treex command (with desired options) to be run
# not run in parallel by default -- see settings.mak
TREEX=treex
TREEXP=$(TREEX) #(TO_SETTINGS)

# Required scenarios
SCEN_DIR=$(WD)/scenarios
# Required scripts
SCRIPT_DIR=$(WD)/scripts

BOOTSTRAP=$(SCRIPT_DIR)/bootstrap_eval
MTRICS=$(SCRIPT_DIR)/mtrics

# Info about the target currently being run
E=@echo MLFIX [$(DIRNAME)]: $@

# Default settings file
SETTINGS_FILE=settings.mak




#####################
# Available targets #
#####################

# Full analysis, fixing and automatic evaluation
default: init default_ni

# Test target
test:
	make default DIRLABEL=small_test \
		DATA_SRC=data/src_en.txt DATA_MT=data/mt_cs.txt DATA_REF=data/ref_cs.txt

# Default target (no init)
default_ni: totreex tag run_giza ner_en parse mlfix write_sentences eval

# Collect training data
collect: totreex tag run_giza ner_en parse collect_edits
collect_all: collect collect_statistics

#(TODO) finish monolingual extraction
#collect_mono: totreex_mono tag_mono collect_edits

#(BACKWARD COMPATIBILITY)
# Default behaviour: try to interpret the target as scenario file name
# e.g. if you type "make fix_new" and there is a scenarios/fix_new.scen file,
# it will be run in the working directory on the translation*.treex.gz files
.DEFAULT:
	$E
	$(TREEXP) \
	$(SCEN_DIR)/$@.scen Write::Treex to=.\
	-- $(DIRPATH)/translation$(DOC_IDS).treex.gz


# Show help
help:
	less README


## INITIALIZATION ##

# Create a new working directory and copy the source data into it
init:
	$E LANG_SRC=$(LANG_SRC) LANG_TGT=$(LANG_TGT) DATA_SRC=$(DATA_SRC) DATA_MT=$(DATA_MT) DATA_REF=$(DATA_REF)
# new directory for data
	@-mkdir $(DIRPATH)
	@echo "Working directory:"
	@echo
	@echo $(DIRPATH)
	@echo
# input data
	@cp $(DATA_SRC) $(DIRPATH)/data_src.txt
	@cp $(DATA_MT) $(DIRPATH)/data_mt.txt
	@cp $(DATA_REF) $(DIRPATH)/data_ref.txt
	@paste $(DIRPATH)/data_src.txt $(DIRPATH)/data_mt.txt > $(DIRPATH)/data_in.txt


## TOKENIZATION ##

# Convert *.txt data to *.treex.gz
#(TODO) replace Scen with SCEN:: block
PROJECT_TOKENIZATION_SCEN=project_tokenization.scen
totreex:
	$E PROJECT_TOKENIZATION_SCEN=$(PROJECT_TOKENIZATION_SCEN)
	@split -a 5 -d -l 100 $(DIRPATH)/data_src.txt $(DIRPATH)/src_part
	@split -a 5 -d -l 100 $(DIRPATH)/data_mt.txt $(DIRPATH)/mt_part 
	@split -a 5 -d -l 100 $(DIRPATH)/data_ref.txt  $(DIRPATH)/ref_part 
	$(TREEX) Read::AlignedSentences file_stem=$(DIRPATH)/translation $(LANG_SRC)="!$(DIRPATH)/src_part*" $(LANG_TGT)="!$(DIRPATH)/mt_part*" $(LANG_TGT)_ref="!$(DIRPATH)/ref_part*" Write::Treex to=.
# remove temporary data
	@rm $(DIRPATH)/src_part* $(DIRPATH)/mt_part* $(DIRPATH)/ref_part* 
# project tokenization
	$(TREEXP) \
	Util::SetGlobal language=$(LANG_TGT) source_language=$(LANG_SRC) \
	$(SCEN_DIR)/$(PROJECT_TOKENIZATION_SCEN) Write::Treex to=. \
	-- $(DIRPATH)/translation*.treex.gz

# No source sentences provided
#(TODO) Test, if working
totreex_mono:
	$E PROJECT_TOKENIZATION_SCEN=$(PROJECT_TOKENIZATION_SCEN)
	@split -a 5 -d -l 100 $(DIRPATH)/data_mt.txt $(DIRPATH)/mt_part 
	@split -a 5 -d -l 100 $(DIRPATH)/data_ref.txt  $(DIRPATH)/ref_part 
	$(TREEX) Read::AlignedSentences file_stem=$(DIRPATH)/translation $(LANG_TGT)="!$(DIRPATH)/mt_part*" $(LANG_TGT)_ref="!$(DIRPATH)/ref_part*" Write::Treex to=.
# remove temporary data
	@rm $(DIRPATH)/mt_part* $(DIRPATH)/ref_part* 


## MORPHOLOGICAL ANALYSIS ##

# Run morphological analyses
# Default values
TAGGER_SRC=morphodita
TAGGER_TGT=morphodita
ISET_DRIVER_SRC=en::penn
ISET_DRIVER_TGT=cs::pdt

SRC_ANALYSIS_1_SCEN=Scen::MLFix::Analysis_1 language=$(LANG_SRC) tagger=$(TAGGER_SRC) iset_driver="$(ISET_DRIVER_SRC)"
TGT_ANALYSIS_1_SCEN=Scen::MLFix::Analysis_1 language=$(LANG_TGT) tagger=$(TAGGER_TGT) iset_driver="$(ISET_DRIVER_TGT)"

tag:
	$E SRC_ANALYSIS_1_SCEN=$(SRC_ANALYSIS_1_SCEN) TGT_ANALYSIS_1_SCEN=$(TGT_ANALYSIS_1_SCEN)
	$(TREEXP) \
	$(SRC_ANALYSIS_1_SCEN) \
	$(TGT_ANALYSIS_1_SCEN) Write::Treex to=. \
	-- $(DIRPATH)/translation*.treex.gz

#(TODO) Test, if working
tag_mono:
	$E SRC_ANALYSIS_1_SCEN=$(SRC_ANALYSIS_1_SCEN) TGT_ANALYSIS_1_SCEN=$(TGT_ANALYSIS_1_SCEN)
	$(TREEXP) \
    $(TGT_ANALYSIS_1_SCEN) Write::Treex to=. \
    -- $(DIRPATH)/translation*.treex.gz


## ALIGNMENT AND NER ##

# Run the Giza++ aligner
# We want to create alignment from the MT to SRC
RUN_GIZA_SCEN=Scen::MLFix::RunMGiza from_language=$(LANG_TGT) to_language=$(LANG_SRC) model=$(LANG_TGT)-$(LANG_SRC) tmp_dir=${TMPDIR}
run_giza:
	$E RUN_GIZA_SCEN=$(RUN_GIZA_SCEN)
	$(TREEXP) $(RUN_GIZA_SCEN) Write::Treex to=. \
	-- $(DIRPATH)/translation*.treex.gz

#(TODO) add tgt lang ner?
# Run Named Entity Recognizer for English
# Default values
NER_MODEL_SRC=ner-eng-ie.crf-3-all2008.ser.gz

SRC_NER_SCEN=Scen::MLFix::NER language=$(LANG_SRC) model=$(NER_MODEL_SRC)
ner_en:
	$E SRC_NER_SCEN=$(SRC_NER_SCEN)
	$(TREEXP) $(SRC_NER_SCEN) Write::Treex to=. \
	-- $(DIRPATH)/translation*.treex.gz

# Run dependency parsers
# Default values
PARSER_SRC=mst
PARSER_TGT=

SRC_ANALYSIS_2_SCEN=Scen::MLFix::Analysis_2 language=$(LANG_SRC) parser=$(PARSER_SRC)
TGT_ANALYSIS_2_SCEN=Scen::MLFix::Analysis_2 language=$(LANG_TGT) src_language=$(LANG_SRC) parser=$(PARSER_TGT)

# Some parsing target variety
parse: parse_src parse_tgt parse_backup
parse_no_backup: parse_src parse_tgt

#(TODO) delete? - This should be covered by "parse" and SCENs
#parse_src_only: parse_src parse_backup

# This is basically a stopping point for analysis, so we backup the results
parse_backup:
	@-mkdir $(DIRPATH)/parsed
# back up parsed files without fixes
	cp $(DIRPATH)/translation*.treex.gz $(DIRPATH)/parsed

parse_src:
	$E SRC_ANALYSIS_2_SCEN=$(SRC_ANALYSIS_2_SCEN)
	$(TREEXP) \
	$(SRC_ANALYSIS_2_SCEN) Write::Treex to=. \
	-- $(DIRPATH)/translation*.treex.gz

parse_tgt:
	$E TGT_ANALYSIS_2_SCEN=$(TGT_ANALYSIS_2_SCEN)
	$(TREEXP) \
	$(TGT_ANALYSIS_2_SCEN) Write::Treex to=. \
	-- $(DIRPATH)/translation*.treex.gz


## MLFIX Fix blocks ##

# Default values
MARK_CONFIG_FILE=""
FIX_CONFIG_FILE=""
VOTING_METHOD="majority"
MARK2FIX_THRESHOLD="0.5"
DETOKENIZE=0

WRITE_SENTENCES_SCEN=Scen::MLFix::WriteSentences language=$(LANG_TGT) detokenize=$(DETOKENIZE)

mlfix: fix_prepare mlfix_run
mlfix_run: save_config
	$E MARK_CONFIG_FILE=$(MARK_CONFIG_FILE) FIX_CONFIG_FILE=$(FIX_CONFIG_FILE)
	$(TREEXP) \
	Scen::MLFix::Fix language=$(LANG_TGT) selector= mark_config_file=$(MARK_CONFIG_FILE) fix_config_file=$(FIX_CONFIG_FILE) iset_driver=$(ISET_DRIVER_TGT) voting_method=$(VOTING_METHOD) threshold=$(MARK2FIX_THRESHOLD) Write::Treex to=. \
	-- $(DIRPATH)/translation*.treex.gz

# Restore parsed files without fixes
restore_parsed:
	$E
	cp $(DIRPATH)/parsed/translation*.treex.gz $(DIRPATH)

# Prepare for fixing but do not fix
NER_TGT_SCEN=Scen::MLFix::NER language=$(LANG_TGT)
FIX_PREPARE_SCEN=Scen::MLFix::FixPrepare src_language=$(LANG_SRC) tgt_language=$(LANG_TGT)
fix_prepare: restore_parsed
	$E FIX_PREPARE_SCEN=$(FIX_PREPARE_SCEN)
	$(TREEXP) \
	$(FIX_PREPARE_SCEN) \
	$(NER_TGT_SCEN) Write::Treex to=. \
	-- $(DIRPATH)/translation*.treex.gz


# Results of mlfix (written by write_sentences),
# to be used in evaluation (both auto and manual) and comparison
OUTPUT_TXT=mlfix_output.txt

# Print out the fixed sentences
write_sentences: write_fixlog
#write_sentences:
	$E WRITE_SENTENCES_SCEN=$(WRITE_SENTENCES_SCEN) OUTPUT_TXT=$(OUTPUT_TXT)
	$(TREEXP) \
	$(WRITE_SENTENCES_SCEN) \
	Write::Sentences to=. \
	-- $(DIRPATH)/translation*.treex.gz 
	cat $(DIRPATH)/translation*.txt \
	> $(DIRPATH)/$(OUTPUT_TXT)

write_fixlog:
	$(TREEX) \
	$(SCEN_DIR)/write_fixlog.scen \
	-- $(DIRPATH)/translation*.treex.gz \
	> $(DIRPATH)/fixlog.txt

WRITE_TRIPARALLEL_SCEN=Scen::MLFix::WriteTriparallel language=$(LANG_TGT)
write_triparallel:
	$E WRITE_TRIPARALLEL_SCEN=$(WRITE_TRIPARALLEL_SCEN)
	$(TREEX) \
	$(WRITE_TRIPARALLEL_SCEN) \
	-- $(DIRPATH)/translation*.treex.gz | \
	$(SCRIPT_DIR)/filter_sent.pl \
	> $(DIRPATH)/triparallel.txt




################
## EVALUATION ##
################

# Perform automatic evaluation, storing its result into $(AUTOEVAL_OUT),
# and show it as tab separated values
# Evaluates original source and $(OUTPUT_TXT).
AUTOEVAL_OUT=autoeval.out
SRC_TXT=data_src.txt
MT_TXT=data_mt.txt
REF_TXT=data_ref.txt

eval: eval_dirname eval_lines eval_bleu eval_ter eval_show

# Store the working directory name
eval_dirname:
	@echo $(DIRPATH) > $(DIRPATH)/$(AUTOEVAL_OUT)

# Count number of lines changed by Depfix
eval_lines:
	@$(SCRIPT_DIR)/chgd.pl $(DIRPATH)/$(MT_TXT) $(DIRPATH)/$(OUTPUT_TXT) >> $(DIRPATH)/$(AUTOEVAL_OUT)

# Compute BLEU and NIST
eval_bleu:
	@$(SCRIPT_DIR)/wrapmteval.pl $(DIRPATH)/$(SRC_TXT) $(DIRPATH)/$(REF_TXT) $(DIRPATH)/$(MT_TXT) 2> /dev/null | grep "^NIST"   >> $(DIRPATH)/$(AUTOEVAL_OUT)
	@$(SCRIPT_DIR)/wrapmteval.pl $(DIRPATH)/$(SRC_TXT) $(DIRPATH)/$(REF_TXT) $(DIRPATH)/$(OUTPUT_TXT)  2> /dev/null | grep "^NIST"   >> $(DIRPATH)/$(AUTOEVAL_OUT)

# Compute PER and TER
eval_ter:
	@$(MTRICS) --per --ter -c $(DIRPATH)/$(MT_TXT) $(DIRPATH)/$(OUTPUT_TXT) -r $(DIRPATH)/$(REF_TXT)   | grep "[PT]ER:" >> $(DIRPATH)/$(AUTOEVAL_OUT)

# Show results of automatic evaluation
eval_show:
	$E AUTOEVAL_OUT=$(AUTOEVAL_OUT)
	@$(SCRIPT_DIR)/process_eval_scores.pl $(DIRPATH)/$(AUTOEVAL_OUT)


eval_cased:
	@$(MTRICS) --tokenize --case-sensitive --bleu --nist --per --ter -c $(DIRPATH)/$(MT_TXT) $(DIRPATH)/$(OUTPUT_TXT) -r $(DIRPATH)/$(REF_TXT)

view:
	less $(DIRPATH)/$(OUTPUT_TXT)


# Textual comparison of mlfix inputs (ORI) and outputs (NEW),
# Also showing reference (REF) and translation source (SRC)
ORI=$(MT_TXT)
NEW=$(OUTPUT_TXT)
REF=$(REF_TXT)
SRC=$(SRC_TXT)

# Compare ORI and NEW
compare:
	$(SCRIPT_DIR)/compare4.pl $(DIRPATH)/$(ORI) $(DIRPATH)/$(NEW) $(DIRPATH)/$(REF) $(DIRPATH)/$(SRC) | less -p'\*[^\*]*\*'
# Case-insensitive
compare_ci:
	$(SCRIPT_DIR)/compare4_ci.pl $(DIRPATH)/$(ORI) $(DIRPATH)/$(NEW) $(DIRPATH)/$(REF) $(DIRPATH)/$(SRC) | less -p'\*[^\*]*\*'
# Also showing fixlog
compare_log:
	$(SCRIPT_DIR)/compare4_log.pl $(DIRPATH)/$(ORI) $(DIRPATH)/$(NEW) $(DIRPATH)/$(REF) $(DIRPATH)/$(SRC) $(DIRPATH)/fixlog.txt | less -p'\*[^\*]*\*'
# Also showing fixlog, case-insensitive
compare_log_ci:
	$(SCRIPT_DIR)/compare4_log_ci.pl $(DIRPATH)/$(ORI) $(DIRPATH)/$(NEW) $(DIRPATH)/$(REF) $(DIRPATH)/$(SRC) $(DIRPATH)/fixlog.txt | less -p'\*[^\*]*\*'
# Outputs HTML
comparehtml:
	@$(SCRIPT_DIR)/comparehtml.pl $(DIRPATH)/$(NEW) $(DIRPATH)/$(ORI) $(DIRPATH)/$(REF) $(DIRPATH)/$(SRC)
# Outputs Latex
compare5:
	$(SCRIPT_DIR)/compare5.pl $(DIRPATH)/$(ORI) $(DIRPATH)/$(NEW) $(DIRPATH)/$(REF) $(DIRPATH)/$(SRC) | less

# Compare NEW in DIRPATH and DIRPATH2
compare2:
	$(SCRIPT_DIR)/compare2.pl $(DIRPATH)/$(NEW) $(DIRPATH2)/$(NEW) $(DIRPATH)/$(ORI) $(DIRPATH)/$(REF) $(DIRPATH)/$(SRC) | less -p'\*[^\*]*\*'
compare2html:
	@$(SCRIPT_DIR)/compare2html.pl $(DIRPATH)/$(NEW) $(DIRPATH2)/$(NEW) $(DIRPATH)/$(ORI) $(DIRPATH)/$(REF) $(DIRPATH)/$(SRC)


fixReportOnTrees:
	cat $(DIRPATH)/translation*.treex.gz | $(SCRIPT_DIR)/fixReportOnTrees.pl

# Clone experiment data (copies an experiment directory into a new one)
# Usage: make clone OLDDIRROOT=/some/root/experiment/dir OLDDIRNAME=2011-04-27_18-08-53_moses DIRROOT=/new/root/experiment/dir DIRLABEL=moses_fixed
# to clone OLDDIRROOT/OLDDIRNAME to DIRROOT/DIRNAME (= DIRROOT/DIRBASE_DIRLABEL)
# (or you can use cp -r to do that manually)
clone:
	cp -r $(OLDDIRROOT)/$(OLDDIRNAME) $(DIRROOT)/$(DIRNAME)
	@echo "Experiment directory:"
	@echo
	@echo $(DIRROOT)/$(DIRNAME)
	@echo

# Bootstrap eval
SAMPLES=1000 #(TO EVAL SETTINGS)
ALPHA=0.05 #(TO EVAL SETTINGS

#(TODO) check this out
bootstrap_eval:
#ngrams:
	$(BOOTSTRAP)/get_ngrams.pl $(DIRNAME)/$(REF_TXT) $(DIRNAME)/data_cs.txt $(DIRNAME)/$(OUTPUT_TXT) > $(DIRNAME)/ngrams
#bleu.tsv: ngrams
	head -n 1 $(DIRNAME)/ngrams | cut -f 2- > $(DIRNAME)/bleu.tsv
	tail -n +2 $(DIRNAME)/ngrams | $(BOOTSTRAP)/bleu.pl >> $(DIRNAME)/bleu.tsv
	for i in `seq $(SAMPLES)`; do echo -n "$$i " >&2; tail -n +2 $(DIRNAME)/ngrams | $(BOOTSTRAP)/resample.pl | $(BOOTSTRAP)/bleu.pl >> $(DIRNAME)/bleu.tsv; done
#confidence_intervals.txt: bleu.tsv (we use our modified bootstrap_stats.pl here
	cat $(DIRNAME)/bleu.tsv | $(SCRIPT_DIR)/bootstrap_stats.pl $(ALPHA) > $(DIRNAME)/confidence_intervals.txt
#view
	echo "Results stored in $(DIRNAME)/confidence_intervals.txt"
	cat $(DIRNAME)/confidence_intervals.txt

tagchanges:
	$(TREEX) Read::AlignedSentences cs_out="$(DATA_CS)" cs_ref="$(REFERENCE_CS)" Util::SetGlobal language=cs \
      W2A::CS::Tokenize selector=ref W2A::CS::Tokenize selector=out W2A::CS::TagMorce selector=ref Write::Treex to=ali.treex.gz
	$(TREEX) -Lcs W2A::CS::TagMorce selector=out Align::A::MonolingualGreedy selector=ref to_selector=out Write::Treex to=. -- ali.treex.gz
	$(TREEX) -Lcs Print::TagChanges selector=ref to=data/tagchanges.tsv clobber=1 -- ali.treex.gz

worsen_corpus:
	$(TREEX) -Lcs Read::Sentences from=data/newstest2010.cz W2A::CS::Tokenize W2A::CS::TagMorce A2A::CS::WorsenWordForms err_distr_from=data/tagchanges.tsv Write::Treex to=worsened.treex.gz Write::Treex to=.

   

# Manual evaluation manual:
#
# 1.
# make maneval_prepare
#
# 2.
# Give file depfix_maneval_2011_.../depfix_maneval_01.anot to the first annotater
# Give .../depfix_maneval_02.anot to the 2nd annotator  etc.
#
# 3.
# Let the annotators annotate the files
# Files are to be annotated by adding one character (any, eg. 1, *, y...)
# to the beginning of the line which is BETTER than the other line, eg:
#
#EN_ORIG	Another leading role in the film is played by Matt Damon.
#CS_REF	Další významnou roli v něm hraje Matt Damon.
#*	Další hlavní role ve filmu hraje Matt Damon.
#	Další hlavní role ve filmu hrajou Matt Damon.
#
# Do not do anything with the line which is not the good one.
# If quality of the lines is equal, do not add anything anywhere, just leave it as it is.
# The lines start with a TAB character, which must be kept.
# The lines marked EN_ORIG and CS_REF are just for your information.
# Do NOT add any newlines!
#
# 4.
# Put the annotated files back to the directory where you got them.
#
# 5.
# make maneval_eval

#number of lines to annotate
ANNOT_LINES=3003 #(TO EVAL SETTINGS)
#number of annotation chunks for manual evaluation
ANNOT_NUM=20 #(TO EVAL SETTINGS)
#files prefix 
MAN_SUFFIX=mlfix_maneval #(TO EVAL SETTINGS)
#dir with manual evaluation files
MAN_DIR=$(DIRNAME)_$(MAN_SUFFIX) #(TO EVAL SETTINGS)

#scripts/quickjudge.pl --refs=$(MAN_DIR)/EN_ORIG_$$a,$(MAN_DIR)/CS_REF_$$a $(MAN_DIR)/$(MAN_PREFIX)_$$a $(MAN_DIR)/CS_BASE_$$a $(MAN_DIR)/CS_OUR_$$a ;
#scripts/quickjudge.pl --refs=$(MAN_DIR)/EN_ORIG_$$a $(MAN_DIR)/$(MAN_PREFIX)_$$a $(MAN_DIR)/CS_BASE_$$a $(MAN_DIR)/CS_OUR_$$a ;

maneval_prepare:
#prepare data and create annotation files
	mkdir $(MAN_DIR)
	head -n $(ANNOT_LINES) $(DIRNAME)/data_src.txt > $(MAN_DIR)/EN_ORIG
	head -n $(ANNOT_LINES) $(DIRNAME)/$(REF_TXT) > $(MAN_DIR)/CS_REF
	head -n $(ANNOT_LINES) $(DIRNAME)/data_mt.txt > $(MAN_DIR)/CS_BASE.tmp
	head -n $(ANNOT_LINES) $(DIRNAME)/$(OUTPUT_TXT) > $(MAN_DIR)/CS_OUR.tmp
	export chunksize=`echo $(ANNOT_LINES)/$(ANNOT_NUM) | bc` ; \
	$(SCRIPT_DIR)/highlight.pl $(MAN_DIR)/CS_BASE.tmp $(MAN_DIR)/CS_OUR.tmp $(MAN_DIR)/CS_BASE $(MAN_DIR)/CS_OUR ; \
	for a in `seq $(ANNOT_NUM)` ; do \
	  head -n `echo $$a*$$chunksize | bc` $(MAN_DIR)/EN_ORIG | tail -n $$chunksize > $(MAN_DIR)/EN_ORIG_$$a; \
	  head -n `echo $$a*$$chunksize | bc` $(MAN_DIR)/CS_REF | tail -n $$chunksize > $(MAN_DIR)/CS_REF_$$a; \
	  head -n `echo $$a*$$chunksize | bc` $(MAN_DIR)/CS_BASE | tail -n $$chunksize > $(MAN_DIR)/CS_BASE_$$a; \
	  head -n `echo $$a*$$chunksize | bc` $(MAN_DIR)/CS_OUR | tail -n $$chunksize > $(MAN_DIR)/CS_OUR_$$a; \
	  $(SCRIPT_DIR)/quickjudge.pl --refs=$(MAN_DIR)/EN_ORIG_$$a,$(MAN_DIR)/CS_REF_$$a $(MAN_DIR)/$(MAN_PREFIX)_$$a $(MAN_DIR)/CS_BASE_$$a $(MAN_DIR)/CS_OUR_$$a ; \
	done

maneval_eval:
	cd $(MAN_DIR) ; \
	echo -e "filename\tchanges_made\tbase_better\tour_better\tindefinite\tour_percent_1\tour_percent_2" > $(MAN_PREFIX)_results.tsv ; \
	for a in *.anot ; do \
	  $(SCRIPT_DIR)/quickjudge.pl $${a%.anot} --print > $${a%.anot}.out ; \
	  $(SCRIPT_DIR)/maneval_eval.pl $${a%.anot} $$(echo "`cat $$a | wc -l`/5" | bc) >> $(MAN_PREFIX)_results.tsv ; \
	done ;\
	cat $(MAN_PREFIX)_results.tsv

cross_annot_agree:
	cd $(MAN_DIR) ; \
	echo -e "filename1\tfilename2\tagree\tdisagree\tagree_percent\tagree_our\tagree_base\tagree_indef\tdisagree_strict\tdisagree_indef\tagree_percent_strict" > $(MAN_PREFIX)_cross_annot_agree.tsv ; \
	for a in *V.out ; do \
	  $(SCRIPT_DIR)/crossAnnotAgree.pl $${a%V.out}D.out $$a $$(echo "`cat $${a%out}anot | wc -l`/5" | bc) >> $(MAN_PREFIX)_cross_annot_agree.tsv ; \
	done

cross_annot_agree_matrix:
	cd $(MAN_DIR) ; \
	for a in *V.out ; do \
	  echo $${a%V.out} >> $(MAN_PREFIX)_cross_annot_agree_matrix.tsv ; \
	  $(SCRIPT_DIR)/crossAnnotAgreeMatrix.pl $${a%V.out}D.out $$a $$(echo "`cat $${a%out}anot | wc -l`/5" | bc) >> $(MAN_PREFIX)_cross_annot_agree_matrix.tsv ; \
	done

maneval_prepare_r:
#prepare data and create annotation files
	mkdir $(MAN_DIR)
	cp $(DIRNAME)/data_en.txt $(MAN_DIR)/EN_ORIG.tmp
	cp $(DIRNAME)/$(REF_TXT) $(MAN_DIR)/CS_REF.tmp
	cp $(DIRNAME)/data_cs.txt $(MAN_DIR)/CS_BASE.tmp
	cp $(DIRNAME)/$(OUTPUT_TXT) $(MAN_DIR)/CS_OUR.tmp
# randomize, split and let quickjudge generate its files
	cd $(MAN_DIR) ; \
	$(SCRIPT_DIR)/highlight.pl CS_BASE.tmp CS_OUR.tmp CS_BASE.tmph CS_OUR.tmph ; \
	for i in $$(seq `cat EN_ORIG.tmp | wc -l`) ; do echo -e "$$RANDOM\t$i" ; done > rands.tmp ; \
	paste rands.tmp EN_ORIG.tmp | sort -n -s | cut -f3- > EN_ORIG ; \
	paste rands.tmp CS_REF.tmp  | sort -n -s | cut -f3- > CS_REF ; \
	paste rands.tmp CS_BASE.tmph | sort -n -s | cut -f3- > CS_BASE ; \
	paste rands.tmp CS_OUR.tmph | sort -n -s | cut -f3- > CS_OUR ; \
	export chunksize=`echo $(ANNOT_LINES)/$(ANNOT_NUM) | bc` ; \
	for a in `seq $(ANNOT_NUM)` ; do \
	  head -n `echo $$a*$$chunksize | bc` EN_ORIG | tail -n $$chunksize > EN_ORIG_$$a; \
	  head -n `echo $$a*$$chunksize | bc` CS_REF | tail -n $$chunksize > CS_REF_$$a; \
	  head -n `echo $$a*$$chunksize | bc` CS_BASE | tail -n $$chunksize > CS_BASE_$$a; \
	  head -n `echo $$a*$$chunksize | bc` CS_OUR | tail -n $$chunksize > CS_OUR_$$a; \
	  $(SCRIPT_DIR)/quickjudge.pl --refs=EN_ORIG_$$a,CS_REF_$$a $(MAN_PREFIX)_$$a CS_BASE_$$a CS_OUR_$$a 2> /dev/null ; \
	done


maneval_prepare_2:
#prepare data and create annotation files
	mkdir $(MAN_DIR)
	cp $(DIRNAME)/data_en.txt $(MAN_DIR)/EN_ORIG.tmp
	cp $(DIRNAME)/$(REF_TXT) $(MAN_DIR)/CS_REF.tmp
	cp $(DIRNAME)/data_cs.txt $(MAN_DIR)/CS_BASE.tmp
	cp $(DIRNAME)/$(OUTPUT_TXT) $(MAN_DIR)/CS_OUR1.tmp
	cp $(DIRNAME2)/$(OUTPUT_TXT) $(MAN_DIR)/CS_OUR2.tmp
# randomize, split and let quickjudge generate its files
	cd $(MAN_DIR) ; \
	for i in $$(seq `cat EN_ORIG.tmp | wc -l`) ; do echo -e "$$RANDOM\t$i" ; done > rands.tmp ; \
	paste rands.tmp EN_ORIG.tmp | sort -n -s | cut -f3- > EN_ORIG ; \
	paste rands.tmp CS_REF.tmp  | sort -n -s | cut -f3- > CS_REF ; \
	paste rands.tmp CS_BASE.tmp | sort -n -s | cut -f3- > CS_BASE ; \
	paste rands.tmp CS_OUR1.tmp | sort -n -s | cut -f3- > CS_OUR1 ; \
	paste rands.tmp CS_OUR2.tmp | sort -n -s | cut -f3- > CS_OUR2 ; \
	export chunksize=`echo $(ANNOT_LINES)/$(ANNOT_NUM) | bc` ; \
	for a in `seq $(ANNOT_NUM)` ; do \
	  head -n `echo $$a*$$chunksize | bc` EN_ORIG | tail -n $$chunksize > EN_ORIG_$$a; \
	  head -n `echo $$a*$$chunksize | bc` CS_REF | tail -n $$chunksize > CS_REF_$$a; \
	  head -n `echo $$a*$$chunksize | bc` CS_BASE | tail -n $$chunksize > CS_BASE_$$a; \
	  head -n `echo $$a*$$chunksize | bc` CS_OUR1 | tail -n $$chunksize > CS_OUR1_$$a; \
	  head -n `echo $$a*$$chunksize | bc` CS_OUR2 | tail -n $$chunksize > CS_OUR2_$$a; \
	  $(SCRIPT_DIR)/quickjudge.pl --refs=EN_ORIG_$$a,CS_REF_$$a $(MAN_PREFIX)_$$a CS_BASE_$$a CS_OUR1_$$a CS_OUR2_$$a 2> /dev/null ; \
	done

maneval_prepare_3:
#prepare data and create annotation files
	mkdir $(MAN_DIR)
	cp $(DIRNAME)/data_en.txt $(MAN_DIR)/EN_ORIG.tmp
	cp $(DIRNAME)/$(REF_TXT) $(MAN_DIR)/CS_REF.tmp
	cp $(DIRNAME)/data_cs.txt $(MAN_DIR)/CS_BASE.tmp
	cp $(DIRNAME)/$(OUTPUT_TXT) $(MAN_DIR)/CS_OUR1.tmp
	cp $(DIRNAME2)/$(OUTPUT_TXT) $(MAN_DIR)/CS_OUR2.tmp
	cp $(DIRNAME3)/$(OUTPUT_TXT) $(MAN_DIR)/CS_OUR3.tmp
# randomize, split and let quickjudge generate its files
	cd $(MAN_DIR) ; \
	for i in $$(seq `cat EN_ORIG.tmp | wc -l`) ; do echo -e "$$RANDOM\t$i" ; done > rands.tmp ; \
	paste rands.tmp EN_ORIG.tmp | sort -n -s | cut -f3- > EN_ORIG ; \
	paste rands.tmp CS_REF.tmp  | sort -n -s | cut -f3- > CS_REF ; \
	paste rands.tmp CS_BASE.tmp | sort -n -s | cut -f3- > CS_BASE ; \
	paste rands.tmp CS_OUR1.tmp | sort -n -s | cut -f3- > CS_OUR1 ; \
	paste rands.tmp CS_OUR2.tmp | sort -n -s | cut -f3- > CS_OUR2 ; \
	paste rands.tmp CS_OUR3.tmp | sort -n -s | cut -f3- > CS_OUR3 ; \
	export chunksize=`echo $(ANNOT_LINES)/$(ANNOT_NUM) | bc` ; \
	for a in `seq $(ANNOT_NUM)` ; do \
	  head -n `echo $$a*$$chunksize | bc` EN_ORIG | tail -n $$chunksize > EN_ORIG_$$a; \
	  head -n `echo $$a*$$chunksize | bc` CS_REF  | tail -n $$chunksize > CS_REF_$$a; \
	  head -n `echo $$a*$$chunksize | bc` CS_BASE | tail -n $$chunksize > CS_BASE_$$a; \
	  head -n `echo $$a*$$chunksize | bc` CS_OUR1 | tail -n $$chunksize > CS_OUR1_$$a; \
	  head -n `echo $$a*$$chunksize | bc` CS_OUR2 | tail -n $$chunksize > CS_OUR2_$$a; \
	  head -n `echo $$a*$$chunksize | bc` CS_OUR3 | tail -n $$chunksize > CS_OUR3_$$a; \
	  $(SCRIPT_DIR)/quickjudge.pl --refs=EN_ORIG_$$a,CS_REF_$$a $(MAN_PREFIX)_$$a CS_BASE_$$a CS_OUR1_$$a CS_OUR2_$$a CS_OUR3_$$a 2> /dev/null ; \
	done

maneval_eval_2:
	cd $(MAN_DIR) ; \
	echo -e "filename\tchanges_made\tbase_better\tour1_better\tour2_better\tindefinite" > $(MAN_PREFIX)_results.tsv ; \
	for a in *.anot ; do \
	  $(SCRIPT_DIR)/quickjudge.pl $${a%.anot} --print > $${a%.anot}.out ; \
	  $(SCRIPT_DIR)/maneval_eval_2.pl $${a%.anot} `grep -c EN_ORIG $$a` >> $(MAN_PREFIX)_results.tsv ; \
	done

maneval_eval_2p:
	cd $(MAN_DIR) ; \
	echo -e "filename\tchanges_made\tbase_better\tour1_better\tour2_better\tindefinite" > $(MAN_PREFIX)_results2.tsv ; \
	for a in *.anot2p ; do \
          cp $$a tmp.anot; \
          cp $${a%.anot2p}.coresp tmp.coresp; \
	  $(SCRIPT_DIR)/quickjudge.pl tmp --print > $${a%.anot2p}.out2p ; \
	  $(SCRIPT_DIR)/maneval_eval_2p.pl $${a%.anot2p} `grep -c EN_ORIG $$a` >> $(MAN_PREFIX)_results2p.tsv ; \
	  rm tmp*; \
	done

maneval_eval_3:
	cd $(MAN_DIR) ; \
	rm $(MAN_PREFIX)_results.tsv ; \
	for a in *.anot ; do \
	  $(SCRIPT_DIR)/quickjudge.pl $${a%.anot} --print > $${a%.anot}.out ; \
	  $(SCRIPT_DIR)/maneval_eval_3.pl $${a%.anot} `grep -c EN_ORIG $$a` >> $(MAN_PREFIX)_results.tsv ; \
	done

cross_annot_agree_2:
	cd $(MAN_DIR) ; \
	echo -e "3/3\t2/3\t1/3\t0/3\tboth indef\tundecidable" > $(MAN_PREFIX)_cross_annot_agree.tsv ; \
	for i in {1..${ANNOT_NUM}} ; do \
	  $(SCRIPT_DIR)/crossAnnotAgree_2.pl *"_"$$i"_"*.out `grep -c EN_ORIG *"_"$$i"_"*D*.anot` >> $(MAN_PREFIX)_cross_annot_agree.tsv ; \
	done
# the 'D' matches either OD or DM

#(TODO)
# agreement by mozna mel bejt neco jako editacni vzdalenost anotaci,
# kde prohozeni poradi dvou vet je jedna operace (a prepis toho cisla taky)
cross_annot_agree_3:
	cd $(MAN_DIR) ; \
	echo -e "IAA" > $(MAN_PREFIX)_cross_annot_agree.tsv ; \
	for i in {1..${ANNOT_NUM}} ; do \
	  $(SCRIPT_DIR)/crossAnnotAgree_3.pl *"_"$$i"_"*.out `grep -c EN_ORIG *"_"$$i"_"*D*.anot` >> $(MAN_PREFIX)_cross_annot_agree.tsv ; \
	done
# the 'D' matches either OD or DM

# depfix_maneval_2_DM_stars.out


parse_parallel:
	mkdir -p project_syndicate
	$(SCRIPT_DIR)/clean_corpus.pl data/news-commentary-v6.cs-en.en data/news-commentary-v6.cs-en.cs project_syndicate/en.txt project_syndicate/cs.txt
	split -d -l 2000 project_syndicate/en.txt project_syndicate/en_part
	split -d -l 2000 project_syndicate/cs.txt project_syndicate/cs_part
#convert to *.treex
	$(TREEX) Read::AlignedSentences file_stem=project_syndicate/nc en=$$(echo project_syndicate/en_part* | sed s/' '/,/g) cs=$$(echo project_syndicate/cs_part* | sed s/' '/,/g) Write::Treex to=.;
#remove temporary data
	rm project_syndicate/en_part* project_syndicate/cs_part*
#run analyses on data
	$(TREEX) -p -j 70 $(SCEN_DIR)/cs_analysis.scen $(SCEN_DIR)/en_analysis.scen \
        Write::LemmatizedBitexts language=en to_language=cs Write::Treex to=. \
	    -- project_syndicate/nc*.treex > project_syndicate/bitexts.tsv




###############################
## TRAINING AND DEVELOPEMENT ##
###############################

# Collect post-edit feature vectors
collect_edits: analyze_ref collect_postedits
	@-mkdir $(DIRPATH)/parsed
	# back up parsed files without fixes
	cp $(DIRPATH)/translation*.treex.gz $(DIRPATH)/parsed

# Reference analysis
# Default values
TAGGER_REF=$(TAGGER_TGT)
PARSER_REF=mst

REF_ANALYSIS_1_SCEN=Scen::MLFix::Analysis_1 language=$(LANG_TGT) selector=ref tagger=$(TAGGER_REF) iset_driver=${ISET_DRIVER_TGT}
REF_NER_SCEN=Scen::MLFix::NER language=$(LANG_TGT) selector=ref model=""
REF_ALIGNMENT_SCEN=Align::A::MonolingualGreedy selector= language=$(LANG_TGT) to_selector=ref
analyze_ref: analyze_1_ref analyze_2_ref
analyze_1_ref:
	$E REF_ANALYSIS_1_SCEN=$(REF_ANALYSIS_1_SCEN) REF_ALIGNMENT_SCEN=$(REF_ALIGNMENT_SCEN)
	$(TREEXP) \
   	$(REF_ANALYSIS_1_SCEN) \
	$(REF_NER_SCEN) \
    $(REF_ALIGNMENT_SCEN) Write::Treex to=. \
    -- $(DIRPATH)/translation*.treex.gz

REF_ANALYSIS_2_SCEN=Scen::MLFix::Analysis_2 language=$(LANG_TGT) parser=$(PARSER_REF) selector=ref src_language=$(LANG_SRC)
analyze_2_ref:
	$E REF_ANALYSIS_2_SCEN=$(REF_ANALYSIS_2_SCEN)
	$(TREEXP) \
	$(REF_ANALYSIS_2_SCEN) Write::Treex to=. \
	-- $(DIRPATH)/translation*.treex.gz


# After collect_postedits_prepare
collect_postedits:	
	$(TREEXP) \
	-L$(LANG_TGT) MLFix::CollectEdits print_column_names=1 language=$(LANG_TGT) selector=  to=. config_file=${WD}/config/all_fields.yaml \
	-- $(DIRPATH)/translation*.treex.gz
	zcat $(DIRPATH)/translation*_edits.tsv.gz | head -1 > $(DIRPATH)/features_header
	cat $(DIRPATH)/features_header | gzip -c > $(DIRPATH)/all_edits.tsv.gz
	for f in `ls $(DIRPATH)/translation*_edits.tsv.gz`; do \
		zcat $$f | tail -n +2 | gzip -c >> $(DIRPATH)/all_edits.tsv.gz; \
	done

OUTPUT_DIR=$(DIRPATH)/stats/default
collect_statistics:
	@mkdir -p $(OUTPUT_DIR)
	zcat $(DIRPATH)/all_edits.tsv.gz | $(SCRIPT_DIR)/print_columns.pl "old_node_lemma|old_node_pos" | grep -v punc | cut -f1 | sort | uniq -c | sort -nr > $(OUTPUT_DIR)/lemma_freq
	zcat $(DIRPATH)/all_edits.tsv.gz | $(SCRIPT_DIR)/analyze_changes.pl 0 > $(OUTPUT_DIR)/changed_categories_freq
	zcat $(DIRPATH)/all_edits.tsv.gz | $(SCRIPT_DIR)/analyze_changes.pl 1 > $(OUTPUT_DIR)/different_pos
	zcat $(DIRPATH)/all_edits.tsv.gz | $(SCRIPT_DIR)/analyze_changes.pl 2 > $(OUTPUT_DIR)/changes_all
	zcat $(DIRPATH)/all_edits.tsv.gz | $(SCRIPT_DIR)/analyze_changes.pl 3 > $(OUTPUT_DIR)/changes_iset
	zcat $(DIRPATH)/all_edits.tsv.gz | $(SCRIPT_DIR)/analyze_changes.pl 4 > $(OUTPUT_DIR)/feat_clusters
	zcat $(DIRPATH)/all_edits.tsv.gz | $(SCRIPT_DIR)/analyze_changes.pl 5 > $(OUTPUT_DIR)/changes_agr
	zcat $(DIRPATH)/all_edits.tsv.gz | $(SCRIPT_DIR)/analyze_changes.pl 6 > $(OUTPUT_DIR)/features_size
	zcat $(DIRPATH)/all_edits.tsv.gz | $(SCRIPT_DIR)/analyze_changes.pl 7 > $(OUTPUT_DIR)/changed_pos_freq
	$(SCRIPT_DIR)/get_stats.R 2016-04-10_19-02-56_0818207012_autodesk_train_collect/all_edits.tsv.gz > $(OUTPUT_DIR)/statistics


#####
## You should run 'make collect' before running the oracle
#####
save_config:
	cp $(MARK_CONFIG_FILE) $(DIRPATH)/.
	cp $(FIX_CONFIG_FILE) $(DIRPATH)/.

mlfix_oracle_markonly: fix_prepare save_config
	$E
	$(TREEXP) \
	Scen::MLFix::Fix mark_method=oracle language=$(LANG_TGT) selector= mark_config_file=$(MARK_CONFIG_FILE) fix_config_file=$(FIX_CONFIG_FILE) iset_driver=$(ISET_DRIVER_TGT) Write::Treex to=. \
	-- $(DIRPATH)/translation*.treex.gz

mlfix_oracle_fixonly: fix_prepare save_config
	$E
	$(TREEXP) \
	Scen::MLFix::Fix fix_method=oracle language=$(LANG_TGT) selector= mark_config_file=$(MARK_CONFIG_FILE) fix_config_file=$(FIX_CONFIG_FILE) iset_driver=$(ISET_DRIVER_TGT) voting_method=$(VOTING_METHOD) threshold=$(MARK2FIX_THRESHOLD) Write::Treex to=. \
	-- $(DIRPATH)/translation*.treex.gz

mlfix_oracle_all: fix_prepare save_config
	$E
	$(TREEXP) \
	Scen::MLFix::Fix mark_method=oracle fix_method=oracle language=$(LANG_TGT) selector= mark_config_file=$(MARK_CONFIG_FILE) fix_config_file=$(FIX_CONFIG_FILE) iset_driver=$(ISET_DRIVER_TGT) Write::Treex to=. \
	-- $(DIRPATH)/translation*.treex.gz



# Developement target (DELETE THIS)
test_tar:
	echo $(DIRPATH)

include $(SETTINGS_FILE)
