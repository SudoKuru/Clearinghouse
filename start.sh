source utils.sh

print_yellow "Starting Postgres Docker..."

SECONDS=0
if [[ -z "$GENERATE_TIME_LIMIT" ]]; then
	GENERATE_TIME_LIMIT=60
fi
if [[ -z "$GENERATE_THREADS" ]]; then
	GENERATE_THREADS=1
fi
if [[ -z "$PUZZLE_FILE" ]]; then
	PUZZLE_FILE=puzzles1.txt
fi

if docker run --name sudoku-postgres -e POSTGRES_PASSWORD=sudokuru -d -p 5432:5432 postgres ; then
	print_green "Postgres Docker started successfully in $SECONDS seconds."
else
	print_yellow "sudoku-postgres already exists, attempting restart..."
	if docker start sudoku-postgres ; then
		print_green "Postgres Docker restarted successfully in $SECONDS seconds."
	else
		print_red "Postgres Docker failed to start."
		exit 1
	fi
fi

sleep 3 # Give time for database to spin up before executing commands in it

if cat ./create-puzzles-table.sql | docker exec -i sudoku-postgres psql -U postgres -d postgres ; then
	print_green "Created Puzzles table successfully."
else
	print_red "Failed to create Puzzles table."
	exit 1
fi

cat ./puzzles.sql | docker exec -i sudoku-postgres psql -U postgres -d postgres > /dev/null

touch inserts.sql
sql_query="SELECT * FROM Puzzles WHERE puzzle = '%s';"
let thread=0
total_puzzles=$(grep -c . $PUZZLE_FILE)
solved_puzzles=$(grep -c . "puzzles.sql")
total_steps=$(echo $total_puzzles-$solved_puzzles | bc)
current_step=0
for line in $(cat $PUZZLE_FILE); do
	if [[ $SECONDS -gt $GENERATE_TIME_LIMIT ]]; then
    		break
  	fi
	rows=$(printf "$sql_query" "$line" | docker exec -i sudoku-postgres psql -U postgres -d postgres -t ;)
	if [[ -z "$rows" ]]; then
		if [[ "$thread" == "$GENERATE_THREADS" ]]; then
			wait $child_pid
			let thread=0
		else
			let thread++
		fi
		$(bun GenerateInsert.ts $line >> "inserts.sql") &
		child_pid=$!

		current_step=$((current_step + 1))

		# Calculate the percentage of completion
  		percentage=$((current_step * 100 / total_steps))

  		# Fill the progress bar based on the percentage
  		filled_bar="${progress_bar:0:percentage}"

  		# Print the progress bar
  		echo -ne "\r[${filled_bar} ] ${percentage}%"
	fi
done
wait

cat inserts.sql >> puzzles.sql
cat ./inserts.sql | docker exec -i sudoku-postgres psql -U postgres -d postgres > /dev/null
rm inserts.sql

if [[ $current_step -gt 0 ]]; then
	print_green " Added $current_step new puzzles to puzzles.sql"
else
	print_green "Finished without adding any new puzzles to puzzles.sql"
fi
