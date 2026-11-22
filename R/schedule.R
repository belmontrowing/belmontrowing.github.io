# =============================================================================
# R/schedule.R: builds the seasonal tables and facts from schedule.xlsx
#
# Pages load this with a hidden setup chunk at the top:
#     ```{r}
#     #| include: false
#     source("../R/schedule.R")      # home page: source("R/schedule.R")
#     ```
# and then call one function per table, or `r season(...)` inside a sentence.
#
#   season(program, item)          one fact from the "seasons" tab, for sentences/headings
#                                  (case = "upper" or "lower" changes capitals)
#   session_count(program)         how many sessions a program has ("3")
#   weekly_table(program)          Sunday-Saturday practice table   (tab: practices)
#   season_summary(program)        small Season | Days | Times table (practices + seasons)
#   regatta_table(program)         Date | Regatta | Location         (tab: regattas)
#   session_table(program)         Date | Time table                 (tab: sessions)
#   session_links(program)         bold linked session lines         (tab: sessions)
#   price_table(table)             pricing tables on the Other page  (tab: prices)
#   home_events()                  "Upcoming Events" on the home page (tab: home_events)
#
# Each table function writes the same markdown a person would type (a pipe table
# inside ::: {.schedule}), so the theme styles it exactly as before.
# Needs only the R packages knitr and readxl. Check the workbook without
# rendering:  Rscript R/check-schedule.R
# =============================================================================

# ---- Names the workbook may use (the dropdowns in schedule.xlsx match these) --

.brc_days <- c("Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday")
.brc_day_abbr <- c("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat")

# For each tab: its columns, which must be filled in, which hold dates/times
# (Excel must not convert those), and the allowed names in dropdown columns.
.brc_tabs <- list(
  seasons = list(
    columns  = c("program", "item", "value"),
    required = c("program", "item", "value"),
    datelike = character(0),
    allowed  = list(
      program = c("youth", "masters-training", "masters-skills", "masters",
                  "adult-learn-to-row", "youth-summer", "collegiate", "independent"),
      item    = c("year", "term", "start", "end", "fee", "practice_days", "groups",
                  "meets", "regatta_season", "months", "register_link"))),
  practices = list(
    columns  = c("program", "day", "time", "activity", "groups"),
    required = c("program", "day", "time", "activity"),
    datelike = c("time"),
    allowed  = list(program = c("youth", "masters-training", "masters-skills"),
                    day = .brc_days)),
  regattas = list(
    columns  = c("program", "date", "regatta", "location"),
    required = c("program", "date", "regatta", "location"),
    datelike = c("date"),
    allowed  = list(program = c("youth", "masters"))),
  sessions = list(
    columns  = c("program", "dates", "time", "price", "link"),
    required = c("program", "dates", "time"),
    datelike = c("dates", "time"),
    allowed  = list(program = c("adult-learn-to-row", "youth-learn-to-row", "youth-development"))),
  prices = list(
    columns  = c("table", "item", "dates", "price"),
    required = c("table", "item", "price"),
    datelike = c("dates"),
    allowed  = list(table = c("collegiate", "private-lessons", "independent"))),
  home_events = list(
    columns  = c("heading", "link", "line", "bold", "register"),
    required = c("heading", "link", "line"),
    datelike = character(0),
    allowed  = list(bold = c("yes")))
)

# Seasons items that hold a date, so a number there means Excel converted it.
.brc_date_items <- c("start", "end")

# Headers and layout of each pricing table on the Other page.
.brc_price_tables <- list(
  "collegiate"      = list(headers = c("Program", "Pricing"),      narrow = TRUE,  bold_item = FALSE),
  "private-lessons" = list(headers = c("Lesson Packs", "Pricing"), narrow = TRUE,  bold_item = FALSE),
  "independent"     = list(headers = c("Pass", "Dates", "Cost"),   narrow = FALSE, bold_item = TRUE)
)

# ---- Finding and reading the workbook ---------------------------------------

.brc_stop <- function(..., page = FALSE) {
  fix <- if (page) {
    "\n\nThis is a mistake in a page's R call (the .qmd file), not in the workbook.\n"
  } else {
    paste0("\n\nFix it in Excel, save, close the file, and render again.\n",
           "(Run  Rscript R/check-schedule.R  to list every problem at once.)\n")
  }
  stop(paste0("\n\nPROBLEM IN schedule.xlsx\n", paste0(..., collapse = "\n"), fix), call. = FALSE)
}

