##########################################
# Libraries
##########################################
library(dplyr)
library(tidyr)
library(modeest)
setwd("~/GitHub/kNN/PulmasCA")
##########################################
# Data cleaning
##########################################

theCounties=c("plumas","shasta","lassen","tehama","butte","sierra","nevada","yuba")
for (theCounty in theCounties) {

# theCounty="plumas"
inname=paste("originalData/FIAData_",theCounty,"CA.csv",sep="")# name of the input csv data.
df.raw=read.csv(inname,header=F)# Read the data frame that contains all the tree data measured in the county.
colnames(df.raw)=c(
  "county",
  "plotID",
  "design",
  "treeID",
  "invYr",
  "ownerCode",
  "ownerName",
  "SI",
  "diameter",
  "subplot",
  "H",
  "cuftPerAcre",
  "nTreesPerAcre",
  "BHAge",
  "totalAge",
  "speciesGroup",
  "speciesName"
)# Change column names
head(df.raw)

##########################################
# Aggregate into plot
##########################################
# Mode function picks up the name
Mode <- function(x) {
  ux <- unique(x)
  primary=ux[which.max(tabulate(match(x, ux)))]
  uxx=ux[ux!=primary]
  secondary=uxx[which.max(tabulate(match(x, uxx)))]
  return(c(primary,secondary))
}

domAge<-function(height,age){
  # ind=which.max(height)
  # domTreeHeight=height[ind]
  # domA=age[ind]
  top20=top_frac(data.frame(height),0.4)
  domTreeHeight=mean(top20$height)
  ages=c()
  for (topx in top20$height){
    ages=c(ages,age[which(height==topx)])
  }
  domA=mean(ages,na.rm=TRUE)
  return(c(domTreeHeight,domA))
}

df.raw$volPerAcre=df.raw$cuftPerAcre*df.raw$nTreesPerAcre# compute the volume per acre.

# For each plot, acquire single value for each variables of interest.
# First, create the data frame that contains all the variables that is not dependent on the primary species.
df=data.frame(
  df.raw%>%
    group_by(plotID)%>%
    summarise(
      lastInvYr=max(invYr),
      lastInvYrSD=sd(invYr),
      priSpecies=Mode(speciesGroup)[1],
      secSpecies=Mode(speciesGroup)[2],
      priSpeciesName=Mode(speciesName)[1],
      secSpeciesName=Mode(speciesName)[2],
      owner=Mode(ownerName)[1],
      ownerCD=Mode(ownerCode)[1],
      volPerAcre=sum(volPerAcre,na.rm=T),
      SI=Mode(SI)[1]
      )
  )
print(df)
# Add the dominant tree age and height as 2 extra variables to the data frame. They are dependent on the primary species.
i=0
dominantTreeAge=c()
dominantTreeHeight=c()
for (id in df$plotID) {
  i=i+1
  temp=df.raw[which(df.raw$plotID==id),]
  temp=temp[temp$speciesGroup==df$priSpecies[which(df$plotID==id)],]
  dominantTreeHeight=c(dominantTreeHeight,domAge(temp$H,temp$BHAge)[1])
  dominantTreeAge=c(dominantTreeAge,domAge(temp$H,temp$BHAge)[2])
  if(i%%10==0){
  }
}
df$dominantTreeAge=dominantTreeAge
df$dominantTreeheight=dominantTreeHeight
df.rec=df[df$lastInvYr>2006,]

# Convert the species group code to species group name using the western species group table.
# Convert the ownership code to ownership name
spcTbl=read.csv("WesternSpeciesGroup.csv")
for (i in 1:nrow(df.rec)){
  # nrow(df.rec)) {
  thePriRow=which(spcTbl$code==df.rec$priSpecies[i])
  theSecRow=which(spcTbl$code==df.rec$secSpecies[i])
  if(length(theSecRow)==0){
    theSecRow=which(spcTbl$code==49)
  }
  df.rec$priSpeciesName[i]=as.character(spcTbl$grpname[thePriRow])
  df.rec$secSpeciesName[i]=as.character(spcTbl$grpname[theSecRow])
  if(df.rec$ownerCD[i]==10){
    df.rec$owner[i]="Forest Service"
  }
  else if(df.rec$ownerCD[i]==20){
    df.rec$owner[i]="Other Federal"
  }
  else if(df.rec$ownerCD[i]==30){
    df.rec$owner[i]="State and local government"
  }
  else if(df.rec$ownerCD[i]==40){
    df.rec$owner[i]="Private and Native American" 
  }
}


# Leave the records that are measured after 2007.
head(df.rec)
###########################################
# Functions
###########################################
cr1=function(h,h0,a0,b1,b2,b3,b4){
  b3=b3
  b4=b4
  age=
    log(
      (1-(((h-4.5)/(h0-4.5))^(1/b2))*(1-exp(b1*a0)))
    )/b1
  return(age)
}
cr2=function(h,h0,a0,b1,b2,b3,b4){
  b4=b4
  L0=log(h0-4.5)
  Y0=log(1-exp(b1*a0))
  R0=0.5*((L0-b2*Y0)+sqrt(((L0-b2*Y0)^2)-4*b3*Y0))
  age=log(1-(1-exp(b1*a0))*((h-4.5)/(h0-4.5))^(1/(b2+(b3/R0))))/b1
  return(age)
}
sh1=function(h,h0,a0,b1,b2,b3,b4){
  b3=b3
  b4=b4
  r0=log(h0-4.5)-(b1*a0^b2)
  age=((log(h-4.5)-r0)/b1)^(1/b2)
  return(age)
}
sh2=function(h,h0,a0,b1,b2,b3,b4){
  r0=(log(h0-4.5)-b1-(b2*a0)^b4)/(1+(b3*a0)^b4)
  age=((log(h-4.5)-r0)/b1)^(1/b2)
  return(age)
}
#############################################
# Age estimation from growth and yield model
#############################################
spcd=read.csv("WesternSpeciesGroup_Code.csv",na.strings=c("","NA"))
baseAge=50
modelNames=as.character(unique(spcd$model))[-1]
ages=c()
models=c()
df.rec$estDomSpAge=NA
for (row in 1:nrow(df.rec)) {
  spcd.row=which(spcd$code==df.rec$priSpecies[row])
  h=df.rec$dominantTreeheight[row]
  h0=df.rec$SI[row]
  a0=baseAge
  b1=spcd$b1[spcd.row]
  b2=spcd$b2[spcd.row]
  b3=spcd$b3[spcd.row]
  b4=spcd$b4[spcd.row]
    if(spcd$model[spcd.row]=="CR1"&&!is.na(spcd$model[spcd.row])){
      print(spcd$model[spcd.row])
      ages=c(ages,cr1(h,h0,a0,b1,b2,b3,b4))
      models=c(models,spcd$model[spcd.row])
      df.rec$estDomSpAge[row]=cr1(h,h0,a0,b1,b2,b3,b4)
    }
  else if(spcd$model[spcd.row]=="CR2"&&!is.na(spcd$model[spcd.row])){
    print(spcd$model[spcd.row])
    ages=c(ages,cr2(h,h0,a0,b1,b2,b3,b4))
    models=c(models,spcd$model[spcd.row])
    df.rec$estDomSpAge[row]=cr2(h,h0,a0,b1,b2,b3,b4)
  }
  else if(spcd$model[spcd.row]=="SH1"&&!is.na(spcd$model[spcd.row])){
    print(spcd$model[spcd.row])
    ages=c(ages,sh1(h,h0,a0,b1,b2,b3,b4))
    models=c(models,spcd$model[spcd.row])
    df.rec$estDomSpAge[row]=sh1(h,h0,a0,b1,b2,b3,b4)
  }
  else if(spcd$model[spcd.row]=="SH2"&&!is.na(spcd$model[spcd.row])){
    print(spcd$model[spcd.row])
    ages=c(ages,sh2(h,h0,a0,b1,b2,b3,b4))
    models=c(models,spcd$model[spcd.row])
    df.rec$estDomSpAge[row]=sh2(h,h0,a0,b1,b2,b3,b4)
  }
  }


plot(df.rec$dominantTreeAge~df.rec$estDomSpAge)
lines(seq(0,1000),seq(0,1000))
df.rec$county=theCounty

write.csv(df.rec,paste("summaryData/",theCounty,"_summary.csv",sep=""))

}

