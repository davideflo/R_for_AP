### better functions for PUN PREDICTION IN ACTION (PPIA)

library(readxl)
library(lubridate)
library(birk)
library(data.table)
library(mailR)

#source("R_code/send_mail_server.R")
source("R_code/functions_for_PUN_server.R")

#### lubridate vignette: https://cran.r-project.org/web/packages/lubridate/vignettes/lubridate.html
###########################################
mean_up_to_now <- function(pun, date)
{
  dd <- unlist(strsplit(date,"/"))
  asdd <- as.Date(paste0(dd[3],"-",dd[2],"-",dd[1]))
  dp <- dates2(dates(unlist(pun[,1])))
  ix <- which(dp < asdd)
  
  mm <- mean(unlist(pun[ix,"PUN"]))
  if(is.nan(mm)){
    mm <- 0
  }
  return(mm)
}
###########################################
yesterday_mean <- function(pun, date)
{
  dd <- unlist(strsplit(date,"/"))
  asdd <- as.Date(paste0(dd[3],"-",dd[2],"-",dd[1]))
  dp <- dates2(dates(unlist(pun[,1])))
  ix <- which(dp == (asdd-1))
  mm <- mean(unlist(pun[ix,"PUN"]))
  if(is.nan(mm))
  {
    mm <- 0
  }
  return(mm)
}
###########################################
create_rolling_dataset <- function(pun, first_day, varn, meteo, step, day_ahead, hb)
{
  ## ALGORITMO ROLLING
  ## step starts from 0, in which case the model predicts the hour after the predictors provided 
  ## and goes to 24, which is the same hour the day after
  ## hb (=hours_back) is how many hours I'm going back to build the training set
  ## day_ahead is how many ahead I'm going to predict
  d_f <- data_frame()
  Names <- c(paste0(varn,"-",hb:1), paste0("aust-",hb:1), paste0("cors-",hb:1), paste0("fran-",hb:1), paste0("grec-",hb:1),
             paste0("slov-",hb:1), paste0("sviz-",hb:1), paste0("angleday-",hb:1), paste0("holiday-",hb:1),
             paste0("angleora-",hb:1),
             paste0("tmin-",hb:1), paste0("tmax-",hb:1), paste0("tmed-",hb:1), paste0("rain-",hb:1), paste0("vento-",hb:1),
             "y","target_ora", "target_day", "target_holiday","target_tmin","target_tmax","target_tmed","target_pioggia","target_vento",
             paste0("day-",hb:1))
  
  hbb <- hb - 1
  da <- 24*day_ahead
  for(i in 1:(nrow(pun)-(hb+step+da)))
  {
    #print(da+i+hb+step)
    y <- p <- aus <- cors <- fran <- grec <- slov <- sviz <- ora <- dat <- c()
    for(j in i:(i+hbb))
    {
      p <- c(p, pun[j,varn]); aus <- c(aus, pun[j,"AUST"]); cors <- c(cors, pun[j,"CORS"])
      fran <- c(fran, pun[j,"FRAN"]); grec <- c(grec, pun[j,"GREC"]); slov <- c(slov, pun[j,"SLOV"])
      sviz <- c(sviz, pun[j,"SVIZ"]); ora <- c(ora, pun[j,2]); dat <- c(dat, pun[j,1]) 
    }
    
    ds <- dates(dat)
    #dt <- as.Date(ds[length(ds)])
    
    #target values and dates
    y <- c(y, pun[(da+i+hb+step),varn])
    new_hour <- pun[(da+i+hb+step),2]
    new_date <- dates(pun[(da+i+hb+step),1])
    thol <- add_holidays(new_date)
    dd3 <- unlist(strsplit(new_date,"/"))
    #print(paste0(dd3[3],"-",dd3[2],"-",dd3[1]))
    asdd <- as.Date(paste0(dd3[3],"-",dd3[2],"-",dd3[1]))
    tday <- convert_day_to_angle(convert_day(as.character(lubridate::wday(as.Date(asdd),label=TRUE))))
    thour <- convert_hour_to_angle(new_hour)
    
    ## target meteo
    ttmin <- associate_meteo_ora(new_date, meteo, "Tmin")
    ttmax <- associate_meteo_ora(new_date, meteo, "Tmax")
    ttmed <- associate_meteo_ora(new_date, meteo, "Tmedia")
    train <- associate_meteo_ora(new_date, meteo, "Pioggia")
    tvm <- associate_meteo_ora(new_date, meteo, "Vento_media")
    
    day <- unlist(ifelse(nrow(d_f) > 0, d_f[nrow(d_f),ncol(d_f)], first_day))
    #print(day)
    
    hol <- add_holidays(ds)
    vdays <- associate_days(ora, day)
    vdays2 <- maply(1:length(vdays), function(n) as.character(vdays[n]))
    aday <- maply(1:length(vdays2), function(n) convert_day_to_angle(vdays2[n]))
    ahour <- convert_hour_to_angle(ora)
    
    ## togli vdays e metti variabili meteo
    tmin <- associate_meteo_ora(ds, meteo, "Tmin")
    tmax <- associate_meteo_ora(ds, meteo, "Tmax")
    tmed <- associate_meteo_ora(ds, meteo, "Tmedia")
    rain <- associate_meteo_ora(ds, meteo, "Pioggia")
    vm <- associate_meteo_ora(ds, meteo, "Vento_media")
    
    ### transpose the vectors as they are column vectors in R
    adf <- data.frame(t(p), t(aus), t(cors), t(fran), t(grec), t(slov), t(sviz), t(aday[1:23]), t(hol[1:23]), t(ahour[1:23]),
                      t(tmin[1:hb]), t(tmax[1:hb]), t(tmed[1:hb]), t(rain[1:hb]), t(vm[1:hb]), y, thour, tday, thol, ttmin, ttmax, ttmed, train, tvm,
                      t(vdays[1:hb]), stringsAsFactors = FALSE)
    colnames(adf) <- Names
    
    d_f <- bind_rows(d_f, adf)
    #l <- list(d_f,adf)
    #d_f <- rbindlist(l, use.names = TRUE)
  }
  colnames(d_f) <- Names
  return(d_f[,1:354])
}
#######################################################
create_fixed_dataset <- function(pun, first_day, varn, meteo, step, day_ahead)
{
  ## ALGORITMO "FIXED"  
  # here step is the target hour to forecast
  # in particular, here step and day_ahead start from 1
  d_f <- data_frame()
  
  Names <- c(paste0(varn,"-",24:1), paste0("aust-",24:1), paste0("cors-",24:1), paste0("fran-",24:1), paste0("grec-",24:1),
             paste0("slov-",24:1), paste0("sviz-",24:1), "angleday", "holiday",
             paste0("angleora-",24:1),
             "tmin","tmax","tmed","pioggia","vento",
             "y","target_ora", "target_day", "target_holiday","target_tmin","target_tmax","target_tmed","target_pioggia","target_vento",
             "day")
  
  corr <- step + day_ahead*24
  
  well_dates <- dates(unlist(pun[,1]))
  dat <- c()
  
  day <- first_day
  
  for(i in 1:(nrow(pun)-corr))
  {
    #print(paste("i: ",i))
    y <- p <- aus <- cors <- fran <- grec <- slov <- sviz <- ora <- hol <- c()
    tmin <- tmax <- tmed <- rain <- vm <- c()
    ttmin <- ttmax <- ttmed <- train <- tvm <- thol <- tday <- c()
    
    dd <- pun[i,1]
    dd2 <- dates(dd)
    at_date <- pun[which(unlist(pun[,1]) == unlist(dd)),]
    
    if(!(dd2 %in% dat))
    {
      #print("preso")
      dat <- c(dat, dd2) 
      p <- at_date[varn] 
      aus <- at_date["AUST"] 
      cors <- at_date["CORS"]
      fran <- at_date["FRAN"] 
      grec <- at_date["GREC"] 
      slov <- at_date["SLOV"]
      sviz <- at_date["SVIZ"] 
      ora <- at_date[,2]
      
      if( nrow(at_date) == 23)
      {
        p <- c(unlist(p), unlist(p)[23] - 5.96 ) 
        aus <- c(unlist(aus), unlist(aus)[23] - 5.96) 
        cors <- c(unlist(cors), unlist(cors)[23] - 5.96)
        fran <- c(unlist(fran), unlist(fran)[23] - 5.96) 
        grec <- c(unlist(grec), unlist(grec)[23] - 5.96) 
        slov <- c(unlist(slov), unlist(slov)[23] - 5.96)
        sviz <- c(unlist(sviz), unlist(sviz)[23] - 5.96) 
        ora <- c(unlist(ora), 24)
      }
      
      else if( nrow(at_date) == 25)
      {
        p <- unlist(p)[1:24]
        aus <- unlist(aus)[1:24] 
        cors <- unlist(cors)[1:24]
        fran <- unlist(fran)[1:24]
        grec <- unlist(grec)[1:24]
        slov <- unlist(slov)[1:24]
        sviz <- unlist(sviz)[1:24]
        ora <- unlist(ora)[1:24]
      }
      #day <- unlist(ifelse(nrow(d_f) > 0, d_f[nrow(d_f),ncol(d_f)], first_day))
      #print(paste("day qui:", day))
      #vdays <- associate_days(ora, day)
      #vdays2 <- maply(1:length(vdays), function(n) as.character(vdays[n]))
      #aday <- maply(1:length(vdays2), function(n) convert_day_to_angle(vdays2[n]))
      #aday <- convert_day_to_angle(as.character(vdays[hb]))
      ahour <- convert_hour_to_angle(ora)
      
      if(i > 1) day <- subsequent_day(day)
      
      aday <- convert_day_to_angle(as.character(day))
      hol <- add_holidays(dd2)
      
      tmin <- associate_meteo_ora(dd2, meteo, "Tmin")
      tmax <- associate_meteo_ora(dd2, meteo, "Tmax")
      tmed <- associate_meteo_ora(dd2, meteo, "Tmedia")
      rain <- associate_meteo_ora(dd2, meteo, "Pioggia")
      vm <- associate_meteo_ora(dd2, meteo, "Vento_media")
      
      dd3 <- unlist(strsplit(dd2,"/"))
      asdd <- as.Date(paste0(dd3[3],"/",dd3[2],"/",dd3[1]))
      target_da <- asdd + day_ahead
      tda <- unlist(strsplit(as.character(target_da),"-"))
      target_data <- paste0(tda[3],"/",tda[2],"/",tda[1])
      
      tr <- which(well_dates %in% target_data)
      #print(tr)
      target_pun <- pun[tr,]
      #print(target_pun[,1])
      tdts <- dates(unlist(target_pun[,1]))
      #print(target_data)
      if(all(tdts==target_data) & length(tr) == 24)
      {
        y <- target_pun[which(target_pun[,2] == step),varn]
        ttmin <- associate_meteo_ora(target_data, meteo, "Tmin")
        ttmax <- associate_meteo_ora(target_data, meteo, "Tmax")
        ttmed <- associate_meteo_ora(target_data, meteo, "Tmedia")
        train <- associate_meteo_ora(target_data, meteo, "Pioggia")
        tvm <- associate_meteo_ora(target_data, meteo, "Vento_media")
        thol <- add_holidays(target_data)
        #print(day)
        tday <- convert_day_to_angle(compute_day_at(day, day_ahead))
      }
      
      else if(all(tdts==target_data) & length(tr) == 23) ### if I'm here, I'm trying to predict some hour on the ending day of daylight saving
      {
        th <- step
        if(th == 24) th <- 23
        y <- target_pun[which(target_pun[,2] == th),varn] - 5.96
        ttmin <- associate_meteo_ora(target_data, meteo, "Tmin")
        ttmax <- associate_meteo_ora(target_data, meteo, "Tmax")
        ttmed <- associate_meteo_ora(target_data, meteo, "Tmedia")
        train <- associate_meteo_ora(target_data, meteo, "Pioggia")
        tvm <- associate_meteo_ora(target_data, meteo, "Vento_media")
        thol <- add_holidays(target_data)
        #print(day)
        tday <- convert_day_to_angle(compute_day_at(day, day_ahead))
      }
      
      else if(all(tdts==target_data) & length(tr) == 25) ### if I'm here, I'm trying to predict some hour on the starting day of daylight saving
      {
       
        y <- target_pun[which(target_pun[,2] == step),varn]
        ttmin <- associate_meteo_ora(target_data, meteo, "Tmin")
        ttmax <- associate_meteo_ora(target_data, meteo, "Tmax")
        ttmed <- associate_meteo_ora(target_data, meteo, "Tmedia")
        train <- associate_meteo_ora(target_data, meteo, "Pioggia")
        tvm <- associate_meteo_ora(target_data, meteo, "Vento_media")
        thol <- add_holidays(target_data)
        #print(day)
        tday <- convert_day_to_angle(compute_day_at(day, day_ahead))
      }
      
      else
      {
        print("ERROR: target dates not found")
        break
      }
      df <- data.frame(t(p),t(aus),t(cors),t(fran),t(grec),t(slov),t(sviz),aday,hol,t(ahour),tmin,tmax,tmed,rain,vm,
                       y,convert_hour_to_angle(step+1),tday,thol,ttmin,ttmax,ttmed,train,tvm,as.character(day),stringsAsFactors = FALSE)

      colnames(df) <- Names
      
      #ll <- list(d_f,df)
      #d_f <- rbindlist(ll,use.names = TRUE)
      d_f <- bind_rows(d_f, df)
    }
    
  }
  return(d_f[,1:208])
}
############################################################
create_fixed_dataset_average <- function(pun, first_day, varn, meteo, day_ahead)
{
  ## ALGORITMO "FIXED" - AVERAGED - immediately predicts average price of next day  
  # day_ahead starts from 1
  d_f <- data_frame()
  
  Names <- c(paste0(varn,"-",24:1), paste0("aust-",24:1), paste0("cors-",24:1), paste0("fran-",24:1), paste0("grec-",24:1),
             paste0("slov-",24:1), paste0("sviz-",24:1), "mean_uptonow", "yesterday_mean","angleday", "holiday",
             "tmin","tmax","tmed","pioggia","vento",
             "y", "target_day", "target_holiday","target_tmin","target_tmax","target_tmed","target_pioggia","target_vento",
             "day")
  
  corr <- day_ahead*24
  
  well_dates <- dates(unlist(pun[,1]))
  dat <- c()
  
  day <- first_day
  
  for(i in 1:(nrow(pun)-corr))
  {
    #print(paste("i: ",i))
    y <- p <- aus <- cors <- fran <- grec <- slov <- sviz <- ora <- hol <- c()
    tmin <- tmax <- tmed <- rain <- vm <- c()
    ttmin <- ttmax <- ttmed <- train <- tvm <- thol <- tday <- c()
    mutn <- ym <- 0
    
    dd <- pun[i,1]
    dd2 <- dates(dd)
    at_date <- pun[which(unlist(pun[,1]) == unlist(dd)),]
    
    if(!(dd2 %in% dat))
    {
      dat <- c(dat, dd2) 
      p <- at_date[varn] 
      aus <- at_date["AUST"] 
      cors <- at_date["CORS"]
      fran <- at_date["FRAN"] 
      grec <- at_date["GREC"] 
      slov <- at_date["SLOV"]
      sviz <- at_date["SVIZ"] 
      ora <- at_date[,2]
      mutn <- mean_up_to_now(pun, dd2)
      ym <- yesterday_mean(pun, dd2)
      
      if( nrow(at_date) == 23)
      {
        p <- c(unlist(p), unlist(p)[23] - 5.96 ) ### 5.96 is the mean difference between the 24th and the first hour of the day
        aus <- c(unlist(aus), unlist(aus)[23] - 5.96) 
        cors <- c(unlist(cors), unlist(cors)[23] - 5.96)
        fran <- c(unlist(fran), unlist(fran)[23] - 5.96) 
        grec <- c(unlist(grec), unlist(grec)[23] - 5.96) 
        slov <- c(unlist(slov), unlist(slov)[23] - 5.96)
        sviz <- c(unlist(sviz), unlist(sviz)[23] - 5.96) 
        ora <- c(unlist(ora), 24)
      }
      
      else if( nrow(at_date) == 25)
      {
        p <- unlist(p)[1:24]
        aus <- unlist(aus)[1:24] 
        cors <- unlist(cors)[1:24]
        fran <- unlist(fran)[1:24]
        grec <- unlist(grec)[1:24]
        slov <- unlist(slov)[1:24]
        sviz <- unlist(sviz)[1:24]
        ora <- unlist(ora)[1:24]
      }
      
      if(i > 1) day <- subsequent_day(day)
      
      aday <- convert_day_to_angle(as.character(day))
      hol <- add_holidays(dd2)
      
      tmin <- associate_meteo_ora(dd2, meteo, "Tmin")
      tmax <- associate_meteo_ora(dd2, meteo, "Tmax")
      tmed <- associate_meteo_ora(dd2, meteo, "Tmedia")
      rain <- associate_meteo_ora(dd2, meteo, "Pioggia")
      vm <- associate_meteo_ora(dd2, meteo, "Vento_media")
      
      dd3 <- unlist(strsplit(dd2,"/"))
      asdd <- as.Date(paste0(dd3[3],"/",dd3[2],"/",dd3[1]))
      target_da <- asdd + day_ahead
      tda <- unlist(strsplit(as.character(target_da),"-"))
      target_data <- paste0(tda[3],"/",tda[2],"/",tda[1])
      
      tr <- which(well_dates %in% target_data)
      
      target_pun <- pun[tr,]
      
      tdts <- dates(unlist(target_pun[,1]))
      
      y <- mean(unlist(target_pun[,varn]))
      ttmin <- associate_meteo_ora(target_data, meteo, "Tmin")
      ttmax <- associate_meteo_ora(target_data, meteo, "Tmax")
      ttmed <- associate_meteo_ora(target_data, meteo, "Tmedia")
      train <- associate_meteo_ora(target_data, meteo, "Pioggia")
      tvm <- associate_meteo_ora(target_data, meteo, "Vento_media")
      thol <- add_holidays(target_data)
        
      tday <- convert_day_to_angle(convert_day(lubridate::wday(target_da, label = TRUE)))
      
      if(hol > 0) {hol <- 1}
      if(thol > 0) {thol <- 1}
      
      df <- data.frame(t(p),t(aus),t(cors),t(fran),t(grec),t(slov),t(sviz),mutn,ym,aday,hol,tmin,tmax,tmed,rain,vm,
                       y,tday,thol,ttmin,ttmax,ttmed,train,tvm,as.character(day),stringsAsFactors = FALSE)
      
      colnames(df) <- Names
      
      d_f <- bind_rows(d_f, df)
    }
    
  }
  return(data.frame(d_f[,1:185]))
}
############################################################
bootstrap_f_r <- function(yhat, step, day_ahead, B = 100)
{
  ## remember: step coincides with the hour to predict
  start <- Sys.Date() - 31
  db <- read_excel("C:\\Users\\utente\\Documents\\PUN\\DB_Borse_Elettriche_PER MI.xlsx", sheet = "DB_Dati")
  utc <- as.Date(db$Date)
  use <- db[which(utc >= start & utc <= (Sys.Date()-1)),]
  gh <- unlist(use[which(use["Hour"] == step),13])
  vdiff <- maply(1:B, function(n) mean(maply(1:10, function(h) sample(gh, size = 1, replace = TRUE))) - yhat) #### VERY STRONG HYPOTHESIS ###
  return(c(yhat+quantile(vdiff,probs=0.025, na.rm = TRUE), yhat-quantile(vdiff,probs=0.975, na.rm = TRUE)))
}
######################################################################
treat_meteo2016 <- function(met)
{
  cols <- which(tolower(colnames(met)) %in% c("data", "tmin","tmax","tmedia","pioggia","vento_media"))
  met2 <- met[,cols]
  colnames(met2) <- c("Data", "Tmin","Tmax","Tmedia","Pioggia","Vento_media")
  return(met2)
}
######################################################################
bind_meteos <- function(meteo1, meteo2)
{
  cn1 <- colnames(meteo1)
  cn2 <- colnames(meteo2)
  common <- intersect(cn1, cn2)
  
  met <- rbind(meteo1[,which(cn1 %in% common)],meteo1[,which(cn2 %in% common)])
  return(met)
}
######################################################################
generate_rolling_dataset <- function(data1,data2,meteo1,meteo2)
{
  gc()
  meteolong <- bind_rows(meteo1,meteo2)
  count <- 0
  for(da in 0:5)
  {
    for(step in 0:23)
    {
      tryCatch(
      {
        start <- Sys.time()
        aug <- augmented_dataset(data1, data2, step = step , day_ahead = da)
        trainset <- create_rolling_dataset(data1, "ven", "PUN",meteolong,step,da,23)
        testset <- create_rolling_dataset(data2, "ven", "PUN",meteo2,step,da,23)
        
        trainseth2o <- as.h2o(trainset)
        testseth2o <- as.h2o(testset)
        
        name1 <- paste0("C:\\Users\\utente\\Documents\\PUN\\rolling\\trainset_step_",step,"_dayahead_",da,".csv")
        name2 <- paste0("C:\\Users\\utente\\Documents\\PUN\\rolling\\testset_step_",step,"_dayahead_",da,".csv")  
        
        h2o.exportFile(trainseth2o, name1)
        h2o.exportFile(testseth2o, name2)
        
        rm(trainset); rm(trainseth2o); rm(testset); rm(testseth2o);
        print(paste("done step",step,"day ahead", da, "and removed the files"))
        
        end <- Sys.time()
        
        body <- paste("done step ", step, "and day_ahead", da, "with time = ", end-start)
        
        if(!file.exists("monitor_rolling.txt")) write.csv2(body, "monitor_rolling.txt")
        else write.csv2(body, "monitor_rolling.txt",append = TRUE)
        
        count <- count + 1
        print(paste0("passages left: ",24*6 - count))
      }, error = function(cond)
      {
        message(cond)
        print(paste("day ahead", da, "and step", step, "failed"))
      }
      )
    }
  }
}
##############################################################################
generate_fixed_dataset <- function(data1,data2,meteo1,meteo2)
{
  gc()
  meteolong <- bind_rows(meteo1,meteo2)
  #l <- list(meteo1,meteo2)
  #meteolong <- rbindlist(l, use.names = TRUE)
  count <- 0
  for(da in 1:5)
  {
    for(step in 1:24)
    {
      tryCatch(
        {
          start <- Sys.time()
          aug <- augmented_dataset(data1, data2, step = step , day_ahead = da)
          trainset <- create_fixed_dataset(data1, "ven", "PUN",meteolong,step,da)
          testset <- create_fixed_dataset(data2, "ven", "PUN",meteo2,step,da)
          
          trainseth2o <- as.h2o(trainset)
          testseth2o <- as.h2o(testset)
          
          name1 <- paste0("C:\\Users\\utente\\Documents\\PUN\\fixed\\trainset_step_",step,"_dayahead_",da,".csv")
          name2 <- paste0("C:\\Users\\utente\\Documents\\PUN\\fixed\\testset_step_",step,"_dayahead_",da,".csv")  
          
          h2o.exportFile(trainseth2o, name1)
          h2o.exportFile(testseth2o, name2)
          
          rm(trainset); rm(trainseth2o); rm(testset); rm(testseth2o);
          print(paste("done step",step,"day ahead", da, "and removed the files"))
          
          end <- Sys.time()
          end-start
          
          body <- paste("done step ", step, "and day_ahead", da, "with time = ", end-start)
          
          if(!file.exists("monitor_fixed.txt")) write.csv2(body, "monitor_fixed.txt")
          else write.csv2(body, "monitor_fixed.txt",append = TRUE)
          
          count <- count + 1
          print(paste0("passages left: ",24*5 - count))
        }, error = function(cond)
        {
          message(cond)
          print(paste("day ahead", da, "and step", step, "failed"))
        }
      )
    }
  }
}
##############################################################################
generate_fixed_dataset_2016 <- function(data,meteo)
{
  gc()
  count <- 0
  for(da in 1:5)
  {
    for(step in 1:24)
    {
      tryCatch(
        {
          start <- Sys.time()
          Trainset <- create_fixed_dataset(data, "ven", "PUN",meteo,step,da)
          
          strain <- sample.int(nrow(Trainset), ceiling(0.8*nrow(Trainset))) 
          stest <- setdiff(1:nrow(Trainset), strain)
          stest <- sample(stest)
          
          trainset <- Trainset[strain,]
          testset <- Trainset[stest,]
          
          
          trainseth2o <- as.h2o(trainset)
          testseth2o <- as.h2o(testset)
          
          name1 <- paste0("C:\\Users\\utente\\Documents\\PUN\\fixed\\2016\\trainset_step_",step,"_dayahead_",da,".csv")
          name2 <- paste0("C:\\Users\\utente\\Documents\\PUN\\fixed\\2016\\testset_step_",step,"_dayahead_",da,".csv")  
          
          h2o.exportFile(trainseth2o, name1)
          h2o.exportFile(testseth2o, name2)
          
          rm(trainset); rm(trainseth2o); rm(testset); rm(testseth2o);
          print(paste("done step",step,"day ahead", da, "and removed the files"))
          
          end <- Sys.time()
          end-start
          
          body <- paste("done step ", step, "and day_ahead", da, "with time = ", end-start)
          
          if(!file.exists("monitor_fixed.txt")) write.csv2(body, "monitor_fixed.txt")
          else write.csv2(body, "monitor_fixed.txt",append = TRUE)
          
          count <- count + 1
          print(paste0("passages left: ",24*5 - count))
        }, error = function(cond)
        {
          message(cond)
          print(paste("day ahead", da, "and step", step, "failed"))
        }
      )
    }
  }
}
#######################################################
to_dates <- function(vd)
{
  vec <- unlist(as.character(vd))
  dt <- maply(1:length(vec), function(i) paste0(stri_sub(vec[i],from = 1,to = 4),"-",stri_sub(vec[i],from = 5,to = 6),"-",stri_sub(vec[i],from = 7,to = 8)))
  return(dt)
}
########################################################
mode <- function(v) 
{
  uniqv <- unique(v)
  uniqv[which.max(tabulate(match(v, uniqv)))]
}
########################################################
find_next_monday <- function(day)
{
  nm <- 0
  for(n in 1:7)
  {
    if( convert_day(as.character(lubridate::wday(day+n, label = TRUE))) == "lun" )
    {
      nm <- day + n
    }
  }
  return(nm)
}
########################################################
create_fixed_dataset_week <- function(pun, varn, meteo)
{
  ## ALGORITMO "FIXED" a week in advance  
  # here step is the target hour to forecast
  # in particular, here step and day_ahead start from 1
  d_f <- data_frame()
  
  Names <- c(paste0(varn,"-",7:1), paste0("aust-",7:1), paste0("cors-",7:1), paste0("fran-",7:1), paste0("grec-",7:1),
             paste0("slov-",7:1), paste0("sviz-",7:1), "holiday", "mese",
             paste0("tmin-",7:1),paste0("tmax-",7:1),paste0("tmed-",7:1),paste0("pioggia-",7:1),paste0("vento-",7:1),
             "y", "target_holiday","target_mese","target_tmin","target_tmax","target_tmed","target_pioggia","target_vento")
  
  step <- 0
  day_ahead <- 7
  
  corr <- step + day_ahead * 24
  
  well_dates <- as.Date(to_dates(unlist(pun[,1])))
  
  dats <- unique(well_dates)
  dats <- dats[8:length(dats)]
  
  ix <- which(dats == find_next_monday(dats[1]))
  
  week_to_predict <- find_next_monday(dats[1] + 7) #### must be the first monday after dats[1] + 7
  start <- week_to_predict
  end <- start + 6
  
  for(d in dats[ix:length(dats)] )
  {
    d <- as.Date(d, origin = '1970-01-01')
    
    print(d)
     
    y <- p <- aus <- cors <- fran <- grec <- slov <- sviz <- c()
    tmin <- tmax <- tmed <- rain <- vm <- c()
    ttmin <- ttmax <- ttmed <- train <- tvm <- c()

    hol <- thol <- 0
    
    if(d < dats[length(dats)]-6)
    {
      
      
      if( convert_day((as.character(lubridate::wday(d, label = TRUE)))) == "lun" & convert_day((as.character(lubridate::wday(d-6, label = TRUE)))) == "mar")
      {
        week_to_predict <- d + 7
        start <- week_to_predict
        end <- start + 6
      }
      
      p <- maply(0:6, function(n) mean(unlist(pun[which(well_dates == d-n),"PUN"])))
      aus <- maply(0:6, function(n) mean(unlist(pun[which(well_dates == d-n),"AUST"])))
      cors <- maply(0:6, function(n) mean(unlist(pun[which(well_dates == d-n),"CORS"])))
      fran <- maply(0:6, function(n) mean(unlist(pun[which(well_dates == d-n),"FRAN"])))
      grec <- maply(0:6, function(n) mean(unlist(pun[which(well_dates == d-n),"GREC"])))
      slov <- maply(0:6, function(n) mean(unlist(pun[which(well_dates == d-n),"SLOV"])))
      sviz <- maply(0:6, function(n) mean(unlist(pun[which(well_dates == d-n),"SVIZ"])))
      
      y <- mean(unlist(pun[which(well_dates >= start & well_dates <= end),"PUN"]))

      mese <- mode(maply(0:6, function(n) month(d-n)))      
      tmese <- mode(maply(0:6, function(n) month(week_to_predict+n)))
      
      for(j in 0:6)
      {
        tda <- unlist(strsplit(as.character(d-j),"-"))
        tdata <- paste0(tda[3],"/",tda[2],"/",tda[1])
        
        tmin <- c(tmin, associate_meteo_ora(tdata, meteo, "Tmin"))
        tmax <- c(tmax, associate_meteo_ora(tdata, meteo, "Tmax"))
        tmed <- c(tmed, associate_meteo_ora(tdata, meteo, "Tmedia"))
        rain <- c(rain, associate_meteo_ora(tdata, meteo, "Pioggia"))
        vm <- c(vm, associate_meteo_ora(tdata, meteo, "Vento_media"))
        
        hol <- hol + add_holidays(tdata)
        
        twtp <- unlist(strsplit(as.character(week_to_predict+j),"-"))
        tdata2 <- paste0(twtp[3],"/",twtp[2],"/",twtp[1])
        
        ttmin <- c(ttmin, associate_meteo_ora(tdata2, meteo, "Tmin"))
        ttmax <- c(ttmax, associate_meteo_ora(tdata2, meteo, "Tmax"))
        ttmed <- c(ttmed, associate_meteo_ora(tdata2, meteo, "Tmedia"))
        train <- c(train, associate_meteo_ora(tdata2, meteo, "Pioggia"))
        tvm <- c(tvm, associate_meteo_ora(tdata2, meteo, "Vento_media"))
        
        thol <- thol + add_holidays(tdata2)
      }

      df <- data.frame(t(p),t(aus),t(cors),t(fran),t(grec),t(slov),t(sviz),hol,mese,t(tmin),t(tmax),t(tmed),t(rain),t(vm),
                       y,thol,tmese,mean(ttmin),mean(ttmax),mean(ttmed),mean(train),mean(tvm),stringsAsFactors = FALSE)
      
      
      colnames(df) <- Names
      
      d_f <- bind_rows(d_f, df)
      
    }
    #print(paste("i: ",i)

  }

  return(d_f)
}
##########################################################################
generate_fixed_dataset_average <- function(data1,data2,meteo1,meteo2)
{
  gc()
  meteolong <- bind_rows(meteo1,meteo2)
  count <- 0
  for(da in 1:5)
  {
    tryCatch(
      {
        start <- Sys.time()
        aug <- augmented_dataset(data1, data2, step = 0 , day_ahead = da)
        trainset <- create_fixed_dataset_average(aug, "gio", "PUN",meteolong,da)
        from <- nrow(trainset) - floor(0.2*nrow(trainset))
        testset <- trainset[from:nrow(trainset),]
        trainset <- trainset[1:(from-1),]
          
        trainseth2o <- as.h2o(trainset)
        testseth2o <- as.h2o(testset)
          
        name1 <- paste0("C:\\Users\\utente\\Documents\\PUN\\fixed\\2016\\AVtrainset_dayahead_",da,".csv")
        name2 <- paste0("C:\\Users\\utente\\Documents\\PUN\\fixed\\2016\\AVtestset_dayahead_",da,".csv")  
          
        h2o.exportFile(trainseth2o, name1)
        h2o.exportFile(testseth2o, name2)
          
        rm(trainset); rm(trainseth2o); rm(testset); rm(testseth2o);
        print(paste("done day ahead", da, "and removed the files"))
          
        end <- Sys.time()
        end-start
          
        body <- paste("done day_ahead", da, "with time = ", end-start)
          
        if(!file.exists("monitor_fixed.txt")) write.csv2(body, "monitor_fixed.txt")
        else write.csv2(body, "monitor_fixed.txt",append = TRUE)
          
        count <- count + 1
        print(paste0("passages left: ",5 - count))
      }, error = function(cond)
      {
        message(cond)
        print(paste("day ahead", da, "failed"))
      }
    )
  }
}
##########################################################################
generate_fixed_dataset_average_2016 <- function(data, meteo)
{
  gc()
  count <- 0
  for(da in 1:5)
  {
    tryCatch(
      {
        start <- Sys.time()
        trainset <- create_fixed_dataset_average(data, "ven", "PUN",meteo,da)
        
        sam <- sample.int(nrow(trainset), size = ceiling(0.8*nrow(trainset)))
        
        testset <- trainset[setdiff(1:nrow(trainset),sam),]
        trainset <- trainset[sam,]
        
        trainseth2o <- as.h2o(trainset)
        testseth2o <- as.h2o(testset)
        
        name1 <- paste0("C:\\Users\\utente\\Documents\\PUN\\fixed\\2016\\AVtrainset_dayahead_",da,".csv")
        name2 <- paste0("C:\\Users\\utente\\Documents\\PUN\\fixed\\2016\\AVtestset_dayahead_",da,".csv")  
        
        h2o.exportFile(trainseth2o, name1)
        h2o.exportFile(testseth2o, name2)
        
        rm(trainset); rm(trainseth2o); rm(testset); rm(testseth2o);
        print(paste("done day ahead", da, "and removed the files"))
        
        end <- Sys.time()
        end-start
        
        body <- paste("done day_ahead", da, "with time = ", end-start)
        
        if(!file.exists("monitor_fixed.txt")) write.csv2(body, "monitor_fixed.txt")
        else write.csv2(body, "monitor_fixed.txt",append = TRUE)
        
        count <- count + 1
        print(paste0("passages left: ",5 - count))
      }, error = function(cond)
      {
        message(cond)
        print(paste("day ahead", da, "failed"))
      }
    )
  }
}
##############################################################################


