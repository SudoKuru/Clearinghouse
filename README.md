# Clearinghouse

# Prerequisites

* Docker
* Bash
* npm
* bun

# Setup

1. Run `bun install`

# Usage

```bash
# Start Postgres DB, create Puzzles table to store puzzle data, and run ingest pipeline to load puzzle data
# GENERATE_TIME_LIMIT is the number of seconds the puzzle generation jobs can run before they wind down, defaults to 60
# GENERATE_THREADS is the number of threads used during puzzle generation (in addition to main thread), defaults to 1
# PUZZLE_FILE is the file with one sudoku puzzle string per line to ingest, defaults to puzzles1.txt
GENERATE_TIME_LIMIT=60 GENERATE_THREADS=1 PUZZLE_FILE=puzzles1.txt bash start.sh

# Queries the DB for the number of puzzles requested with the desired difficulty values and then runs each
# line through the export.ts script to process them into the desired compact Puzzle format used by Sudokuru Frontend local database
# Results will be written to exports.ts (type declaration can be found in Puzzle.type.ts)
# PUZZLE_COUNT is the number of puzzles that will be exported, script will fail if not enough puzzles in DB
# MIN_DIFFICULTY is the minimum difficulty (inclusive) of puzzles that will be considered for export
# MAX_DIFFICULTY is the maximum difficulty (inclusive) of puzzles that will be considered for export
PUZZLE_COUNT=2 MIN_DIFFICULTY=20 MAX_DIFFICULTY=100 bash export.sh

# Exec into the DB to run SQL commands (run exit when done)
docker exec -it sudoku-postgres psql -U postgres

# Stop Postgres DB to store puzzle data
bash stop.sh

# Delete Postgres DB to store puzzle data
bash delete.sh

# Generate difficutly report for puzzles in DB
cat ./difficulty.sql | docker exec -i sudoku-postgres psql -U postgres -d postgres > DifficultyReport.txt
```

# Ingest Pipeline (run by start.sh)

1. Insert puzzle data from puzzles.sql into the Postgres DB

2. For each puzzles in puzzles.txt (or until reach GENERATE_TIME_LIMIT):
	* Checks if the puzzle is already in the database
	* If the puzzle is not already in the database then does the following:
		* Checks if each of the GENERATE_THREADS has been assigned already to generate data for a puzzle
		* If threads are all assigned then waits until the youngest thread finishes
		* Once a thread is available it assigns it to generate puzzle data and put the insert statement in inserts.sql

3. Once all the insert statements for the new puzzles have been created they are appended to puzzles.sql

4. All the new insert statements in inserts.sql are executed and inserts.sql is deleted

# Export Pipeline (run by export.sh)

1. export.sh builds sql query using environment variables 

2. export.sh runs constructed sql query and redirects output to temp1.csv

3. export.sh cleans up the output and puts the new output in temp2.csv

4. export.sh runs export.ts using bun and redirects the output to exports.ts

5. export.ts parses temp2.csv and outputs the data in the desired format

# Puzzles

Puzzles are generated using the Sudokuru [sudoku.js fork](https://github.com/Sudokuru/sudoku.js).