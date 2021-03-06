##### conferimento #######
library(openxlsx)
library(plyr)
library(dplyr)
library(reshape)
library(stringi)
library(xlsx)

source("functions_for_curve_clustering.R")
source("SparseFunctClust.R")
source("funtional_gap_statistic.R")
source("functions_for_OP.R")

########
mar15 <- openxlsx::read.xlsx("max_allocato.xlsx", sheet = "marzo 2015", colNames = TRUE)
apr15 <- openxlsx::read.xlsx("max_allocato.xlsx", sheet = "aprile 2015", colNames = TRUE)
mag15 <- openxlsx::read.xlsx("max_allocato.xlsx", sheet = "maggio 2015", colNames = TRUE)
giu15 <- openxlsx::read.xlsx("max_allocato.xlsx", sheet = "giugno 2015", colNames = TRUE)
lug15 <- openxlsx::read.xlsx("max_allocato.xlsx", sheet = "luglio 2015", colNames = TRUE)
ago15 <- openxlsx::read.xlsx("max_allocato.xlsx", sheet = "agosto 2015", colNames = TRUE)
set15 <- openxlsx::read.xlsx("max_allocato.xlsx", sheet = "settembre 2015", colNames = TRUE)
ott15 <- openxlsx::read.xlsx("max_allocato.xlsx", sheet = "ottobre 2015", colNames = TRUE)
nov15 <- openxlsx::read.xlsx("max_allocato.xlsx", sheet = "novembre 2015", colNames = TRUE)
dic15 <- openxlsx::read.xlsx("max_allocato.xlsx", sheet = "dicembre 2015", colNames = TRUE)
gen16 <- openxlsx::read.xlsx("max_allocato.xlsx", sheet = "gennaio 2016", colNames = TRUE)
feb16 <- openxlsx::read.xlsx("max_allocato.xlsx", sheet = "febbraio 2016", colNames = TRUE)
mar16 <- openxlsx::read.xlsx("max_allocato.xlsx", sheet = "marzo 2016", colNames = TRUE)
apr16 <- openxlsx::read.xlsx("max_allocato.xlsx", sheet = "aprile 2016", colNames = TRUE)

dfs <- ls()[sapply(mget(ls(), .GlobalEnv), is.data.frame)]
#dfs <- dfs[c(1:13,17)]
dfs <- dfs[c(10,2,9,7,8,1,14,13,12,4,6,5,11,3)]

### dati 2015-2016:
cgen15 <- read_and_plot_data_2015("GENNAIO")
cfeb15 <- read_and_plot_data_2015("FEBBRAIO")
cmar15 <- read_and_plot_data_2015("MARZO")
capr15 <- read_and_plot_data_2015("APRILE")
cmag15 <- read_and_plot_data_2015("MAGGIO")
cgiu15 <- read_and_plot_data_2015("GIUGNO")
clug15 <- read_and_plot_data_2015("LUGLIO")
cago15 <- read_and_plot_data_2015("AGOSTO")
cset15 <- read_and_plot_data_2015("SETTEMBRE")
cott15 <- read_and_plot_data("OTTOBRE")
cnov15 <- read_and_plot_data("NOVEMBRE")
cdic15 <- read_and_plot_data("DICEMBRE")
cgen <- read_and_plot_data("GENNAIO")
cfeb <- read_and_plot_data("FEBBRAIO")
cmar <- read_and_plot_data("MARZO")
capr <- read_and_plot_data("APRILE")
dfs2 <- c("cmar15", "capr15", "cmag15","cgiu15","clug15","cago15","cset15","cott15","cnov15","cdic15","cgen","cfeb","cmar","capr")

for(df in dfs2)
{
  xlsx::write.xlsx(data.frame(get(df)), paste0(df,".xlsx"), row.names=TRUE, col.names = TRUE)
}
#########

# dfs <- ls()[sapply(mget(ls(), .GlobalEnv), is.data.frame)]
# dfs <- dfs[1:37]
# dfs <- dfs[c(26,5,17,20,1,35,32,29,8,15,12,27,6,23,18,21,2,36,33,30,9,16,13,28,7,24,19,22,3,37,34,31,10,14,11,25,4)]

pm <- openxlsx::read.xlsx("profili_mensili.xlsx", sheet = 1, colNames = TRUE)
ver <- openxlsx::read.xlsx("Report_214.xlsx", sheet = 1, colNames = TRUE)
ver[is.na(ver)] <- 0
ver2 <- extract_relevant_val(ver[which(ver["SHIPPER"] == "0001808491-AXOPOWER SRL"),])
profili_consumo <- openxlsx::read.xlsx("profili15.xlsx", sheet = 1, colNames = TRUE)
prof <- data.frame(profili_consumo[2:nrow(profili_consumo),3:38])

