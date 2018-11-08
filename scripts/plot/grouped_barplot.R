library(ggplot2)

args = commandArgs(trailingOnly = TRUE)
input = args[1]
output = args[2]

t = read.csv(input, header = TRUE, sep="\t", fill = TRUE)
t2 = head(t, 10)
op <- par(mar = c(12, 4, 4, 8) + 0.1)
png(filename=output, units="in", width=5, height=4, pointsize=12, res=144)
# 't()' is matrix tranposition, 'beside = TRUE' separates the benchmarks, 'heat' provides nice colors
barplot(t(as.matrix(t2)), beside = TRUE, col = heat.colors(4), las=2)
# 'cex' stands for 'character expansion', 'bty' for 'box type' (we don't want borders)
legend("topright", names(t2), cex = 0.9, bty = "n", fill = heat.colors(4))
dev.off()
