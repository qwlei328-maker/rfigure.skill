#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(ggplot2)
  library(patchwork)
})

required_packages <- c("ragg")
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]
if (length(missing_packages)) {
  stop("Missing packages: ", paste(missing_packages, collapse = ", "))
}

FONT_FAMILY <- "Arial"
TEXT_PT <- 8
LINE_MM <- 25.4 / 72
PANEL_ASPECT <- 0.72
FIGURE_WIDTH_MM <- 190
FIGURE_HEIGHT_MM <- 145
ALIGNMENT_TOLERANCE_MM <- 0.20
PANEL_ASPECT_TOLERANCE <- 0.005
MIN_PANEL_AREA_SHARE <- 0.40

set.seed(20260819)
group_colours <- c(Control = "#0072B2", Treatment = "#D55E00")

frame_theme <- theme_classic(
  base_size = TEXT_PT,
  base_family = FONT_FAMILY
) +
  theme(
    panel.border = element_rect(
      colour = "black", fill = NA, linewidth = LINE_MM
    ),
    axis.line = element_blank(),
    panel.grid = element_blank(),
    plot.margin = margin(3, 3, 3, 3, "mm")
  )

scatter_df <- data.frame(
  x = rep(1:20, 2),
  group = rep(names(group_colours), each = 20)
)
scatter_df$y <- 0.4 * scatter_df$x +
  ifelse(scatter_df$group == "Treatment", 2, 0) +
  rnorm(nrow(scatter_df), sd = 1)

p1 <- ggplot(scatter_df, aes(x, y, colour = group, shape = group)) +
  geom_point() +
  scale_colour_manual(values = group_colours) +
  labs(x = "Predictor", y = "Response", colour = NULL, shape = NULL) +
  frame_theme +
  theme(legend.position = "top")

p2 <- ggplot(
  data.frame(category = LETTERS[1:4], value = c(4, 7, 5, 8)),
  aes(category, value)
) +
  geom_col(fill = "#56B4E9", width = 0.7) +
  labs(x = "Category", y = "A deliberately longer response label") +
  frame_theme

time_df <- data.frame(
  time = rep(1:10, 2),
  group = rep(names(group_colours), each = 10),
  value = c(cumsum(runif(10)), cumsum(runif(10)) + 1)
)
p3 <- ggplot(time_df, aes(time, value, colour = group)) +
  geom_line(linewidth = 0.55) +
  geom_point(size = 1.3) +
  scale_colour_manual(values = group_colours) +
  labs(
    x = "Time",
    y = "Value",
    colour = NULL
  ) +
  frame_theme +
  theme(legend.position = "none")

matrix_df <- expand.grid(row = LETTERS[1:4], column = LETTERS[1:4])
matrix_df$value <- seq(-1, 1, length.out = nrow(matrix_df))
p4 <- ggplot(matrix_df, aes(column, row, fill = value)) +
  geom_tile(colour = "white", linewidth = LINE_MM) +
  scale_fill_gradient2(
    low = "#2166AC", mid = "white", high = "#B2182B",
    midpoint = 0, limits = c(-1, 1), name = "Value"
  ) +
  labs(x = "Matrix column", y = "Matrix row") +
  frame_theme +
  theme(legend.position = "right")

composite <- wrap_plots(
  p1 + theme(aspect.ratio = PANEL_ASPECT),
  p2 + theme(aspect.ratio = PANEL_ASPECT),
  p3 + theme(aspect.ratio = PANEL_ASPECT),
  p4 + theme(aspect.ratio = PANEL_ASPECT),
  ncol = 2
) +
  plot_annotation(tag_levels = "a")

