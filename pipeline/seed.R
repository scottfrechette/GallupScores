# seed.R
# Writes a season's schedule and owners into the JSON store. Run it at the start
# of each season, and once for a new league, from the repo root:
#
#   Rscript pipeline/seed.R
#
# The schedule comes from Yahoo through fvoa::get_schedule(). Team names are
# entered by hand: the first run writes data/{season}/owners.csv with the team
# IDs and blank names. Fill in the names, then run this script again.
# Set the SEASON environment variable to seed a season other than this year's.
#
# UNTESTED: written from the glimpse() output of get_schedule().

suppressPackageStartupMessages({
  library(tidyverse)
  library(lubridate)
  library(fvoa)
})

source(here::here("pipeline", "config.R"))
source(here::here("pipeline", "store.R"))

season <- as.integer(Sys.getenv("SEASON", unset = year(today())))

# Schedule ------------------------------------------------------------------
# Each game appears twice, once from each team's side. IDs come back as text,
# so convert them to integers to match the rest of the pipeline.

schedule <- fvoa::get_schedule(league = "yahoo", leagueID = cfg$yahoo_league_id,
                               season = season) |>
  transmute(season = season, week, teamID = as.integer(teamID),
            opponentID = as.integer(opponentID))

team_ids <- sort(unique(schedule$teamID))
n_weeks <- n_distinct(schedule$week)

if (length(team_ids) != cfg$num_teams) {
  warning("The schedule has ", length(team_ids), " teams but league.json says num_teams = ",
          cfg$num_teams, call. = FALSE)
}
if (n_weeks != cfg$regular_season_weeks) {
  warning("The schedule has ", n_weeks, " weeks but league.json says regular_season_weeks = ",
          cfg$regular_season_weeks, call. = FALSE)
}

write_store_json(schedule, file.path(store_dir(season), "schedule.json"))
message("Wrote the schedule: ", n_weeks, " weeks, ", length(team_ids), " teams.")

# Owners --------------------------------------------------------------------

owners_csv <- file.path(store_dir(season), "owners.csv")

if (!file.exists(owners_csv)) {
  write_csv(tibble(teamID = team_ids, team = ""), owners_csv)
  stop("Wrote ", owners_csv, " with the team IDs. Fill in the team column with the ",
       "names you want shown, then run this script again.", call. = FALSE)
}

owners <- read_csv(owners_csv, show_col_types = FALSE) |>
  transmute(season = season, teamID = as.integer(teamID), team = as.character(team))

if (anyNA(owners$team) || any(owners$team == "")) {
  stop("Some teams in ", owners_csv, " have no name yet.", call. = FALSE)
}
if (!setequal(owners$teamID, team_ids)) {
  stop("The team IDs in owners.csv do not match the schedule's: ",
       paste(team_ids, collapse = ", "), call. = FALSE)
}
if (!cfg$commissioner_team %in% owners$team) {
  warning("commissioner_team '", cfg$commissioner_team,
          "' in league.json is not one of the team names in owners.csv", call. = FALSE)
}

write_store_json(owners, file.path(store_dir(season), "owners.json"))
message("Wrote owners.json for ", nrow(owners), " teams. Next: pipeline/backfill.R if the season is underway.")