# The project folder is the one holding _quarto.yml. During `quarto render`
# QUARTO_PROJECT_DIR points there; when a single page is rendered or previewed
# (e.g. from RStudio) R runs inside the page's folder, so walk up from there.
brc_project_root <- function(start = getwd()) {
  env <- Sys.getenv("QUARTO_PROJECT_DIR")
  if (nzchar(env) && file.exists(file.path(env, "_quarto.yml"))) return(normalizePath(env))
  dir <- normalizePath(start)
  repeat {
    if (file.exists(file.path(dir, "_quarto.yml"))) return(dir)
    parent <- dirname(dir)
    if (parent == dir) break
    dir <- parent
  }
  stop("Could not find the website folder (the one with _quarto.yml) above ", start, call. = FALSE)
}

# One cell from readxl (read with col_types = "list") as text, or a problem.
.brc_cell_text <- function(v, datelike) {
  if (is.null(v) || length(v) == 0 || (length(v) == 1 && is.na(v))) return(list(text = NA_character_))
  if (inherits(v, "POSIXt") || inherits(v, "Date")) {
    return(list(text = format(v, "%Y-%m-%d %H:%M"), problem = paste0(
      "Excel changed what was typed here into a date or time (it now reads ",
      format(v, "%Y-%m-%d %H:%M"), "). Format this cell as Text and retype it.")))
  }
  if (is.numeric(v)) {
    txt <- format(v, scientific = FALSE, trim = TRUE, digits = 15)
    if (datelike) {
      return(list(text = txt, problem = paste0(
        "Excel changed what was typed here into a number (", txt,
        "). Format this cell as Text and retype it.")))
    }
    return(list(text = txt))
  }
  list(text = as.character(v))
}

# Read one tab. Returns list(data = data.frame of trimmed text with an
# `.row` column holding the Excel row number, problems = character vector).
.brc_read_tab <- function(path, tab) {
  spec <- .brc_tabs[[tab]]
  raw <- suppressMessages(readxl::read_excel(path, sheet = tab, col_types = "list",
                                             .name_repair = "minimal", trim_ws = FALSE))
  names(raw) <- trimws(names(raw))
  problems <- character(0)
  missing <- setdiff(spec$columns, names(raw))
  if (length(missing)) {
    return(list(data = NULL, problems = paste0(
      "Tab '", tab, "': the column(s) ", paste0("'", missing, "'", collapse = ", "),
      " are missing from the first row. The first row must contain: ",
      paste(spec$columns, collapse = ", "), ".")))
  }
  n <- nrow(raw)
  out <- data.frame(.row = seq_len(n) + 1L, stringsAsFactors = FALSE)
  for (col in spec$columns) {
    vals <- character(n)
    for (i in seq_len(n)) {
      cell <- .brc_cell_text(raw[[col]][[i]], col %in% spec$datelike)
      txt <- cell$text
      if (!is.na(txt)) {
        txt <- gsub("\r\n?", "\n", txt)
        txt <- enc2utf8(txt)
        txt <- gsub(intToUtf8(160), " ", txt, fixed = TRUE)   # non-breaking space
        txt <- paste(trimws(strsplit(txt, "\n", fixed = TRUE)[[1]]), collapse = "\n")
        txt <- trimws(txt)
        if (!nzchar(txt)) txt <- NA_character_
      }
      vals[i] <- txt
      if (!is.null(cell$problem)) {
        problems <- c(problems, paste0("Tab '", tab, "', row ", i + 1, ", column '", col, "': ", cell$problem))
      }
    }
    out[[col]] <- vals
  }
  # Ignore fully blank rows.
  blank <- apply(is.na(out[spec$columns]), 1, all)
  out <- out[!blank, , drop = FALSE]
  rownames(out) <- NULL

  for (i in seq_len(nrow(out))) {
    r <- out$.row[i]
    for (col in spec$required) {
      if (is.na(out[[col]][i])) {
        problems <- c(problems, paste0("Tab '", tab, "', row ", r, ": the '", col,
                                       "' cell is empty. Fill it in (or delete the whole row)."))
      }
    }
    for (col in names(spec$allowed)) {
      v <- out[[col]][i]
      if (!is.na(v) && !(v %in% spec$allowed[[col]])) {
        problems <- c(problems, paste0("Tab '", tab, "', row ", r, ": '", v, "' is not a known ", col,
                                       ". Use one of: ", paste(spec$allowed[[col]], collapse = ", "), "."))
      }
    }
  }
  list(data = out, problems = problems)
}

