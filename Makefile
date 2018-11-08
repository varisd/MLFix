SHELL := /bin/bash

##########################
# Setting some variables #
##########################

# input data

# source and target languages
LANG_SRC=en
LANG_TGT=cs

# small test data by default
DATA_SRC=data/en.txt
DATA_MT=data/csw.txt
DATA_REF=data/cs.txt

# working directory

# only for backward compatibility
NEWDIR_NAME=

# base of the name of new directory (default is date_time_randseed)
DIRBASE:=$(shell echo `date +%Y-%m-%d_%H-%M-%S_``printf %05d $$RANDOM``printf %05d $$RANDOM`)
# suffix of the new directory name (empty by default)
# set this variable
DIRLABEL=$(NEWDIR_NAME)
#the whole name
DIRNAME=$(DIRBASE)_$(DIRLABEL)

# job control

DOC_IDS=*

# not run in parallel by default -- see settings.mak
TREEX=treex
TREEXP=treex

#ENVIRONMENT VARIABLES
#BOOTSTRAP=${TMT_ROOT}/tools/bootstrap_eval/
BOOTSTRAP=scripts/bootstrap_eval/
#MTRICS=${TMT_ROOT}/share/external_tools/mtrics/bin/mtrics --tokenize 
#MTRICS=scripts/mtrics --tokenize
MTRICS=scripts/mtrics

SD=../scenarios

# info about the target currently being run
E=@echo MLFIX [$(DIRNAME)]: $@

SETTINGS_FILE=settings.mak

######################
# The actual targets #
######################

# full analysis, fixing and automatic evaluation
default: init default_ni

# TODO: redo the test target
test:
	make default DIRLABEL=small_test \
		TREEXP=treex ANALYSIS_2_SCEN=$(TGT)_analysis_2_msta.scen TFIX_SCEN=tfix_rules.scen \
		DATA_EN=data/en.txt DATA_CS=data/csw.txt REFERENCE_CS=data/cs.txt

# default without init
#default_ni:   totreex tag run_giza ner_en parse fix deepfix write_sentences eval
#default_ni: totreex tag run_giza ner_en parse fix write_sentences eval
default_ni: totreex tag run_giza ner_en parse mlfix write_sentences eval
collect: totreex tag run_giza ner_en parse collect_edits
collect_mono: totreex_mono tag_mono collect_edits

# default behaviour: try to interpret the target as scenario file name
# e.g. if you type "make fix_new" and there is a scenarios/fix_new.scen file,
# it will be run in the working directory on the translation*.treex.gz files
.DEFAULT:
	$E
	$(TREEXP) -s \
	scenarios/$@.scen \
	-- $(DIRNAME)/translation$(DOC_IDS).treex.gz


# show help
help:
	less README

# create a new working directory and copy the source data into it
init:
	$E LANG_SRC=$(LANG_SRC) LANG_TGT=$(LANG_TGT) DATA_SRC=$(DATA_SRC) DATA_MT=$(DATA_MT) DATA_REF=$(DATA_REF)
#new directory for data
	@-mkdir $(DIRNAME)
	@echo "Working directory:"
	@echo
	@echo $(DIRNAME)
	@echo
#input data
	@cp $(DATA_SRC) $(DIRNAME)/data_src.txt
	@cp $(DATA_MT) $(DIRNAME)/data_mt.txt
	@cp $(DATA_REF) $(DIRNAME)/data_ref.txt
	@paste $(DIRNAME)/data_src.txt $(DIRNAME)/data_mt.txt > $(DIRNAME)/data_in.txt

# convert *.txt data to *.treex.gz
# TODO: replace Scen with SCEN:: block
PROJECT_TOKENIZATION_SCEN=project_tokenization.scen
totreex:
	$E PROJECT_TOKENIZATION_SCEN=$(PROJECT_TOKENIZATION_SCEN)
	@split -a 5 -d -l 100 $(DIRNAME)/data_src.txt $(DIRNAME)/src_part
	@split -a 5 -d -l 100 $(DIRNAME)/data_mt.txt $(DIRNAME)/mt_part 
	@split -a 5 -d -l 100 $(DIRNAME)/data_ref.txt  $(DIRNAME)/ref_part 
	$(TREEX) -s Read::AlignedSentences file_stem=$(DIRNAME)/translation $(LANG_SRC)="!$(DIRNAME)/src_part*" $(LANG_TGT)="!$(DIRNAME)/mt_part*" $(LANG_TGT)_ref="!$(DIRNAME)/ref_part*"
#remove temporary data
	@rm $(DIRNAME)/src_part* $(DIRNAME)/mt_part* $(DIRNAME)/ref_part* 
# project tokenization
	$(TREEXP) -s \
	Util::SetGlobal language=$(LANG_TGT) source_language=$(LANG_SRC) \
	scenarios/$(PROJECT_TOKENIZATION_SCEN) \
	-- $(DIRNAME)/translation*.treex.gz

