##### script for prediction --- FIXED ONLY ---

library(h2o)
library(readxl)
library(lubridate)
library(dplyr)

### all variables called date are of the type used by lubridate 
### and excel

## source
source("C://Users//utente//Documents//R_code//functions_for_PPIA_server.R")
source("C://Users//utente//Documents//R_code//functions_for_PUN_server.R")

build_meteo_new <- function(date)
{
  ## call all meteo datasets for all cities
  ## mediate_meteos
  ## store the results in a matrix with each row being a day
  ## and variables: (tmin, tmax, tmed, rain, wind)
  ## both now and future:
  # 1: tmin.now, tmax.now, tmed.now, rain.now, wind.now
  # 2: tmin.+1, tmax.+1, tmed.+1, rain.+1, wind.+1
  # 3: tmin.+2, tmax.+2, tmed.+2, rain.+2, wind.+2
  #
  res <- matrix(0, nrow = 6, ncol= 5)
  
  var_names <- c("mi","ro","fi","ca","pa","rc")
  
  mi <- read.csv2("C:\\Users\\utente\\Downloads\\Milano.csv", header = FALSE, sep=",", colClasses = "character", stringsAsFactors = FALSE)
  ro <- read.csv2("C:\\Users\\utente\\Downloads\\Roma.csv", header = FALSE, sep=",", colClasses = "character", stringsAsFactors = FALSE)
  fi <- read.csv2("C:\\Users\\utente\\Downloads\\Firenze.csv", header = FALSE, sep=",", colClasses = "character", stringsAsFactors = FALSE)
  ca <- read.csv2("C:\\Users\\utente\\Downloads\\Cagliari.csv", header = FALSE, sep=",", colClasses = "character", stringsAsFactors = FALSE)
  pa <- read.csv2("C:\\Users\\utente\\Downloads\\Palermo.csv", header = FALSE, sep=",", colClasses = "character", stringsAsFactors = FALSE)
  rc <- read.csv2("C:\\Users\\utente\\Downloads\\Reggio Calabria.csv", header = FALSE, sep=",", colClasses = "character", stringsAsFactors = FALSE)
  
  
  for(i in 0:5)
  {
    #print(i)
    temp <- matrix(0,nrow=6,ncol=5)
    dt <- as.Date(date) + i
    for(n in var_names)
    {
      df <- get(n)
      at <- which(as.Date(df[,1], format = "%Y-%m-%d") == dt)
      df2 <- df[at,]
      
      r <- which(var_names == n)
      #print(paste("r", r))
      #print(mean(as.numeric(unlist(df2[,4]))))
      row4 <- row5 <- c()
      for(k in 1:nrow(df2))
      {
        if(df2[k,5] == "")
        {
          row4 <- c(row4, k) 
        } else
        {
          row5 <- c(row5, k)
        }
      }
      
      if(i == 0)
      {
        temp[r,1] <- min(as.numeric(unlist(df2[row5,3])))
        temp[r,2] <- max(as.numeric(unlist(df2[row5,3])))
        temp[r,3] <- mean(as.numeric(unlist(df2[row5,3])))
        temp[r,4] <- mean(as.numeric(unlist(df2[row5,5])), na.rm=TRUE) ### RAIN
        temp[r,5] <- mean(as.numeric(unlist(df2[row5,4])), na.rm=TRUE) ### WIND
      }
      else 
      {
        temp[r,1] <- min(as.numeric(unlist(df2[row4,2])))
        temp[r,2] <- max(as.numeric(unlist(df2[row4,2])))
        temp[r,3] <- mean(as.numeric(unlist(df2[row4,2])))
        temp[r,4] <- mean(as.numeric(unlist(df2[row4,4])), na.rm=TRUE) ### RAIN
        temp[r,5] <- mean(as.numeric(unlist(df2[row4,3])), na.rm=TRUE) ### WIND
      }
    }
    res[i+1,] <- c(unlist(colMeans(temp)))
  }
  res <- data.frame(res)
  colnames(res) <- c("tmin", "tmax", "tmed", "pioggia", "vento")
  
  return(res)
}
#######################################################
build_new <- function(df)
{
  ## put the prices in rows
  ## compute old and new holidays
  ## old and new angleday 
  ## all the "new" variables are in the last columns
  dt <- Sys.Date()
  
  untime <- maply(1:nrow(df), function(n) unlist(df[n,1]))
  
  #utc <- as.POSIXct(untime, format="%d/%m/%Y %H:%M:%S", origin = "1970-01-01", tz="UCT")
  utc <- as.POSIXct(untime, origin = "1970-01-01")
  
  
  #ad <- as.character(unlist(df[,1]))
  #add <- unlist(strsplit(ad, " "))
  #add
  lasty <- max(which(as.Date(utc) == (dt-1)))
  
  oggi <- which(as.Date(utc) == dt)
  dft <- df[c(lasty,oggi[1:(length(oggi)-1)]),]
  aday1 <- convert_day_to_angle(subsequent_day(tolower(as.character(dft[1,6]))))
  
  tda <- unlist(strsplit(as.character(dt),"-"))
  target_data <- paste0(tda[3],"/",tda[2],"/",tda[1])
  hol <- add_holidays(target_data)
  ahour <- convert_hour_to_angle(1:24)
  
  len <- nrow(dft)
  
  if(len == 23)
  {
    df2 <- data.frame(t(dft[c(1:23,23),13]), t(dft[c(1:23,23),14]), t(dft[c(1:23,23),19]), t(dft[c(1:23,23),22]), t(dft[c(1:23,23),23]),
                      t(dft[c(1:23,23),30]), t(dft[c(1:23,23),32]),aday1, hol, t(ahour))
    
  }
  
  else if(len == 25)
  {
    df2 <- data.frame(t(dft[c(1:24),13]), t(dft[c(1:24),14]), t(dft[c(1:24),19]), t(dft[c(1:24),22]), t(dft[c(1:24),23]),
                      t(dft[c(1:24),30]), t(dft[c(1:24),32]),aday1, hol, t(ahour))
    
  }
  
  else 
  {
    df2 <- data.frame(t(dft[,13]), t(dft[,14]), t(dft[,19]), t(dft[,22]), t(dft[,23]), t(dft[,30]), t(dft[,32]),aday1, hol, t(ahour))
  }
  Names <- c(paste0("pun-",24:1), paste0("aust-",24:1), paste0("cors-",24:1), paste0("fran-",24:1), paste0("grec-",24:1),
             paste0("slov-",24:1), paste0("sviz-",24:1),"angleday","holiday",paste0("anglehour-",24:1))
  colnames(df2) <- Names
  
  return(df2)
  
}
#######################################################
assemble_pm <- function(pn, meteo)
{
  res <- matrix(0,nrow=5*24,ncol=207)
  # "meteo" comes from build_meteo_new
  
  ### DEFINE day
  wd <- tolower(as.character(lubridate::wday(Sys.Date(), label = TRUE)))
  
  for(i in 1:120)
  {
    step_p <- ifelse(i %% 24 == 0, 24, i %% 24)
    step_m <- ifelse(i %% 5 == 0, 5, i %% 5)
    
    tday <- convert_day_to_angle(compute_day_at(wd, step_m))
    
    dt <- Sys.Date() + 1 + step_m
    
    tda <- unlist(strsplit(as.character(dt),"-"))
    target_data <- paste0(tda[3],"/",tda[2],"/",tda[1])
    thol <- add_holidays(target_data)
    
    
    row <- c(unlist(pn),unlist(meteo[1,]), convert_hour_to_angle(step_p),tday,thol,unlist(meteo[1+step_m,]))
    
    res[i,] <- row
  }
  
  res <- data.frame(res)
  
  Names <- c(paste0("PUN-",24:1), paste0("aust-",24:1), paste0("cors-",24:1), paste0("fran-",24:1), paste0("grec-",24:1),
             paste0("slov-",24:1), paste0("sviz-",24:1), "angleday", "holiday",
             paste0("angleora-",24:1),
             "tmin","tmax","tmed","pioggia","vento",
             "target_ora", "target_day", "target_holiday","target_tmin","target_tmax","target_tmed","target_pioggia","target_vento")
  
  colnames(res) <- Names
  
  return(res)
}
#######################################################
prediction <- function(date)
{
  res <- restr <- matrix(0, nrow=24, ncol=15)
  ## load pun file
  pp <- read_excel("C:\\Users\\utente\\Documents\\PUN\\DB_Borse_Elettriche_PER MI.xlsx", sheet = "DB_Dati")
  ## look for date
  #ppnew <- pp[which(pp[,1] == as.Date(date))]
  ## build "new observation"
  meteonew <- build_meteo_new(date)
  pn <- build_new(pp)
  apm <- assemble_pm(pn, meteonew)
  xnew <- as.h2o(apm)
  
  #### correction phase
  #odie <- Sys.Date()
  odie <- as.Date(date)
  untime <- maply(1:nrow(pp), function(n) unlist(pp[n,1]))
  utc <- as.POSIXct(untime, origin = "1970-01-01")
  lasty <- max(which(as.Date(utc) == (odie-1)))
  pun_oggi <- unlist(pp[c(lasty,which(as.Date(utc) == odie)),13])
  pun_oggi <- pun_oggi[1:24]
  # correction 1
  prev <- read_excel(paste0("C:\\Users\\utente\\Documents\\prediction_PUN_not_corrected_",odie-1,".xlsx")) 
  prev2 <- unlist(prev[paste0("prediction_",as.character(odie))])
  diff <- prev2 - pun_oggi
  file <- "C:\\Users\\utente\\Documents\\PUN\\differences_true_predicted.xlsx"
  if(file.exists(file))
  {
    of <- read_excel(file)
    of <- data.frame(of)
    diff2 <- data.frame(diff)
    colnames(diff2) <- as.character(odie)
    of <- bind_cols(of,diff2)
    xlsx::write.xlsx(of,"C:\\Users\\utente\\Documents\\PUN\\differences_true_predicted.xlsx", row.names = FALSE, col.names = TRUE)
  }
  else
  {
    diff2 <- data.frame(diff)
    colnames(diff2) <- as.character(odie)
    xlsx::write.xlsx(diff2,"C:\\Users\\utente\\Documents\\PUN\\differences_true_predicted.xlsx", row.names = FALSE, col.names = TRUE)
  }
  # correction 2
  prevcorr <- read_excel(paste0("C:\\Users\\utente\\Documents\\prediction_PUN_",odie-1,".xlsx"))
  prev2corr <- unlist(prev[paste0("prediction_",as.character(odie))])
  diffcorr <- prev2corr - pun_oggi
  file2 <- "C:\\Users\\utente\\Documents\\PUN\\differences_true_predicted_corr.xlsx"
  if(file.exists(file2))
  {
    of2 <- read_excel(file2)
    of2 <- data.frame(of2)
    diff2corr <- data.frame(diffcorr)
    colnames(diff2corr) <- as.character(odie)
    of2 <- bind_cols(of2,diff2corr)
    xlsx::write.xlsx(of2,"C:\\Users\\utente\\Documents\\PUN\\differences_true_predicted_corr.xlsx", row.names = FALSE, col.names = TRUE)
  }
  else
  {
    diff2 <- data.frame(diffcorr)
    colnames(diff2corr) <- as.character(odie)
    xlsx::write.xlsx(diff2corr,"C:\\Users\\utente\\Documents\\PUN\\differences_true_predicted_corr.xlsx", row.names = FALSE, col.names = TRUE)
  }
  ## call all models and make predictions
  for(da in 1:5)
  {
    for(step in 1:24)
    {
      #print(paste("step:",step,"da:", da))
      dal <- da + (da-1)*2
      dam <- da + (da-1)*2 + 1
      dau <- da*3
      id <- paste0("sda",step,"_",da)
      model <- h2o.loadModel(paste0("C:\\Users\\utente\\Documents\\PUN\\fixed\\models\\",id))
      x <- predict(model,xnew[da,])
      x2 <- as.numeric(x$predict)
      x3 <- as.matrix(x2)
      x4 <- unlist(x3[,1])
      yhat <- x4 - diff[step] #- diffcorr[step]
      res[step,dam] <- yhat
      restr[step, da] <- x4
      h2o.rm(model)
      bc <- bootstrap_f_r(yhat,step,da)
      res[step,dal] <- bc[1]
      res[step,dau] <- bc[2]
    }
  }
  res <- data.frame(res)
  rownames(res) <- 1:24
  restr <- data.frame(restr)
  rownames(restr) <- 1:24  
  names <- c()
  for(n in 1:5)
  {
    names <- c(names,paste0(c("L_", "prediction_", "U_"),as.character(odie+n)))
  }
  colnames(res) <- names
  colnames(restr) <- names
  xlsx::write.xlsx(restr,paste0("prediction_PUN_not_corrected_",date,".xlsx"), row.names = FALSE, col.names = TRUE)
  return(res)
}
############################################################
bootstrap_f_r_errors <- function(yhat, step, day_ahead, B = 100)
{
  ## remember: step coincides with the hour to predict
  db <- read_excel(paste0("C:/Users/utente/Documents/PUN/fixed/errors/distribution_errors_step_",step,"_dayahead_",day_ahead,".xlsx"))
  gh <- as.numeric(unlist(db[,2]))
  vdiff <- maply(1:B, function(n) mean(maply(1:10, function(h) sample(gh, size = 1, replace = TRUE)))) ### UNDERESTIMATED ###
  return(c(yhat+quantile(vdiff,probs=0.025, na.rm = FALSE), yhat+quantile(vdiff,probs=0.975), na.rm = FALSE))
}
#######################################################
prediction_weekend <- function(date)
{
  odie <- as.Date(date)
  res <- restr <- matrix(0, nrow=24, ncol=15)
  
  pp <- read_excel("C:\\Users\\utente\\Documents\\PUN\\DB_Borse_Elettriche_PER MI.xlsx", sheet = "DB_Dati")
  
  if(convert_day(lubridate::wday(as.Date(date), label=TRUE)) == 'lun')
  {
    for(d in 2:1)
    {
      odie <- date <- odie - d
      
      meteonew <- build_meteo_new(date)
      pn <- build_new(pp)
      apm <- assemble_pm(pn, meteonew)
      xnew <- as.h2o(apm)

      #### correction phase
      untime <- maply(1:nrow(pp), function(n) unlist(pp[n,1]))
      utc <- as.POSIXct(untime, origin = "1970-01-01")
      lasty <- max(which(as.Date(utc) == (odie-1)))
      pun_oggi <- unlist(pp[c(lasty,which(as.Date(utc) == odie)),13])
      pun_oggi <- pun_oggi[1:24]
      # correction 1
      prev <- read_excel(paste0("C:\\Users\\utente\\Documents\\prediction_PUN_not_corrected_",odie-1,".xlsx")) 
      prev2 <- unlist(prev[paste0("prediction_",as.character(odie))])
      diff <- prev2 - pun_oggi
      file <- "C:\\Users\\utente\\Documents\\PUN\\differences_true_predicted.xlsx"
      if(file.exists(file))
      {
        of <- read_excel(file)
        of <- data.frame(of)
        diff2 <- data.frame(diff)
        colnames(diff2) <- as.character(odie)
        of <- bind_cols(of,diff2)
        xlsx::write.xlsx(of,"C:\\Users\\utente\\Documents\\PUN\\differences_true_predicted.xlsx", row.names = FALSE, col.names = TRUE)
      }
      else
      {
        diff2 <- data.frame(diff)
        colnames(diff2) <- as.character(odie)
        xlsx::write.xlsx(diff2,"C:\\Users\\utente\\Documents\\PUN\\differences_true_predicted.xlsx", row.names = FALSE, col.names = TRUE)
      }
      # correction 2
      prevcorr <- read_excel(paste0("C:\\Users\\utente\\Documents\\prediction_PUN_",odie-1,".xlsx"))
      prev2corr <- unlist(prev[paste0("prediction_",as.character(odie))])
      diffcorr <- (prev2corr - pun_oggi)/2
      file2 <- "C:\\Users\\utente\\Documents\\PUN\\differences_true_predicted_corr.xlsx"
      if(file.exists(file2))
      {
        of2 <- read_excel(file2)
        of2 <- data.frame(of2)
        diff2corr <- data.frame(diffcorr)
        colnames(diff2corr) <- as.character(odie)
        of2 <- bind_cols(of2,diff2corr)
        xlsx::write.xlsx(of2,"C:\\Users\\utente\\Documents\\PUN\\differences_true_predicted_corr.xlsx", row.names = FALSE, col.names = TRUE)
      }
      else
      {
        diff2 <- data.frame(diffcorr)
        colnames(diff2corr) <- as.character(odie)
        xlsx::write.xlsx(diff2corr,"C:\\Users\\utente\\Documents\\PUN\\differences_true_predicted_corr.xlsx", row.names = FALSE, col.names = TRUE)
      }
      ## call all models and make predictions
      for(da in 1:5)
      {
        for(step in 1:24)
        {
          
          dal <- da + (da-1)*2
          dam <- da + (da-1)*2 + 1
          dau <- da*3
          id <- paste0("sda",step,"_",da)
          model <- h2o.loadModel(paste0("C:\\Users\\utente\\Documents\\PUN\\fixed\\models\\",id))
          x <- predict(model,xnew[da,])
          x2 <- as.numeric(x$predict)
          x3 <- as.matrix(x2)
          x4 <- unlist(x3[,1])
          yhat <- x4 - diff[step] #- diffcorr[step]
          res[step,dam] <- yhat
          restr[step, da] <- x4
          h2o.rm(model)
          bc <- bootstrap_f_r(yhat,step,da)
          res[step,dal] <- bc[1]
          res[step,dau] <- bc[2]
        }
      }
     
      res <- data.frame(res)
      rownames(res) <- 1:24
      restr <- data.frame(restr)
      rownames(restr) <- 1:24  
      names <- c()
      for(n in 1:5)
      {
        names <- c(names,paste0(c("L_", "prediction_", "U_"), as.character(odie+n)))
      }
      colnames(res) <- names
      colnames(restr) <- names
      xlsx::write.xlsx(restr,paste0("prediction_PUN_not_corrected_",date,".xlsx"), row.names = FALSE, col.names = TRUE)
      xlsx::write.xlsx(res,paste0("prediction_PUN_",date,".xlsx"), row.names = FALSE, col.names = TRUE)
      
    }
    
    return(res) ## return only the last one, but the predictions are saved anyway
  }
  else
  {
    print("it's not monday => no need to update the pun over the weekend")
    return(NULL)
  }
}
###################################################################################################
get_last_month <- function(pp, odie, bVerbose = FALSE)
{
  week_days <- c("lun", "mar", "mer", "gio", "ven")
  
  untime <- maply(1:nrow(pp), function(n) unlist(pp[n,1]))
  utc <- as.POSIXct(untime, origin = "1970-01-01")
  last_month <- as.Date(odie) - months(1)
  last <- which(as.Date(utc) >= last_month & as.Date(utc) < odie)
  pp_last <- pp[last,]
  
  if(bVerbose)
  {
    tda <- unlist(strsplit(as.character(odie),"-"))
    target_data <- paste0(tda[3],"/",tda[2],"/",tda[1])
    thol <- add_holidays(target_data)
    
    if( convert_day(lubridate::wday(odie, label = TRUE)) %in% week_days & thol == 0)
    {
      pp_last <- pp_last[which(pp_last["Lavorativo/Festivo"] == "Lavorativo"),]
    } else
    {
      pp_last <- pp_last[which(pp_last["Lavorativo/Festivo"] == "Festivo"),]
    }
  }
  
  return(pp_last)
}
###################################################################################################
call_corrector_mean <- function(pp_last, odie)
{
  grand_mean <- mean(unlist(pp_last[,13]))
  
  return(grand_mean)
}
###################################################################################################
call_corrector_yesterday_mean <- function(pp_last, odie, bVerbose = FALSE)
{
  untime <- maply(1:nrow(pp_last), function(n) unlist(pp_last[n,1]))
  utc <- as.POSIXct(untime, origin = "1970-01-01")
  
  pun_oggi <- unlist(pp[c(max(which(as.Date(utc) == (odie-1))),which(as.Date(utc) == odie)),13])
  
  
  ###first heuristic correction
  prev <- read_excel(paste0("C:\\Users\\utente\\Documents\\prediction_PUN_not_corrected_",odie-1,".xlsx")) 
  prev2 <- unlist(prev[paste0("prediction_",as.character(odie))])
  diff <- prev2 - pun_oggi
  
  file <- "C:\\Users\\utente\\Documents\\PUN\\differences_true_predicted.xlsx"
  
  if(file.exists(file))
  {
    of <- read_excel(file)
    of <- data.frame(of)
    diff2 <- data.frame(diff)
    colnames(diff2) <- as.character(odie)
    of <- bind_cols(of,diff2)
    xlsx::write.xlsx(of,"C:\\Users\\utente\\Documents\\PUN\\differences_true_predicted.xlsx", row.names = FALSE, col.names = TRUE)
  } else
  {
    diff2 <- data.frame(diff)
    colnames(diff2) <- as.character(odie)
    xlsx::write.xlsx(diff2,"C:\\Users\\utente\\Documents\\PUN\\differences_true_predicted.xlsx", row.names = FALSE, col.names = TRUE)
  }
  
  
  ### second heuristic correction
  prevcorr <- read_excel(paste0("C:\\Users\\utente\\Documents\\prediction_PUN_",odie-1,".xlsx"))
  prev2corr <- unlist(prev[paste0("prediction_",as.character(odie))])
  diffcorr <- prev2corr - pun_oggi
  file2 <- "C:\\Users\\utente\\Documents\\PUN\\differences_true_predicted_corr.xlsx"
  if(file.exists(file2))
  {
    of2 <- read_excel(file2)
    of2 <- data.frame(of2)
    diff2corr <- data.frame(diffcorr)
    colnames(diff2corr) <- as.character(odie)
    of2 <- bind_cols(of2,diff2corr)
    xlsx::write.xlsx(of2,"C:\\Users\\utente\\Documents\\PUN\\differences_true_predicted_corr.xlsx", row.names = FALSE, col.names = TRUE)
  }
  else
  {
    diff2 <- data.frame(diffcorr)
    colnames(diff2corr) <- as.character(odie)
    xlsx::write.xlsx(diff2corr,"C:\\Users\\utente\\Documents\\PUN\\differences_true_predicted_corr.xlsx", row.names = FALSE, col.names = TRUE)
  }
  
  ycorrection <- diff
  
  if(bVerbose) ycorrection <- ycorrection + diffcorr
  
  return(ycorrection)
}
###################################################################################################
call_corrector_hourly <- function(pp_last, odie)
{
  
  hm <- rep(0, 24)
  
  for(i in 1:24)
  {
    ath <- unlist(pp_last[which(unlist(pp_last["Hour"]) == i),13])
    hm[i] <- mean(ath)
  }
  std_hm <- (hm - mean(hm))/sd(hm)
  
  return(std_hm)
}
###################################################################################################
Prediction <- function(date, bVerbose = FALSE)
{
  res <- restr <- matrix(0, nrow=24, ncol=15)
  ## load pun file
  pp <- read_excel("C:\\Users\\utente\\Documents\\PUN\\DB_Borse_Elettriche_PER MI.xlsx", sheet = "DB_Dati")

  meteonew <- build_meteo_new(date)
  pn <- build_new(pp)
  apm <- assemble_pm(pn, meteonew)
  xnew <- as.h2o(apm)
  
  odie <- as.Date(date)
  
  #### correction phase
  pp_last <- get_last_month(pp, odie)
  
  hm <- call_corrector_hourly(pp_last, odie)
  diff <- 0
  if(bVerbose)
  {
    diff <- call_corrector_yesterday_mean(pp_last, odie)
  } else 
  {
    diff <- call_corrector_mean(pp_last, odie)
  }
  
  ## call all models and make predictions
  for(da in 1:5)
  {
    for(step in 1:24)
    {
      #print(paste("step:",step,"da:", da))
      dal <- da + (da-1)*2
      dam <- da + (da-1)*2 + 1
      dau <- da*3
      id <- paste0("sda",step,"_",da)
      model <- h2o.loadModel(paste0("C:\\Users\\utente\\Documents\\PUN\\fixed\\models\\",id))
      x <- predict(model,xnew[da,])
      x2 <- as.numeric(x$predict)
      x3 <- as.matrix(x2)
      x4 <- unlist(x3[,1])
      yhat <- 0

      if(bVerbose) 
      {
        yhat <- x4 - diff[step] + hm[step] 
      }
      else
      {
        yhat <- x4 + hm[step]
      }
      
      res[step,dam] <- yhat
      restr[step, da] <- x4
      h2o.rm(model)
      bc <- bootstrap_f_r(yhat,step,da)
      res[step,dal] <- bc[1]
      res[step,dau] <- bc[2]
    }
  }
  
  if(!bVerbose)
  {
    for(j in 1:ncol(res))
    {
      res[,j] <- res[,j] - (mean(res[,j]) - diff)
    }
  }
  
  res <- data.frame(res)
  rownames(res) <- 1:24
  restr <- data.frame(restr)
  rownames(restr) <- 1:24  
  names <- c()
  for(n in 1:5)
  {
    names <- c(names,paste0(c("L_", "prediction_", "U_"),as.character(odie+n)))
  }
  colnames(res) <- names
  colnames(restr) <- names
  xlsx::write.xlsx(restr,paste0("prediction_PUN_not_corrected_",date,".xlsx"), row.names = FALSE, col.names = TRUE)
  return(res)
  
}
###################################################################################################
get_Prediction <- function(date, bVerbose)
{
  
  if( convert_day(lubridate::wday(as.Date(date),label=TRUE)) == "lun" )
  {
    ### prediction for Saturday and Sunday
    mdate <- c(as.Date(date)-2,as.Date(date)-1, as.Date(date))
    print(mdate)
    print(typeof(mdate))
    for(md in mdate)
    {
      print(md); print(typeof(md))
      res <- Prediction(as.Date(md, origin = "1899-12-30"), bVerbose)
      xlsx::write.xlsx(res,paste0("_prediction_PUN_",md,".xlsx"), row.names = FALSE, col.names = TRUE)
    }
  } else
  {
    ### normal weekday prediction
    res <- Prediction(as.Date(date, origin = "1899-12-30"), bVerbose)
    xlsx::write.xlsx(res,paste0("_prediction_PUN_",date,".xlsx"), row.names = FALSE, col.names = TRUE)
  }
  
  return(res)
}