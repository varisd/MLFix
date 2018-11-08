# MLFix
MLFix is an automatic post-editing tool for correcting machine translation outputs.

MLFix is a successor of Depfix, a rule-based post-editing system for English-Czech machine translation. It extends [Depfix](http://ufal.mff.cuni.cz/depfix) by applying a machine-learning algorithms to learn identify the translation errors and finding a proper correction. Similar to Depfix, it is also implemented within the [Treex NLP framework](https://github.com/ufal/treex). It uses Treex pipelines for morphological and syntactic analysis to extract features for the statistical model training and then uses Treex wrappers to apply these models to correct the morphology and syntax of the presented machine translation output.

    Usage:
    # TODO
    # (See Makefile for possible scenarios)
