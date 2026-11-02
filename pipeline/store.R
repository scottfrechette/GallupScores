# store.R
# Plain-JSON storage for the league's data, replacing the SQLite database.
# source() it from any script that reads or writes season data.
#
#   data/{season}/owners.json            season, teamID, team
#   data/{season}/schedule.json          season, week, teamID, opponentID
#   data/{season}/teams/week-NN.json     raw roster rows from Yahoo, one file per week
#
# JSON diffs cleanly in git and needs no database to create or seed.
#
# UNTESTED: written from the column names weekly.R already relies on.

store_dir <- function(season) here::here("data", season)

write_store_json <- function(df, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(df, path, dataframe = "rows", digits = NA,
                       na = "null", auto_unbox = TRUE)
}

# Yahoo returns team IDs as text in some places and numbers in others. Use
# integers everywhere so joins on teamID always match.
read_store_json <- function(path) {
  df <- tibble::as_tibble(jsonlite::fromJSON(path))
  for (col in intersect(c("teamID", "opponentID"), names(df))) {
    df[[col]] <- as.integer(df[[col]])
  }
  df
}

read_season_file <- function(season, name) {
  f <- file.path(store_dir(season), paste0(name, ".json"))
  if (!file.exists(f)) {
    stop(f, " not found. Write the season's ", name, " file first.", call. = FALSE)
  }
  read_store_json(f)
}

read_owners <- function(season) read_season_file(season, "owners")
read_schedule <- function(season) read_season_file(season, "schedule")

# One file per week, so a re-run replaces that week and nothing else
write_teams_week <- function(df, season, week) {
  write_store_json(
    df,
    file.path(store_dir(season), "teams", sprintf("week-%02d.json", week))
  )
}

read_teams <- function(season) {
  files <- sort(list.files(file.path(store_dir(season), "teams"),
                           pattern = "^week-[0-9]+\\.json$", full.names = TRUE))
  if (!length(files)) {
    stop("No team files for ", season, ". Run pipeline/backfill.R first.", call. = FALSE)
  }
  dplyr::bind_rows(lapply(files, read_store_json))
}