for (csv in list.files("summaryData")){
  df=read.csv(paste("summaryData/",csv,sep=""))
  if (exists("grandData")){
    grandData=rbind(grandData,df)
  }
  else{
    grandData=df
  }
}


plot(grandData$dominantTreeAge~grandData$estDomSpAge)
lines(seq(0,1000),seq(0,1000))

xyplot(grandData$dominantTreeAge~grandData$estDomSpAge|grandData$county,
       data=grandData,
       main="Dominant species age by county",
       xlab="Estimated dominant species age (Years)",
       ylab="Observed dominant species age (Years)")
xyplot(grandData$dominantTreeAge~grandData$estDomSpAge|grandData$owner,
       data=grandData,
       main="Dominant species age by ownership",
       xlab="Estimated dominant species age (Years)",
       ylab="Observed dominant species age (Years)")
grandData.sub=grandData[grandData$priSpeciesName=="True fir"|grandData$priSpeciesName=="Douglas-fir"|grandData$priSpeciesName=="Ponderosa and Jeffrey pines",]

xyplot(grandData.sub$dominantTreeAge~grandData.sub$estDomSpAge|grandData.sub$priSpeciesName,
       data=grandData.sub,
       main="Dominant species age by primary species",
       xlab="Estimated dominant species age (Years)",
       ylab="Observed dominant species age (Years)")
