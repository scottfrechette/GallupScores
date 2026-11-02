# backfill.R
# One-off: loads every week played so far into the JSON store
# (data/{season}/teams/week-NN.json), for a league that starts using this
# pipeline mid-season. Run once, locally, from the repo root, after league.json
# is filled in and owners.json and schedule.json exist for the season:
#
#   Rscript pipeline/backfill.R
#
# Then run pipeline/weekly.R as usual. Safe to re-run: each week's file is replaced.
#
# UNTESTED: mirrors the scrape step in weekly.R.

suppressPackageStartupMessages({
  library(tidyverse)
  library(lubridate)
  library(fvoa)
})

source(here::here("pipeline", "config.R"))
source(here::here("pipeline", "store.R"))

# Same week math as weekly.R
today_week <- today() %>%
  floor_date(unit = "week", week_start = 2) %>%
  week()
weeks_played <- today_week - cfg$season_week_offset - 1
current_season <- year(today())

if (weeks_played < 1) {
  stop("No weeks played yet (weeks_played = ", weeks_played,
       "). Check season_week_offset in league.json.", call. = FALSE)
}

for (w in seq_len(weeks_played)) {
  message("Week ", w, " of ", weeks_played)
  
  tmp <- get_team(w, "yahoo", leagueID = cfg$yahoo_league_id, season = current_season) %>%
    mutate(season = current_season, .before = 1)
  write_teams_week(tmp, current_season, w)
  
  Sys.sleep(5)  # be polite to Yahoo
}

message("Done. Loaded weeks 1-", weeks_played, " for ", current_season, ".")