# No source sentences provided
totreex_mono:
	$E PROJECT_TOKENIZATION_SCEN=$(PROJECT_TOKENIZATION_SCEN)
	@split -a 5 -d -l 100 $(DIRNAME)/data_mt.txt $(DIRNAME)/mt_part 
	@split -a 5 -d -l 100 $(DIRNAME)/data_ref.txt  $(DIRNAME)/ref_part 
	$(TREEX) -s Read::AlignedSentences file_stem=$(DIRNAME)/translation $(LANG_TGT)="!$(DIRNAME)/mt_part*" $(LANG_TGT)_ref="!$(DIRNAME)/ref_part*"
#remove temporary data
	@rm $(DIRNAME)/mt_part* $(DIRNAME)/ref_part* 

totreex_noproject:
	$E
	@split -a 5 -d -l 100 $(DIRNAME)/data_en.txt $(DIRNAME)/en_part
	@split -a 5 -d -l 100 $(DIRNAME)/data_cs.txt $(DIRNAME)/cs_part 
	@split -a 5 -d -l 100 $(DIRNAME)/ref_cs.txt  $(DIRNAME)/ref_part 
	$(TREEX) -s Read::AlignedSentences file_stem=$(DIRNAME)/translation $(LANG_SRC)="!$(DIRNAME)/src_part*" $(LANG_TGT)="!$(DIRNAME)/mt_part*" ref="!$(DIRNAME)/ref_part*"
#remove temporary data
	@rm $(DIRNAME)/src_part* $(DIRNAME)/mt_part* $(DIRNAME)/ref_part* 


# run morphological analyses
# TODO: more general
TAGGER_TGT=morphodita
SRC_ISET_DRIVER=en::penn
TGT_ISET_DRIVER=cs::pdt
SRC_ANALYSIS_1_SCEN=Scen::MLFix::Analysis_1 language=$(LANG_SRC) iset_driver="$(SRC_ISET_DRIVER)"
TGT_ANALYSIS_1_SCEN=Scen::MLFix::Analysis_1 language=$(LANG_TGT) tagger=$(TAGGER_TGT) iset_driver="$(TGT_ISET_DRIVER)"
# backward compatibility
analyze: tag
tag:
	$E SRC_ANALYSIS_1_SCEN=$(SRC_ANALYSIS_1_SCEN) TGT_ANALYSIS_1_SCEN=$(TGT_ANALYSIS_1_SCEN)
	$(TREEXP) -s \
	$(SRC_ANALYSIS_1_SCEN) \
	$(TGT_ANALYSIS_1_SCEN) \
	-- $(DIRNAME)/translation*.treex.gz

tag_mono:
	$E SRC_ANALYSIS_1_SCEN=$(SRC_ANALYSIS_1_SCEN) TGT_ANALYSIS_1_SCEN=$(TGT_ANALYSIS_1_SCEN)
	$(TREEXP) -s \
    $(TGT_ANALYSIS_1_SCEN) \
    -- $(DIRNAME)/translation*.treex.gz

# run the Giza++ aligner
# Mainly, we want to create alignment from the MT to SRC
# TODO: more general
RUN_GIZA_SCEN=Scen::MLFix::RunMGiza from_language=$(LANG_TGT) to_language=$(LANG_SRC) model=$(LANG_TGT)-$(LANG_SRC) 
run_giza:
	$E RUN_GIZA_SCEN=$(RUN_GIZA_SCEN)
	$(TREEXP) -s $(RUN_GIZA_SCEN) \
	-- $(DIRNAME)/translation*.treex.gz

# run Named Entity Recognizer for English
NER_SRC_SCEN=Scen::MLFix::NER language=$(LANG_SRC) model=ner-eng-ie.crf-3-all2008.ser.gz
ner_en:
	$E NER_SRC_SCEN=$(NER_SRC_SCEN)
	$(TREEXP) -s $(NER_SRC_SCEN) \
	-- $(DIRNAME)/translation*.treex.gz

# run dependency parsers
#SRC_ANALYSIS_2_SCEN=en_analysis_2.scen
# the SMT-adapted parser needs 30 GB RAM:
#TGT_ANALYSIS_2_SCEN=cs_analysis_2_boost_model_025.scen
# therefore, the default is the basic parser:
#TGT_ANALYSIS_2_SCEN=cs_analysis_2_msta.scen
PARSER_TGT=
SRC_ANALYSIS_2_SCEN=Scen::MLFix::Analysis_2 language=$(LANG_SRC) parser=mst
TGT_ANALYSIS_2_SCEN=Scen::MLFix::Analysis_2 language=$(LANG_TGT) src_language=$(LANG_SRC) parser=$(PARSER_TGT)
parse: parse_src parse_tgt parse_backup
parse_src_only: parse_src parse_backup

parse_backup:
	@-mkdir $(DIRNAME)/parsed
