grep 'WhiteElo' data.pgn | cut -f2 -d'"' > Features/WhiteElo.txt
grep 'BlackElo' data.pgn | cut -f2 -d'"' > Features/BlackElo.txt
grep '^1\.' data.pgn | cut -f2 -d' ' > Features/WhiteMoveOne.txt
grep '^1\.' data.pgn | cut -f3 -d' ' > Features/BlackMoveOne.txt
grep '^1\.' data.pgn | sed 's/.*2\..*/MoveTwo/g' | sed 's/^1.*/NoMoveTwo/g' > Features/MoveTwo.txt
grep '^1\.' data.pgn | cut -f5 -d' ' > Features/WhiteMoveTwo.txt
grep '^1\.' data.pgn | cut -f6 -d' ' > Features/BlackMoveTwo.txt




# GM game database from http://www.hoflink.com/~npollock/chess.html
# First need to fix up OS X's sed peculiarities
export LC_CTYPE=C
export LANG=C
cat gm2006.pgn | sed -n 'H;${;x;s/\n //;p;}' | awk 'NR % 4 == 0' | sort > Features/SortedGmOpenings.txt
#cat gm1981.pgn | sed -n 'H;${;x;s/\n //;p;}' | awk 'NR % 4 == 0' | sort > Features/SortedGmOpenings2.tx
# TextWrangler -- Remove Line Endings on gm1981.pgn
# then:
cat gm1981.pgn | awk 'NR % 4 == 3' > Features/SortedGmOpenings2.txt
cat Features/SortedGmOpenings.txt Features/SortedGmOpenings2.txt | sort > Features/BigSortedOpenings.txt
cut -d " " -f 1-75 Features/BigSortedOpenings.txt > Features/TrimmedGmOpenings.txt


# That unfolding doesn't seem to work on data.pgn.
# I resorted to using TextWrangler to Remove Line Breaks,
# and saved it as unfoldedData.txt

# Extract results from each game
cat unfoldedData.txt | rev | cut -d ' ' -f1 | rev > Features/Results.txt

