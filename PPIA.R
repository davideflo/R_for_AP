### PUN PREDICTION IN ACTION ###

source("R_code/functions_for_PPIA_server.R")

prices10 <- openxlsx::read.xlsx("C:/Users/utente/Documents/PUN/Anno 2010.xlsx", sheet="Prezzi-Prices", colNames=TRUE)
prices11 <- openxlsx::read.xlsx("C:/Users/utente/Documents/PUN/Anno 2011.xlsx", sheet="Prezzi-Prices", colNames=TRUE)
prices12 <- openxlsx::read.xlsx("C:/Users/utente/Documents/PUN/Anno 2012.xlsx", sheet="Prezzi-Prices", colNames=TRUE)
prices13 <- openxlsx::read.xlsx("C:/Users/utente/Documents/PUN/Anno 2013.xlsx", sheet="Prezzi-Prices", colNames=TRUE)
prices14 <- openxlsx::read.xlsx("C:/Users/utente/Documents/PUN/Anno 2014.xlsx", sheet="Prezzi-Prices", colNames=TRUE)
prices15 <- openxlsx::read.xlsx("C:/Users/utente/Documents/PUN/Anno 2015.xlsx", sheet="Prezzi-Prices", colNames=TRUE)
prices16 <- openxlsx::read.xlsx("C:/Users/utente/Documents/PUN/Anno 2016_06.xlsx", sheet="Prezzi-Prices", colNames=TRUE)

meteonord <- read.csv2("C:/Users/utente/Documents/PUN/storico_milano_aggiornato.txt", header=TRUE, sep="\t",colClasses = "character", stringsAsFactors = FALSE)
meteocsud <- read.csv2("C:/Users/utente/Documents/PUN/storico_roma.txt", header=TRUE, sep="\t",colClasses = "character", stringsAsFactors = FALSE)
meteocnord <- read.csv2("C:/Users/utente/Documents/PUN/storico_firenze_aggiornato.txt", header=TRUE, sep="\t",colClasses = "character", stringsAsFactors = FALSE)
meteosud <- read.csv2("C:/Users/utente/Documents/PUN/storico_reggiocalabria_aggiornato.txt", header=TRUE, sep="\t",colClasses = "character", stringsAsFactors = FALSE)
meteosici <- read.csv2("C:/Users/utente/Documents/PUN/storico_palermo_aggiornato.txt", header=TRUE, sep="\t",colClasses = "character", stringsAsFactors = FALSE)
meteosard <- read.csv2("C:/Users/utente/Documents/PUN/storico_cagliari_aggiornato.txt", header=TRUE, sep="\t",colClasses = "character", stringsAsFactors = FALSE)

mi6 <- openxlsx::read.xlsx("C:/Users/utente/Documents/PUN/Milano 2016.xlsx", sheet= 1, colNames=TRUE)
ro6 <- openxlsx::read.xlsx("C:/Users/utente/Documents/PUN/Roma 2016.xlsx", sheet= 1, colNames=TRUE)
fi6 <- openxlsx::read.xlsx("C:/Users/utente/Documents/PUN/Firenze 2016.xlsx", sheet= 1, colNames=TRUE)
pa6 <- openxlsx::read.xlsx("C:/Users/utente/Documents/PUN/Palermo 2016.xlsx", sheet= 1, colNames=TRUE)
ca6 <- openxlsx::read.xlsx("C:/Users/utente/Documents/PUN/Cagliari 2016.xlsx", sheet= 1, colNames=TRUE)
rc6 <- openxlsx::read.xlsx("C:/Users/utente/Documents/PUN/Reggio Calabria 2016.xlsx", sheet= 1, colNames=TRUE)

### test1: normal-old-revised-function with step = day_ahead = 0

start <- Sys.time()
test <- create_dataset_day_ahead(prices10,"ven","CSUD", meteocsud, 0, day_ahead = 0, hb = 23)
end <- Sys.time()
taken <- end-start
taken ### 20 minutes

