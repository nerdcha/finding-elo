
library(dplyr)

stocktxt <-  tbl_df(read.csv('stockfish.csv'))

nSamplePoints <- 20
emptySamplePoints <- data.frame(matrix(rep(NA, nSamplePoints), nrow=1))
for(i in 1:nSamplePoints){
  names(emptySamplePoints)[i] <- paste0('SamplePoint',i)
}

getSummaryStats <- function(stockline){
  
  game <- as.numeric(strsplit(stockline$MoveScores, split = ' ')[[1]])
  gameLength <- length(game)
  
  if(gameLength < 3){
    return(cbind(data.frame(gameLength = gameLength, gameDrift = 0, gameOscillation = 0,
                      whiteGoodShare = NA, blackGoodShare = NA,
                      whiteBlunders = NA, blackBlunders = NA),
                 emptySamplePoints))
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
  

  whiteMoves <- seq(from=1, by=2, to=gameLength)
  blackMoves <- seq(from=2, by=2, to=gameLength)
  
  sampleMoves <- c(whiteMoves[floor(seq(from=1, to=length(whiteMoves), length.out = nSamplePoints/2))],
                   blackMoves[floor(seq(from=1, to=length(blackMoves), length.out = nSamplePoints/2))])
  theseSamplePoints <- emptySamplePoints
  theseSamplePoints[1,] <- game[sampleMoves]
  return(cbind(data.frame(gameLength = gameLength, gameDrift = gameDrift, gameOscillation = gameOscillation,
                    whiteGoodShare = whiteGoodShare, blackGoodShare = blackGoodShare,
                    whiteBlunders = whiteBlunders, blackBlunders = blackBlunders),
               theseSamplePoints))
}

mySummary <- stocktxt %>% rowwise() %>% do(getSummaryStats(.)) %>% ungroup()

write.csv(mySummary, file='Features/StockSummary.csv')
