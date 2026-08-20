#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
script_path <- if (length(file_arg)) {
  sub("^--file=", "", file_arg[[1]])
} else {
  "scripts/check_public_examples.R"
}
root <- normalizePath(file.path(dirname(script_path), ".."), mustWork = TRUE)

files <- c(
  file.path(root, "SKILL.md"),
  file.path(root, "README.md"),
  sort(list.files(file.path(root, "references"), pattern = "[.]md$", full.names = TRUE))
)

extract_r_blocks <- function(path) {
  lines <- readLines(path, warn = FALSE)
  blocks <- list()
  current <- character()
  in_r <- FALSE
  start <- NA_integer_

  for (i in seq_along(lines)) {
    line <- lines[[i]]
    if (!in_r && grepl("^```[rR]\\s*$", line)) {
      in_r <- TRUE
      current <- character()
      start <- i + 1L
    } else if (in_r && grepl("^```\\s*$", line)) {
      blocks[[length(blocks) + 1L]] <- list(code = current, start = start)
      in_r <- FALSE
    } else if (in_r) {
      current <- c(current, line)
    }
  }
  blocks
}

forbidden <- c(
  # Composition scripts may source the layout helper (see the output
  # contract in SKILL.md); every other source() in a public block is a
  # hidden dependency.
  external_source = "\\bsource\\s*\\((?![^)]*rfigure_layout)",
  private_qw_helper = "\\bqw_[A-Za-z0-9_]+",
  private_theme = "\\btheme_qw_[A-Za-z0-9_]+",
  uppercase_patchwork_tags = "tag_levels\\s*=\\s*['\"]A['\"]",
  uppercase_single_tag = "labs\\s*\\([^)]*tag\\s*=\\s*['\"][A-Z]['\"]"
)

checked <- 0L
for (path in files) {
  for (block in extract_r_blocks(path)) {
    checked <- checked + 1L
    code <- paste(block$code, collapse = "\n")
    for (name in names(forbidden)) {
      if (grepl(forbidden[[name]], code, perl = TRUE)) {
        stop(
          basename(path), ":", block$start,
          ": public R block contains ", name,
          call. = FALSE
        )
      }
    }
  }
}

cat(sprintf(
  "PASS: %d public R blocks are self-contained and use no uppercase default tags.\n",
  checked
))
