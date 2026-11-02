# Fantasy league power rankings site

Weekly FVOA power rankings, season simulations, and AI-drafted commentary for a Yahoo fantasy football league, published as a mobile-first static site.

## How it works

1. **GitHub Actions** runs `pipeline/weekly.R` every Tuesday. It scrapes Yahoo, fits the FVOA model (the `fvoa` R package), simulates the season, and writes JSON snapshots to `data/{season}/week-NN/`.
2. `pipeline/commentary.R` and `pipeline/read.R` draft the weekly take and a paragraph per team with the Claude API, then open a pull request to review. Merging the PR publishes the commentary.
3. **Vercel** rebuilds the Astro site in `web/` from `data/` whenever data lands on the main branch.

## Layout

```
league.json            every league-specific setting (name, Yahoo ID, team count, playoff spots, ...)
DESCRIPTION            R dependencies for CI (not a real package)
pipeline/              R scripts: weekly.R, export.R, export_extra.R, commentary.R, read.R, config.R, checks.R
prompts/               prompt.md, read_prompt.md, voice_examples.md
data/                  league.sqlite (history) and the weekly JSON snapshots
web/                   the Astro site
.github/workflows/     weekly-update.yml
```

## Set up a new league from this template

1. Click **Use this template** on GitHub.
2. Edit `league.json`. `season_week_offset` is the calendar week before week 1 and needs updating every August.
3. Rewrite `prompts/voice_examples.md` in the new author's voice (the files in `prompts/` use `{{placeholders}}` filled from `league.json`).
4. Create `data/league.sqlite` with the `owners`, `schedule`, and `teams` tables the pipeline reads.
5. In the repo settings, add the secret `ANTHROPIC_API_KEY`. Under Settings > Actions > General, give workflows read and write permission and allow them to create pull requests.
6. Import the repo in Vercel: Root Directory `web`, turn on "Include source files outside of the Root Directory", and set the Ignored Build Step to `git diff --quiet HEAD^ HEAD -- . ../data ../league.json`.
7. Set `site` in `web/astro.config.mjs`, and add the domain in Vercel.
8. Run the **weekly-update** workflow manually and check the data commit, the Vercel deploy, and the commentary PR.

## Things that bite

- The Yahoo league must be viewable without logging in, or the scraper fails.
- Scheduled workflows in a public repo are disabled after 60 days without activity. Re-enable the workflow each August.
- Bench-point numbers depend on the league's roster slots (`lineup_flex`, `bench_labels` in `league.json`).
- A separate scheduled workflow in any other repo for the same league will double-scrape Yahoo and open duplicate PRs.

## Run locally

- Pipeline: `Rscript pipeline/weekly.R` from the repo root.
- Site: `cd web && npm install && npm run dev`.
- Commentary: set `ANTHROPIC_API_KEY`, then `FORCE_COMMENTARY=1 Rscript pipeline/commentary.R`.