# Checks that involve several rows or tabs.
.brc_cross_checks <- function(d) {
  problems <- character(0)
  s <- d$seasons
  if (!is.null(s)) {
    key <- paste(s$program, s$item)
    dup <- duplicated(key) & !is.na(s$program) & !is.na(s$item)
    for (i in which(dup)) {
      first <- s$.row[match(key[i], key)]
      problems <- c(problems, paste0("Tab 'seasons', row ", s$.row[i], ": program '", s$program[i],
                                     "' already has an item '", s$item[i], "' (row ", first,
                                     "). Keep only one of the two rows."))
    }
    for (i in which(s$item %in% .brc_date_items)) {
      if (!is.na(s$value[i]) && grepl("^[0-9]+(\\.[0-9]+)?$", s$value[i])) {
        problems <- c(problems, paste0("Tab 'seasons', row ", s$.row[i], ", column 'value': Excel changed the ",
                                       s$item[i], " date into a number (", s$value[i],
                                       "). Format this cell as Text and retype it."))
      }
    }
  }
  h <- d$home_events
  if (!is.null(h)) {
    for (hd in unique(stats::na.omit(h$heading))) {
      links <- unique(stats::na.omit(h$link[h$heading %in% hd]))
      if (length(links) > 1) {
        problems <- c(problems, paste0("Tab 'home_events': the heading '", hd,
                                       "' has different links on different rows (", paste(links, collapse = " and "),
                                       "). Use the same link on every row of that heading."))
      }
      regs <- unique(stats::na.omit(h$register[h$heading %in% hd]))
      if (length(regs) > 1) {
        problems <- c(problems, paste0("Tab 'home_events': the heading '", hd,
                                       "' has different register links on different rows (", paste(regs, collapse = " and "),
                                       "). Put the register link on one row of that heading only."))
      }
    }
  }
  problems
}

# Read and check the whole workbook. Returns list(data, problems, path).
brc_read_workbook <- function(root = brc_project_root()) {
  path <- file.path(root, "schedule.xlsx")
  if (!file.exists(path)) {
    return(list(data = list(), path = path,
                problems = paste0("Could not find the workbook at ", path, ".")))
  }
  sheets <- readxl::excel_sheets(path)
  data <- list(); problems <- character(0)
  for (tab in names(.brc_tabs)) {
    if (!(tab %in% sheets)) {
      problems <- c(problems, paste0("The tab '", tab, "' is missing (tabs found: ",
                                     paste(sheets, collapse = ", "), "). Tab names must not be changed."))
      next
    }
    res <- .brc_read_tab(path, tab)
    data[[tab]] <- res$data
    problems <- c(problems, res$problems)
  }
  problems <- c(problems, .brc_cross_checks(data))
  list(data = data, problems = problems, path = path)
}

.brc_env <- new.env()

# The checked workbook, read once per page. Stops the render on any problem.
.brc_data <- function() {
  if (is.null(.brc_env$data)) {
    wb <- brc_read_workbook()
    if (length(wb$problems)) .brc_stop(paste0("- ", wb$problems))
    .brc_env$data <- wb$data
  }
  .brc_env$data
}

# Rows of a tab for one program (or price table); stops if there are none.
.brc_rows <- function(tab, value, column = "program") {
  d <- .brc_data()[[tab]]
  allowed <- .brc_tabs[[tab]]$allowed[[column]]
  if (!(value %in% allowed)) {
    .brc_stop("A page asks for ", column, " '", value, "' in the '", tab, "' tab, but that name is not allowed there. ",
              "Known names: ", paste(allowed, collapse = ", "), ".", page = TRUE)
  }
  rows <- d[d[[column]] %in% value, , drop = FALSE]
  if (nrow(rows) == 0) {
    .brc_stop("A page needs rows for ", column, " '", value, "' in the '", tab,
              "' tab, but there are none. Add at least one row with ", column, " = ", value, ".")
  }
  rows
}

