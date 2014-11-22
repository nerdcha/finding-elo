
library(dplyr)

stocktxt <-  tbl_df(read.csv('stockfish.csv'))

getSummaryStats <- function(stockline){
  game <- as.numeric(strsplit(stockline$MoveScores, split = ' ')[[1]])
  gameLength <- length(game)
  if(gameLength < 3){
    return(data.frame(gameLength = gameLength, gameDrift = 0, gameOscillation = 0,
                      whiteGoodShare = NA, blackGoodShare = NA,
                      whiteBlunders = NA, blackBlunders = NA))
  }
  diffGame <- diff(game)
  blackDiffs <- seq(from=1, by=2, to=length(diffGame))
  whiteDiffs <- seq(from=2, by=2, to=length(diffGame))
  whiteGoodShare <- sum(diffGame[whiteDiffs] > 0) / (gameLength/2)
  blackGoodShare <- sum(diffGame[blackDiffs] < 0) / (gameLength/2)
  whiteBlunders <- sum(diffGame[whiteDiffs] < -100)
  blackBlunders <- sum(diffGame[blackDiffs] > 100)
  gameDrift <- median(diffGame)
  gameOscillation <- median(abs(diffGame))
  return(data.frame(gameLength = gameLength, gameDrift = gameDrift, gameOscillation = gameOscillation,
                    whiteGoodShare = whiteGoodShare, blackGoodShare = blackGoodShare,
                    whiteBlunders = whiteBlunders, blackBlunders = blackBlunders))
}

mySummary <- stocktxt %>% rowwise() %>% do(getSummaryStats(.)) %>% ungroup()

write.csv(mySummary, file='Features/StockSummary.csv')
