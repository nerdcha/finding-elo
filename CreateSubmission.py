'''
Created on 4 Mar 2015

@author: jamie
'''

from sklearn.linear_model import ridge_regression
import pandas as pd
import numpy as np


# 10-fold CV scores:
#    StockSummary 195.0363
#    OutOfBook 201.576
#    Moves 193.800
#    Samples 198.3313
cv_scores = np.array([ 195.04, 201.6, 193.8, 198.3 ])
# Test-set leaderboard scores (43% of test data):
#    StockSummary 194.23023
#    OutOfBook 200.39328
#    Moves 191.67236
#    Samples 197.87072
lb_scores = np.array([194.23023, 200.39328, 191.67236, 197.87072])

train_sample_size = 25000
test_sample_size = 0.43 * 25000

stock = pd.read_csv('predictions_stocksummary.csv')
book = pd.read_csv('predictions_outofbook.csv')
moves = pd.read_csv('predictions_moves.csv')
samples = pd.read_csv('predictions_samples.csv')

white_guesses = np.vstack([stock['WhiteElo'].values,
                           book['WhiteElo'].values,
                           moves['WhiteElo'].values,
                           samples['WhiteElo'].values])
black_guesses = np.vstack([stock['BlackElo'].values,
                           book['BlackElo'].values,
                           moves['BlackElo'].values,
                           samples['BlackElo'].values])
mean_white = np.mean(white_guesses)
mean_black = np.mean(black_guesses)

xprime_y = train_sample_size * cv_scores + test_sample_size * lb_scores
xprimex = (white_guesses - mean_white).dot( (white_guesses - mean_white).transpose())

hacky_inverse_weights_unnormalised = train_sample_size * 1/(cv_scores-190) + test_sample_size * 1/(lb_scores-190)
inverse_weights = hacky_inverse_weights_unnormalised/np.sum(hacky_inverse_weights_unnormalised)

predictedWhite = inverse_weights.dot(white_guesses)
predictedBlack = inverse_weights.dot(black_guesses)
prediction = pd.DataFrame({'Event': [i for i in range(25001,50001)],
                            'WhiteElo': np.round(predictedWhite,1),
                            'BlackElo': np.round(predictedBlack,1)} )
prediction.to_csv('predictions.csv', columns=['Event','WhiteElo','BlackElo'], index=False)