smoothScatter(grandData$dominantTreeAge~grandData$estDomSpAge,
              main="Dominant species age",
              xlab="Estimated dominant species age (Years)",
              ylab="Observed dominant species age (Years)")


barchart(grandData$volPerAcre~grandData$owner,
        )











histogram(~volPerAcre|priSpeciesName,grandData,
          main="Forest stand volume distribution by primary species (Cubic feet per acre)",
          xlab="Volume per acre (cubic feet)",
          ylab="Number of plots")

###########################################
# extract the last year for each plot
###########################################
# total area and total volume are computed from Evalidator table. 
totalarea=1728234-247669-95055
totalarea# in acre. doesnt include nonstocked area.
totalvolume=5490509928-3377129#Net merchantable bole volume of live trees (at least 5 inches d.b.h./d.r.c.), in cubic feet, on forest land


###########################################
# Data output
###########################################
#outname=paste("plotData/FIAData_",theCounty,"CA_plot.csv",sep="")
#write.csv(df.rec,outname)
}


par(mfrow=c(2,3)) 
#####################################
# CR1 simulation
#####################################
# Species: True fir
h0=66# site index
a0=50# age for the site index 
b1=-0.03357
b2=1.658
b3=0
b4=0
height=c()
# simulate the height from age 1 to 200. 
for (age in 1:200){

  height[age]=4.5+(h0-4.5)*((1-exp(b1*age))/(1-exp(b1*a0)))^b2
  if (age==50){
    print(height[age])
  }
}
plot(height,xlab="Age",main="CR1 model\nSpecies: True fir",type="l",ylim=c(0,200))# plot it.
sampleHeight=df.rec$dominantTreeheight[df.rec$priSpeciesName=="True fir"]
sampleAge=df.rec$dominantTreeAge[df.rec$priSpeciesName=="True fir"]
points(sampleHeight~sampleAge)
#####################################
# CR2 simulation
#####################################
# Species: Douglas fir
h0=63# site index
a0=50# age for the site index 
b1=-0.01564
b2=-6.26
b3=38.98
height=c()
# simulate the height from age 1 to 200. 
for (age in 1:200){
  L0=log(h0-4.5)
  Y0=log(1-exp(b1*a0))
  R0=0.5*((L0-b2*Y0)+sqrt(((L0-b2*Y0)^2)-4*b3*Y0))
  height[age]=4.5+(h0-4.5)*((1-exp(b1*age))/(1-exp(b1*a0)))^(b2+(b3/R0))
  if (age==50){
    print(height[age])
  }
}
plot(height,xlab="Age",main="CR2 model\nSpecies: Douglas fir",type="l")# plot it.
sampleHeight=df.rec$dominantTreeheight[df.rec$priSpeciesName=="Ponderosa and Jeffrey pines"]
sampleAge=df.rec$dominantTreeAge[df.rec$priSpeciesName=="Ponderosa and Jeffrey pines"]
points(sampleHeight~sampleAge)

