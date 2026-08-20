#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
script_path <- if (length(file_arg)) sub("^--file=", "", file_arg[[1]]) else "scripts/check_docs.R"
root <- normalizePath(file.path(dirname(script_path), ".."), mustWork = TRUE)

files <- c(
  file.path(root, "SKILL.md"),
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

  if (in_r) stop("Unclosed R code fence in ", path, " at line ", start - 1L)
  blocks
}

checked <- 0L
for (path in files) {
  blocks <- extract_r_blocks(path)
  for (block in blocks) {
    checked <- checked + 1L
    tryCatch(
      parse(text = block$code),
      error = function(e) {
        stop(
          basename(path), ":", block$start,
          ": invalid R code block: ", conditionMessage(e),
          call. = FALSE
        )
      }
    )
  }
}

cat(sprintf("PASS: parsed %d R code blocks in %d Markdown files.\n", checked, length(files)))