# ---- Markdown helpers --------------------------------------------------------

# Escape characters that markdown would treat specially, so text appears
# exactly as typed (e.g. "$200", "U19/U17", "*").
.brc_md <- function(x) {
  x <- gsub("([\\\\`*_{}\\[\\]<>#$|^~@])", "\\\\\\1", x, perl = TRUE)
  # A line starting with "-", "+" or "1." would become a list.
  x <- gsub("(^|\n)([-+])", "\\1\\\\\\2", x, perl = TRUE)
  x <- gsub("(^|\n)([0-9]+)\\.", "\\1\\2\\\\.", x, perl = TRUE)
  x
}

# Table-cell text: escaped, with in-cell line breaks shown as <br>.
.brc_cell <- function(x) {
  x[is.na(x)] <- ""
  gsub("\n", "<br>", .brc_md(x), fixed = TRUE)
}

# A pipe table inside a .schedule wrapper. `cells` is a character matrix.
# equal = TRUE gives every column the same width (the weekly tables).
.brc_table <- function(headers, cells, narrow = FALSE, equal = FALSE) {
  cells <- matrix(cells, ncol = length(headers))
  widths <- pmax(3, nchar(headers), apply(rbind(cells, ""), 2, function(col) max(nchar(col))))
  if (equal) widths[] <- 10
  line <- function(v) paste0("| ", paste(v, collapse = " | "), " |")
  rule <- paste0("|", paste(strrep("-", widths + 2), collapse = "|"), "|")
  body <- if (nrow(cells)) apply(cells, 1, line) else character(0)
  wrapper <- if (narrow) "::: {.schedule .schedule-narrow}" else "::: {.schedule}"
  knitr::asis_output(paste(c("", wrapper, line(headers), rule, body, ":::", ""), collapse = "\n"))
}

# ---- Functions used by the pages ---------------------------------------------

#' One fact from the seasons tab, for use inside a sentence or heading:
#'   The fee for the Fall season is `r season("masters-training", "fee")`.
#' case = "upper" / "lower" changes the capitals (e.g. for an all-caps title bar).
season <- function(program, item, case = c("as-is", "upper", "lower")) {
  case <- match.arg(case)
  s <- .brc_data()$seasons
  hit <- s$value[s$program %in% program & s$item %in% item]
  if (length(hit) == 0) {
    have <- s$item[s$program %in% program]
    .brc_stop("A page needs '", item, "' for program '", program, "' from the 'seasons' tab, ",
              "but there is no row with program = ", program, " and item = ", item, ".",
              if (length(have)) paste0("\nItems that program has now: ", paste(have, collapse = ", "), ".")
              else "\nThat program has no rows at all in the seasons tab.")
  }
  v <- gsub("\n", " ", hit[1], fixed = TRUE)
  v <- switch(case, upper = toupper(v), lower = tolower(v), v)
  if (item == "register_link") v else .brc_md(v)
}

#' How many sessions a program has, as text (e.g. "3"), for sentences.
session_count <- function(program) {
  as.character(nrow(.brc_rows("sessions", program)))
}

#' Sunday-Saturday table of weekly practices. Several practices on one day stack
#' in that day's cell. If any practice lists groups, a second row shows them.
weekly_table <- function(program) {
  p <- .brc_rows("practices", program)
  slot <- paste0(p$time, "\n", p$activity)
  row1 <- vapply(.brc_days, function(d) paste(.brc_cell(slot[p$day == d]), collapse = "<br>"), "")
  cells <- rbind(row1)
  if (any(!is.na(p$groups))) {
    row2 <- vapply(.brc_days, function(d) {
      g <- p$groups[p$day == d]
      paste(.brc_cell(g[!is.na(g)]), collapse = "<br>")
    }, "")
    cells <- rbind(cells, row2)
  }
  .brc_table(.brc_days, cells, equal = TRUE)
}

