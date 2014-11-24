
library(dplyr)

openings <- tbl_df(read.table('Features/TrimmedGmOpenings.txt', header=FALSE, sep=' ', fill=TRUE))

stopifnot(ncol(openings) %% 3 == 0)
maxOpeningDepth <- ncol(openings)/3

# The openings textfile include move numbers, so prepare to trim them out
moveIndices <- (1:ncol(openings))
moveIndices <- moveIndices[-which(moveIndices %% 3 == 1)] 
openings <- openings[,moveIndices]

openingTree <- list()

addToTree <- function(gameData, thisColumn){
  possibleMoves <- unique(gameData[[thisColumn]])
  moveFrequencies <- unlist(Map(function(i) sum(gameData[[thisColumn]] == possibleMoves[i]),
                                1:length(possibleMoves)))
  names(moveFrequencies) <- possibleMoves
  if(thisColumn == maxOpeningDepth){
    return(list(Frequency = moveFrequencies, ChosenMoves = NULL))
  }
  nextMoves <- list()
  for(chosenMove in possibleMoves){
    if(thisColumn == 1){
      print(chosenMove)
    }
    followingMoves <- gameData %>% filter(gameData[[thisColumn]] == chosenMove)
    nextMoves[[chosenMove]] <- addToTree(followingMoves, thisColumn + 1)
  }
  return(list(Frequency = moveFrequencies, ChosenMoves = nextMoves))
}


print('Parsing opening book...')
openingTree <- addToTree(openings,1)
print('Done.')

data <- readLines('unfoldedData.txt')

minimumOpeningTreeNodeSize <- 4
outOfBookThresholdPercent <- 5
outOfBookMoves <- rep(NA, length(data))
for(gameI in 1:length(data)){
  thisGame <- data[gameI]
  splitGame <- strsplit(thisGame, split=' ')[[1]]
  gameMoveIndices <- (1:length(splitGame))
  splitGame <- splitGame[-which(gameMoveIndices %% 3 == 1)] 
  thisOpeningTree <- openingTree
  for(moveI in 1:min(length(splitGame), maxOpeningDepth)){
    thisMove <- splitGame[moveI]
    totalGamesInThisNode <- sum(thisOpeningTree$Frequency)
    if(totalGamesInThisNode < minimumOpeningTreeNodeSize){
      break
    }
    thisMovePercent <- 100*thisOpeningTree$Frequency[thisMove] / totalGamesInThisNode
    if(is.na(thisMovePercent)){
      thisMovePercent <- 0
    }
    if(thisMovePercent < outOfBookThresholdPercent){
      break
    }
    thisOpeningTree <- thisOpeningTree$ChosenMoves[[thisMove]]
  }
  outOfBookMoves[gameI] <- moveI
}


write(outOfBookMoves, file='Features/OutOfBookMove.txt', ncolumns=1, sep='\n')




