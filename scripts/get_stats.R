#!/usr/bin/env Rscript
library(infotheo)
library(simba)

args = commandArgs(trailingOnly = TRUE)
input = args[1]

data = read.csv(input, header=TRUE, quote="", colClasses="factor", encoding="UTF-8", sep="\t")

nodenames = names(data)[grep("new", names(data))]
nodenames = gsub("new_", "", nodenames)

print("||| Attribute changes |||")

for(name in nodenames) {
    if(name != "node_other" && name != "node_form" && name != "node_lemma" && name != "node_tag") {
        print(name)
        print(table(data[,gsub("^", "new_", name)], data[,gsub("^", "old_", name)]))
    }
}

print ("||| Attribute change similarity |||")

changes = list()
for(name in nodenames) {
    if(name != "node_other" && name != "node_form" && name != "node_lemma" && name != "node_tag") {
        col = rep(0, nrow(data))
        col[as.character(data[,gsub("^", "new_", name)]) == as.character(data[,gsub("^", "old_", name)])] = 1
        changes = cbind(changes, col)
        colnames(changes)[ncol(changes)] = name
    }
}

sim(t(changes), method="jaccard")