############# matrici per ottimizzazione conferimento ##############
remi_found <- c()
for(df in dfs)
{
  remi_found <- c(remi_found, as.character(get(df)[,1]))
}
remi_found <- unique(remi_found)

M2 <- matrix(0,nrow = length(remi_found), ncol = 48) ### totale
rownames(M2) <- remi_found
M3 <- matrix(0,nrow = nrow(M2), ncol = 48) ## solo lg
rownames(M3) <- rownames(M2)
M4 <- matrix(0,nrow = nrow(M2), ncol = 48) ## altri
rownames(M4) <- rownames(M2)
M5 <- matrix(0,nrow = nrow(M2), ncol = 48) ## lg ricostruiti con profilo di prelievo
rownames(M5) <- rownames(M2)
start <- Sys.time()
for(rf in rownames(M2))
{
  re <- ver2[which(ver2["COD_REMI"] == rf),]
  CG <- CGlg <- CGlgrec <- rep(0, 24)
  {
    if(nrow(re) > 0)
    {
      max_rf2 <- rep(0, length(dfs))
      for(j in 1:length(dfs))
      {
        if(rf %in% get(dfs[j])[,1]) max_rf2[j] <- get(dfs[j])[which(get(dfs[j])[,1] == rf),2]
      }
      names(max_rf2) <- c("03/2015","04/2015","05/2015","06/2015","07/2015","08/2015","09/2015",
                          "10/2015","11/2015","12/2015","01/2016","02/2016","03/2016","04/2016")
      max_rf <- c(0,0,max_rf2,rep(0,8))
      
      sum_remi <- compute_sum_remi(re)
      
      for(k in 1:nrow(re))
      {
        CGtemp <-  CGtemplg <- CGlgrectemp <- rep(0, 24)
        pdr <- unique(unlist(re[k,"PDR"]))
        cons <- ifelse(re[k,"CONSUMO_DISTRIBUTORE"] != "0", as.numeric(as.character(re[k,"CONSUMO_DISTRIBUTORE"])), as.numeric(as.character(re[k,"CONSUMO_CONTR_ANNUO"])))
        agg <- data_frame(prodotto = re[k,"CODICE_PRODOTTO"], data.inizio = as.character(re[k,"D_VALIDO_DAL_T"]), 
                          data.fine = as.character(re[k,"D_VALIDO_AL_T"]), profilo= as.character(re[k,"PROFILO_PRELIEVO"]), 
                          consumo = cons)
        colnames(agg) <- c("prodotto", "data inizio", "data fine", "profilo", "consumo")
        
        CGtemp <- compute_max_prof(agg, prof)
        #CGtemppp <- compute_max_prof(agg, prof)
        for(ds in dfs2)
        {
          if(pdr %in% rownames(get(ds)))
          {
            DF <- correct_obs(get(ds))
            my <- get_month_year(ds)
            month <- map_months(my[1])
            #index <- take_month(month, my[2], profili_temp)
            index <- which(dfs2 == ds)
            index2 <- which(rownames(DF) == pdr)
            CGtemp[index+2] <- max(DF[index2,])
            CGtemplg[index+2] <- max(DF[index2,])
            #CGtemppp[index+2] <- CGtemppp[index+2] - max(DF[index2,])
            M3[which(rownames(M3) == rf), index+26] <- M3[which(rownames(M3) == rf), index+26] -  max(DF[index2,])
            #M4[which(rownames(M4) == rf), index+26] <- M4[which(rownames(M4) == rf), index+26] -  max(DF[index2,])
            CGlgrectemp <- compute_max_prof(agg, prof)
          }
        }
        CGtemp <- CGtemp*active(agg$`data inizio`, agg$`data fine`)
        CGtemplg <- CGtemplg*active(agg$`data inizio`, agg$`data fine`)
        CGlgrectemp <- CGlgrectemp*active(agg$`data inizio`, agg$`data fine`)
        #CGtemppp <- CGtemppp*active(agg$`data inizio`, agg$`data fine`)
        
        #print(CG_temp);print(CG_temp_hp);print(CGr_temp);print(CGrhp_temp);
        
        CG <- CG + CGtemp
        CGlg <- CGlg + CGtemplg
        CGlgrec <- CGlgrec + CGlgrectemp
        #CGpp <- CGpp + CGtemppp
      }
      
      index2 <- which(rownames(M2) == rf)
      index3 <- which(rownames(M3) == rf)
      index4 <- which(rownames(M4) == rf)
      index5 <- which(rownames(M5) == rf)
      for(j in 1:24)
      {
        M2[index2,j] <- CG[j]
        M2[index2,(24+j)] <- max_rf[j]
        M3[index3,j] <- CGlg[j]
        M3[index3,(24+j)] <- max_rf[j] - M3[index3,j]
        M4[index4,j] <- M2[index2,j] - M3[index3,j]
        #M4[index4,j+24] <- max_rf[j] + M3[index3,(j+24)]
        M4[index4,j+24] <- M2[index3,(j+24)] - M3[index3,j]
        M5[index5,j] <- CGlgrec[j]
        M5[index5, j+24] <- CGlg[j]
      }
    }
  }
}
end <- Sys.time()
end-start

