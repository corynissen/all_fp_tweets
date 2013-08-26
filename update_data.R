
library(lubridate)
library(RJSONIO)
library(RCurl)
library(stringr)

tablename <- "cory_tweets"
searchterm <- "minnesota_food_poisoning"
searchterms <- c("minnesota_food_poisoning", "boston_food_poisoning",
                 "philadelphia_fp", "sanfran_food_poisoning",
                 "la_food_poisoning", "houston_food_poisoning",
                 "phoenix_food_poisoning", "jacksonville_food_poisoning")
max.id <- "0"

update.df <- function(df, tablename, searchterm){
  max.id <- max(df$tweetid[df$search_term==searchterm])
  new.df <- read.tweets(tablename, searchterm, max.id)
  if(nrow(new.df) > 0){
    new.df <- add.cols(new.df)
    new.df <- data.frame(rbind(df, new.df), stringsAsFactors=F)
  }else{
    new.df <- df
  }
  return(new.df)
}

add.cols <- function(df){
  df$text <- iconv(df$text, "WINDOWS-1252", "UTF-8")
  df$created.at2 <- gsub("\\+0000 ", "", df$created.at)
  df$created.at2 <- parse_date_time(substring(df$created.at2, 5,
                      nchar(df$created.at2)), "%b %d %H:%M:%S %Y")
  df$epoch <- as.numeric(seconds(df$created.at2))
  df$is.rt <- grepl("^RT| RT @", df$text)
  fp.url <- "http://174.129.49.183/cgi-bin/R/fp_classifier?text="
  text2 <- as.character(sapply(df$text, clean.text))
  df$classification <- sapply(text2,
                         function(x)getURI(paste0(fp.url,
                           curlPercentEncode(x))))
  df$classification <- ifelse(df$classification=="food poisoning tweet\n",
                              "Good", "Junk")
  df$status.link <- paste0('<a href="https://twitter.com/', df$author,
                           '/status/', df$tweetid,
                           '" target="_blank">View on Twitter</a>')
  return(df)
}

read.tweets <- function(tablename, searchterm, max.id){
  # throws warning is json is too long
  if(max.id==""){max.id <- "0"}
  tweets.json <-suppressWarnings(system(paste0(
      "python get_tweets_since_tweetid_from_dynamo.py '", tablename, "' '",
      searchterm, "' '", max.id, "'"), intern=T))
  tweets.json <- paste(tweets.json, collapse="")
  #tweets.json <- gsub('"', '\\\\"', tweets.json)
  tweets <- fromJSON(tweets.json)
  text <- sapply(tweets$tweets, "[[", "text")
  tweetid <- sapply(tweets$tweets, "[[", "tweetid")
  author <- sapply(tweets$tweets, "[[", "author")
  search_term <- sapply(tweets$tweets, "[[", "search_term")
  timestamp_pretty <- sapply(tweets$tweets, "[[", "timestamp_pretty")
  df <- as.data.frame(cbind(text=text, author=author, search_term=search_term,
                            tweetid=tweetid, created.at=timestamp_pretty),
                      stringsAsFactors=F)
  return(df)
}

clean.text <- function(text){
  # INPUT: Text to be "cleansed"
  # OUTPUT: Cleansed text
  # USAGE: clean.text(text) will return a string that has the punctuation removed
  #        lower case, and all other text cleaning operations done
  replace.links <- function(text){
    # extract urls from string, only works with t.co links, which all links in
    # twitter are nowadays
    return(str_replace_all(text,
                           ignore.case("http://[a-z0-9].[a-z]{2,3}/[a-z0-9]+"),
                           "urlextracted"))
  }
  remove.word <- function(string, starts.with.char){
    # INPUT:  string is a string to be edited,
    #         starts.with.char is a string or partial string to search and remove
    # OUTPUT: string with words removed
    # USAGE:  remove.word(string, "@") removes words starting with "@"
    #         remove.word(string, "RT") removes RT from string
    word.len <- nchar(starts.with.char)
    list.of.words <- strsplit(string, " ")[[1]]
    # remove ones that start with "starts.with.char"
    list.of.words <- list.of.words[!substring(list.of.words, 1,
                                              word.len)==starts.with.char]
    ret.string <- paste(list.of.words, collapse=" ")
    return(ret.string)
  }
  
  text.cleansed <- tolower(text)
  # remove the string "food poisoning" because every tweet has this in it...
  text.cleansed <- gsub("food poisoning", "", text.cleansed)
  text.cleansed <- replace.links(text.cleansed)
  text.cleansed <- remove.word(text.cleansed, "@")
  text.cleansed <- remove.word(text.cleansed, "rt")
  # replace non-letters with spaces
  text.cleansed <- gsub("[^[:alnum:]]", " ", text.cleansed)
  # remove leading and trailing spaces
  text.cleansed <- gsub("^\\s+|\\s+$", "", text.cleansed)
  # replace multiple spaces next to each other with single space
  text.cleansed <- gsub("\\s{2,}", " ", text.cleansed)
  return(text.cleansed)
}  

  

if(file.exists("all_fp.Rdata")){
  load("all_fp.Rdata")
  for(searchterm in searchterms){
    df <- update.df(df, tablename, searchterm)
  }
}else{
  df <- NULL
  for(searchterm in searchterms){
    df <- data.frame(rbind(df, read.tweets(tablename, searchterm, "0")),
                     stringsAsFactors=F)
  }
  df <- add.cols(df)

}

df <- df[!duplicated(df$tweetid),]
save(list=c("df"), file="all_fp.Rdata")


# scp -i ~/cn/chicago/keys/rserver.pem .chireply_twitter_creds ubuntu@107.22.187.183:/src/minneapolis-fp-tweets/minneapolis-fp-tweets
