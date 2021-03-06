##### Random Forest Experiments on differential consumption given meteo --> Sbilanciamento Python

library(plyr)
library(dplyr)
library(readxl)
library(feather)
library(lubridate)
library(data.table)
library(randomForest)
library(RFinfer)

# references:
# https://cran.r-project.org/web/packages/RFinfer/vignettes/IJ_vig.html
# https://cran.r-project.org/web/packages/randomForest/randomForest.pdf
# https://cran.rstudio.com/web/packages/RFinfer/RFinfer.pdf

DWT <- data.table(read_excel('C:/Users/utente/Documents/DWT.xlsx'))

rf <- randomForest(y ~ ., data = DWT, ntree = 3000,  keep.inbag = TRUE)
summary(rf)

rfpv <- rfPredVar(rf, rf.data = DWT, CI = TRUE, tree.type = 'rf')

plot(1:243, DWT$y, pch = 16, col = 'blue')
points(1:243, rfpv$pred, pch = 17, col = 'red')

plot(rfpv$pred, type = 'l', col = 'black', lwd = 2)
lines(DWT$y, type = 'l', col = 'purple')
lines(rfpv$l.ci, type = 'l', col = 'red')
lines(rfpv$u.ci, type = 'l', col = 'black')

plot(DWT$y - rfpv$pred, pch = 16, col = 'green')

residuals = DWT$y - rfpv$pred
mean(residuals)
sd(residuals)
