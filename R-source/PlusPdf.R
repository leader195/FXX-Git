#|------------------------------------------------------------------------------------------|
#|                                                                                PlusPdf.R |
#|                                                             Copyright � 2012, Dennis Lee |
#| Assert Background                                                                        |
#|    The data for this R script comes from backdoor access to various research firms.      |
#|                                                                                          |
#| Assert Function                                                                          |
#|                                                                                          |
#| Assert History                                                                           |
#|  1.0.0   This library contains external R functions to perform PDF reports manipulation. |
#|------------------------------------------------------------------------------------------|
library(R.utils)
source("~/100 FxOption/103 FxOptionVerBack/080 Fx Git/R-source/PlusReg.R")
source("~/100 FxOption/103 FxOptionVerBack/080 Fx Git/R-source/PlusFile.R")

#|------------------------------------------------------------------------------------------|
#|                            E X T E R N A L   F U N C T I O N S                           |
#|------------------------------------------------------------------------------------------|
PdfNomuraSeqNum <- function(toNum, toChr=NULL, gapNum=5, waitNum=1, silent=FALSE)
{
  #---  Assert FOUR (4) arguments:                                                   
  #       toNum:        integer value for number of PDFs to download
  #       gapNum:       integer value for number cumulative gaps between downloads before 
  #                     stop (default: 5)
  #       waitNum:      integer value for seconds to wait between EACH query (default: 1) 
  #       silent:       boolean value for displaying console messages (default: FALSE)
  
  #---  Check that arguments are valid
  if( as.numeric(toNum) < 1 ) 
    stop("toNum MUST be greater than OR equal to ONE (1)")
  if( as.numeric(gapNum) < 1 | as.numeric(gapNum) > 20 ) 
    stop("gapNum MUST be between ONE (1) and TWENTY (20)")
  if( as.numeric(waitNum) < 1 | as.numeric(waitNum) > 20 ) 
    stop("waitNum MUST be between ONE (1) and TWENTY (20)")
  if( !is.null(toChr) )
    for( i in 1:length(toChr) )
    {
      if( !RegIsEmailBln(toChr[i]) )
        stop("To recipients MUST contain valid email formats")
    }
  
  #siteChr <- "http://www.nomuranow.com/research/globalresearchportal/getpub.aspx?pid="
  siteChr <- "http://www.kelive.com/KimEng/servlet/PDFDownloadViaEmail?source=0&rid="
  suffixChr <- "&uid=32549&ky=12557"
  retFileChr <- "pdfNomura" 
  retDfr <- fileReadDfr( retFileChr )
  if( is.null(retDfr) )
    retDfr <- dataFrame( colClasses=c( pid="character" ), 
                         nrow=0 )
  
  #startIdNum <- 550344
  startIdNum <- 23287
  if( nrow(retDfr)>0 )
  {
    #--- Coerce character into numeric or date
    nextIdNum <- max( suppressWarnings( as.numeric( retDfr[, 1] ) ) ) + 1
    if( !is.na(nextIdNum) )
    {
      if( nextIdNum > startIdNum ) startIdNum <- nextIdNum
    }
  }
  
  #---  Initialize page rank
  #       Page rank is the count of gaps between pids
  #       Save last pid that has a valid PDF
  #       Set warnings to generate an error
  pr <- 0
  retNum <- 0
  sentNum <- 0
  pidNum <- startIdNum
  optWarnNum <- options()$warn
  while( pr < gapNum )
  {
    urlChr <- paste0(siteChr, pidNum, suffixChr)
    tmpFileChr <- tempfile(fileext = ".pdf")
    options(warn=2)
    errNum <- tryCatch( download.file(urlChr, tmpFileChr, mode = "wb", quiet=silent),
                        error=function(e) { 9999 }, finally={} )
    options(warn=0)
    #---  Error can occur in THREE (3) ways
    #       (1) download.file() returns an error
    #       (2) download.file() returns ok, but PDF file does not exists
    #       (3) download.file() returns ok, and PDF file exists, 
    #           but it is damaged
    if( errNum == 9999 | errNum > 0 )
      pr <- pr + 1
    else if( !file.exists(tmpFileChr) )
      pr <- pr + 1
    else
    {
      #---  Downloaded file
      #       Parse text of PDF to see if it is of interest
      #       Save last pid that is a valid PDF
      #       Move PDF from temp folder to R-nonsource
      txtChr <- pdfParseChr( tmpFileChr )
      if(is.null(txtChr))
        pr <- pr + 1
      else
      {
        pidChr <- paste0(pidNum)
        rDfr <- data.frame( pidChr )
        names(rDfr) <- names( retDfr )
        retDfr <- rDfr
        
        #---  Search for specific words
        #       (1) Filter by country
        #       (2) Filter by industry
        #       (3) Filter by company
        nonspam.dir <- paste0(RegGetRDir(),"PDF-nonspam/")
        spam01.dir  <- paste0(RegGetRDir(),"PDF-spam-01/")
        spam02.dir  <- paste0(RegGetRDir(),"PDF-spam-02/")
        if( pdfSearchCountryNum(txtChr) < 0 )
        {
          destFileChr <- paste0(spam01.dir, "NMA", pidChr, ".pdf")      
          file.rename( tmpFileChr, destFileChr )
        }
        else if( pdfSearchIndustryNum(txtChr) < 0 )
        {
          destFileChr <- paste0(spam02.dir, "NMA", pidChr, ".pdf")      
          file.rename( tmpFileChr, destFileChr )
        }
        else
        {
          #---  Move file to PDF-nonspam folder
          #       Write first 20 lines of PDF as message
          #       Mail file as attachment
          #       Optionally remove file from system
          destFileChr <- paste0(nonspam.dir, "NMA", pidChr, ".pdf")      
          if( file.rename( tmpFileChr, destFileChr ) )
          {
            msgFileChr <- sub(".pdf", ".txt", destFileChr)
            mRow <- min(20, length(txtChr))
            writeLines(txtChr[1:mRow], msgFileChr)
            
            if( !is.null(toChr) )
              if( pdfGmailNum(destFileChr, toChr=toChr, 
                              msgFileChr=msgFileChr) 
                  == 0 )
              {
                file.remove( destFileChr )
                file.remove( msgFileChr )
                sentNum <- sentNum + 1
              }
          }
        }
        
        retNum <- retNum + 1
      }
    }
    if( retNum >= toNum ) break
    pidNum <- pidNum + 1
    Sys.sleep(waitNum)
  }
  options(warn=optWarnNum)
  
  if( retNum > 0 )
  {
    formDfr <- as.data.frame(lapply(retDfr, function(x) if (is(x, "Date")) format(x, "%Y/%m/%d") else x))
    fileWriteCsv( formDfr, retFileChr )
  }
  if( !silent ) print( paste0("Total ",sentNum," pdfs sent to email.") )
  retNum
}