### test2: old-revised-function with step = 0 and day_ahead = 1

aug <- augmented_dataset(prices10,prices11,step = 0,day_ahead = 1)

start <- Sys.time()
test2 <- create_dataset_day_ahead(aug,"ven","CSUD", meteocsud, 0, day_ahead = 1, hb = 23)
end <- Sys.time()
taken <- end-start
taken ### 16 minutes

### test3: old-revised-function with step = 6 and day_ahead = 4

aug2 <- augmented_dataset(prices10,prices11,step = 6,day_ahead = 4)

start <- Sys.time()
test3 <- create_dataset_day_ahead(aug2,"ven","CSUD", meteocsud, step = 6, day_ahead = 4, hb = 23)
end <- Sys.time()
taken <- end-start
taken ### 17 minutes

### test4: with old-revised-function step = 0, day_ahead = 1 must equal step = 24, day_ahead = 0

aug3 <- augmented_dataset(prices10,prices11,step = 24,day_ahead = 0)

start <- Sys.time()
test4 <- create_dataset_day_ahead(aug3,"ven","CSUD", meteocsud, 24, day_ahead = 0, hb = 23)
end <- Sys.time()
taken <- end-start
taken ### 14 minutes

### test 5: new-defined-function with step = day_ahead = 1

start <- Sys.time()
test5 <- create_dataset_days_ahead(prices10,"ven","CSUD", meteocsud, step = 1, day_ahead = 1)
end <- Sys.time()
taken <- end-start
taken ### 13.49 secs

### test 6: new-defined-function with step = 1, day_ahead = 2

aug6 <- augmented_dataset(prices10,prices11,step = 1,day_ahead = 2)

start <- Sys.time()
test6 <- create_fixed_dataset(aug6,"ven","CSUD", meteocsud, step = 1, day_ahead = 2)
end <- Sys.time()
taken <- end-start
taken ### 12.69 secs

### test 7: new-defined-function with step = 24, day_ahead = 5

aug7 <- augmented_dataset(prices10,prices11,step = 24,day_ahead = 5)

start <- Sys.time()
test7 <- create_dataset_days_ahead(aug7,"ven","CSUD", meteocsud, step = 24, day_ahead = 5)
end <- Sys.time()
taken <- end-start
taken ### 13.99 secs

#####################################################################################################################
#### generation of all step + day_ahead rolling and fixed datasets
#### aggregating weather information 

variables <- colnames(prices10)[c(1:12,14:21)]
prices <- rbind(prices10[c(1:12,14:21)], prices11[,which(colnames(prices11) %in% variables)], prices12[,which(colnames(prices12) %in% variables)], 
                prices13[,which(colnames(prices13) %in% variables)], prices14[,which(colnames(prices14) %in% variables)],
                prices15[,which(colnames(prices15) %in% variables)])

## average weather variables 

meteonord[,2:ncol(meteonord)] <- data.matrix(meteonord[,2:ncol(meteonord)])
meteocsud[,2:ncol(meteocsud)] <- data.matrix(meteocsud[,2:ncol(meteocsud)])
meteocnord[,2:ncol(meteocnord)] <- data.matrix(meteocnord[,2:ncol(meteocnord)])
meteosici[,2:ncol(meteosici)] <- data.matrix(meteosici[,2:ncol(meteosici)])
meteosard[,2:ncol(meteosard)] <- data.matrix(meteosard[,2:ncol(meteosard)])
meteosud[,2:ncol(meteosud)] <- data.matrix(meteosud[,2:ncol(meteosud)])

meteoav <- mediate_meteos(meteonord, meteocsud, meteocnord, meteosici, meteosard, meteosud, FALSE)
meteoav16 <- mediate_meteos(mi6, ro6, fi6, pa6, ca6, rc6, TRUE)

library(h2o)
h2o.init(nthreads=-1, max_mem_size = '20g')
h2o.clusterInfo()

generate_rolling_dataset(prices, prices16, meteoav, meteoav16)