# back up parsed files without fixes
	cp $(DIRNAME)/translation*.treex.gz $(DIRNAME)/parsed

# TODO: add scenario to create mt dep. tree through the alignment
parse_src:
	$E SRC_ANALYSIS_2_SCEN=$(SRC_ANALYSIS_2_SCEN)
	$(TREEXP) -s \
	$(SRC_ANALYSIS_2_SCEN) \
	-- $(DIRNAME)/translation*.treex.gz

parse_tgt:
	$E TGT_ANALYSIS_2_SCEN=$(TGT_ANALYSIS_2_SCEN)
	$(TREEXP) -s \
	$(TGT_ANALYSIS_2_SCEN) \
	-- $(DIRNAME)/translation*.treex.gz

# TODO: revision, change, fix...
MARK_CONFIG_FILE=""
FIX_CONFIG_FILE=""
WRITE_SENTENCES_SCEN=Scen::MLFix::WriteSentences language=$(LANG_TGT)
mlfix: fix_prepare mlfix_run
#default scikit-learn mlfix run
VOTING_METHOD="majority"
MARK2FIX_THRESHOLD="0.5"
mlfix_run:
	$E MARK_CONFIG_FILE=$(MARK_CONFIG_FILE) FIX_CONFIG_FILE=$(FIX_CONFIG_FILE)
	$(TREEXP) -s \
	Scen::MLFix::Fix language=$(LANG_TGT) selector= mark_config_file=$(MARK_CONFIG_FILE) fix_config_file=$(FIX_CONFIG_FILE) iset_driver=$(TGT_ISET_DRIVER) voting_method=$(VOTING_METHOD) threshold=$(MARK2FIX_THRESHOLD) \
	-- $(DIRNAME)/translation*.treex.gz

# restore parsed files without fixes
restore_parsed:
	$E
	cp $(DIRNAME)/parsed/translation*.treex.gz $(DIRNAME)

# prepare for fixing but do not fix
#NER_TGT_SCEN=scenarios/ner_cs.scen
NER_TGT_SCEN=Scen::MLFix::NER language=$(LANG_TGT)
#FIX_PREPARE_SCEN=fix_prepare_new.scen
FIX_PREPARE_SCEN=Scen::MLFix::FixPrepare src_language=$(LANG_SRC) tgt_language=$(LANG_TGT)
fix_prepare: restore_parsed
	$E FIX_PREPARE_SCEN=$(FIX_PREPARE_SCEN)
	$(TREEXP) -s \
	$(FIX_PREPARE_SCEN) \
	$(NER_TGT_SCEN) \
	-- $(DIRNAME)/translation*.treex.gz


# Results of mlfix - written by write_sentences,
# to be used in evaluation (both auto and manual) and comparison
OUTPUT_TXT=mlfix_output.txt
# print out the fixed sentences
#write_sentences: write_fixlog
write_sentences:
	$E WRITE_SENTENCES_SCEN=$(WRITE_SENTENCES_SCEN) OUTPUT_TXT=$(OUTPUT_TXT)
	$(TREEXP) \
	$(WRITE_SENTENCES_SCEN) \
	Write::Sentences to=. \
	-- $(DIRNAME)/translation*.treex.gz 
	cat $(DIRNAME)/translation*.txt \
	> $(DIRNAME)/$(OUTPUT_TXT)

write_fixlog:
	$(TREEX) \
	scenarios/write_fixlog.scen \
	-- $(DIRNAME)/translation*.treex.gz \
	> $(DIRNAME)/fixlog.txt

WRITE_TRIPARALLEL_SCEN=Scen::MLFix::WriteTriparallel language=$(LANG_TGT)
write_triparallel:
	$E WRITE_TRIPARALLEL_SCEN=$(WRITE_TRIPARALLEL_SCEN)
	$(TREEX) \
	$(WRITE_TRIPARALLEL_SCEN) \
	-- $(DIRNAME)/translation*.treex.gz | \
	scripts/filter_sent.pl \
	> $(DIRNAME)/triparallel.txt

# perform automatic evaluation, storing its result into $(AUTOEVAL_OUT),
# and show it as tab separated values
# Evaluates original source and $(OUTPUT_TXT).
AUTOEVAL_OUT=autoeval.out
SRC_TXT=data_src.txt
MT_TXT=data_mt.txt
REF_TXT=data_ref.txt
eval: eval_dirname eval_lines eval_bleu eval_ter eval_show

# store the working directory name
eval_dirname:
	@echo $(DIRNAME) > $(DIRNAME)/$(AUTOEVAL_OUT)

# count number of lines changed by Depfix
eval_lines:
	@scripts/chgd.pl $(DIRNAME)/$(MT_TXT) $(DIRNAME)/$(OUTPUT_TXT) >> $(DIRNAME)/$(AUTOEVAL_OUT)

