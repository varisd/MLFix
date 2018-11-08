library(ggplot2)

args = commandArgs(trailingOnly = TRUE)
input = args[1]
output = args[2]
Xcol = paste("V",args[3], sep="")
Ycol = paste("V",args[4], sep="")

t = read.table(input, sep="\t", fill=TRUE)
op <- par(mar = c(12, 4, 4, 2) + 0.1)
png(filename=output, units="in", width=5, height=4, pointsize=12, res=144)

xyplot(t[,Ycol] ~ t[,Xcol] , groups=t$V12, auto.key = list(corner = c(0, .98)),  data = t)

#legend("topright", names(t2), cex = 0.9, bty = "n", fill = heat.colors(4))
dev.off()




# t2 = head(t, 50)
# xyplot(t2$V5 ~ strtoi(rownames(t2)) , groups=t2$V12, auto.key = list(corner = c(0, .98)),  distribute.type=TRUE)
