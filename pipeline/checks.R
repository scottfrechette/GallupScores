# checks.R
# Shared output checks, sourced by commentary.R and read.R.

# Flags player names in the model's text that are not in the data it was given.
# Needs roster_names.json (written by export_extra.R). It matches full names and
# last names of 5+ letters, so it errs toward flagging; a human reviews flags.
flag_player_names <- function(out_text, data_text, names_file) {
  if (!file.exists(names_file)) return(character())
  roster <- jsonlite::fromJSON(names_file)

  strip_suffix <- function(n) sub(" (Jr\\.|Sr\\.|II|III|IV|V)$", "", n)
  last_name <- function(n) sub("^.* ", "", strip_suffix(n))

  keys <- unique(c(roster, last_name(roster)))
  keys <- keys[nchar(keys) >= 5]
  found_in <- function(txt) keys[vapply(keys, function(k) grepl(k, txt, fixed = TRUE), logical(1))]

  bad <- setdiff(found_in(out_text), found_in(data_text))
  if (length(bad)) paste("Player names not in the data:", paste(bad, collapse = ", ")) else character()
}