# compute BLEU and NIST
eval_bleu:
	@scripts/wrapmteval.pl $(DIRNAME)/$(SRC_TXT) $(DIRNAME)/$(REF_TXT) $(DIRNAME)/$(MT_TXT) 2> /dev/null | grep "^NIST"   >> $(DIRNAME)/$(AUTOEVAL_OUT)
	@scripts/wrapmteval.pl $(DIRNAME)/$(SRC_TXT) $(DIRNAME)/$(REF_TXT) $(DIRNAME)/$(OUTPUT_TXT)  2> /dev/null | grep "^NIST"   >> $(DIRNAME)/$(AUTOEVAL_OUT)

# compute PER and TER
eval_ter:
	@$(MTRICS) --per --ter -c $(DIRNAME)/$(MT_TXT) $(DIRNAME)/$(OUTPUT_TXT) -r $(DIRNAME)/$(REF_TXT)   | grep "[PT]ER:" >> $(DIRNAME)/$(AUTOEVAL_OUT)

# show results of automatic evaluation
eval_show:
	$E AUTOEVAL_OUT=$(AUTOEVAL_OUT)
	@scripts/process_eval_scores.pl $(DIRNAME)/$(AUTOEVAL_OUT)


eval_cased:
	@$(MTRICS) --tokenize --case-sensitive --bleu --nist --per --ter -c $(DIRNAME)/$(MT_TXT) $(DIRNAME)/$(OUTPUT_TXT) -r $(DIRNAME)/$(REF_TXT)


# Evaluation of the predicted Iset categories
eval_predictions: tag_ref
#eval_predictions:
	$E
	$(TREEX) \
	MLFix::ScikitLearnEval language=$(LANG_TGT) selector=T config_file=$(FIX_CONFIG_FILE) iset_driver=$(ISET_DRIVER) \
	-- $(DIRNAME)/translation*.treex.gz \
	> $(DIRNAME)/mlfix_pred_eval.txt	

PARSER_REF=mst
REF_ANALYSIS_1_SCEN=Scen::MLFix::Analysis_1 language=$(LANG_TGT) selector="ref" parser=${PARSER_REF} iset_driver="$(TGT_ISET_DRIVER)"
tag_ref:
	$E SRC_ANALYSIS_1_SCEN=$(REF_ANALYSIS_1_SCEN)
	$(TREEXP) -s \
	$(REF_ANALYSIS_1_SCEN) \
	Align::A::MonolingualGreedy selector=T language=cs to_selector=ref \
	-- $(DIRNAME)/translation*.treex.gz
	
align_ref:
	

view:
	less $(DIRNAME)/$(OUTPUT_TXT)


# textual comparison of mlfix inputs (ORI) and outputs (NEW),
# also showing reference (REF) and translation source (SRC)
ORI=$(MT_TXT)
NEW=$(OUTPUT_TXT)
REF=$(REF_TXT)
SRC=$(SRC_TXT)

# compare ORI and NEW
compare:
	scripts/compare4.pl $(DIRNAME)/$(ORI) $(DIRNAME)/$(NEW) $(DIRNAME)/$(REF) $(DIRNAME)/$(SRC) | less -p'\*[^\*]*\*'
# case-insensitive
compare_ci:
	scripts/compare4_ci.pl $(DIRNAME)/$(ORI) $(DIRNAME)/$(NEW) $(DIRNAME)/$(REF) $(DIRNAME)/$(SRC) | less -p'\*[^\*]*\*'
# also showing fixlog
compare_log:
	scripts/compare4_log.pl $(DIRNAME)/$(ORI) $(DIRNAME)/$(NEW) $(DIRNAME)/$(REF) $(DIRNAME)/$(SRC) $(DIRNAME)/fixlog.txt | less -p'\*[^\*]*\*'
# also showing fixlog, case-insensitive
compare_log_ci:
	scripts/compare4_log_ci.pl $(DIRNAME)/$(ORI) $(DIRNAME)/$(NEW) $(DIRNAME)/$(REF) $(DIRNAME)/$(SRC) $(DIRNAME)/fixlog.txt | less -p'\*[^\*]*\*'
# outputs HTML
comparehtml:
	@scripts/comparehtml.pl $(DIRNAME)/$(NEW) $(DIRNAME)/$(ORI) $(DIRNAME)/$(REF) $(DIRNAME)/$(SRC)
# outputs Latex
compare5:
	scripts/compare5.pl $(DIRNAME)/$(ORI) $(DIRNAME)/$(NEW) $(DIRNAME)/$(REF) $(DIRNAME)/$(SRC) | less

# compare NEW in DIRNAME and DIRNAME2
compare2:
	scripts/compare2.pl $(DIRNAME)/$(NEW) $(DIRNAME2)/$(NEW) $(DIRNAME)/$(ORI) $(DIRNAME)/$(REF) $(DIRNAME)/$(SRC) | less -p'\*[^\*]*\*'
