# Quality, Accessibility, and Reproducibility

Use this reference before final delivery, especially for figures carrying statistical evidence, spatial data, or accessibility requirements.

## The Rules Apply to the AI

The integrity rules in this skill instruct the AI agent how to handle a user's data. They are not rules imposed on the human. If the human explicitly requests filtering, sampling, transformation, or another defensible choice, the AI may implement it, but must show the operation in code and explain what changed.

The AI must not independently fabricate, hide, discard, or alter evidence merely to make a cleaner or more significant figure.

## Evidence Integrity

- Plot supplied data or a documented deterministic transformation.
- Do not fabricate observations, uncertainty, significance, model outputs, or map locations.
- Never silently drop missing, infinite, out-of-range, or censored values.
- Do not silently subsample a final evidentiary figure.
- Keep raw scale/log scale, normalization, aggregation, smoothing, and interval definitions visible in code and caption.
- Distinguish descriptive summaries from inferential results.

Write the audit directly in the delivered script:

```r
variables_to_plot <- c("group", "x", "estimate")
missing_columns <- setdiff(variables_to_plot, names(analysis_df))
if (length(missing_columns)) {
  stop("Missing columns: ", paste(missing_columns, collapse = ", "))
}

data_audit <- do.call(rbind, lapply(variables_to_plot, function(variable) {
  value <- analysis_df[[variable]]
  numeric_value <- is.numeric(value)
  finite_value <- if (numeric_value) is.finite(value) else !is.na(value)

  data.frame(
    variable = variable,
    class = paste(class(value), collapse = "/"),
    n = length(value),
    missing = sum(is.na(value)),
    nonfinite = if (numeric_value) {
      sum(!is.finite(value) & !is.na(value))
    } else {
      NA_integer_
    },
    distinct_observed = length(unique(value[finite_value]))
  )
}))

# Replace c("sample_id", "time") with the actual unique identifier columns.
duplicate_identifier_count <- sum(duplicated(
  analysis_df[c("sample_id", "time")]
))

print(data_audit)
message("Duplicate identifiers: ", duplicate_identifier_count)
```

When filtering is scientifically justified, keep both the condition and the removed count visible:

```r
keep <- is.finite(analysis_df$estimate)
removed_n <- sum(!keep)
message("Rows excluded because estimate was non-finite: ", removed_n)
plot_df <- analysis_df[keep, , drop = FALSE]
```

## Visual and Structural Checks

Inspect the rendered output at 100% and expected publication size. Also write basic structural checks directly:

```r
plot_labels <- ggplot2::get_labs(p)
has_label <- function(x) {
  length(x) == 1L && !is.na(x) && nzchar(as.character(x))
}
stopifnot(
  has_label(plot_labels$x),
  has_label(plot_labels$y),
  has_label(plot_labels$alt)
)

ggplot2::ggplot_build(p)  # Must complete without error.
```

Then visually confirm:

1. Labels, units, transformations, and category order are correct.
2. Clipping, opaque layers, or overplotting do not hide data.
3. Error bars, intervals, and annotations align with observations.
4. Line widths and symbols survive reduction.
5. Legends match visible encodings and contain no unused levels.
6. Regular multi-panel grids align the rendered panel rectangles: common left/right edges by column and common top/bottom edges by row.
7. Rendered panel height/width matches the declared target and data panels occupy the declared minimum share of the full figure.
8. Fixed-aspect panels and inset frames align after export.
9. Captions and legends remain inside the exported canvas; repeated prose does not unnecessarily shrink every subfigure.
10. Legends occupy verified interior whitespace when available, or use a deliberate direct/right/shared alternative; they do not hide evidence or unnecessarily consume panel height. Interior map legends are transparent and borderless.
11. A requested golden-ratio version reports actual canvas and panel ratios, remains at or below 210 mm width, and preserves every fixed-aspect map projection without stretching.

Do not infer panel quality from equal patchwork slots or the outer image dimensions. Measure the final panel viewport coordinates in physical units, rendered height/width, and total data-panel area share. `scripts/panel_alignment_smoke_test.R` demonstrates these maintainer checks; inline any needed measurement code into a public delivered script rather than sourcing the skill file.