#|------------------------------------------------------------------------------------------|
#|                            I N T E R N A L   F U N C T I O N S                           |
#|------------------------------------------------------------------------------------------|
pdfGmailNum <- function( tmpFileChr,  toChr, ccChr=NULL, 
                         subjChr="Maybank KE Report", msgFileChr=NULL, 
                         exeChr="/usr/bin/mailx" )
{
  #---  Assert SIX (6) arguments:                                                   
  #       tmpFileChr:   a character vector for file attachments
  #       toChr:        a character vector for To recipients
  #       ccChr         a character vector for Cc recipients (default: NULL)
  #       subjChr:      a string for subject header (default: "Maybank KE Report")
  #       msgFileChr:   a string for message file (default: NULL)
  #       exeChr        a string for executable file
  #       retNum        a numeric error code (success: 0)
  
  #---  Check that arguments are valid
  if( !file.exists(tmpFileChr) )
    stop("File attachment tmpFileChr MUST exists.")
  if( !is.null(msgFileChr) )
  {
    if( !file.exists(msgFileChr) )
      stop("Message file msgFileChr MUST exists.")
  }
  for( i in 1:length(toChr) )
  {
    if( !RegIsEmailBln(toChr[i]) )
      stop("To recipients MUST contain valid email formats")
  }
  if( !is.null(ccChr) )
    for( i in 1:length(ccChr) )
    {
      if( !RegIsEmailBln(ccChr[i]) )
        stop("Cc recipients MUST contain valid email formats")
    }
  
  #---  Initialize variables
  if( length(Sys.which("mailx"))==0 )
    exChr <- exeChr
  else
    exChr <- Sys.which("mailx")
  if( length(toChr)==1 )
    tChr <- toChr
  else
  {
    tChr <- ""
    for( i in 1:length(toChr) )
      tChr <- paste(tChr,toChr[i],sep=",")
  }
  if( length(ccChr)==1 )
    cChr <- ccChr
  else
  {
    cChr <- ""
    for( i in 1:length(ccChr) )
      cChr <- paste(cChr,ccChr[i],sep=",")
  }
  
  
  dq <- "\""
  cmdChr <- paste0(dq,exChr,dq," -c ",cChr," -a ",dq,tmpFileChr,dq," -A gmail ",
                   "-s ",dq,subjChr,dq," ",tChr) 
  if( !is.null(msgFileChr) )
    cmdChr <- paste0(cmdChr, " < ",dq,msgFileChr,dq)
  errNum <- RegSystemNum(cmdChr)
  
  errNum
}