compare2html:
	@scripts/compare2html.pl $(DIRNAME)/$(NEW) $(DIRNAME2)/$(NEW) $(DIRNAME)/$(ORI) $(DIRNAME)/$(REF) $(DIRNAME)/$(SRC)


fixReportOnTrees:
	cat $(DIRNAME)/translation*.treex.gz | scripts/fixReportOnTrees.pl

# clone experiment data (copies an experiment directory into a new one)
# usage: make clone OLDDIRNAME=2011-04-27_18-08-53_moses DIRLABEL=moses_fixed
# to clone OLDDIRNAME to DIRNAME (= DIRBASE_DIRLABEL)
# (or you can use cp -r to do that manually)
clone:
	cp -r $(OLDDIRNAME) $(DIRNAME)
	@echo "Working directory:"
	@echo
	@echo $(DIRNAME)
	@echo

# Bootstrap eval
SAMPLES=1000
ALPHA=0.05

#TODO: check this out
bootstrap_eval:
#ngrams:
	$(BOOTSTRAP)/get_ngrams.pl $(DIRNAME)/$(REF_TXT) $(DIRNAME)/data_cs.txt $(DIRNAME)/$(OUTPUT_TXT) > $(DIRNAME)/ngrams
#bleu.tsv: ngrams
	head -n 1 $(DIRNAME)/ngrams | cut -f 2- > $(DIRNAME)/bleu.tsv
	tail -n +2 $(DIRNAME)/ngrams | $(BOOTSTRAP)/bleu.pl >> $(DIRNAME)/bleu.tsv
	for i in `seq $(SAMPLES)`; do echo -n "$$i " >&2; tail -n +2 $(DIRNAME)/ngrams | $(BOOTSTRAP)/resample.pl | $(BOOTSTRAP)/bleu.pl >> $(DIRNAME)/bleu.tsv; done
#confidence_intervals.txt: bleu.tsv (we use our modified bootstrap_stats.pl here
	cat $(DIRNAME)/bleu.tsv | scripts/bootstrap_stats.pl $(ALPHA) > $(DIRNAME)/confidence_intervals.txt
#view
	echo "Results stored in $(DIRNAME)/confidence_intervals.txt"
	cat $(DIRNAME)/confidence_intervals.txt

tagchanges:
	$(TREEX) Read::AlignedSentences cs_out="$(DATA_CS)" cs_ref="$(REFERENCE_CS)" Util::SetGlobal language=cs \
      W2A::CS::Tokenize selector=ref W2A::CS::Tokenize selector=out W2A::CS::TagMorce selector=ref Write::Treex to=ali.treex.gz
	$(TREEX) -s -Lcs W2A::CS::TagMorce selector=out Align::A::MonolingualGreedy selector=ref to_selector=out -- ali.treex.gz
	$(TREEX) -Lcs Print::TagChanges selector=ref to=data/tagchanges.tsv clobber=1 -- ali.treex.gz

worsen_corpus:
	$(TREEX) -s -Lcs Read::Sentences from=data/newstest2010.cz W2A::CS::Tokenize W2A::CS::TagMorce A2A::CS::WorsenWordForms err_distr_from=data/tagchanges.tsv Write::Treex to=worsened.treex.gz

   

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
ANNOT_LINES=3003
#number of annotation chunks for manual evaluation
ANNOT_NUM=20
#files prefix
MAN_SUFFIX=mlfix_maneval
#dir with manual evaluation files
MAN_DIR=$(DIRNAME)_$(MAN_SUFFIX)

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
	scripts/highlight.pl $(MAN_DIR)/CS_BASE.tmp $(MAN_DIR)/CS_OUR.tmp $(MAN_DIR)/CS_BASE $(MAN_DIR)/CS_OUR ; \
	for a in `seq $(ANNOT_NUM)` ; do \
	  head -n `echo $$a*$$chunksize | bc` $(MAN_DIR)/EN_ORIG | tail -n $$chunksize > $(MAN_DIR)/EN_ORIG_$$a; \
	  head -n `echo $$a*$$chunksize | bc` $(MAN_DIR)/CS_REF | tail -n $$chunksize > $(MAN_DIR)/CS_REF_$$a; \
	  head -n `echo $$a*$$chunksize | bc` $(MAN_DIR)/CS_BASE | tail -n $$chunksize > $(MAN_DIR)/CS_BASE_$$a; \
	  head -n `echo $$a*$$chunksize | bc` $(MAN_DIR)/CS_OUR | tail -n $$chunksize > $(MAN_DIR)/CS_OUR_$$a; \
	  scripts/quickjudge.pl --refs=$(MAN_DIR)/EN_ORIG_$$a,$(MAN_DIR)/CS_REF_$$a $(MAN_DIR)/$(MAN_PREFIX)_$$a $(MAN_DIR)/CS_BASE_$$a $(MAN_DIR)/CS_OUR_$$a ; \
	done