xlsx::write.xlsx(data.frame(M2), paste0("C:/Users/d_floriello/Documents/plot_remi/mat_ottimizzazione_NEW.xlsx"), row.names=TRUE, col.names = TRUE)
xlsx::write.xlsx(data.frame(M3), paste0("C:/Users/d_floriello/Documents/plot_remi/mat_ottimizzazione_NEW_LG.xlsx"), row.names=TRUE, col.names = TRUE)
xlsx::write.xlsx(data.frame(M4), paste0("C:/Users/d_floriello/Documents/plot_remi/mat_ottimizzazione_NEW_nonLG.xlsx"), row.names=TRUE, col.names = TRUE)
xlsx::write.xlsx(data.frame(M5), paste0("C:/Users/d_floriello/Documents/plot_remi/mat_ottimizzazione_NEW_LGrec.xlsx"), row.names=TRUE, col.names = TRUE)

########
npdr <- openxlsx::read.xlsx("C:/Users/d_floriello/Documents/plot_remi/num_pdr150.xlsx", sheet = 1, rowNames = TRUE, colNames = TRUE)

Sol <- matrix(0,nrow = nrow(M2), ncol = 15)
rownames(Sol) <- rownames(M2)
colnames(Sol) <- c("% ottima CA totale", "capacita ottima CA totale", "minimo costo CA totale",
                   "% ottima CA LG rec", "capacita ottima CA LG rec", "minimo costo CA LG rec",
                   "% ottima CA NONLG", "capacita ottima CA NONLG", "minimo costo CA NONLG",
                   "simple CA totale", "simple CA LG", "simple CA non LG",
                   "cap. ottima simple tot", "cap ottima simple Lg", "cap ottima simple non lg")

xx <- seq(-1, 1, 0.001)
for(rf in rownames(M2))  
{
  i <- which(rownames(Sol) == rf)
  #  s1 <- Fhd(rf, M2); s2 <- Fhd(rf, M3); s3 <- Fhd(rf, M4); s4 <- Fhd(rf, M5)
  s1 <- Fhdn(rf, M2); s2 <- Fhdn(rf, M5); s3 <- Fhdn(rf, M4); #s4 <- Fhdn(rf, M5)
  x1 <- simple_optim(rf, M2); x4 <- simple_optim(rf, M4); x5 <- simple_optim(rf, M5)
  
  if(sum(s1) > 0)
  {
    Sol[i,1] <- xx[which.min(s1[1:(length(s1)-1)])]
    Sol[i,2] <- unlist(s1[length(s1)])*(1+Sol[i,1])
    Sol[i,3] <- min(s1[1:(length(s1)-1)])
  }
  
  if(sum(s2) > 0)
  {
    Sol[i,4] <- xx[which.min(s2[1:(length(s2)-1)])]
    Sol[i,5] <- unlist(s2[length(s2)])*(1+Sol[i,4])
    Sol[i,6] <- min(s2[1:(length(s2)-1)])
  }
  
  if(sum(s3) > 0)
  {
    Sol[i,7] <- xx[which.min(s3[1:(length(s3)-1)])]
    Sol[i,8] <- unlist(s3[length(s3)])*(1+Sol[i,7])
    Sol[i,9] <- min(s3[1:(length(s3)-1)])
  }
  
  Sol[i,10] <- x1; Sol[i,11] <- x5; Sol[i,12] <- x4; 
  Sol[i,13] <- unlist(s1[length(s1)])*(1+x1); Sol[i,14] <- unlist(s2[length(s2)])*(1+x5); Sol[i,15] <- unlist(s3[length(s3)])*(1+x4); 
}

