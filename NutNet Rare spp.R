### NutNet and rare species #####
# June 13 2017

#Close graphics and clear local memory
#graphics.off()
rm(list=ls())

setwd("~/Google Drive/LTER_Biodiversity_Productivity")

#kim's wd
setwd('C:\\Users\\Kim\\Dropbox\\NutNet data')

require(ggplot2)

library(dplyr)
library(tidyr)
library(purrr)

nutnetdf <-read.csv("full-cover-09-June-2017.csv")
# 
# nutnetpretreatdt <- data.table(nutnetpretreatdf)
# nutnetpretreatdt[, meanPTAbundance:=mean(max_cover, na.rm=T), .(year, site_code, Taxon)]
# nutnetpretreatdt[, maxPTAbundance:=max(max_cover, na.rm=T), .(year, site_code, Taxon)]
# nutnetpretreatdt[, PTfreq:=sum(live==1, na.rm=T), .(year, site_code, Taxon)]

## compute mean abundance, max abundance and frequency of each species in the pretreatment data 
#filter to pretreatment data 
nutnetpretreatdf <- nutnetdf[nutnetdf$year_trt == 0,]
meanAb_byspecies <- aggregate(nutnetpretreatdf$max_cover, by = list(nutnetpretreatdf$year, nutnetpretreatdf$site_code, nutnetpretreatdf$Taxon), FUN = mean, na.rm = TRUE)
names(meanAb_byspecies) = c("year", "site_code", "Taxon", "meanPTAbundance")
meanAb_byspecies <- meanAb_byspecies%>%
  select(-year)
max_abund <-  aggregate(nutnetpretreatdf$max_cover, by = list(nutnetpretreatdf$year, nutnetpretreatdf$site_code, nutnetpretreatdf$Taxon), FUN = max, na.rm = TRUE)
names(max_abund) = c("year", "site_code", "Taxon", "maxPTAbundance")
max_abund <- max_abund%>%
  select(-year)
#filter to species live in a plot and pretreatment year, then sum to get the # of plots the species appeared in
nutnetpretreatdf_live = nutnetpretreatdf[nutnetpretreatdf$live == 1,]
freq <- aggregate(nutnetpretreatdf_live$live, by = list(nutnetpretreatdf_live$year, nutnetpretreatdf_live$site_code, nutnetpretreatdf_live$Taxon), FUN = sum, na.rm = TRUE)
names(freq) = c("year", "site_code", "Taxon", "PTfreq")
freq <- freq%>%
  select(-year)

#### Process data to create a max cover or 0 for each species, plot & year #### 


#nutnetdf <- as.data.frame(nutnetpretreatdt)
nutnetdf_allspp <- nutnetdf %>%
  select(-Family, -live:-ps_path) %>%
  group_by(site_name, site_code) %>%
  nest() %>%
  mutate(spread_df = purrr::map(data, ~spread(., key=Taxon, value=max_cover, fill=0) %>%
                                     gather(key=Taxon, value=max_cover,
                                            -year:-trt))) %>%
  unnest(spread_df)
nutnetdf_allspp <- as.data.frame(nutnetdf_allspp)


# make a column for presence absence of each species in a plot-year
nutnetdf_allspp$PA = ifelse(nutnetdf_allspp$max_cover > 0, 1, 0)

nutnetdf_length <- as.data.frame(nutnetdf_allspp)%>%
  #make a column for max trt year and filter out max year <5
  group_by(site_code)%>%
  summarise(length=max(year_trt))

nutnetdf_allspp2 <- nutnetdf_allspp%>%
  merge(nutnetdf_length, by='site_code')%>%
  select(-year, -max_cover)%>%
  filter(year_trt>0)%>%
  mutate(year_trt2=paste("yr", year_trt, sep=''))%>%
  select(-year_trt, -trt)%>%
  group_by(site_code, Taxon, site_name, block, plot, subplot, year_trt2, length)%>% ###there's duplicate entries for some spp
  summarise(PA2=mean(PA))%>%
  ungroup()%>%
  group_by(site_code, Taxon, site_name, block, plot, subplot, length)%>%
  summarise(PA3=sum(PA2))%>%
  ungroup()%>%
  mutate(yrs_absent=(length-PA3)/length)%>% #some of these are negative, wtf
  merge(meanAb_byspecies, by=c('site_code', 'Taxon'), all=T)%>%
  merge(max_abund, by=c('site_code', 'Taxon'), all=T)%>%
  merge(freq, by=c('site_code', 'Taxon'), all=T)%>%
  mutate(abund_metric=2*meanPTAbundance+PTfreq)%>%
  filter(length>0)

ggplot(nutnetdf_allspp2, aes(x=abund_metric, y=yrs_absent, color=length)) +
  geom_point()

  #spread(key=year_trt2, value=PA2)%>% ###I don't think we want to do this, because it is then unclear which are missing data and which are true 0s

  #mutate(yr_present=(length-yr1-yr2-yr3-yr4-yr5-yr6-yr7-yr8-yr9)/length) ###problem: can't sum over cells with NA, but most experiments have short datasets or missing data