maneval_eval:
	cd $(MAN_DIR) ; \
	echo -e "filename\tchanges_made\tbase_better\tour_better\tindefinite\tour_percent_1\tour_percent_2" > $(MAN_PREFIX)_results.tsv ; \
	for a in *.anot ; do \
	  ../scripts/quickjudge.pl $${a%.anot} --print > $${a%.anot}.out ; \
	  ../scripts/maneval_eval.pl $${a%.anot} $$(echo "`cat $$a | wc -l`/5" | bc) >> $(MAN_PREFIX)_results.tsv ; \
	done ;\
	cat $(MAN_PREFIX)_results.tsv

cross_annot_agree:
	cd $(MAN_DIR) ; \
	echo -e "filename1\tfilename2\tagree\tdisagree\tagree_percent\tagree_our\tagree_base\tagree_indef\tdisagree_strict\tdisagree_indef\tagree_percent_strict" > $(MAN_PREFIX)_cross_annot_agree.tsv ; \
	for a in *V.out ; do \
	  ../scripts/crossAnnotAgree.pl $${a%V.out}D.out $$a $$(echo "`cat $${a%out}anot | wc -l`/5" | bc) >> $(MAN_PREFIX)_cross_annot_agree.tsv ; \
	done

cross_annot_agree_matrix:
	cd $(MAN_DIR) ; \
	for a in *V.out ; do \
	  echo $${a%V.out} >> $(MAN_PREFIX)_cross_annot_agree_matrix.tsv ; \
	  ../scripts/crossAnnotAgreeMatrix.pl $${a%V.out}D.out $$a $$(echo "`cat $${a%out}anot | wc -l`/5" | bc) >> $(MAN_PREFIX)_cross_annot_agree_matrix.tsv ; \
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
	../scripts/highlight.pl CS_BASE.tmp CS_OUR.tmp CS_BASE.tmph CS_OUR.tmph ; \
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
	  ../scripts/quickjudge.pl --refs=EN_ORIG_$$a,CS_REF_$$a $(MAN_PREFIX)_$$a CS_BASE_$$a CS_OUR_$$a 2> /dev/null ; \
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
	  ../scripts/quickjudge.pl --refs=EN_ORIG_$$a,CS_REF_$$a $(MAN_PREFIX)_$$a CS_BASE_$$a CS_OUR1_$$a CS_OUR2_$$a 2> /dev/null ; \
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
	  ../scripts/quickjudge.pl --refs=EN_ORIG_$$a,CS_REF_$$a $(MAN_PREFIX)_$$a CS_BASE_$$a CS_OUR1_$$a CS_OUR2_$$a CS_OUR3_$$a 2> /dev/null ; \
	done

maneval_eval_2:
	cd $(MAN_DIR) ; \
	echo -e "filename\tchanges_made\tbase_better\tour1_better\tour2_better\tindefinite" > $(MAN_PREFIX)_results.tsv ; \
	for a in *.anot ; do \
	  ../scripts/quickjudge.pl $${a%.anot} --print > $${a%.anot}.out ; \
	  ../scripts/maneval_eval_2.pl $${a%.anot} `grep -c EN_ORIG $$a` >> $(MAN_PREFIX)_results.tsv ; \
	done

maneval_eval_2p:
	cd $(MAN_DIR) ; \
	echo -e "filename\tchanges_made\tbase_better\tour1_better\tour2_better\tindefinite" > $(MAN_PREFIX)_results2.tsv ; \
	for a in *.anot2p ; do \
          cp $$a tmp.anot; \
          cp $${a%.anot2p}.coresp tmp.coresp; \
	  ../scripts/quickjudge.pl tmp --print > $${a%.anot2p}.out2p ; \
	  ../scripts/maneval_eval_2p.pl $${a%.anot2p} `grep -c EN_ORIG $$a` >> $(MAN_PREFIX)_results2p.tsv ; \
	  rm tmp*; \
	done

maneval_eval_3:
	cd $(MAN_DIR) ; \
	rm $(MAN_PREFIX)_results.tsv ; \
	for a in *.anot ; do \
	  ../scripts/quickjudge.pl $${a%.anot} --print > $${a%.anot}.out ; \
	  ../scripts/maneval_eval_3.pl $${a%.anot} `grep -c EN_ORIG $$a` >> $(MAN_PREFIX)_results.tsv ; \
	done

cross_annot_agree_2:
	cd $(MAN_DIR) ; \
	echo -e "3/3\t2/3\t1/3\t0/3\tboth indef\tundecidable" > $(MAN_PREFIX)_cross_annot_agree.tsv ; \
	for i in {1..${ANNOT_NUM}} ; do \
	  ../scripts/crossAnnotAgree_2.pl *"_"$$i"_"*.out `grep -c EN_ORIG *"_"$$i"_"*D*.anot` >> $(MAN_PREFIX)_cross_annot_agree.tsv ; \
	done
# the 'D' matches either OD or DM