#####################################
# SH1 simulation
#####################################
# Oak
h0=70# site index
a0=50# age for the site index 
b1=-6.455
b2=-0.3725
r0=log(h0-4.5)-(b1*a0^b2)
height=c()
# simulate the height from age 1 to 200. 
for (age in 1:200){
  height[age]=4.5+exp(r0+b1*age^b2)
}
plot(height,xlab="Age",main="SH1 model\nSpecies: Oak",type="l")
sampleHeight=df.rec$dominantTreeheight[df.rec$priSpeciesName=="Oak"]
sampleAge=df.rec$dominantTreeAge[df.rec$priSpeciesName=="Oak"]
points(sampleHeight~sampleAge)
#####################################
# SH2 simulation
#####################################
# Lodgepole pine
h0=70# site index
a0=50# age for the site index 
b1=0.3879
b2=-1171
b3=194.4
b4=-0.3486

height=c()
# simulate the height from age 1 to 200. 
for (age in 1:200){
  r0=(log(h0-4.5)-b1-(b2*a0^b4))/(1+(b3*a0^b4))
  height[age]=4.5+exp(b1+r0+(b2+b3*r0)*age^b2)
}
plot(height,xlab="Age",main="SH2 model\nSpecies: Lodgepole pine",type="l")
sampleHeight=df.rec$dominantTreeheight[df.rec$priSpeciesName=="Lodgepole pine"]
sampleAge=df.rec$dominantTreeAge[df.rec$priSpeciesName=="Lodgepole pine"]
points(sampleHeight~sampleAge)
#####################################
# LG1 simulation
#####################################
# Incense cedar
h0=70# site index
a0=50# age for the site index 
b1=234.1
b2=3.923
b3=-1.237
b4=-0.3486
height=c()
# simulate the height from age 1 to 200. 
for (age in 1:200){
  L0=h0-4.5
  Y0=exp(b3*log(a0))
  r0=((L0-b1)+sqrt((L0-b1)^2+4*b2*Y0*L0))/2
  height[age]=(4.5+(b1+r0))/((1+(b2/r0)*exp(b3*log(age))))
}
plot(height,xlab="Age",main="LG1 model\n Species: Incense cedar",type="l",xlim=c(0,300),ylim=c(0,200))
sampleHeight=df.rec$dominantTreeheight[df.rec$priSpeciesName=="Incense-cedar"]
sampleAge=df.rec$dominantTreeAge[df.rec$priSpeciesName=="Incense-cedar"]
points(sampleHeight~sampleAge)
#####################################
# KP1 simulation
#####################################
# Redwood
h0=70# site index
a0=50# age for the site index 
b1=1.089
b2=-0.2131
b3=203.4
b4=-0.3486
height=c()
# simulate the height from age 1 to 200. 
for (age in 1:200){
  numerator=((a0^b1)/(h0-4.5))-b2
  denom=b3+a0^b1
  r0=numerator/denom
  height[age]=4.5+(age^b1)/(b2+b3*r0+r0*age^b1)
}
plot(height,xlab="Age",main="KP1 model\n Species: Redwood",type="l")




sampleHeight=df.rec$dominantTreeheight[df.rec$priSpeciesName=="Redwood"]
sampleAge=df.rec$dominantTreeAge[df.rec$priSpeciesName=="Redwood"]
points(sampleHeight~sampleAge)







age=log(
  1-
    (1-exp(b1*a0))*
    ((h-4.5)/(h0-4.5))
  ^(1/(b2+(b3/R0)))
  )/
  b1

(1-exp(b1*a0))*((h-4.5)/(h0-4.5))^(1/(b2+(b3/R0)))