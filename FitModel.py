
import pandas as pd
import numpy as np
from sklearn import cross_validation
from sklearn.preprocessing import Imputer
import sys
sys.path.append('/Users/jamie/xgboost/wrapper')
import xgboost as xgb
np.random.seed(31337)

blackElo = pd.read_csv('Features/BlackElo.txt', names=['blackElo'])
whiteElo = pd.read_csv('Features/WhiteElo.txt', names=['whiteElo'])
stockfish = pd.read_csv('Features/StockSummary.csv')
outOfBook = pd.read_csv('Features/OutOfBookMove.txt', names=['OutOfBook'])
result = pd.read_csv('Features/Results.txt', names=['Result'])

movesToKeep = ['Move'+str(x) for x in range(1,81,3)]
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


def ProjectElo(white, black):
	x = ((black+white)/5000)**2
	y = white - black
	return x, y

def UnprojectElo(x, y):
	blackPlusWhite = 5000 * np.sqrt(x)
	white = 0.5*(blackPlusWhite + y)
	black = 0.5*(blackPlusWhite - y)
	return white, black


class MyModel:
	def __init__(self, param_iter = 10):
		self.random_state = np.random.RandomState(seed=31337)
		self.param_iter = param_iter
	
	def fit(self, X, white, black):
		avg, diff = ProjectElo(white, black)
		
		dtrain_avg = xgb.DMatrix(X, label=avg)
		dtrain_diff = xgb.DMatrix(X, label=diff)
		xgb_params = {'max_depth':8, 'eta':0.05, 'silent':1}
		n_rounds = 300
		self.gbmAvg_ = xgb.train(xgb_params, dtrain_avg, n_rounds)
		self.gbmDiff_ = xgb.train(xgb_params, dtrain_diff, n_rounds)
	
	def predict(self, Xnew):
		dtest = xgb.DMatrix(Xnew)
		avgP = self.gbmAvg_.predict(dtest)
		diffP = self.gbmDiff_.predict(dtest)
		return UnprojectElo(avgP, diffP)


nFolds = 10
kf = cross_validation.KFold(n=25000, n_folds=nFolds, shuffle=True, random_state=0)

testErrors = []

for train_index, test_index in kf:
	print('Fitting a fold.')
	trainX = bigXfilled[train_index,]
	testX = bigXfilled[test_index,]
	trainWhite = whiteElo['whiteElo'].ix[train_index]
	trainBlack = blackElo['blackElo'].ix[train_index]
	testActualWhite = whiteElo['whiteElo'].ix[test_index]
	testActualBlack = blackElo['blackElo'].ix[test_index]
	model = MyModel()
	model.fit(trainX, trainWhite, trainBlack)
	testPredictedWhite, testPredictedBlack = model.predict(testX)
	testErrors.append(float(np.mean(np.abs(np.concatenate(
				[testActualWhite - testPredictedWhite,
				 testActualBlack - testPredictedBlack])))))


bigModel = MyModel()
bigModel.fit(bigXfilled[:25000], whiteElo['whiteElo'].iloc[:25000], blackElo['blackElo'].iloc[:25000])
predictedWhite, predictedBlack = bigModel.predict(bigXfilled[25000:])

print(np.mean(testErrors))

prediction = pd.DataFrame({'Event': [i for i in range(25001,50001)],
							'WhiteElo': np.round(predictedWhite,1),
							'BlackElo': np.round(predictedBlack,1)} )
prediction.to_csv('predictions.csv', columns=['Event','WhiteElo','BlackElo'], index=False)



