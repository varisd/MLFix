#!/usr/bin/env Rscript
library(infotheo)

args = commandArgs(trailingOnly = TRUE)
input = args[1]
output = args[2]
threshold = 300

data = read.csv(input, header=TRUE, quote="", colClasses="factor", encoding="UTF-8", sep="\t")

#columns = rep(FALSE, ncol(data))
#for(i in seq(ncol(data))) {
#	columns[i] = (nrow(table(data[,i])) > 1)
#}
#data.filtered = data[,columns==TRUE]
data.filtered = data[, colSums(is.na(data)) == 0]

features = data.filtered[, grep("new", names(data.filtered), invert=TRUE)]
targets = data.filtered[, grep("new", names(data.filtered))]
features.new = features
for(i in 1:(ncol(targets))) {
	condEnt = c()
	for(j in 1:(ncol(features))){
		condEnt = append(condEnt, condentropy(targets[,i],features[,j]))
	}
	features.indexes = order(condEnt)
	features.new = features.new[, intersect(names(features.new), names(features[, features.indexes[1:threshold]]))]
}

data.filtered = c(features.new, targets)

write.table(data.filtered, file=output, quote=FALSE, row.names=FALSE, col.names=TRUE, na="", sep="\t")
