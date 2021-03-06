#########################################################################################
# Author: Bikash Agrawal
# Date: 28-06-2014
# Description: This example is used to calculate  Kmean clustering
# source("/home/bikash/repos/r2time/examples/Kmean.R")
#########################################################################################

## Load all the necessary libraries
library(r2time)
library(Rhipe)
rhinit()	## Initialize rhipe framework.
library(rJava)
.jinit()    ## Initialize rJava
r2t.init()  ## Initialize R2Time  framework.
library(bitops) ## Load library for bits operation, It is used for conversion between float and integer numbers.
library(gtools)


tagk = c("host") ## Tag keys. It could be list
tagv = c("*")	## Tag values. It could be list or can be separate multiple by pipe
metric = 'r2time.load.test1' ## Assign multiple metrics
startdate ='2000/01/20-00:00:00' ## Start date and time of timeseries
enddate ='2000/02/17-10:00:00' ## End date and time of timeseries
output = "/home/bikash/tmp/ex1.1" ## Output file, should be in HDFS file system.
jobname= "Kmean clustering example 1.1 for 25 million data points" ## Assign relevant job description name.
mapred <- list(mapred.reduce.tasks=0) ## Mapreduce configuration, you can assign number of mapper and reducer for a task. For this case is 0, no reducer is required.


## Calculate
# rhput("/home/ekstern/haisen/bikash/jar/r2time.jar", "/home/ekstern/haisen/bikash/tmp/r2time.jar")
# rhput("/home/ekstern/haisen/bikash/asynchbase.jar", "/home/ekstern/haisen/bikash/tmp/asynchbase.jar")
# rhput("/home/ekstern/haisen/bikash/hbase.jar" , "/home/ekstern/haisen/bikash/tmp/hbase.jar")
# rhput("/home/ekstern/haisen/bikash/zookeeper.jar" , "/home/ekstern/haisen/bikash/tmp/zookeeper.jar")
jars=c("/home/ekstern/haisen/bikash/tmp/r2time.jar","/home/ekstern/haisen/bikash/tmp/zookeeper.jar", "/home/ekstern/haisen/bikash/tmp/hbase.jar")
# This jars need to be in HDFS file system. You can copy jar in HDFS using RHIPE rhput command

## Assign Zookeeper configuration. For HBase to read data zookeeper quorum must be define.
zooinfo=list(zookeeper.znode.parent='/hbase',hbase.zookeeper.quorum='haisen24.ux.uis.no')

map.setup = expression({
    x <- load("/home/ekstern/haisen/bikash/tmp/centers.Rdata") # no need to give full path
    c1 <- get(x[1])
    c2 <- get(x[2])
})

## running map function to caculate centroid
map <- expression({
    library(bitops)
    library(r2time)
    library(gtools)
    m <- lapply(seq_along(map.values), function(r) {
        attr <- names(map.values[[r]])
        val  <- map.values[[r]]
        k1<-r2t.getRowBaseTimestamp(map.keys[[r]])
        v <- lapply(seq_along(attr), function(l) {
            # del <- gsub("t:","",attr[l]) #convert to delta value
            # k <- k1 + strtoi(del)
            v <- r2t.toInt(val[[l]])
            # list(k,v)
            #d<-data.frame(col.x=k, col.y=v, stringsAsFactors=FALSE)
        })
        k <- r2t.getRealTimestamp(k1,val)
        d <- data.frame(col.x=unlist(k), col.y=unlist(v), stringsAsFactors=FALSE)
    })
    y<-data.frame()#data frame
    for(i in 1:length(m))
    {
        y <- rbind(y,m[[i]])
    }
    if(nrow(y) > 0)
    {
        col.x = y[,1]
        col.y = y[,2]
        c1<-c1
        c2<-c2
        centerMat<-rbind(c1,c2)
        #forming the full data frame
        d<-data.frame(col.x=col.x, col.y=col.y, stringsAsFactors=FALSE)
        #Appeding the center matrix to the top of the data frame
        dmat<-rbind(centerMat,as.matrix(d))
        #Finding the euclidean distance
        reqMat<-(as.matrix(dist(dmat,method="euclidean")))[4:nrow(y),1:2]
        #creating three data frame for three different centers
        d1<-data.frame()#data frame for centre1
        d2<-data.frame()#data frame for centre2
        for( i in 1:nrow(reqMat) )
        {
            minimum = which.min(reqMat[i,])
            if(minimum==1)      d1<-rbind(d1,d[i, ])
            else if(minimum==2) d2<-rbind(d2,d[i, ])
        }
        # rhcollect(c1,d1)
        # rhcollect(c2,d2)
    }
 })