pdfParseChr <- function( tmpFileChr, exeChr="/usr/bin/pdftotext" )
{
  if( length(Sys.which("pdftotext"))==0 )
    exChr <- exeChr
  else
    exChr <- Sys.which("pdftotext")
  
  cmdChr <- paste0("\"", exChr, "\" \"", tmpFileChr, "\"")
  errNum <- RegSystemNum(cmdChr)
  
  if(errNum > 0) return(NULL)
  
  # get txt-file name and open it
  txtFileChr <- sub(".pdf", ".txt", tmpFileChr)
  fileDfr <- file.info(tmpFileChr)
  readLines(txtFileChr, warn=FALSE); 
}

pdfSearchCountryNum <- function( txtChr, retFileChr="pdfNomuraCountry" )
{
  if( nchar(retFileChr) != 0 )
    retDfr <- fileReadDfr( retFileChr )
  else
    retDfr <- NULL
  if( is.null(retDfr) )
  {
    pCountryChr <- c("Asean",
                     "Asia",
                     "Singapore", "SGD",
                     "Indonesia", "INR",
                     "Malaysia", "MYR",
                     "Hong Kong", "HKD",
                     #"China",
                     "Australia", "AUD",
                     "Canada", "CAD",
                     "Global")
    nCountryChr <- c("LatAm", "Emerging",
                     "Argentina", "ARS", "Boden", "Bonar",
                     "Brazil", "Brazilian", "BCB", "Selic",
                     "Japan", "JPY",
                     "Korea", "KRW",
                     "Taiwan", "TWD",
                     "Europe", "Eurozone", "European", "Euro Area",
                     "USA", 
                     "Mexico",
                     "Chile")                   
  }
  else
  {
    #---  Split data frame into character vectors
    #       Remove NAs from vectors
    #     Note: When editing file manually, use "NA" for NA
    pCountryChr <- retDfr[, 1]
    nCountryChr <- retDfr[, 2]
    pCountryChr <- pCountryChr[!is.na(pCountryChr)]
    nCountryChr <- pCountryChr[!is.na(nCountryChr)]
  }
  return( RegSearchNum(txtChr, pCountryChr, nCountryChr) )
}

pdfSearchIndustryNum <- function( txtChr, retFileChr="pdfNomuraIndustry" )
{
  if( nchar(retFileChr) != 0 )
    retDfr <- fileReadDfr( retFileChr )
  else
    retDfr <- NULL
  if( is.null(retDfr) )
  {
    pIndustryChr <- c("Commodity", "Commodities",
                      "Dividend",
                      "Forex",
                      "Currency", "Currencies",
                      "Equity", "Equities",
                      "Economics", "policy",
                      "FOMC", "Federal Reserve", "Chairman", "Bernanke"
    )
    nIndustryChr <- c("Health", "Health care", "Laboratories", "Biologi",
                      "patent",
                      "Fixed Income", "butterfly", "swap", "bond",
                      "coupon", "stacks",
                      "inflation", "forward real",
                      "mortgage", "loan"
    )
  }
  else
  {
    #---  Split data frame into character vectors
    #       Remove NAs from vectors
    #     Note: When editing file manually, use "NA" for NA
    pIndustryChr <- retDfr[, 1]
    nIndustryChr <- retDfr[, 2]
    pIndustryChr <- pIndustryChr[!is.na(pIndustryChr)]
    nIndustryChr <- nIndustryChr[!is.na(nIndustryChr)]
  }
  return( RegSearchNum(txtChr, pIndustryChr, nIndustryChr) )
}

#|------------------------------------------------------------------------------------------|
#|                                E N D   O F   S C R I P T                                 |
#|------------------------------------------------------------------------------------------|