########################################################################################################
# tp2 <- read_excel("C:/Users/utente/Documents/PUN/Milano 2016.xlsx")
# > tp2[1,1]
# [1] "2016-07-31 23:59:59 UTC"
# > as.POSIXct(tp2[,1], format="%d/%m/%Y %H:%M:%S", tz="UCT")
# [1] "2016-07-31 23:59:59 UTC" "2016-08-01 00:59:59 UTC" "2016-08-01 01:59:59 UTC" "2016-08-01 02:59:59 UTC" "2016-08-01 03:59:59 UTC" "2016-08-01 04:59:59 UTC"
# [7] "2016-08-01 06:00:00 UTC" "2016-08-01 06:59:59 UTC" "2016-08-01 07:59:59 UTC" "2016-08-01 08:59:59 UTC" "2016-08-01 09:59:59 UTC" "2016-08-01 10:59:59 UTC"
# [13] "2016-08-01 11:59:59 UTC" "2016-08-01 12:59:59 UTC" "2016-08-01 13:59:59 UTC" "2016-08-01 14:59:59 UTC" "2016-08-01 15:59:59 UTC" "2016-08-01 16:59:59 UTC"
# [19] "2016-08-01 17:59:59 UTC" "2016-08-01 18:59:59 UTC" "2016-08-01 19:59:59 UTC" "2016-08-01 20:59:59 UTC" "2016-08-01 21:59:59 UTC" "2016-08-01 22:59:59 UTC"
# [25] "2016-08-01 23:59:59 UTC" "2016-08-02 00:59:59 UTC" "2016-08-02 01:59:59 UTC" "2016-08-02 02:59:59 UTC" "2016-08-02 03:59:59 UTC" "2016-08-02 04:59:59 UTC"
# [31] "2016-08-02 05:59:59 UTC" "2016-08-02 06:59:59 UTC" "2016-08-02 07:59:59 UTC" "2016-08-02 08:59:59 UTC" "2016-08-02 09:59:59 UTC" "2016-08-02 10:59:59 UTC"
# [37] "2016-08-02 11:59:59 UTC" "2016-08-02 12:59:59 UTC" "2016-08-02 13:59:59 UTC" "2016-08-02 14:59:59 UTC" "2016-08-02 15:59:59 UTC" "2016-08-02 16:59:59 UTC"
# [43] "2016-08-02 17:59:59 UTC" "2016-08-02 18:59:59 UTC" "2016-08-02 19:59:59 UTC" "2016-08-02 20:59:59 UTC" "2016-08-02 21:59:59 UTC" "2016-08-02 22:59:59 UTC"
# > uct <- as.POSIXct(tp2[1,1], format="%d/%m/%Y %H:%M:%S", tz="UTC")
# > uct[1]
# [1] "2016-07-31 23:59:59 UTC"
# > typeof(uct[1])
# [1] "double"
# > as.character(uct[1])
# [1] "2016-07-31 23:59:59"
# > ad <- as.character(uct[1])
# > add <- unlist(strsplit(ad, " "))
# > add
# [1] "2016-07-31" "23:59:59"  
# > add[1]
# [1] "2016-07-31"
# > 


# d <- as.Date('2004-01-01')
# month(d) <- month(d) + 1
# day(d) <- days_in_month(d)
# d
# [1] "2004-02-29"