## create inital centroids with k =2 choosen randomly
c1 <-c(954021600,4824)
c2 <-c(953712000,2555)

#writing the centers to a file
write("Initial Centers",file="/home/ekstern/haisen/bikash/tmp/centers",append=TRUE)
write(c1,file="/home/ekstern/haisen/bikash/tmp/centers",append=TRUE)
write(c2,file="/home/ekstern/haisen/bikash/tmp/centers",append=TRUE)
write("---------------------------------------------",file="/home/ekstern/haisen/bikash/tmp/centers",append=TRUE)
#rhsave(c1,c2,file="/home/bikash/tmp/centers.Rdata")
save(c1,c2,file="/home/ekstern/haisen/bikash/tmp/centers.Rdata")

outputdir <- "/home/ekstern/haisen/bikash/r2time/kmean/out01"
breakFlag <- FALSE
for( j in 1:3)
{
	# if(!breakFlag)
 #    {
        if( j > 1)
        	rhdel("/home/ekstern/haisen/bikash/r2time/kmean/out01") #delete after you run mapreduce.
        ## Run job in R2Time.
    	r2t.job(table='tsdb',sdate=startdate, edate=enddate, metrics=metric, tagk=tagk, tagv=tagv, jars=jars, zooinfo=zooinfo,
    	output=outputdir, jobname=jobname, mapred=mapred, map=map, reduce=0, setup=map.setup)
        ## Read Output file
        output<-rhread("/home/ekstern/haisen/bikash/r2time/kmean/out01")
        centers<-list(output[[1]][[1]],output[[2]][[1]])
        # center1<-c(mean(output[[1]][[2]]$col.x),mean(output[[1]][[2]]$col.y))
        # center2<-c(mean(output[[2]][[2]]$col.x),mean(output[[2]][[2]]$col.y))
        center1<-c(mean(output[[1]][[2]]$col.x),mean(output[[1]][[2]]$col.y))
        center2<-c(mean(output[[2]][[2]]$col.x),mean(output[[2]][[2]]$col.y))
        cat(c1)
        cat(c2)
      	for(i in 1:length(centers))
        {
            if((identical(center1,c1)) && (identical(center2, c2)))
            {
                breakFlag <- TRUE
                break
            }
            if(identical(centers[[i]],c1))
                c1 = center1
            else if(identical(centers[[i]], c2))
                c2 = center2
        }
        #writing the new centers to a file
        write(paste("Center After iteration",j,sep=":"),file="/home/ekstern/haisen/bikash/tmp/centers",append=TRUE)
        write(c1,file="/home/ekstern/haisen/bikash/tmp/centers",append=TRUE)
        write(c2,file="/home/ekstern/haisen/bikash/tmp/centers",append=TRUE)
        write("---------------------------------------------",file="/home/ekstern/haisen/bikash/tmp/centers",append=TRUE)
        #deleting the previous centers and output
        #rhdel("/home/bikash/tmp/centers.Rdata")
        fn <- "/home/ekstern/haisen/bikash/tmp/centers.Rdata"
        if (file.exists(fn)) file.remove(fn)
        #saving the new centers
        #rhsave(c1,c2,file="/home/bikash/tmp/centers.Rdata")
        save(c1,c2,file="/home/ekstern/haisen/bikash/tmp/centers.Rdata")
        # df <- data.frame(c1,c2)
        # write.table(df,'centers', col.names=TRUE)
    # }
}
#########################################################################################

