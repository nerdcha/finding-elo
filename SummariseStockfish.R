
library(dplyr)

stocktxt <-  tbl_df(read.csv('stockfish.csv'))

nSamplePoints <- 20
emptySamplePoints <- data.frame(matrix(rep(NA, nSamplePoints), nrow=1))
for(i in 1:nSamplePoints){
  names(emptySamplePoints)[i] <- paste0('SamplePoint',i)
}

movesToKeep <- c(8,15,22,29,36)
nMovesToKeep <- length(movesToKeep)
emptyMovesToKeep <- data.frame(matrix(rep(NA, nMovesToKeep), nrow=1))
for(i in 1:nMovesToKeep){
  names(emptyMovesToKeep)[i] <- paste0('Move',i)
}

getSummaryStats <- function(stockline){
  
  game <- as.numeric(strsplit(stockline$MoveScores, split = ' ')[[1]])
  gameLength <- length(game)
  
  if(gameLength < 3){
    return(cbind(data.frame(gameLength = gameLength, gameDrift = 0, gameOscillation = 0,
                      whiteGoodShare = NA, blackGoodShare = NA,
                      whiteBlunders = NA, blackBlunders = NA, whiteGoodMoves=NA, blackGoodMoves=NA,
                      whiteDeltaMean = NA, gameMedian = NA, minScore=NA, maxScore=NA),
                 emptySamplePoints, emptyMovesToKeep))
  }
  diffGame <- diff(game)
  blackDiffs <- seq(from=1, by=2, to=length(diffGame))
  whiteDiffs <- seq(from=2, by=2, to=length(diffGame))
  whiteGoodShare <- sum(diffGame[whiteDiffs] > 0) / (gameLength/2)
  blackGoodShare <- sum(diffGame[blackDiffs] < 0) / (gameLength/2)
  whiteBlunders <- sum(diffGame[whiteDiffs] < -100)
  blackBlunders <- sum(diffGame[blackDiffs] > 100)
  whiteGoodMoves <- sum(diffGame[whiteDiffs] > 100)
  blackGoodMoves <- sum(diffGame[blackDiffs] < -100)
  whiteDeltaMean <- mean(diffGame[whiteDiffs])   # Thanks to Jeff Moser :)
  
  gameDrift <- median(diffGame)
  gameOscillation <- median(abs(diffGame))
  gameMedian <- median(game)
  minScore <- min(game)
  maxScore <- max(game)
  
  whiteMoves <- seq(from=1, by=2, to=gameLength)
  blackMoves <- seq(from=2, by=2, to=gameLength)
  
  whiteSampleMoves <- seq(from=1, to=length(whiteMoves), length.out = nSamplePoints/2)
  whiteShare <- whiteSampleMoves - floor(whiteSampleMoves)  
  blackShare <- 1 - whiteShare
  sampledWhiteMoves <- whiteShare * whiteMoves[floor(whiteSampleMoves)] + blackShare * blackMoves[floor(whiteSampleMoves)]

  blackSampleMoves <- seq(from=1, to=length(blackMoves), length.out = nSamplePoints/2)
  blackShare <- blackSampleMoves - floor(blackSampleMoves)  
  whiteShare <- 1 - blackShare
  whiteSampleIndices <- min(length(whiteMoves), floor(blackSampleMoves) + 1)
  sampledBlackMoves <- whiteShare * whiteMoves[whiteSampleIndices] + blackShare * blackMoves[floor(blackSampleMoves)]
  
  sampleMoves <- c(sampledWhiteMoves, sampledBlackMoves)
  
  theseSamplePoints <- emptySamplePoints
  theseSamplePoints[1,] <- game[sampleMoves]
  
  theseMovesToKeep <- emptyMovesToKeep
  theseMovesToKeep[1,] <- game[movesToKeep]
  
  return(cbind(data.frame(gameLength = gameLength, gameDrift = gameDrift, gameOscillation = gameOscillation,
                    whiteGoodShare = whiteGoodShare, blackGoodShare = blackGoodShare,
                    whiteBlunders = whiteBlunders, blackBlunders = blackBlunders,
                    whiteGoodMoves = whiteGoodMoves, blackGoodMoves = blackGoodMoves,
                    whiteDeltaMean = whiteDeltaMean, gameMedian = gameMedian,
                    minScore=minScore, maxScore=maxScore),
               theseSamplePoints, theseMovesToKeep))
}

mySummary <- stocktxt %>% rowwise() %>% do(getSummaryStats(.)) %>% ungroup()

write.csv(mySummary, file='Features/StockSummary.csv')