# TODO
# agreement by mozna mel bejt neco jako editacni vzdalenost anotaci,
# kde prohozeni poradi dvou vet je jedna operace (a prepis toho cisla taky)
cross_annot_agree_3:
	cd $(MAN_DIR) ; \
	echo -e "IAA" > $(MAN_PREFIX)_cross_annot_agree.tsv ; \
	for i in {1..${ANNOT_NUM}} ; do \
	  ../scripts/crossAnnotAgree_3.pl *"_"$$i"_"*.out `grep -c EN_ORIG *"_"$$i"_"*D*.anot` >> $(MAN_PREFIX)_cross_annot_agree.tsv ; \
	done
# the 'D' matches either OD or DM

# depfix_maneval_2_DM_stars.out


parse_parallel:
	mkdir -p project_syndicate
	scripts/clean_corpus.pl data/news-commentary-v6.cs-en.en data/news-commentary-v6.cs-en.cs project_syndicate/en.txt project_syndicate/cs.txt
	split -d -l 2000 project_syndicate/en.txt project_syndicate/en_part
	split -d -l 2000 project_syndicate/cs.txt project_syndicate/cs_part
#convert to *.treex
	$(TREEX) -s Read::AlignedSentences file_stem=project_syndicate/nc en=$$(echo project_syndicate/en_part* | sed s/' '/,/g) cs=$$(echo project_syndicate/cs_part* | sed s/' '/,/g);
#remove temporary data
	rm project_syndicate/en_part* project_syndicate/cs_part*
#run analyses on data
	$(TREEX) -sp -j 70 scenarios/cs_analysis.scen scenarios/en_analysis.scen \
        Write::LemmatizedBitexts language=en to_language=cs \
	    -- project_syndicate/nc*.treex > project_syndicate/bitexts.tsv

collect_edits: analyze_ref parse_backup collect_postedits

# after init totreex
#collect_postedits_prepare:
#	scripts/collect_edits_prepare.shc $(DIRNAME) $(DIRNAME)

TAGGER_REF=morphodita
REF_ANALYSIS_1_SCEN=Scen::MLFix::Analysis_1 language=$(LANG_TGT) selector=ref tagger=$(TAGGER_REF) iset_driver=${TGT_ISET_DRIVER}
NER_REF_SCEN=Scen::MLFix::NER language=$(LANG_TGT) selector=ref model=""
REF_ALIGNMENT_SCEN=Align::A::MonolingualGreedy selector= language=$(LANG_TGT) to_selector=ref
# analyze the reference sentences
analyze_ref: analyze_1_ref analyze_2_ref
analyze_1_ref:
	$E REF_ANALYSIS_1_SCEN=$(REF_ANALYSIS_1_SCEN) REF_ALIGNMENT_SCEN=$(REF_ALIGNMENT_SCEN)
	$(TREEXP) -s \
   	$(REF_ANALYSIS_1_SCEN) \
	$(NER_REF_SCEN) \
    $(REF_ALIGNMENT_SCEN) \
    -- $(DIRNAME)/translation*.treex.gz

REF_ANALYSIS_2_SCEN=Scen::MLFix::Analysis_2 language=$(LANG_TGT) selector=ref
analyze_2_ref:
	$E REF_ANALYSIS_2_SCEN=$(REF_ANALYSIS_2_SCEN)
	$(TREEXP) -s \
	$(REF_ANALYSIS_2_SCEN) \
	-- $(DIRNAME)/translation*.treex.gz


# after collect_postedits_prepare
collect_postedits:	
	$(TREEXP) \
	-L$(LANG_TGT) MLFix::CollectEdits print_column_names=1 language=$(LANG_TGT) selector=  to=. config_file=~/workdir-git/mlfix/config/all_fields.yaml \
	-- $(DIRNAME)/translation*.treex.gz
	zcat $(DIRNAME)/translation*_edits.tsv.gz | head -1 > $(DIRNAME)/features_header
	cat $(DIRNAME)/features_header | gzip -c > $(DIRNAME)/all_edits.tsv.gz
	for f in `ls $(DIRNAME)/translation*_edits.tsv.gz`; do \
		zcat $$f | tail -n +2 | gzip -c >> $(DIRNAME)/all_edits.tsv.gz; \
	done

#collect_postedits: 
#   scripts/collect_edits.shc $(DIRNAME)
#   zcat $(DIRNAME)/translation*_edits.tsv.gz | head -1 > $(DIRNAME)/features_header
#   cat $(DIRNAME)/features_header | gzip -c > $(DIRNAME)/all_edits.tsv.gz
#   for f in `ls $(DIRNAME)/translation*_edits.tsv.gz`; do \
#       zcat $$f | tail -n +2 | gzip -c >> $(DIRNAME)/all_edits.tsv.gz; \
#   done

