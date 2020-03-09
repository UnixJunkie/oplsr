
library("pls", quietly = TRUE)

# FBR: use the cLogP dataset

data <- as.matrix(read.table("data/Boston_regr_train.csv", colClasses = "numeric", header = TRUE))
ydim <- dim(data)[1]
xdim <- dim(data)[2]
stopifnot(xdim == 14 && ydim == 456)
xs <- data[, 2:14]
ys <- data[, 1:1]
mydata <- data.frame(y = ys, x = xs)

# just a train a model
model <- plsr(data.y ~ data.x, ncomp = 10, method = "simpls", data = mydata, validation = "none")

# FBR: find the best ncomp using NxCV - fix the number of folds !!!

model <- plsr(y ~ x, method = "simpls", data = mydata, validation = "CV")


model <- plsr(octane ~ NIR, method = "simpls", data = gasTrain, validation = "CV")
plot(RMSEP(model)) # FBR: extract ncomp from there; i.e. ncomp where CV is minimum

predict(model, ncomp = 10, newdata = gasTest)

predplot(model, ncomp = 10, newdata = gasTest, asp = 1, line = TRUE)
