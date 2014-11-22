grep 'WhiteElo' data.pgn | cut -f2 -d'"' > Features/WhiteElo.txt
grep 'BlackElo' data.pgn | cut -f2 -d'"' > Features/BlackElo.txt
grep '^1\.' data.pgn | cut -f2 -d' ' > Features/WhiteMoveOne.txt
grep '^1\.' data.pgn | cut -f3 -d' ' > Features/BlackMoveOne.txt
grep '^1\.' data.pgn | sed 's/.*2\..*/MoveTwo/g' | sed 's/^1.*/NoMoveTwo/g' > Features/MoveTwo.txt
grep '^1\.' data.pgn | cut -f5 -d' ' > Features/WhiteMoveTwo.txt
grep '^1\.' data.pgn | cut -f6 -d' ' > Features/BlackMoveTwo.txt


# ECO in PGN format accessed from http://www.interajedrez.com/v2005/ecoe.zip
# via http://www.chessvisor.com/v-aperturas.html