measure_panel_rectangles <- function(
  plot_object,
  width_mm,
  height_mm,
  expected_panels
) {
  temporary_png <- tempfile(fileext = ".png")
  ragg::agg_png(
    temporary_png,
    width = width_mm,
    height = height_mm,
    units = "mm",
    res = 96,
    background = "white"
  )
  measurement_device <- grDevices::dev.cur()
  on.exit({
    if (grDevices::dev.cur() == measurement_device) grDevices::dev.off()
    if (file.exists(temporary_png)) unlink(temporary_png)
  }, add = TRUE)

  grid::grid.newpage()
  grid::grid.draw(plot_object)
  grid::grid.force()
  viewport_listing <- grid::grid.ls(
    viewports = TRUE,
    grobs = FALSE,
    fullNames = TRUE,
    print = FALSE
  )
  is_panel <- grepl("^viewport\\[panel;", viewport_listing$name) &
    viewport_listing$vpDepth == 2
  if (sum(is_panel) != expected_panels) {
    stop(
      "Expected ", expected_panels,
      " top-level panel rectangles, found ", sum(is_panel)
    )
  }

  strip_viewport_name <- function(x) {
    sub("^viewport\\[(.*)\\]$", "\\1", x)
  }
  panel_names <- viewport_listing$name[is_panel]
  panel_paths <- viewport_listing$vpPath[is_panel]
  boxes <- lapply(seq_along(panel_names), function(index) {
    grid::upViewport(0)
    parent_names <- strsplit(panel_paths[[index]], "::", fixed = TRUE)[[1]]
    parent_names <- vapply(
      parent_names, strip_viewport_name, character(1)
    )
    for (parent_name in parent_names[-1]) {
      grid::downViewport(parent_name, strict = TRUE)
    }
    grid::downViewport(
      strip_viewport_name(panel_names[[index]]), strict = TRUE
    )
    lower_left <- grid::deviceLoc(
      grid::unit(0, "npc"), grid::unit(0, "npc"), valueOnly = TRUE
    )
    upper_right <- grid::deviceLoc(
      grid::unit(1, "npc"), grid::unit(1, "npc"), valueOnly = TRUE
    )
    data.frame(
      panel = letters[[index]],
      left_mm = lower_left$x * 25.4,
      bottom_mm = lower_left$y * 25.4,
      right_mm = upper_right$x * 25.4,
      top_mm = upper_right$y * 25.4
    )
  })

  grid::upViewport(0)
  grDevices::dev.off()
  unlink(temporary_png)
  do.call(rbind, boxes)
}

panel_boxes <- measure_panel_rectangles(
  composite,
  width_mm = FIGURE_WIDTH_MM,
  height_mm = FIGURE_HEIGHT_MM,
  expected_panels = 4
)
panel_boxes$column <- c(1L, 2L, 1L, 2L)
panel_boxes$row <- c(1L, 1L, 2L, 2L)

max_group_spread <- function(values, groups) {
  max(vapply(
    split(values, groups),
    function(group_values) diff(range(group_values)),
    numeric(1)
  ))
}
deviations_mm <- c(
  column_left = max_group_spread(panel_boxes$left_mm, panel_boxes$column),
  column_right = max_group_spread(panel_boxes$right_mm, panel_boxes$column),
  row_bottom = max_group_spread(panel_boxes$bottom_mm, panel_boxes$row),
  row_top = max_group_spread(panel_boxes$top_mm, panel_boxes$row),
  width = diff(range(panel_boxes$right_mm - panel_boxes$left_mm)),
  height = diff(range(panel_boxes$top_mm - panel_boxes$bottom_mm))
)
if (any(deviations_mm > ALIGNMENT_TOLERANCE_MM)) {
  stop(
    "Panel alignment failed: ",
    paste(
      names(deviations_mm), round(deviations_mm, 3),
      sep = "=", collapse = ", "
    )
  )
}

panel_widths_mm <- panel_boxes$right_mm - panel_boxes$left_mm
panel_heights_mm <- panel_boxes$top_mm - panel_boxes$bottom_mm
rendered_panel_aspects <- panel_heights_mm / panel_widths_mm
panel_area_share <- sum(panel_widths_mm * panel_heights_mm) /
  (FIGURE_WIDTH_MM * FIGURE_HEIGHT_MM)
max_aspect_deviation <- max(abs(rendered_panel_aspects - PANEL_ASPECT))

if (panel_area_share < MIN_PANEL_AREA_SHARE) {
  stop(
    "Data panels occupy only ", round(100 * panel_area_share, 1),
    "% of the figure; required at least ",
    round(100 * MIN_PANEL_AREA_SHARE, 1), "%"
  )
}
if (max_aspect_deviation > PANEL_ASPECT_TOLERANCE) {
  stop(
    "Rendered panel aspect differs from the target by ",
    round(max_aspect_deviation, 3),
    "; tolerance is ", PANEL_ASPECT_TOLERANCE
  )
}

preview_png <- file.path(tempdir(), "rfigure-panel-alignment-smoke.png")
ggsave(
  preview_png,
  composite,
  device = ragg::agg_png,
  width = FIGURE_WIDTH_MM,
  height = FIGURE_HEIGHT_MM,
  units = "mm",
  dpi = 150,
  bg = "white"
)

print(panel_boxes, row.names = FALSE, digits = 4)
cat("rfigure panel alignment smoke test: PASS\n")
cat("max deviation (mm): ", max(deviations_mm), "\n", sep = "")
cat("panel area share: ", round(panel_area_share, 4), "\n", sep = "")
cat(
  "mean rendered panel aspect: ",
  round(mean(rendered_panel_aspects), 4), "\n", sep = ""
)
cat(
  "max aspect deviation: ",
  round(max_aspect_deviation, 4), "\n", sep = ""
)
cat("preview=", preview_png, "\n", sep = "")