Automated checks do not replace visual inspection or scientific review.

## Accessible Encoding

Do not rely on hue alone when categories matter:

```r
group_cols <- c(Control = "#0072B2", Treatment = "#D55E00")
group_shapes <- c(Control = 21, Treatment = 24)

p <- ggplot(df, aes(x, y, fill = group, shape = group)) +
  geom_point(size = 2.4, colour = "white", stroke = 0.45) +
  scale_fill_manual(values = group_cols, breaks = names(group_cols)) +
  scale_shape_manual(values = group_shapes, breaks = names(group_shapes))
```

If a numerical contrast check is useful, include its formula rather than calling a private helper:

```r
rgb <- grDevices::col2rgb(group_cols) / 255
rgb_linear <- ifelse(
  rgb <= 0.04045,
  rgb / 12.92,
  ((rgb + 0.055) / 1.055)^2.4
)
luminance <- 0.2126 * rgb_linear[1, ] +
  0.7152 * rgb_linear[2, ] +
  0.0722 * rgb_linear[3, ]
contrast_vs_white <- 1.05 / (luminance + 0.05)
print(data.frame(colour = group_cols, contrast_vs_white))
```

This check is only one diagnostic; visually inspect color-vision and grayscale separation. For continuous data, prefer perceptually ordered scales. For signed effects, use a diverging scale centered on a meaningful zero.

For categorical sampling-site maps, keep all points as the same solid circle when that is the requested visual language. Choose a color-vision-aware palette, use explicit legend labels, and carry the same colors into statistical panels. Do not reintroduce mixed map shapes merely to satisfy generic redundancy advice; use direct labels, facets, or non-map encodings when additional identification is needed.

## Alt Text

Add concise alt text with `labs(alt = ...)`. Describe chart type, variables, strongest pattern, uncertainty, and important exceptions without overstating inference:

```r
p <- p + labs(
  alt = paste(
    "Scatter plot of soil moisture against canopy temperature.",
    "Temperature generally decreases with higher moisture, with wider",
    "variation at low moisture. Treatment is encoded by color and shape."
  )
)

ggplot2::get_alt_text(p)
```

For patchwork, define one figure-level string in the same script and record it with the export metadata even if child alt text cannot be recovered.

## Reproducible Export

Keep export choices visible and refuse accidental overwrite:

```r
output_png <- "outputs/figure_2.png"
dir.create(dirname(output_png), recursive = TRUE, showWarnings = FALSE)
if (file.exists(output_png)) stop("Refusing to overwrite: ", output_png)

ggplot2::ggsave(
  filename = output_png,
  plot = p,
  device = ragg::agg_png,
  width = FIG_WIDTH_MM,
  height = FIG_HEIGHT_MM,
  units = "mm",
  dpi = FIG_DPI,
  bg = "white"
)

stopifnot(file.exists(output_png), file.info(output_png)$size > 0)
```

An optional manifest can also be written explicitly:

```r
figure_alt <- ggplot2::get_alt_text(p)
manifest <- data.frame(
  key = c(
    "file", "device", "width_mm", "height_mm", "dpi",
    "r_version", "ggplot2_version", "alt"
  ),
  value = c(
    normalizePath(output_png), "ragg::agg_png",
    FIG_WIDTH_MM, FIG_HEIGHT_MM, FIG_DPI,
    R.version.string, as.character(packageVersion("ggplot2")), figure_alt
  )
)
utils::write.table(
  manifest, paste0(output_png, ".manifest.tsv"),
  sep = "\t", row.names = FALSE, quote = TRUE
)
```

## Final Review Record

Report source data, transformations, exclusions, figure purpose, encoding decisions, output formats/dimensions, device versions, warnings, limitations, tests, and whether exported files were visually inspected.

Official references: [ggplot2 alt text](https://ggplot2.tidyverse.org/reference/get_alt_text.html), [ggplot2 labels](https://ggplot2.tidyverse.org/reference/labs.html), [ggsave](https://ggplot2.tidyverse.org/reference/ggsave.html), and [ragg devices](https://ragg.r-lib.org/reference/agg_png.html).