OUTPUT_DIR=stats/default
collect_statistics:
	@mkdir -p $(OUTPUT_DIR)
	zcat $(DIRNAME)/all_edits.tsv.gz | scripts/print_columns.pl "old_node_lemma|old_node_pos" | grep -v punc | cut -f1 | sort | uniq -c | sort -nr > $(OUTPUT_DIR)/lemma_freq
	zcat $(DIRNAME)/all_edits.tsv.gz | scripts/analyze_changes.pl 0 > $(OUTPUT_DIR)/changed_categories_freq
	zcat $(DIRNAME)/all_edits.tsv.gz | scripts/analyze_changes.pl 1 > $(OUTPUT_DIR)/different_pos
	zcat $(DIRNAME)/all_edits.tsv.gz | scripts/analyze_changes.pl 2 > $(OUTPUT_DIR)/changes_all
	zcat $(DIRNAME)/all_edits.tsv.gz | scripts/analyze_changes.pl 3 > $(OUTPUT_DIR)/changes_iset
	zcat $(DIRNAME)/all_edits.tsv.gz | scripts/analyze_changes.pl 4 > $(OUTPUT_DIR)/feat_clusters
	zcat $(DIRNAME)/all_edits.tsv.gz | scripts/analyze_changes.pl 5 > $(OUTPUT_DIR)/changes_agr
	zcat $(DIRNAME)/all_edits.tsv.gz | scripts/analyze_changes.pl 6 > $(OUTPUT_DIR)/features_size
	zcat $(DIRNAME)/all_edits.tsv.gz | scripts/analyze_changes.pl 7 > $(OUTPUT_DIR)/changed_pos_freq
	scripts/get_stats.R 2016-04-10_19-02-56_0818207012_autodesk_train_collect/all_edits.tsv.gz > $(OUTPUT_DIR)/statistics

#####
## You should run 'make collect' before running the oracle
#####
#mlfix_oracle_markonly: analyze_ref fix_prepare
mlfix_oracle_markonly: fix_prepare
	$E
	$(TREEXP) -s \
	Scen::MLFix::Fix mark_method=oracle language=$(LANG_TGT) selector= mark_config_file=$(MARK_CONFIG_FILE) fix_config_file=$(FIX_CONFIG_FILE) iset_driver=$(TGT_ISET_DRIVER) \
	-- $(DIRNAME)/translation*.treex.gz

#mlfix_oracle_fixonly: analyze_ref fix_prepare
mlfix_oracle_fixonly: fix_prepare
	$E
	$(TREEXP) -s \
	Scen::MLFix::Fix fix_method=oracle language=$(LANG_TGT) selector= mark_config_file=$(MARK_CONFIG_FILE) fix_config_file=$(FIX_CONFIG_FILE) iset_driver=$(TGT_ISET_DRIVER) voting_method=$(VOTING_METHOD) threshold=$(MARK2FIX_THRESHOLD) \
	-- $(DIRNAME)/translation*.treex.gz

#mlfix_oracle_all: analyze_ref fix_prepare
mlfix_oracle_all: fix_prepare
	$E
	$(TREEXP) -s \
	Scen::MLFix::Fix mark_method=oracle fix_method=oracle language=$(LANG_TGT) selector= mark_config_file=$(MARK_CONFIG_FILE) fix_config_file=$(FIX_CONFIG_FILE) iset_driver=$(TGT_ISET_DRIVER) \
	-- $(DIRNAME)/translation*.treex.gz

# new depfix -- without saving the treex files, thus saving about half of
# runtime (work in progress; there are still problems with mgiza and problems
# with writing out multiple output files)

deepfix_allin1: init totreex_noproject deepfix_all_1 run_giza deepfix_all_2 write_sentences eval

deepfix_allin1_ni: totreex_noproject deepfix_all_1 run_giza deepfix_all_2 write_sentences eval

anal_only: init totreex tag run_giza ner_en parse a2t_not

full_new_ni: full_new_manal full_new_giza full_new_parse_fix_write eval

full_new: init full_new_ni

full_new_manal:
	$E
	cd $(DIRNAME); \
		$(TREEX) $(SD)/deepfix_all_new_1.scen;\
		# mkdir mtagged; cp *streex* mtagged;

full_new_giza:
	$E
	cd $(DIRNAME); \
		$(TREEX) $(SD)/deepfix_all_new_2.scen;\
		# mkdir aligned; cp *streex* aligned;

# parse, fix, deepfix, write sentences to indiv. files
full_new_parse_fix_write:
	$E
	cd $(DIRNAME); \
		$(TREEXP) $(SD)/deepfix_all_new_3.scen;\
		cat depfix???.txt > output.txt; \
		cat fixlog???.txt > fixlog.txt;

#full_new_run:
#	$E
#	cd $(DIRNAME) && $(TREEXP) ../scenarios/deepfix_all_new_1.scen && $(TREEXP) ../scenarios/deepfix_all_new_2.scen && $(TREEXP) ../scenarios/deepfix_all_new_3.scen

include $(SETTINGS_FILE)