xlsx::write.xlsx(data.frame(Sol), paste0("C:/Users/d_floriello/Documents/plot_remi/soluzione_ottimizzazione.xlsx"), row.names=TRUE, col.names = TRUE)

result1 <- sumprod_by_cluster(Sol, 1,npdr)
result2 <- sumprod_by_cluster(Sol, 4,npdr)
result3 <- sumprod_by_cluster(Sol, 7,npdr)

result1
result2
result3

penali2 <- matrix(0,nrow=nrow(M2),ncol = 12)
rownames(penali2) <- rownames(M2)
for(rf in rownames(M2))  
{
  i <- which(rownames(penali2) == rf)
  penali2[i,] <- penali(rf,M2,0)
}

penali4 <- matrix(0,nrow=nrow(M4),ncol = 12)
rownames(penali4) <- rownames(M2)
for(rf in rownames(M2))  
{
  i <- which(rownames(penali4) == rf)
  penali4[i,] <- penali(rf,M4,0)
}  

penali5 <- matrix(0,nrow=nrow(M5),ncol = 12)
rownames(penali5) <- rownames(M2)
for(rf in rownames(M2))  
{
  i <- which(rownames(penali5) == rf)
  penali5[i,] <- penali(rf,M5,0)
}  

r2 <- rowSums(penali2)
r4 <- rowSums(penali4)
r5 <- rowSums(penali5)

dd <- data.frame(r2,r4,r5)
colnames(dd) <- c("totale", "non_LG", "LG")
 
xlsx::write.xlsx(dd, paste0("C:/Users/d_floriello/Documents/plot_remi/penali_remi.xlsx"), row.names=TRUE, col.names = TRUE)

#################################################################################
##### i remi del secondo cluster sono quelli che prendono piu' penali? ##########

M2 <- openxlsx::read.xlsx("C:/Users/d_floriello/Documents/plot_remi/mat_ottimizzazione_NEW.xlsx", rowNames = TRUE)
M4 <- openxlsx::read.xlsx("C:/Users/d_floriello/Documents/plot_remi/mat_ottimizzazione_NEW_nonLG.xlsx", rowNames = TRUE)
M5 <- openxlsx::read.xlsx("C:/Users/d_floriello/Documents/plot_remi/mat_ottimizzazione_NEW_LGrec.xlsx", rowNames = TRUE)

mp <- matrix(0,nrow=3,ncol=4)
count <- 0

for(re in rownames(M2))
{
  mp[1,4] <- length(which(npdr[,1] <= 10))
  mp[2,4] <- length(which(npdr[,1] > 10 & npdr[,1] <= 30))
  mp[3,4] <- length(which(npdr[,1] > 30))
  
  i2 <- which(rownames(M2) == re)
  i4 <- which(rownames(M4) == re)
  i5 <- which(rownames(M5) == re)
  i <- which(rownames(npdr) == re)
  
  if(length(i) > 0)
  {
    if(as.numeric(npdr[i,1]) <= 10)
    {
      mp[1,1] <- mp[1,1] + sum(penali(re,data.matrix(M2)))
      mp[1,2] <- mp[1,2] + sum(penali(re,data.matrix(M4)))
      mp[1,3] <- mp[1,3] + sum(penali(re,data.matrix(M5)))
    }
    
    else if(as.numeric(npdr[i,1]) > 10 & as.numeric(npdr[i,1]) <= 30)
    {
      mp[2,1] <- mp[2,1] + sum(penali(re,data.matrix(M2)))
      mp[2,2] <- mp[2,2] + sum(penali(re,data.matrix(M4)))
      mp[2,3] <- mp[2,3] + sum(penali(re,data.matrix(M5)))
    }
    
    else
    {
      mp[3,1] <- mp[3,1] + sum(penali(re,data.matrix(M2)))
      mp[3,2] <- mp[3,2] + sum(penali(re,data.matrix(M4)))
      mp[3,3] <- mp[3,3] + sum(penali(re,data.matrix(M5)))
    }
  }
  else count <- count + 1
}

mp <- data.frame(mp)
colnames(mp) <- c("somma penali tot", "somma penali nonLG", "somma penali LG rec", "numeros. cluster")
rownames(mp) <- c("cluster <= 10", "cluster <= 30", "cluster > 30")


for(i in 1:3)
{
  for(j in 1:3)
  {
    print(paste(paste(i,j,sep=","), mp[i,j]/mp[i,4], sep=" : "))
  }
  print("###############################")
}