#' Small "Season | Days | Times" table: practices that share a time are grouped
#' (Tue/Thu), one line per time, in week order. Season = year + term.
season_summary <- function(program) {
  p <- .brc_rows("practices", program)
  p <- p[order(match(p$day, .brc_days)), , drop = FALSE]
  times <- unique(p$time)
  days <- vapply(times, function(t) {
    paste(unique(.brc_day_abbr[match(p$day[p$time == t], .brc_days)]), collapse = "/")
  }, "")
  label <- paste(season(program, "year"), season(program, "term"))
  cells <- c(label, paste(.brc_cell(days), collapse = "<br>"), paste(.brc_cell(times), collapse = "<br>"))
  .brc_table(c("Season", "Days", "Times"), matrix(cells, nrow = 1), narrow = TRUE)
}

#' Date | Regatta | Location, in the order of the rows in the tab.
regatta_table <- function(program) {
  r <- .brc_rows("regattas", program)
  .brc_table(c("Date", "Regatta", "Location"),
             cbind(.brc_cell(r$date), .brc_cell(r$regatta), .brc_cell(r$location)))
}

#' Date | Time table of sign-up sessions (Adult Learn To Row).
session_table <- function(program) {
  s <- .brc_rows("sessions", program)
  .brc_table(c("Date", "Time"), cbind(.brc_cell(s$dates), .brc_cell(s$time)))
}

#' One bold link per session: "<dates>, sessions run from <time> (<price>)".
session_links <- function(program) {
  s <- .brc_rows("sessions", program)
  for (i in seq_len(nrow(s))) {
    for (col in c("price", "link")) {
      if (is.na(s[[col]][i])) {
        .brc_stop("- Tab 'sessions', row ", s$.row[i], ": the '", col, "' cell is empty. ",
                  "Sessions for ", program, " are shown as links with their price, so they need a ", col, ".")
      }
    }
  }
  one_line <- function(x) gsub("\n", " ", x, fixed = TRUE)
  lines <- paste0("**[", .brc_md(one_line(s$dates)), ", sessions run from ", .brc_md(one_line(s$time)),
                  " (", .brc_md(one_line(s$price)), ")](", s$link, ")**")
  knitr::asis_output(paste(c("", lines, ""), collapse = "\n\n"))
}

#' A pricing table on the Other page: "collegiate", "private-lessons" or "independent".
price_table <- function(table) {
  cfg <- .brc_price_tables[[table]]
  if (is.null(cfg)) .brc_stop("price_table('", table, "'): unknown table. Known tables: ",
                              paste(names(.brc_price_tables), collapse = ", "), ".", page = TRUE)
  r <- .brc_rows("prices", table, column = "table")
  item <- .brc_cell(r$item)
  if (cfg$bold_item) item <- paste0("**", item, "**")
  cells <- if (length(cfg$headers) == 3) cbind(item, .brc_cell(r$dates), .brc_cell(r$price))
           else cbind(item, .brc_cell(r$price))
  .brc_table(cfg$headers, cells, narrow = cfg$narrow)
}

#' The "Upcoming Events" blocks on the home page: one block per heading (in the
#' order headings first appear), its lines in row order, "bold = yes" lines in bold.
#' A "register" link on any row of a heading adds a green Register button under it.
home_events <- function() {
  h <- .brc_data()$home_events
  if (is.null(h) || nrow(h) == 0) .brc_stop("The 'home_events' tab has no rows. Add at least one event line.")
  blocks <- vapply(unique(h$heading), function(hd) {
    rows <- h[h$heading %in% hd, , drop = FALSE]
    lines <- .brc_md(gsub("\n", " ", rows$line, fixed = TRUE))
    bold <- !is.na(rows$bold) & rows$bold == "yes"
    lines[bold] <- paste0("**", lines[bold], "**")
    reg <- stats::na.omit(rows$register)
    button <- if (length(reg)) paste0("\n\n::: {.btn-row}\n[Register](", reg[1], "){.btn-brc}\n:::") else ""
    paste0("::: {.event}\n### [", .brc_md(hd), "](", rows$link[1], ")\n\n",
           paste(lines, collapse = "\\\n"), button, "\n:::")
  }, "")
  knitr::asis_output(paste(c("", ":::: {.events}", "", paste(blocks, collapse = "\n\n"), "", "::::", ""),
                           collapse = "\n"))
}
