
set.seed(31337)

# library(devtools)
# install_github('tqchen/xgboost/R-package')
# Using version 0.3, accessed 23 Nov 2014
library(extraTrees)

blackElo <- read.table('Features/BlackElo.txt', header=FALSE)$V1
blackMoveOne <- read.table('Features/BlackMoveOne.txt', header=FALSE)$V1
blackMoveTwoRaw <- read.table('Features/BlackMoveTwo.txt', header=FALSE)$V1
whiteElo <- read.table('Features/WhiteElo.txt', header=FALSE)$V1
whiteMoveOne <- read.table('Features/WhiteMoveOne.txt', header=FALSE)$V1
whiteMoveTwoRaw <- read.table('Features/WhiteMoveTwo.txt', header=FALSE)$V1
stockfish <- read.csv('Features/StockSummary.csv')
moveTwo <- read.table('Features/MoveTwo.txt', header=FALSE)$V1
outOfBook <- read.table('Features/OutOfBookMove.txt', header=FALSE)$V1
result <- read.table('Features/Results.txt', header=FALSE)$V1

replaceWithMedian <- function(x){
  x[is.na(x)] <- median(na.omit(x))
  return(x)
}
for(stockColumn in names(stockfish)){
  stockfish[[stockColumn]] <- replaceWithMedian(stockfish[[stockColumn]])
}



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
  data.frame(OutOfBook = outOfBook[1:25000],
             Result = factor(result[1:25000])),
  stockfish[1:25000,])
xTestBig <- cbind(
  data.frame(OutOfBook = outOfBook[25001:50000],
             Result = factor(result[25001:50000])),
  stockfish[25001:50000,])
yTrainBig <- data.frame(WhiteElo = whiteElo, BlackElo = blackElo,
                        AverageElo = 0.5*blackElo + 0.5*whiteElo,
                        WhiteMinusBlack = whiteElo - blackElo)
yTrainBig$AverageBC <- (yTrainBig$AverageElo/2500)**2


movesToKeep <- c(1:40)
nMovesToKeep <- length(movesToKeep)
moveNames <- c()
for(i in 1:nMovesToKeep){
  moveNames <- c(moveNames, paste0('Move',i))
}

featureColumnNames <- c('gameLength', 'gameDrift', 'gameOscillation',
                        'whiteGoodShare', 'blackGoodShare', 'whiteBlunders', 'blackBlunders',
                        'SamplePoint18', 'SamplePoint19', 'SamplePoint20',
                        moveNames,
                        'OutOfBook', 'Result')
xTestBigMatrix <- model.matrix(as.formula(paste('~ 0 +',
                                                paste(featureColumnNames, collapse="+"))), xTestBig)


trainSize <- 1000
testSize <- 5000

nFolds <- 20
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
  
  trainMatrix <- model.matrix(as.formula(paste('~ 0 +', paste(featureColumnNames, collapse="+"))), trainDf)
  testMatrix <- model.matrix(as.formula(paste('~ 0 +', paste(featureColumnNames, collapse="+"))), testDf)
  
  et1 <- extraTrees(trainMatrix, trainDf[['AverageBC']], nodesize=10, ntree=500, numRandomCuts=3)
  testDf$PredictedAvg <- 2500 * sqrt(predict(et1, newdata=testMatrix))
  bigPredictedAvg <- 2500 * sqrt(predict(et1, newdata=xTestBigMatrix))
  
  et2 <- extraTrees(trainMatrix, trainDf[['WhiteMinusBlack']], nodesize=10, ntree=500, numRandomCuts=3)
  
  testDf$PredictedDiff <- predict(et2, newdata=testMatrix)
  bigPredictedDiff <- predict(et2, newdata=xTestBigMatrix)
  
  testDf$PredictedWhite <- testDf$PredictedAvg + 0.5*testDf$PredictedDiff
  testDf$PredictedBlack <- testDf$PredictedAvg - 0.5*testDf$PredictedDiff
  
  thisMAE <- mean(c(abs(testDf$PredictedWhite - testDf$WhiteElo),
                    abs(testDf$PredictedBlack - testDf$BlackElo)))
  MAEs <- c(MAEs,thisMAE)
  print(thisMAE)
  
  predictionsWhite[,foldI] <- bigPredictedAvg + 0.5*bigPredictedDiff
  predictionsBlack[,foldI] <- bigPredictedAvg - 0.5*bigPredictedDiff
}

print(mean(MAEs))

finalWhitePredictions <- apply(predictionsWhite, 1, function(x){round(median(x),0)})
finalBlackPredictions <- apply(predictionsBlack, 1, function(x){round(median(x),0)})

predictions <- data.frame(Event = 25001:50000,
                          WhiteElo = finalWhitePredictions,
                          BlackElo = finalBlackPredictions)
write.csv(predictions, file='predictions.csv', row.names=FALSE)


