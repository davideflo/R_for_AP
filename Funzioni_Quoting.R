##### FUNZIONI QUOTING #######

library(plyr)
library(dplyr)
library(readxl)
library(feather)
library(lubridate)
library(data.table)
library(xlsx)
library(WriteXLS)
#################################################################################
#################################################################################
Assembler2 <- function(real, ph)
{
  rows <- which(unlist(!is.na(real[,13])))
  real <- real[rows,]
  ### comparison step
  last_date <- as.Date(ph$date[max(which(ph$real == 1))])
  mld <- max(which(ph$real == 1))
  errors <- unlist(real[(mld+1):nrow(real),13]) - ph$pun[(mld+1):nrow(real)]
  r <- (mld+1):nrow(real)
  #write.xlsx(data.frame(ph[r,1:(ncol(ph)-2)],Errors = errors), "C:/Users/t_carrubba/Documents/forward_pun_model_error/errors.xlsx", row.names = FALSE, append = TRUE)
  ### assembling step
  re <- rep(0, nrow(ph))
  
  for(i in 1:length(rows))
  {
    ph[i, "pun"] <- unlist(real[rows[i],13])
    re[i] <- 1
  }
  ph <- data.frame(ph, real = re)
  return(ph)
}
#################################################################################
Redimensioner_pkop <- function(ph, mh, mw, from, to, what)
{
  #### @BRIEF: if what == PK => mw is referring to PK
  d_f <- data_frame()
  from <- as.Date(from)
  to <- as.Date(to)
  nOP <- nrow(ph[which(as.Date(ph$date) >= from & as.Date(ph$date) <= to & ph$`PK.OP` == "OP"),])
  nPK <- nrow(ph[which(as.Date(ph$date) >= from & as.Date(ph$date) <= to & ph$`PK.OP` == "PK"),])
  rOP <- which(as.Date(ph$date) >= from & as.Date(ph$date) <= to & ph$`PK.OP` == "OP")
  rPK <- which(as.Date(ph$date) >= from & as.Date(ph$date) <= to & (ph$`PK.OP` == "PK" | ph$`PK.OP` == "P"))
  M <- nOP + nPK
  
  periodpk <- ph[rPK,]
  periodop <- ph[rOP,]
  
  nPKr <- length(which(periodpk$real == 1))
  nOPr <- length(which(periodop$real == 1))
  
  if(what == "PK")  
  {
    opm <- (1/nOP)*((mh*M) - (mw*nPK))
    
    
    pbpk <- ifelse(length(periodpk$pun[periodpk$real == 1]) > 0, (1/nPK)*sum(periodpk$pun[periodpk$real == 1]), 0)
    pbop <- ifelse(length(periodop$pun[periodop$real == 1]) > 0, (1/nOP)*sum(periodop$pun[periodop$real == 1]), 0)
    pihatpk <- (mw - pbpk)/((1/nPK)*sum(periodpk$pun[periodpk$real == 0]))
    pihatop <- (opm - pbop)/((1/nOP)*sum(periodop$pun[periodop$real == 0]))
    for(i in 1:length(rPK))
    {
      if(ph[rPK[i], "real"] == 0) ph[rPK[i], "pun"] <- pihatpk * unlist(ph[rPK[i], "pun"])
    }
    for(i in 1:length(rOP))
    {
      if(ph[rOP[i], "real"] == 0) ph[rOP[i], "pun"] <- pihatop * unlist(ph[rOP[i], "pun"])
    }
  }
  else
  {
    pkm <- (1/nPK)*((mh*M) - (mw*nOP))
    
    pbpk <- ifelse(length(periodpk$pun[periodpk$real == 1]) > 0, (1/nPK)*sum(periodpk$pun[periodpk$real == 1]), 0)
    pbop <- ifelse(length(periodop$pun[periodop$real == 1]) > 0, (1/nOP)*sum(periodop$pun[periodop$real == 1]), 0)
    pihatpk <- (pkm - pbpk)/((1/nPK)*sum(periodpk$pun[periodpk$real == 0]))
    pihatop <- (mw - pbop)/((1/nOP)*sum(periodop$pun[periodop$real == 0]))
    
    for(i in 1:length(rPK))
    {
      ph[rPK[i], "pun"] <- pihatpk * unlist(ph[rPK[i], "pun"])
    }
    for(i in 1:length(rOP))
    {
      ph[rOP[i], "pun"] <- pihatop * unlist(ph[rOP[i], "pun"])
    }
  }
  
  return(ph)
}
#################################################################################
WeekRedimensioner <- function(ph, mh, from, to)
{
  #### @BRIEF: if what == PK => mw is referring to PK
  d_f <- data_frame()
  from <- as.Date(from)
  to <- as.Date(to)
  M <- nrow(ph[which(as.Date(ph$date) >= from & as.Date(ph$date) <= to),])
  rows <- which(as.Date(ph$date) >= from & as.Date(ph$date) <= to)
  
  
  period <- ph[rows,]
  
  pb <- ifelse(length(period$pun[period$real == 1]) > 0, (1/M)*sum(period$pun[periodpk$real == 1]), 0)
  
  pihat <- (mh - pb)/mean(period$pun[period$real == 0])
  
  for(i in 1:length(rows))
  {
    ph[rows[i], "pun"] <- pihat * unlist(ph[rows[i], "pun"])
  }
  
  
  return(ph)
}
###################################################################
AnalyzePeriod <- function(s, y1, y2)
  #### @PARAM: y1 and y2 are the two consecutive years of which we need to compute the quoting
{
  sy1 <- y1 - 2000
  sy2 <- y2 - 2000
  mesi <- c("Gennaio_", "Febbraio_", "Marzo_", "Aprile_", "Maggio_", "Giugno_", 
            "Luglio_", "Agosto_", "Settembre_", "Ottobre_", "Novembre_", "Dicembre_")
  
  mesi17 <- paste0(mesi, sy1)
  mesi18 <- paste0(mesi, sy2)
  
  splitted <- strsplit(s, "-")
  YEAR <- 0
  
  if(length(splitted[[1]]) > 1)
  {
    #### weeks
    split1 <- strsplit(splitted$Periodo[1], "/")
    split2 <- strsplit(splitted$Periodo[2], "/")
    from <- paste0(as.numeric(split1[[1]][1]),'-',as.numeric(split1[[1]][2]),'-',as.numeric(split1[[1]][3]))
    to <- paste0(as.numeric(split2[[1]][1]),'-',as.numeric(split2[[1]][2]),'-',as.numeric(split2[[1]][3]))
    YEAR <- as.numeric(split2[[1]][1])
  }
  else if(length(splitted[[1]]) == 1)
  {
    if(tolower(s) %in% tolower(mesi17))
    {
      YEAR <- y1
      mese <- ifelse(which(tolower(s) == tolower(mesi17)) < 10, paste0('0',which(tolower(s) == tolower(mesi17))), which(tolower(s) == tolower(mesi17)))
      from <- paste0(YEAR, '-', mese, '-01')
      to <- paste0(YEAR, '-', mese, '-', days_in_month(as.Date(from)))
    }
    else if(tolower(s) %in% tolower(mesi18))
    {
      YEAR <- y2
      mese <- ifelse(which(tolower(s) == tolower(mesi18)) < 10, paste0('0',which(tolower(s) == tolower(mesi18))), which(tolower(s) == tolower(mesi18)))
      from <- paste0(YEAR, '-', mese, '-01')
      to <- paste0(YEAR, '-', mese, '-', days_in_month(as.Date(from)))
    }
    else if(s == paste0('Q1_',sy1))
    {
      YEAR <- y1
      from <- paste0(YEAR,'-01-01')
      to <- paste0(YEAR,'-03-31')
    }
    else if(s == paste0('Q2_',sy1))
    {
      YEAR <- y1
      from <- paste0(YEAR,'-04-01')
      to <- paste0(YEAR,'-06-30')
    }
    else if(s == paste0('Q3_',sy1))
    {
      YEAR <- y1
      from <- paste0(YEAR,'-07-01')
      to <- paste0(YEAR,'-09-30')
    }
    else if(s == paste0('Q4_',sy1))
    {
      YEAR <- y1
      from <- paste0(YEAR,'-10-01')
      to <- paste0(YEAR,'-12-31')
    }
    else if(s == paste0('Q1_',sy2))
    {
      YEAR <- y2
      from <- paste0(YEAR,'-01-01')
      to <- paste0(YEAR,'-03-31')
    }
    else if(s == paste0('Q2_',sy2))
    {
      YEAR <- y2
      from <- paste0(YEAR,'-04-01')
      to <- paste0(YEAR,'-06-30')
    }
    else if(s == paste0('Q3_',sy2))
    {
      YEAR <- y2
      from <- paste0(YEAR,'-07-01')
      to <- paste0(YEAR,'-09-30')
    }
    else if(s == paste0('Q4_',sy2))
    {
      YEAR <- y2
      from <- paste0(YEAR,'-10-01')
      to <- paste0(YEAR,'-12-31')
    }
    else
    {### BSL annuale
      YEAR <- y2
      from <- paste0(YEAR, '-01-01')
      to <- paste0(YEAR, '-12-31')
    }
  }
  return(list(from = from, to = to))
}
###################################################################
EstraiAnno <- function(ft)
{
  splitted <- strsplit(ft, "-")
  return(as.numeric(splitted[[1]][1]))
}
###################################################################
GetQ <- function(m)
{
  if(m <= 3) return("Q1")
  else if(m > 3 & m <= 6) return("Q2")
  else if(m > 6 & m <= 9) return("Q3")
  else return("Q4")
}
###################################################################
MissingValues1 <- function(d_f, DF, Q, Qnm, sy)
{
  ### @BRIEF: function to compute missing BSL and PK when all the three months in a Q are present and it's the first month
  
  ind2 <- which(d_f$period == paste0(Q[2],"_",sy))
  ind3 <- which(d_f$period == paste0(Q[3],"_",sy))
  start2 <- paste0("20",sy,"-",Qnm[2], "-01")
  end2 <- paste0("20",sy,"-",Qnm[2], "-", lubridate::days_in_month(as.Date(start2, origin = "1899-12-30")))
  start3 <- paste0("20",sy,"-",Qnm[3], "-01")
  end3 <- paste0("20",sy,"-",Qnm[3], "-", lubridate::days_in_month(as.Date(start3, origin = "1899-12-30")))
  d.f2 <- data.frame(inizio = start2, fine = end2, BSL = d_f$BSL[ind2], PK = d_f$PK[ind2], stringsAsFactors = FALSE) 
  d.f3 <- data.frame(inizio = start3, fine = end3, BSL = d_f$BSL[ind3], PK = d_f$PK[ind3], stringsAsFactors = FALSE) 
  
  if(!(start2 %in% DF$inizio))
  {
    l <- list(DF, d.f2)
    DF <- rbindlist(l)
  }
  if(!(start3 %in% DF$inizio))
  {
    l <- list(DF, d.f3)
    DF <- rbindlist(l)
  }
  return(DF)
}
###################################################################
MissingValues2 <- function(d_f, DF, Q, Qn, Qnm, sy, ore, mm, i)
  ### @BRIEF: function to compute missing BSL and PK when the second month of the Q is present, but not the third and it's the first month
{
  mesi <- c("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")
  ind2 <- which(d_f$period == paste0(Q[2],"_",sy))
  start2 <- paste0("20",sy,"-",Qnm[2], "-01")
  end2 <- paste0("20",sy,"-",Qnm[2], "-", lubridate::days_in_month(as.Date(start2, origin = "1899-12-30")))
  d.f2 <- data.frame(inizio = start2, fine = end2, BSL = d_f$BSL[ind2], PK = d_f$PK[ind2], stringsAsFactors = FALSE) 
  bQ <- d_f$BSL[which(d_f$period == paste0(GetQ(which(mesi == mm)), "_",sy))]
  pQ <- d_f$PK[which(d_f$period == paste0(GetQ(which(mesi == mm)), "_",sy))]
  missing_b <- (bQ*sum(ore$BSL[Qn[1]:Qn[3]]) -  d_f$BSL[i]*ore$BSL[Qn[1]] - d_f$BSL[ind2]*ore$BSL[Qn[2]])/ore$BSL[Qn[3]]
  missing_p <- (pQ*sum(ore$PK[Qn[1]:Qn[3]]) -  d_f$PK[i]*ore$PK[Qn[1]] - d_f$PK[ind2]*ore$PK[Qn[2]])/ore$PK[Qn[3]]
  start3 <- paste0("20",sy,"-",Qnm[3], "-01")
  end3 <- paste0("20",sy,"-",Qnm[3], "-", lubridate::days_in_month(as.Date(start3, origin = "1899-12-30")))
  d.f3 <- data.frame(inizio = start3, fine = end3, BSL = missing_b, PK = missing_p, stringsAsFactors = FALSE) 
  
  if(!(start2 %in% DF$inizio))
  {
    l <- list(DF, d.f2)
    DF <- rbindlist(l)
  }
  if(!(start3 %in% DF$inizio))
  {
    l <- list(DF, d.f3)
    DF <- rbindlist(l)
  }
  return(DF)
}
###################################################################
MissingValues3 <- function(d_f, DF, Q, Qn, Qnm, sy, ore, mm, i)
  ### @BRIEF: function to compute the missing BSL and PK if the third of the Q is present, but not the second and it's the first month
{
  mesi <- c("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")
  ind2 <- which(d_f$period == paste0(Q[3],"_",sy))
  start2 <- paste0("20",sy,"-",Qnm[3], "-01")
  end2 <- paste0("20",sy,"-",Qnm[3], "-", lubridate::days_in_month(as.Date(start2, origin = "1899-12-30")))
  d.f2 <- data.frame(inizio = start2, fine = end2, BSL = d_f$BSL[ind2], PK = d_f$PK[ind2], stringsAsFactors = FALSE) 
  bQ <- d_f$BSL[which(d_f$period == paste0(GetQ(which(mesi == mm)), "_",sy))]
  pQ <- d_f$PK[which(d_f$period == paste0(GetQ(which(mesi == mm)), "_",sy))]
  missing_b <- (bQ*sum(ore$BSL[Qn[1]:Qn[3]]) -  d_f$BSL[i]*ore$BSL[Qn[1]] - d_f$BSL[ind2]*ore$BSL[Qn[3]])/ore$BSL[Qn[2]]
  missing_p <- (pQ*sum(ore$PK[Qn[1]:Qn[3]]) -  d_f$PK[i]*ore$PK[Qn[1]] - d_f$PK[ind2]*ore$PK[Qn[3]])/ore$PK[Qn[2]]
  start3 <- paste0("20",sy,"-",Qnm[2], "-01")
  end3 <- paste0("20",sy,"-",Qnm[2], "-", lubridate::days_in_month(as.Date(start3, origin = "1899-12-30")))
  d.f3 <- data.frame(inizio = start3, fine = end3, BSL = missing_b, PK = missing_p, stringsAsFactors = FALSE) 
  
  if(!(start2 %in% DF$inizio))
  {
    l <- list(DF, d.f2)
    DF <- rbindlist(l)
  }
  if(!(start3 %in% DF$inizio))
  {
    l <- list(DF, d.f3)
    DF <- rbindlist(l)
  }
  return(DF)  
}
###################################################################
MissingValues4 <- function(d_f, DF, Q, Qn, Qnm, sy, ore, mm, i)
  ### @BRIEF: function to compute the missing BSL and PK if both the second and the third month of the Q are missing => I get BSL and PK
  #### of the two months together and it's the first month
{
  mesi <- c("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")
  bQ <- d_f$BSL[which(d_f$period == paste0(GetQ(which(mesi == mm)), "_",sy))]
  pQ <- d_f$PK[which(d_f$period == paste0(GetQ(which(mesi == mm)), "_",sy))]
  missing_b <- (bQ*sum(ore$BSL[Qn[1]:Qn[3]]) -  d_f$BSL[i]*ore$BSL[Qn[1]])/sum(ore$BSL[Qn[2]:Qn[3]])
  missing_p <- (pQ*sum(ore$PK[Qn[1]:Qn[3]]) -  d_f$PK[i]*ore$PK[Qn[1]])/sum(ore$PK[Qn[2]:Qn[3]])
  start3 <- paste0("20",sy,"-",Qnm[2], "-01")
  s <- paste0("20",sy,"-",Qnm[3], "-01")
  end3 <- paste0("20",sy,"-",Qnm[3], "-", lubridate::days_in_month(as.Date(s, origin = "1899-12-30")))
  d.f3 <- data.frame(inizio = start3, fine = end3, BSL = missing_b, PK = missing_p, stringsAsFactors = FALSE)
  
  if(!(start3 %in% DF$inizio))
  {
    l <- list(DF, d.f3)
    DF <- rbindlist(l)
  }
  return(DF)
}
###################################################################
MissingValues5 <- function(d_f, DF, Q, Qnm, sy)
  ### @BRIEF: function to compute missing BSL and PK of the third month pf the Q and it's the second month of the Q
{
  ind3 <- which(d_f$period == paste0(Q[3],"_",sy))
  start3 <- paste0("20",sy,"-",Qnm[3], "-01")
  end3 <- paste0("20",sy,"-",Qnm[3], "-", lubridate::days_in_month(as.Date(start3, origin = "1899-12-30")))
  d.f3 <- data.frame(inizio = start3, fine = end3, BSL = d_f$BSL[ind3], PK = d_f$PK[ind3], stringsAsFactors = FALSE) 
  if(!(start3 %in% DF$inizio))
  {
    l <- list(DF, d.f3)
    DF <- rbindlist(l)
  }
  return(DF)
}
###################################################################
TFileReader <- function(y1, y2)
{
  mesi <- c("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")
  ore7 <- read_excel("C:/Users/t_carrubba/Documents/shinyapp/sudd_ore_anno.xlsx", sheet = as.character(y1))
  ore8 <- read_excel("C:/Users/t_carrubba/Documents/shinyapp/sudd_ore_anno.xlsx", sheet = as.character(y2))
  
  sy1 <- y1 - 2000
  sy2 <- y2 - 2000
  
  files <- list.files("C:/Users/t_carrubba/Documents/shinyapp")
  fq <- grep('mercato', files, value=TRUE)
  df <- read_excel(paste0("C:/Users/t_carrubba/Documents/shinyapp/", fq), skip = 3)
  df <- df[,1:7]
  colnames(df) <- c("Period","Base.1","Peak.1","OffPeak.1","Base.2","Peak.2","OffPeak.2")
  df[is.na(df)] <- 0
  if(df$Period[1] == "Week") df <- df[2:nrow(df),]
  d_f <- data_frame()
  for( i in 1:nrow(df))
  {
    if(as.numeric(df$Base.1[i]) + as.numeric(df$Peak.1[i]) > 0)
    {
      per <- as.character(df$Period[i])
      if(per %in% mesi | per %in% c("Q1","Q2","Q3", "Q4") | per == "Y") per <- as.character(paste0(per, "_", sy1))
      d.f <- data.frame(period = as.character(per), BSL = df$Base.1[i], PK = df$Peak.1[i], stringsAsFactors=FALSE)
      l = list(d_f, d.f)
      d_f <- rbindlist(l)
    }
    else
    {
      next
    }
  }
  for( i in 1:nrow(df))
  {
    if(as.numeric(df$Base.2[i]) + as.numeric(df$Peak.2[i]) > 0)
    {
      per <- as.character(df$Period[i])
      if(per %in% mesi | per %in% c("Q1", "Q2","Q3", "Q4") | per == "Y") per <- as.character(paste0(per, "_", sy2))
      d.f <- data.frame(period = as.character(per), BSL = df$Base.2[i], PK = df$Peak.2[i], stringsAsFactors=FALSE)
      l = list(d_f, d.f)
      d_f <- rbindlist(l)
    }
    else
    {
      next
    }
  }
  d_f$BSL <- as.numeric(d_f$BSL)
  d_f$PK <- as.numeric(d_f$PK)
  ##### compute the missing values #####
  usageQ7 <- c(0,0,0,0)
  usageQ8 <- c(0,0,0,0)
  
  Q1 <- mesi[1:3]
  Q2 <- mesi[4:6]
  Q3 <- mesi[7:9]
  Q4 <- mesi[10:12]
  
  Q1n <- c(1:3)
  Q2n <- c(4:6)
  Q3n <- c(7:9)
  Q4n <- c(10:12)
  
  Q1nm <- c("01","02","03")
  Q2nm <- c("04","05","06")
  Q3nm <- c("07","08","09")
  Q4nm <- c("10","11","12")
  
  DF <- data_frame()
  DF <- bind_rows(DF, data.frame(inizio = '2016-01-01', fine = '2016-01-31', BSL = 0, PK = 0, stringsAsFactors = FALSE))
  for(i in 1:nrow(d_f))
  {
    #print(i)
    if(!(strsplit(d_f$period[i], "_")[[1]][1] %in% mesi) & !(strsplit(d_f$period[i], "_")[[1]][1] %in% c("Q1","Q2","Q3","Q4")) & strsplit(d_f$period[i], "_")[[1]][1] != "Y")
    {
      split1 <- gsub(" ", "", strsplit(d_f$period[i], "-")[[1]][1], fixed = TRUE)
      split2 <- gsub(" ", "", strsplit(d_f$period[i], "-")[[1]][2], fixed = TRUE)
      
      ss1 <- strsplit(split1, "/")[[1]]
      ss2 <- strsplit(split2, "/")[[1]]
      
      start <- paste0(ss1[3], "-", ss1[2], "-", ss1[1])
      end <- paste0(ss2[3], "-", ss2[2], "-", ss2[1])
      
      d.f <- data.frame(inizio = start, fine = end, BSL = d_f$BSL[i], PK = d_f$PK[i])
      
      if(!(start %in% DF$inizio))
      {
        l <- list(DF, d.f)
        DF <- rbindlist(l)
      }
    }
    
    else if(strsplit(d_f$period[i], "_")[[1]][1] %in% mesi)
    {
      mm <- strsplit(d_f$period[i], "_")[[1]][1]
      y <- strsplit(d_f$period[i], "_")[[1]][2]
      m <- lubridate::month(Sys.Date())
      Q <- get(GetQ(which(mesi == mm)))
      Qn <- get(paste0(GetQ(which(mesi == mm)), "n"))
      Qnm <- get(paste0(GetQ(which(mesi == mm)), "nm"))
      
      if(y == "17")
      {
        usageQ7[Qn[3]/3] <- 1
      }
      else
      {
        usageQ8[Qn[3]/3] <- 1
        
        ind <- which(d_f$period == paste0(Q[1],"_",y))
        start <- paste0("20",y,"-",Qnm[1], "-01")
        end <- paste0("20",y,"-",Qnm[1], "-", lubridate::days_in_month(as.Date(start, origin = "1899-12-30")))
        d.f <- data.frame(inizio = start, fine = end, BSL = d_f$BSL[ind], PK = d_f$PK[ind], stringsAsFactors = FALSE) 
        if(!(start %in% DF$inizio))
        {
          l <- list(DF, d.f)
          DF <- rbindlist(l)
        }
        
        if(paste0(Q[2],"_",y) %in% d_f$period & paste0(Q[3],"_",y) %in% d_f$period)
        {
          DF <- MissingValues1(d_f, DF, Q, Qnm, y)
        }
        else if(paste0(Q[2],"_",y) %in% d_f$period & !(paste0(Q[3],"_",y) %in% d_f$period))
        {
          DF <- MissingValues2(d_f, DF, Q, Qn, Qnm, y, ore8, mm, i)
        }
        
        else if(!(paste0(Q[2],"_",y) %in% d_f$period) & (paste0(Q[3],"_",y) %in% d_f$period))
        {
          DF <- MissingValues3(d_f, DF, Q, Qn, Qnm, y, ore8, mm, i)
        }
        
        else if(paste0(Qn[3]/3,"_",y) %in% d_f$period)
        {
          DF <- MissingValues4(d_f, DF, Q, Qn, Qnm, y, ore8, mm, i)
        }
        
        
      }
      
      if(m %in% Qn)
      {
        if(m == Qn[1])
        {
          
          if(paste0(Q[2],"_",y) %in% d_f$period & paste0(Q[3],"_",y) %in% d_f$period)
          {
            DF <- MissingValues1(d_f, DF, Q, Qnm, y)
          }
          else if(paste0(Q[2],"_",y) %in% d_f$period & !(paste0(Q[3],"_",y) %in% d_f$period))
          {
            DF <- MissingValues2(d_f, DF, Q, Qn, Qnm, y, ore7, mm, i)
          }
          
          else if(!(paste0(Q[2],"_",y) %in% d_f$period) & (paste0(Q[3],"_",y) %in% d_f$period))
          {
            DF <- MissingValues3(d_f, DF, Q, Qn, Qnm, y, ore7, mm, i)
          }
          
          else
          {
            DF <- MissingValues4(d_f, DF, Q, Qn, Qnm, y, ore7, mm, i)
          }
          
        }
        else if(m == Qn[2])
        {
          if(paste0(Q[3],"_",y) %in% d_f$period)
          {
            DF <- MissingValues5(d_f, DF, Q, Qnm, y)
          }
          else
          {
            bQ <- d_f$BSL[which(d_f$period == paste0(GetQ(m), "_",y))]
            pQ <- d_f$PK[which(d_f$period == paste0(GetQ(m), "_",y))]
            missing_b <- (bQ*sum(ore7$BSL[Qn[1]:Qn[3]]) -  d_f$BSL[i]*ore7$BSL[Qn[2]])/ore7$BSL[Qn[3]]
            missing_p <- (bQ*sum(ore7$PK[Qn[1]:Qn[3]]) -  d_f$PK[i]*ore7$PK[Qn[2]])/ore7$PK[Qn[3]]
            start3 <- paste0("20",y,"-",Qnm[3], "-01")
            end3 <- paste0("20",y,"-",Qnm[3], "-", lubridate::days_in_month(as.Date(start3, origin = "1899-12-30")))
            d.f3 <- data.frame(inizio = start3, fine = end3, BSL = missing_b, PK = missing_p, stringsAsFactors = FALSE)
            if(!(start3 %in% DF$inizio))
            {
              l <- list(DF, d.f3)
              DF <- rbindlist(l)
            }
            
          }
        }
        else
        {
          start3 <- paste0("20",y,"-",Qnm[3], "-01")
          end3 <- paste0("20",y,"-",Qnm[3], "-", lubridate::days_in_month(as.Date(start3, origin = "1899-12-30")))
          d.f3 <- data.frame(inizio = start3, fine = end3, BSL = d_f$BSL[i], PK = d_f$PK[i], stringsAsFactors = FALSE)
          if(!(start3 %in% DF$inizio))
          {
            l <- list(DF, d.f3)
            DF <- rbindlist(l)
          }
          
        }#### end if loop m \in Qn
      }
      else if(m < Qn[1])
      {
        start <- paste0("20",y,"-",Qnm[1], "-01")
        end <- paste0("20",y,"-",Qnm[1], "-", lubridate::days_in_month(as.Date(start, origin = "1899-12-30")))
        d.f <- data.frame(inizio = start, fine = end, BSL = d_f$BSL[i], PK = d_f$PK[i], stringsAsFactors = FALSE)
        if(!(start %in% DF$inizio))
        {
          l <- list(DF, d.f)
          DF <- rbindlist(l)
        }
        
        if(paste0(Q[2],"_",y) %in% d_f$period & paste0(Q[3],"_",y) %in% d_f$period)
        {
          DF <- MissingValues1(d_f, DF, Q, Qnm, y)
        }
        else if(paste0(Q[2],"_",y) %in% d_f$period & !(paste0(Q[3],"_",y) %in% d_f$period))
        {
          DF <- MissingValues2(d_f, DF, Q, Qnm, y, ore7, mm, i)
        }
        
        else if(!(paste0(Q[2],"_",y) %in% d_f$period) & (paste0(Q[3],"_",y) %in% d_f$period))
        {
          DF <- MissingValues3(d_f, DF, Q, Qnm, y, ore7, mm, i)
        }
        
        else
        {
          DF <- MissingValues4(d_f, DF, Q, Qn, Qnm, y, ore7, mm, i)
        }
        
      }
    }
    else if(strsplit(d_f$period[i], "_")[[1]][1] %in% c("Q1","Q2","Q3","Q4"))
    {
      q <- strsplit(d_f$period[i], "_")[[1]][1]
      y <- strsplit(d_f$period[i], "_")[[1]][2]
      
      if(y == as.character(sy1) & usageQ7[which(c("Q1","Q2","Q3","Q4") == q)] > 0)
      {
        next
      }
      else if(y == as.character(sy2) & usageQ8[which(c("Q1","Q2","Q3","Q4") == q)] > 0)
      {
        next
      }
      else
      {
        Q <- get(q)
        Qnm <- get(paste0(q,"nm"))
        start <- paste0("20",y,"-",Qnm[1], "-01")
        s <- paste0("20",y,"-",Qnm[3], "-01")
        end <- paste0("20",y,"-",Qnm[3],'-', lubridate::days_in_month(as.Date(s, origin = "1899-12-30")))
        d.f <- data.frame(inizio = start, fine = end, BSL = d_f$BSL[i], PK = d_f$PK[i], stringsAsFactors = FALSE)
        if(!(start %in% DF$inizio))
        {
          l <- list(DF, d.f)
          DF <- rbindlist(l)
        }
        if(y == as.character(sy2))
        {
          usageQ8[which(c("Q1","Q2","Q3","Q4") == q)] = 1
        }
        if(y == as.character(sy1))
        {
          usageQ7[which(c("Q1","Q2","Q3","Q4") == q)] = 1
        }
      }
      
    }
    else if(strsplit(d_f$period[i], "_")[[1]][1] == 'Y')
    {
      usage <- c() 
      if(strsplit(d_f$period[i], "_")[[1]][2] == as.character(sy1))
      {usage <- usageQ7}
      else
      {usage <- usageQ8}
      
      ore <- c()
      if(strsplit(d_f$period[i], "_")[[1]][2] == as.character(sy1))
      {ore <- ore7}
      else
      {ore <- ore8}
      
      if(sum(usage) > 0)
      {
        if(paste0("Q1_",y) %in% d_f$period | paste0("Q2_",y) %in% d_f$period | paste0("Q3_",y) %in% d_f$period | paste0("Q4_",y) %in% d_f$period)
        {
          used <- paste0("Q", which(usage == 1))
          not_used <- setdiff(c("Q1","Q2","Q3","Q4"), used)
          month_taken <- c()
          diff <- 0
          diffPK <- 0
          for(j in 1:4)
          {
            if(usage[j] == 1)
            {
              month_taken <- c(month_taken, get(paste0("Q", j,"n")))
              diff <- diff + sum(d_f$BSL[which(d_f$period %in% paste0(c("Q1","Q2","Q3","Q4")[j],"_",y))] * ore$BSL[get(paste0("Q", j,"n"))])
              diffPK <- diffPK + sum(d_f$PK[which(d_f$period %in% paste0(c("Q1","Q2","Q3","Q4")[j],"_",y))] * ore$PK[get(paste0("Q", j,"n"))])
            }
          }
          sum_missingQ_BSL <- (d_f$BSL[i]*sum(ore$BSL) - diff)/sum(ore$BSL[setdiff(1:12, month_taken)])
          sum_missingQ_PK <- (d_f$PK[i]*sum(ore$PK) - diffPK)/sum(ore$PK[setdiff(1:12, month_taken)])
          
          p <- max(which(usage == 1))
          Qp <- paste0("Q",1:p)
          Q <- get(paste0("Q", min(which(usage == 0))))
          Qn <- get(paste0("Q", min(which(usage == 0)),"n"))
          Qnm <- get(paste0("Q", min(which(usage == 0)),"nm"))
          start <- paste0("2018-",Qnm[1], "-01")
          end <- '2018-12-31'
          d.f <- data.frame(inizio = start, fine = end, BSL = sum_missingQ_BSL, PK = sum_missingQ_PK, stringsAsFactors = FALSE)
          if(!(start %in% DF$inizio))
          {
            l <- list(DF, d.f)
            DF <- rbindlist(l)
          }
        }
        else
        {
          month_taken <- c()
          diff <- 0
          diffPK <- 0
          for(j in 1:12)
          {
            if(paste0(mesi[j],"_",y) %in% d_f$period)
            {
              month_taken <- c(month_taken, j)
              diff <- diff + sum(d_f$BSL[which(d_f$period %in% paste0(mesi[j],"_",y))] * or8$BSL[j])
              diffPK <- diffPK + sum(d_f$PK[which(d_f$period %in% paste0(mesi[j],"_",y))] * ore$PK[j])
            }
          }
          
          sum_missingQ_BSL <- (d_f$BSL[i]*sum(ore$BSL) - diff)/sum(ore$BSL[setdiff(1:12, month_taken)])
          sum_missingQ_PK <- (d_f$PK[i]*sum(ore$PK) - diffPK)/sum(ore$PK[setdiff(1:12, month_taken)])
          
          p <- max(month_taken) + 1
          np <- ifelse(p < 10, paste0("0",p), p)
          
          start <- paste0("2018-",np, "-01")
          end <- '2018-12-31'
          d.f <- data.frame(inizio = start, fine = end, BSL = sum_missingQ_BSL, PK = sum_missingQ_PK, stringsAsFactors = FALSE)
          if(!(start %in% DF$inizio))
          {
            l <- list(DF, d.f)
            DF <- rbindlist(l)
          }
        }
      }
    }
    else
    {
      d.f <- data.frame(inizio = '2018-01-01', fine = '2018-12-31', BSL = d_f$BSL[i], PK = d_f$PK[i], stringsAsFactors = FALSE)
      l <- list(DF, d.f)
      DF <- rbindlist(l)
    }
  }
  return(DF[2:nrow(DF)])
}
###################################################################
###################################################################
