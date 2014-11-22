
library(randomForest)

blackElo <- read.table('Features/BlackElo.txt', header=FALSE)$V1
blackMoveOne <- read.table('Features/BlackMoveOne.txt', header=FALSE)$V1
blackMoveTwoRaw <- read.table('Features/BlackMoveTwo.txt', header=FALSE)$V1
whiteElo <- read.table('Features/WhiteElo.txt', header=FALSE)$V1
whiteMoveOne <- read.table('Features/WhiteMoveOne.txt', header=FALSE)$V1
whiteMoveTwoRaw <- read.table('Features/WhiteMoveTwo.txt', header=FALSE)$V1
stockfish <- read.csv('Features/StockSummary.csv')
moveTwo <- read.table('Features/MoveTwo.txt', header=FALSE)$V1

replaceWithMedian <- function(x){
  x[is.na(x)] <- median(na.omit(x))
  return(x)
}
stockfish$gameDrift <- replaceWithMedian(stockfish$gameDrift)
stockfish$gameOscillation <- replaceWithMedian(stockfish$gameOscillation)
stockfish$whiteGoodShare <- replaceWithMedian(stockfish$whiteGoodShare)
stockfish$blackGoodShare <- replaceWithMedian(stockfish$blackGoodShare)
stockfish$whiteBlunders <- replaceWithMedian(stockfish$whiteBlunders)
stockfish$blackBlunders <- replaceWithMedian(stockfish$blackBlunders)


groupMoves <- function(x, nLevels){
  factorX <- factor(x)
  topLevels <- names(sort(summary(factorX), decreasing=TRUE))[1:nLevels]
  x[!(x %in% topLevels)] <- 'Other'
  return(factor(x))
}

whiteMoveTwo <- moveTwo
whiteMoveTwo[moveTwo != 'NoMoveTwo'] <- whiteMoveTwoRaw
blackMoveTwo <- moveTwo
blackMoveTwo[moveTwo != 'NoMoveTwo'] <- blackMoveTwoRaw

whiteMoveOneGrouped <- groupMoves(whiteMoveOne, 5)
whiteMoveTwoGrouped <- groupMoves(whiteMoveTwo, 10)
blackMoveOneGrouped <- groupMoves(blackMoveOne, 5)
blackMoveTwoGrouped <- groupMoves(blackMoveTwo, 10)

openingMoves <- paste(whiteMoveOneGrouped, blackMoveOneGrouped,
                      whiteMoveTwoGrouped, blackMoveTwoGrouped)
openingMovesGrouped <- groupMoves(openingMoves, 50)

xTrainBig <- cbind(
  data.frame(WhiteMoveOne = whiteMoveOneGrouped[1:25000],
             WhiteMoveTwo = whiteMoveTwoGrouped[1:25000],
             BlackMoveOne = blackMoveOneGrouped[1:25000],
             BlackMoveTwo = blackMoveTwoGrouped[1:25000],
             OpeningMoves = openingMovesGrouped[1:25000]),
  stockfish[1:25000,])
xTestBig <- cbind(
  data.frame(WhiteMoveOne = whiteMoveOneGrouped[25001:50000],
             WhiteMoveTwo = whiteMoveTwoGrouped[25001:50000],
             BlackMoveOne = blackMoveOneGrouped[25001:50000],
             BlackMoveTwo = blackMoveTwoGrouped[25001:50000],
             OpeningMoves = openingMovesGrouped[25001:50000]),
  stockfish[25001:50000,])
yTrainBig <- data.frame(WhiteElo = whiteElo, BlackElo = blackElo,
                        AverageElo = 0.5*blackElo + 0.5*whiteElo,
                        WhiteMinusBlack = whiteElo - blackElo)
yTrainBig$AverageBC <- (yTrainBig$AverageElo/2500)**2


trainSize <- 8000
testSize <- 5000

nFolds <- 5
predictionsWhite <- matrix(NA, nrow=25000, ncol=nFolds)
predictionsBlack <- matrix(NA, nrow=25000, ncol=nFolds)
MAEs <- c()

for(foldI in 1:nFolds){
  print(sprintf('Training fold %d...', foldI))
  
  trainRows <- sample.int(n=25000, size=trainSize, replace=TRUE)
  testRows <- sample((1:25000)[-trainRows], size=testSize, replace=FALSE)
  trainDf <- cbind(xTrainBig[trainRows,],
                   yTrainBig[trainRows,])
  testDf <- cbind(xTrainBig[testRows,], yTrainBig[testRows,])
  
  featureColumnNames <- c('OpeningMoves', 'gameLength', 'gameDrift', 'gameOscillation',
                          'whiteGoodShare', 'blackGoodShare', 'whiteBlunders', 'blackBlunders')
  rf1 <- randomForest(trainDf[featureColumnNames], trainDf[['AverageBC']])
  testDf$PredictedAvg <- 2500 * sqrt(predict(rf1, newdata=testDf))
  bigPredictedAvg <- 2500 * sqrt(predict(rf1, newdata=xTestBig))
  
  rf2 <- randomForest(trainDf[featureColumnNames], trainDf[['WhiteMinusBlack']])
  testDf$PredictedDiff <- predict(rf2, newdata=testDf)
  bigPredictedDiff <- predict(rf2, newdata=xTestBig)
  
  testDf$PredictedWhite <- testDf$PredictedAvg + 0.5*testDf$PredictedDiff
  testDf$PredictedBlack <- testDf$PredictedAvg - 0.5*testDf$PredictedDiff
  
  MAEs <- c(MAEs,
            mean(c(abs(testDf$PredictedWhite - testDf$WhiteElo),
                   abs(testDf$PredictedBlack - testDf$BlackElo))))
  
  predictionsWhite[,foldI] <- bigPredictedAvg + 0.5*bigPredictedDiff
  predictionsBlack[,foldI] <- bigPredictedAvg - 0.5*bigPredictedDiff
}

finalWhitePredictions <- apply(predictionsWhite, 1, function(x){round(median(x),0)})
finalBlackPredictions <- apply(predictionsBlack, 1, function(x){round(median(x),0)})

predictions <- data.frame(Event = 25001:50000,
                          WhiteElo = finalWhitePredictions,
                          BlackElo = finalBlackPredictions)
write.csv(predictions, file='predictions.csv', row.names=FALSE)