# library(data.table)
# nutnetdt <- data.table(nutnetdf)
# 
# # create a data.table of unique species x year combos by site
# site_spp_yr_dt <- nutnetdt[,expand.grid(unique(plot), unique(Taxon), unique(year)), by=site_code]
# names(site_spp_yr_dt) <- c("site_code", "plot", "Taxon", "year")
# filled_nutnetdt <- merge(nutnetdt, site_spp_yr_dt, by=c("site_code", "plot", "Taxon", "year"), all=T)
# filled_nutnetdt[,PA:=!is.na(max_cover)]
# filled_nutnetdt[,tot_site_years:=length(unique(year)), by=site_code]
# filled_nutnetdt[,tot_spp_plot_years_present:=sum(PA), by=.(plot, site_code, Taxon)]
# filled_nutnetdt[,frac_absent:=(tot_site_years-tot_spp_plot_years_present)/tot_site_years]
# # make a variable that is just tot_site_years-tot_spp_plot_years_present
# head(filled_nutnetdt)
# summary(filled_nutnetdt$frac_absent)

## merge back into the full nutnet data (not only pretreatment year)
# nutnetdf_allspp  <- merge(nutnetdf_allspp ,meanAb_byspecies,  by = c("site_code", "Taxon"), all.x = T)
# nutnetdf_allspp  <- merge(max_abund, nutnetdf_allspp , by = c("site_code", "Taxon"), all = T)
# nutnetdf_allspp  <- merge(freq, nutnetdf_allspp ,  by = c("site_code", "Taxon"), all = T)


#nutnetdf_allspp2 <- reshape(nutnetdf_allspp, idvar=c('site_code', 'Taxon', 'PTfreq', 'maxPTAbundance', 'meanPTAbundance', 'site_name', 'trt'), timevar='year_trt', direction='wide')

# ### Code from Kim using Codyn 
# 
# library(codyn)
# 
# # codyn function modification ---------------------------------------------
# #modifying codyn functions to output integer numbers of species appearing and disappearing, plus total spp number over two year periods, rather than ratios
# turnover_allyears <- function(df, 
#                               time.var, 
#                               species.var, 
#                               abundance.var, 
#                               metric=c("total", "disappearance","appearance")) {
#   
#   # allows partial argument matching
#   metric = match.arg(metric) 
#   
#   # sort and remove 0s
#   df <- df[order(df[[time.var]]),]
#   df <- df[which(df[[abundance.var]]>0),]
#   
#   ## split data by year
#   templist <- split(df, df[[time.var]])
#   
#   ## create two time points (first year and each other year)
#   t1 <- templist[1]
#   t2 <- templist[-1]
#   
#   ## calculate turnover for across all time points
#   out <- Map(turnover_twoyears, t1, t2, species.var, metric)
#   output <- as.data.frame(unlist(out))
#   names(output)[1] = metric
#   
#   ## add time variable column
#   alltemp <- unique(df[[time.var]])
#   output[time.var] =  alltemp[2:length(alltemp)]
#   
#   # results
#   return(output)
# }
# 
# turnover_twoyears <- function(d1, d2, 
#                               species.var, 
#                               metric=c("total", "disappearance","appearance")){
#   
#   # allows partial argument matching
#   metric = match.arg(metric)
#   
#   # create character vectors of unique species from each df
#   d1spp <- as.character(unique(d1[[species.var]]))
#   d2spp <- as.character(unique(d2[[species.var]]))
#   
#   # ID shared species
#   commspp <- intersect(d1spp, d2spp)
#   
#   # count number not present in d2
#   disappear <- length(d1spp)-length(commspp)
#   
#   # count number that appear in d2
#   appear <- length(d2spp)-length(commspp)
#   
#   # calculate total richness
#   totrich <- sum(disappear, appear, length(commspp))
#   
#   # output based on metric 
#   if(metric == "total"){
#     output <- totrich
#   } else {
#     if(metric == "appearance"){
#       output <- appear
#     } else {
#       if(metric == "disappearance"){
#         output <- disappear
#       }
#     }
#   }
#   
#   # results
#   return(output)
# }
# 
# 
# # generating appearances and disappearances for each experiment ---------------------------------------------
# #make a new dataframe with just the label;
# site_code=nutnetdf_allspp%>%
#   select(site_code)%>%
#   unique()
# 
# #makes an empty dataframe
# for.analysis=data.frame(row.names=1)
# 
# for(i in 1:length(site_code$site_code)) {
#   
#   #creates a dataset for each unique site-year
#   subset=nutnetdf_allspp[nutnetdf_allspp$site_code==as.character(site_code$site_code[i]),]%>%
#     select(site_code, year, Taxon, max_cover, plot)%>%
#     group_by(site_code, year, plot, Taxon)%>%
#     summarise(max_cover=max(max_cover))%>%
#     ungroup()%>%
#     filter(max_cover>0)
#   
#   #need this to keep track of sites
#   labels=subset%>%
#     select(year, site_code)%>%
#     unique()
#   
#   #calculating appearances and disappearances (from previous year): for each year
#   appear<-turnover_allyears(df=subset, time.var='year', species.var='Taxon', abundance.var='max_cover', metric='appearance')
#   disappear<-turnover_allyears(df=subset, time.var='year', species.var='Taxon', abundance.var='max_cover', metric='disappearance')
#   total<-turnover_allyears(df=subset, time.var='year', species.var='Taxon', abundance.var='max_cover', metric='total')
#   
#   #merging back with labels to get back experiment labels
#   turnover<-merge(appear, disappear, by=c('year'))
#   turnoverAll<-merge(turnover, total, by=c('year'))
#   turnoverLabel<-merge(turnoverAll, labels, by=c('year'), all=T)
#   
#   #pasting into the dataframe made for this analysis
#   for.analysis=rbind(turnoverLabel, for.analysis)  
# }