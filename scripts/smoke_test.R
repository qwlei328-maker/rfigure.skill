#!/usr/bin/env Rscript

options(warn = 1)

script_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
script_dir <- dirname(normalizePath(script_file[[1L]], mustWork = TRUE))
source(file.path(script_dir, "rfigure_helpers.R"))

qw_require("ggplot2")
qw_require("patchwork")
qw_assert_font("Arial")

cjk <- tryCatch(qw_cjk_family(), error = function(e) NA_character_)
if (!is.na(cjk)) {
  cjk_theme <- theme_qw_pub_cjk(family = cjk)
  stopifnot(
    identical(cjk_theme$text$family, cjk),
    identical(cjk_theme$axis.text$family, cjk),
    identical(cjk_theme$legend.text$family, cjk),
    identical(cjk_theme$strip.text$family, cjk)
  )
}

cst <- qw_constants()
stopifnot(
  abs(cst$line - 25.4 / 72) < 1e-12,
  cst$data_line / cst$line >= 1.7,
  cst$text_pt == 8
)

audit_data <- qw_data_audit(
  data.frame(x = c(1, 2, NA, Inf), y = c(0, 1, 2, 3)),
  variables = c("x", "y"),
  log_variables = "y"
)
stopifnot(
  audit_data$missing[audit_data$variable == "x"] == 1,
  audit_data$nonfinite[audit_data$variable == "x"] == 1,
  audit_data$log_invalid[audit_data$variable == "y"] == 1,
  all(audit_data$duplicate_rows == 0)
)

palette <- c(Observed = "#0072B2", Predicted = "#D55E00")
palette_result <- qw_palette_audit(palette)
stopifnot(nrow(palette_result) == 2L, all(is.finite(palette_result$contrast_vs_background)))

p <- ggplot2::ggplot(
  mtcars,
  ggplot2::aes(wt, mpg, colour = factor(cyl), shape = factor(cyl))
) +
  ggplot2::geom_point(size = 1.8) +
  ggplot2::labs(
    x = "Vehicle mass (1000 lb)",
    y = "Fuel economy (mpg)",
    colour = "Cylinders",
    shape = "Cylinders",
    alt = paste(
      "Scatter plot of vehicle mass and fuel economy.",
      "Fuel economy generally decreases as mass increases; symbols identify cylinder count."
    )
  ) +
  theme_qw_pub()

plot_audit <- qw_plot_audit(p)
stopifnot(plot_audit$ok, nzchar(plot_audit$alt))

p_fixed <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) +
  ggplot2::geom_point() +
  ggplot2::coord_fixed() +
  theme_qw_pub()
stopifnot(is.finite(qw_panel_ratio(p_fixed)), qw_panel_ratio(p_fixed) > 0)

inset_geometry <- qw_inset_geometry(
  p_fixed, p_fixed, inset_height = 0.25,
  right = 0.9, bottom = 0.1
)
stopifnot(
  abs(inset_geometry$inset_width - 0.25) < 1e-12,
  abs(inset_geometry$left - 0.65) < 1e-12,
  abs(inset_geometry$top - 0.35) < 1e-12
)

stopifnot(
  identical(qw_p_label(0.0002), "italic(p) < 0.001"),
  grepl("italic\\(R\\)\\^2", qw_r2_label(0.82)),
  grepl("\n", qw_wrap_text(paste(rep("caption", 20), collapse = " "), width = 40))
)

output_dir <- file.path(tempdir(), "rfigure-smoke")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
png_path <- file.path(output_dir, "smoke.png")
svg_path <- file.path(output_dir, "smoke.svg")
pdf_path <- file.path(output_dir, "smoke.pdf")
tiff_path <- file.path(output_dir, "smoke.tiff")
patchwork_path <- file.path(output_dir, "smoke-patchwork.png")
for (path in c(png_path, svg_path, pdf_path, tiff_path, patchwork_path)) {
  if (file.exists(path)) unlink(path)
  if (file.exists(paste0(path, ".manifest.tsv"))) unlink(paste0(path, ".manifest.tsv"))
}

qw_save(p, png_path, width_mm = 85, height_mm = 60)
qw_save(p, svg_path, width_mm = 85, height_mm = 60)
qw_save(p, pdf_path, width_mm = 85, height_mm = 60)
qw_save(p, tiff_path, width_mm = 85, height_mm = 60)
qw_save(
  p | p, patchwork_path,
  width_mm = 170, height_mm = 60,
  alt = "Two matching scatter-plot panels used to test composite alt text."
)
stopifnot(
  file.info(png_path)$size > 0,
  file.info(svg_path)$size > 0,
  file.info(pdf_path)$size > 0,
  file.info(tiff_path)$size > 0,
  file.info(patchwork_path)$size > 0,
  all(file.exists(paste0(
    c(png_path, svg_path, pdf_path, tiff_path, patchwork_path),
    ".manifest.tsv"
  )))
)

manifest <- utils::read.delim(paste0(png_path, ".manifest.tsv"), stringsAsFactors = FALSE)
stopifnot(all(c(
  "device", "created_utc", "r_version", "ggplot2_version",
  "renderer_package", "renderer_version", "alt"
) %in% manifest$key))
patchwork_manifest <- utils::read.delim(
  paste0(patchwork_path, ".manifest.tsv"),
  stringsAsFactors = FALSE
)
stopifnot(grepl(
  "Two matching scatter-plot panels",
  patchwork_manifest$value[patchwork_manifest$key == "alt"],
  fixed = TRUE
))

overwrite_error <- tryCatch({
  qw_save(p, png_path, width_mm = 85, height_mm = 60)
  NULL
}, error = identity)
stopifnot(inherits(overwrite_error, "error"))

cat("rfigure helper smoke test: PASS\n")
cat(sprintf("preview=%s\n", png_path))
