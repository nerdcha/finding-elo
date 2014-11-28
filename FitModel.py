
import pandas as pd
import numpy as np
from sklearn import cross_validation
from sklearn.ensemble import GradientBoostingRegressor
from sklearn.cross_validation import KFold
from sklearn.preprocessing import Imputer


blackElo = pd.read_csv('Features/BlackElo.txt', names=['blackElo'])
whiteElo = pd.read_csv('Features/WhiteElo.txt', names=['whiteElo'])
stockfish = pd.read_csv('Features/StockSummary.csv')
outOfBook = pd.read_csv('Features/OutOfBookMove.txt', names=['OutOfBook'])
result = pd.read_csv('Features/Results.txt', names=['Result'])

movesToKeep = ['Move'+str(x) for x in range(1,41)]
samplesToKeep = ['SamplePoint'+str(x) for x in [18,19,20]]
stockfishFeatureNames = (['gameLength', 'gameDrift', 'gameOscillation', 'whiteGoodShare',
				'blackGoodShare', 'whiteBlunders', 'blackBlunders']
				+ movesToKeep + samplesToKeep)

bigX = stockfish[stockfishFeatureNames]
bigX['OutOfBook'] = outOfBook


bigX['Result'] = result['Result'].replace({'1-0': 1, '1/2-1/2': 0, '0-1': -1})

for colName in movesToKeep + samplesToKeep:
	midCode = (bigX['Result']==0) & (np.isnan(bigX[colName]))
	bigX.loc[midCode, colName] = 0
	topCode = (bigX['Result']==1) & (np.isnan(bigX[colName]))
	bigX.loc[topCode,colName] = 12400
	bottomCode = (bigX['Result']==-1) & (np.isnan(bigX[colName]))
	bigX.loc[bottomCode,colName] = -12400
	
fillWithMedian = Imputer(strategy='median', copy=False)
bigXfilled = fillWithMedian.fit_transform(bigX)


AverageElo = 0.5*blackElo['blackElo'] + 0.5*whiteElo['whiteElo']
AverageEloBC = (AverageElo/2500)**2
EloDiff = whiteElo['whiteElo'] - blackElo['blackElo']


nFolds = 10
kf = KFold(n=25000, n_folds=nFolds, shuffle=True, random_state=0)

testErrors = []

for train_index, test_index in kf:
	print('Fitting a fold.')
	trainX = bigXfilled[train_index,]
	testX = bigXfilled[test_index,]
	trainAvgBC = AverageEloBC.ix[train_index]
	testAvgBC = AverageEloBC.ix[test_index]
	trainDiff = EloDiff.ix[train_index]
	testDiff = EloDiff.ix[test_index]
	gbmAvg = GradientBoostingRegressor(verbose=0)
	gbmAvg = gbmAvg.fit(trainX, trainAvgBC)
	testPredictionAvg = 2500 * np.sqrt(gbmAvg.predict(testX))
	gbmDiff = GradientBoostingRegressor(verbose=0)
	gbmDiff = gbmDiff.fit(trainX, trainDiff)
	testPredictionDiff = gbmDiff.predict(testX)
	testPredictedWhite = testPredictionAvg + 0.5*testPredictionDiff
	testPredictedBlack = testPredictionAvg - 0.5*testPredictionDiff
	testActualWhite = whiteElo['whiteElo'].ix[test_index]
	testActualBlack = blackElo['blackElo'].ix[test_index]
	testErrors.append(float(np.mean(np.abs(np.concatenate(
				[testActualWhite - testPredictedWhite,
				 testActualBlack - testPredictedBlack])))))

print(np.mean(testErrors))

gbmAvg = GradientBoostingRegressor(verbose=0)
gbmAvg = gbmAvg.fit(bigXfilled[:25000], AverageEloBC)
testPredictionAvg = 2500 * np.sqrt(gbmAvg.predict(bigXfilled[25000:]))
gbmDiff = GradientBoostingRegressor(verbose=0)
gbmDiff = gbmDiff.fit(bigXfilled[:25000], EloDiff)
testPredictionDiff = gbmDiff.predict(bigXfilled[25000:])

prediction = pd.DataFrame({'Event': [i for i in range(25001,50001)],
							'WhiteElo': np.round(testPredictionAvg + 0.5*testPredictionDiff,1),
							'BlackElo': np.round(testPredictionAvg - 0.5*testPredictionDiff,1)} )
prediction.to_csv('predictions.csv', columns=['Event','WhiteElo','BlackElo'], index=False)



