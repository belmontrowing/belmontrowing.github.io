# =============================================================================
# Check schedule.xlsx and print what is in it, without rendering the site.
#
#   Rscript R/check-schedule.R
#
# Runs every check the render runs. Exits with status 1 and a list of problems
# (tab, row, what to fix) if anything is wrong; otherwise prints a summary.
# Needs only the R package readxl (plus knitr, which the site needs anyway).
# =============================================================================

# Print dashes and accents properly even when the terminal's R runs in the C locale.
invisible(suppressWarnings(Sys.setlocale("LC_CTYPE", "en_US.UTF-8")))

local({
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- sub("^--file=", "", args[grepl("^--file=", args)])
  here <- if (length(file_arg)) dirname(normalizePath(file_arg[1])) else file.path(getwd(), "R")
  source(file.path(here, "schedule.R"), local = FALSE)
  assign(".check_root", brc_project_root(dirname(here)), envir = globalenv())
})

wb <- brc_read_workbook(.check_root)
cat("Workbook:", wb$path, "\n")
if (file.exists(file.path(.check_root, "~$schedule.xlsx"))) {
  cat("Note: schedule.xlsx seems to be open in Excel (~$schedule.xlsx exists).",
      "Only what has been SAVED is checked; close Excel before rendering.\n")
}

if (length(wb$problems)) {
  cat("\nPROBLEMS (", length(wb$problems), "):\n", sep = "")
  cat(paste0("- ", wb$problems, collapse = "\n"), "\n")
  cat("\nFix these in Excel, save, close the file, and run this check again.\n")
  quit(status = 1)
}

d <- wb$data
one <- function(x) gsub("\n", " / ", x, fixed = TRUE)
show <- function(title, lines) {
  cat("\n== ", title, " ==\n", sep = "")
  cat(paste0("  ", lines), sep = "\n")
}

# seasons
s <- d$seasons
for (p in unique(s$program)) {
  r <- s[s$program == p, ]
  show(paste0("seasons: ", p), sprintf("%-15s %s", r$item, one(r$value)))
}

# practices (program, then week order)
pr <- d$practices
for (p in unique(pr$program)) {
  r <- pr[pr$program == p, ]
  r <- r[order(match(r$day, .brc_days)), ]
  show(paste0("practices: ", p),
       sprintf("%-9s %-15s %-30s %s", r$day, r$time, one(r$activity), ifelse(is.na(r$groups), "", r$groups)))
}

# regattas
rg <- d$regattas
for (p in unique(rg$program)) {
  r <- rg[rg$program == p, ]
  show(paste0("regattas: ", p), sprintf("%-14s %-35s %s", r$date, r$regatta, r$location))
}

# sessions
se <- d$sessions
for (p in unique(se$program)) {
  r <- se[se$program == p, ]
  show(paste0("sessions: ", p),
       sprintf("%s | %s | %s | %s", one(r$dates), one(r$time),
               ifelse(is.na(r$price), "-", r$price), ifelse(is.na(r$link), "-", r$link)))
}

# prices
pc <- d$prices
for (p in unique(pc$table)) {
  r <- pc[pc$table == p, ]
  show(paste0("prices: ", p),
       sprintf("%-32s %-18s %s", r$item, ifelse(is.na(r$dates), "", r$dates), r$price))
}

# home events
he <- d$home_events
for (h in unique(he$heading)) {
  r <- he[he$heading == h, ]
  show(paste0("home_events: ", h, "  (links to ", r$link[1], ")"),
       paste0(ifelse(!is.na(r$bold) & r$bold == "yes", "[bold] ", ""), one(r$line)))
}

cat("\nAll checks passed.\n")
