# Belmont Rowing Center website

The website of Belmont Rowing Center, a non-profit rowing club on the Catawba River
in Belmont, NC. Built with [Quarto](https://quarto.org) and published with GitHub Pages.

## Quick start

1. Open `belmontrowing.Rproj` in RStudio (or open the folder in a terminal).
2. Edit a page: the home page is `index.qmd`; the other pages are
   `about/`, `youth/`, `adult/`, `other/`, and `contact/` (each has an `index.qmd`).
3. Preview: `quarto preview` (or RStudio's **Render** button).
4. Publish: `quarto render`, then commit and push everything, including the `docs/` folder.

Rendering needs R (https://cran.r-project.org) with three packages. Install them once,
in RStudio's Console:

```r
install.packages(c("knitr", "rmarkdown", "readxl"))
```

No Quarto on your computer? Install it from https://quarto.org/docs/get-started/, or use
the copy inside RStudio:
`/Applications/RStudio.app/Contents/Resources/app/quarto/bin/quarto render`

## Updating the schedule each season

Practice times, regattas, camp and Learn To Row sessions, fees, prices and the home
page's Upcoming Events are **all in one Excel file: `schedule.xlsx`**. The pages read
it every time the site is rendered; you never edit those dates in the pages.

1. Open `schedule.xlsx`. The first tab (README) explains each tab. One row per
   practice / regatta / session; use the dropdowns for names.
2. Save and **close** the file.
3. Optional check: `Rscript R/check-schedule.R` (lists the whole schedule, or says
   exactly which tab and row to fix).
4. Render (`quarto render` or RStudio's **Render** button) and look at the pages.

If something in the workbook is wrong, the render stops with a plain-English message
naming the tab, row and problem. The most common one: Excel turned a date like
"October 10" into a real date. Format that cell as Text and retype it.

## Where things live

- `schedule.xlsx`: everything that changes each season
- `R/schedule.R`: reads the workbook and builds the seasonal tables (`R/check-schedule.R` checks it)
- `_quarto.yml`: site title, menu, footer
- `theme.scss`: colours, fonts, and the reusable page building blocks
- `images/`: photos (`images/staff/` for coach and board portraits)
- `docs/`: the finished website (generated; don't edit by hand)

`CLAUDE.md` has the full guide: every building block with a copy-paste example,
where to change common things, and how the schedule workbook works. Claude Code reads it automatically.
