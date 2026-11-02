# Setup -------------------------------------------------------------------

# Load packages
suppressPackageStartupMessages(library(tidyverse))
suppressPackageStartupMessages(library(lubridate))
suppressPackageStartupMessages(library(fvoa))

source(here::here("pipeline", "config.R"))  # league settings from league.json
source(here::here("pipeline", "store.R"))   # JSON storage for season data

# Use all available cores for rstanarm sampling
options(mc.cores = parallel::detectCores())

# Identify current week
today_week <- today() %>%
  floor_date(unit = "week", week_start = 2) %>%
  week()
start_week <- cfg$season_week_offset  # update each August
current_week <- today_week - start_week
weeks_played <- current_week - 1
current_season <- year(today())

# NEW: skip cleanly outside the season so the Tuesday cron doesn't fail
# in the offseason
if (weeks_played < 1 || weeks_played > cfg$last_data_week) {
  message("Outside season (weeks_played = ", weeks_played, "), nothing to do")
  quit(save = "no", status = 0)
}

# Scrape Data -------------------------------------------------------------

gallup_team_tmp <- get_team(weeks_played, 'yahoo', leagueID = cfg$yahoo_league_id, season = current_season) %>% 
  mutate(season = current_season, .before = 1)

# One file per week (data/{season}/teams/week-NN.json); a re-run replaces the week
write_teams_week(gallup_team_tmp, current_season, weeks_played)
rm(gallup_team_tmp)

# Sys.sleep(60)

gallup_wp_tmp <- get_win_prob(current_week, leagueID = cfg$yahoo_league_id) %>% 
  mutate(season = current_season,
         week = current_week, .before = 1)

# Collect Results ---------------------------------------------------------

gallup_owners <- read_owners(current_season) %>% 
  select(teamID, team)
gallup_schedule <- read_schedule(current_season) %>% 
  left_join(gallup_owners, by = "teamID") %>% 
  left_join(select(gallup_owners, opponent = team, opponentID = teamID),
            by = "opponentID") %>% 
  select(season, week, team, opponent)
gallup_team <- read_teams(current_season) %>% 
  left_join(gallup_owners, by = "teamID") %>% 
  select(week, team, score:points)
gallup_scores <- extract_scores(gallup_team)
gallup_proj <- extract_projections(gallup_team)
gallup_wp <- gallup_wp_tmp %>%
  left_join(gallup_owners, by = "teamID") %>% 
  select(week, team, wp) %>% 
  mutate(wp = scales::percent(wp, accuracy = 1))

if (max(gallup_scores$week) != weeks_played) {stop("Did not collect previous week scores")}

# Fit Model ---------------------------------------------------------------

gallup_fit_season <- fit_team_season(gallup_scores)
gallup_fit <- slice_tail(gallup_fit_season, n = 1)$model[[1]]
gallup_draws <- fvoa:::extract_team_draws(gallup_fit)

# Run Simulations ---------------------------------------------------------

set.seed(42)
gallup_simulated_scores <- simulate_season_scores(gallup_schedule, gallup_fit)
gallup_simulated_standings <- simulate_season_standings(gallup_simulated_scores)
gallup_simulated_final_standings <- simulate_final_standings(gallup_simulated_standings)
set.seed(42)
gallup_simulated_records <- simulate_final_standings_season(gallup_fit_season, gallup_schedule)

# Run Calculations --------------------------------------------------------

gallup_current_matchups <- compare_current_matchups(gallup_schedule, gallup_fit, gallup_wp, quality = T, gallup_simulated_standings) %>%
  select(-Yahoo)
# compare_playoff_teams() was removed here: it hardcoded this league's team names
# and its result was not saved or used
gallup_fvoa_season <- calculate_fvoa_season(gallup_fit_season)
gallup_rankings <- calculate_rankings(gallup_schedule, gallup_fit) %>% 
  set_names("Team", "PF", "PA", 
            "Record", "WP", "Yahoo Rank", 
            "FVOA", "FVOA Rank",
            "SOS Favored", "SOS", "SOS Rank", 
            "SOS Played Favored", "SOS Played Avg FVOA", "SOS Played Margin", "SOS Played", "SOS Played Rank",
            "SOS Remaining Favored", "SOS Remaining", "SOS Remaining Rank",
            "SOR", "SOR Rank",
            "Colley Rating", "Colley Rank")
gallup_lines <- compare_league(gallup_fit) %>% 
  fvoa:::spread_league(.output = "spread") %>% 
  rename(Team = team)
gallup_lineup_eval <- gallup_team %>% 
  evaluate_lineup(flex = cfg$lineup_flex) %>% 
  plot_roster_skills()
gallup_model_eval <- evaluate_model(gallup_fit_season)
gallup_playoff_leverage <- plot_playoff_leverage(gallup_simulated_standings)
gallup_schedule_luck <- plot_schedule_luck(gallup_schedule, gallup_scores, gallup_owners, sims = 1000)
gallup_sim_standings_df <- crossing(team = unique(gallup_scores$team), 
                                 rank = seq_len(cfg$num_teams)) %>% 
  left_join(count(gallup_simulated_standings, team, rank),
            by = c("team", "rank")) %>% 
  replace_na(list(n = 0)) %>% 
  mutate(pct = n / sum(n),
         .by = "team") %>% 
  select(-n) %>% 
  # mutate(pct = scales::percent(pct)) %>% 
  spread(rank, pct) %>% 
  arrange(across(all_of(as.character(seq_len(cfg$num_teams))), \(x) -x))

# Save Data ---------------------------------------------------------------

# JSON snapshots -> data/{season}/week-{NN}/
source(here::here("pipeline", "export.R"))
source(here::here("pipeline", "export_extra.R"))