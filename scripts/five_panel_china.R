#!/usr/bin/env Rscript

# Maintainer reference implementation of the Five-Panel Standard
# (references/maps-and-spatial.md). Writes its outputs to tempdir() so a
# regression run never touches the skill repository. Delivered scripts must
# inline what they need from here, never source() this file.

# Self-contained rfigure example: five-panel China synthesis.
# Panel a: province map with 28 newly simulated demonstration sites in four
#          quadrant regions (solid circles, colour-coded, transparent legend).
# Panel b: distribution of the simulated response by region (raw + box).
# Panel c: relationship between response and simulated temperature (lm fit).
# Panel d: simulated monthly trajectory by region (mean and 95% t CI ribbon).
# Panel e: standardized linear-model effects with a null reference line.
# All sites, covariates, and responses are deterministic simulations, not
# observations or inferential results.

suppressPackageStartupMessages({
  library(ggplot2)
  library(patchwork)
  library(sf)
  library(ggmapcn)
})

# Composition-time geometry. A delivered composition script may source this
# same file (see the Self-Contained Output Contract in SKILL.md); the panel
# plotting code below is what must stay inline in a deliverable.
SCRIPT_ARGUMENTS <- commandArgs(trailingOnly = FALSE)
SCRIPT_FILE <- sub("^--file=", "", grep("^--file=", SCRIPT_ARGUMENTS,
                                        value = TRUE)[1])
LAYOUT_HELPER <- if (!is.na(SCRIPT_FILE)) {
  file.path(dirname(SCRIPT_FILE), "rfigure_layout.R")
} else {
  "scripts/rfigure_layout.R"
}
source(LAYOUT_HELPER)

required_packages <- c("ragg", "svglite", "systemfonts")
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]
if (length(missing_packages)) {
  stop("Install required packages: ", paste(missing_packages, collapse = ", "))
}

# ---- Visible parameters ---------------------------------------------------
SITE_SEED <- 73019
RESPONSE_SEED <- 41522
MONTH_SEED <- 88604

FONT_FAMILY <- "Arial"
TEXT_PT <- 8
TAG_PT <- 9
TEXT_GG <- TEXT_PT / ggplot2::.pt
LINE_MM <- 25.4 / 72
DATA_LINE_MM <- LINE_MM * 1.8
TAG_CLEARANCE_MM <- 1.2   # minimum gap between a tag and axis decorations

FIGURE_WIDTH_MM <- 190
FIGURE_DPI <- 600
STAT_ROW_HEIGHT_MM <- 48     # height of the lower statistical row (H2)
OUTER_TOTAL_MM <- 18         # tag/margin space above + axis space below rows
ALIGNMENT_TOLERANCE_MM <- 0.35
MIN_PANEL_AREA_SHARE <- 0.52

DESIGN <- "aaaabb\nccddee"   # one flat grid: map spans columns 1-4 of row 1
COLUMN_WIDTHS <- c(1, 1, 1, 1, 1, 1)

MAIN_XLIM <- c(72, 142)
MAIN_YLIM <- c(12, 56)
INSET_XLIM <- c(105, 125)
INSET_YLIM <- c(0, 25)

GRATICULE_LON <- seq(80, 130, by = 10)     # degrees east; every break labelled
GRATICULE_LAT <- seq(20, 50, by = 10)      # degrees north
GRATICULE_DECIMALS <- 1
INSET_HEIGHT <- 0.28
INSET_RIGHT <- 1
INSET_BOTTOM <- 0

# Projection kept in one visible parameter. Equal-area conic is the default
# for a national China map; "robinson" is the default for world maps. Any
# registry name, PROJ string, or EPSG code may be used instead.
MAP_PROJECTIONS <- c(
  plate_carree = "EPSG:4326",
  behrmann     = "+proj=cea +lat_ts=30 +lon_0=0 +datum=WGS84 +units=m +no_defs",
  robinson     = "+proj=robin +lon_0=0 +datum=WGS84 +units=m +no_defs",
  equal_earth  = "+proj=eqearth +lon_0=0 +datum=WGS84 +units=m +no_defs",
  china_albers = paste(
    "+proj=aea +lat_1=25 +lat_2=47 +lat_0=0 +lon_0=105",
    "+datum=WGS84 +units=m +no_defs"
  ),
  china_lcc    = paste(
    "+proj=lcc +lat_1=25 +lat_2=47 +lat_0=0 +lon_0=105",
    "+datum=WGS84 +units=m +no_defs"
  )
)
MAP_PROJECTION <- "china_albers"
MAP_CRS <- if (MAP_PROJECTION %in% names(MAP_PROJECTIONS)) {
  MAP_PROJECTIONS[[MAP_PROJECTION]]
} else {
  MAP_PROJECTION
}

REGION_SPLIT_LON <- 107
REGION_SPLIT_LAT <- 35
REGION_COLOURS <- c(
  Northwest = "#D55E00",
  Northeast = "#0072B2",
  Southwest = "#009E73",
  Southeast = "#CC79A7"
)
REGION_SHORT <- c(
  Northwest = "NW", Northeast = "NE", Southwest = "SW", Southeast = "SE"
)
TARGET_COUNTS <- c(Northwest = 7L, Northeast = 7L, Southwest = 7L,
                   Southeast = 7L)
SEASONAL_AMPLITUDE <- c(
  Northwest = 0.45, Northeast = 0.55, Southwest = 0.22, Southeast = 0.30
)

SCRIPT_DIR <- tempdir()
OUTPUT_PNG <- file.path(SCRIPT_DIR, "five_panel_china_demo.png")
OUTPUT_SVG <- file.path(SCRIPT_DIR, "five_panel_china_demo.svg")

available_fonts <- unique(systemfonts::system_fonts()$family)
if (!FONT_FAMILY %in% available_fonts) {
  stop("Required font is not installed: ", FONT_FAMILY)
}

# Decimal-degree graticule labels. The \u00b0 escape marks the string UTF-8, so the
# glyph survives a C locale; a literal degree character renders as "..".
decimal_degree <- function(values, hemisphere) {
  sprintf(paste0("%.", GRATICULE_DECIMALS, "f\u00b0%s"), values, hemisphere)
}
stopifnot(Encoding(decimal_degree(80, "E")) == "UTF-8")

# Every graticule break must produce a drawn label. Check the labels the axes
# rendered, not the geometry of the graticule lines: on a pseudocylindrical
# world map no parallel reaches the left edge yet all latitude labels appear,
# so a geometric touch test would reject correct world maps.
axis_label_texts <- function(grob) {
  out <- character(0)
  # gTrees keep children in $children; gtables keep them in $grobs.
  for (slot in c("children", "grobs")) {
    kids <- grob[[slot]]
    if (!is.null(kids)) for (child in kids) {
      out <- c(out, axis_label_texts(child))
    }
  }
  if (!is.null(grob$label)) out <- c(out, as.character(grob$label))
  out
}

assert_graticule_labelled <- function(plot_object, expected_x, expected_y) {
  table <- ggplot2::ggplotGrob(plot_object)
  collect <- function(pattern) {
    unlist(lapply(
      table$grobs[grep(pattern, table$layout$name)], axis_label_texts
    ))
  }
  missing_labels <- c(
    setdiff(expected_x, collect("^axis-b")),
    setdiff(expected_y, collect("^axis-l"))
  )
  if (length(missing_labels)) {
    stop(
      "Graticule breaks drawn without a label: ",
      paste(missing_labels, collapse = ", "),
      ". Choose breaks that the labelled edges can carry."
    )
  }
  invisible(TRUE)
}

# ---- Load and audit the China province map --------------------------------
map_paths <- ggmapcn::check_geodata(files = "China_sheng.rda", quiet = TRUE)
map_path <- map_paths[!is.na(map_paths) & file.exists(map_paths)][1]
if (!length(map_path) || is.na(map_path)) {
  stop("Could not locate China_sheng.rda through ggmapcn::check_geodata().")
}

map_environment <- new.env(parent = emptyenv())
load(map_path, envir = map_environment)
map_objects <- ls(map_environment, all.names = TRUE)
if ("China_sheng" %in% map_objects) {
  china <- get("China_sheng", envir = map_environment, inherits = FALSE)
} else if (length(map_objects) == 1L) {
  china <- get(map_objects[[1]], envir = map_environment, inherits = FALSE)
} else {
  stop("Could not identify the province map object in: ", map_path)
}
if (!inherits(china, "sf")) stop("Loaded China map is not an sf object.")

boundary_row <- rep(FALSE, nrow(china))
for (column in intersect(c("name", "name_en"), names(china))) {
  value <- as.character(china[[column]])
  boundary_row <- boundary_row |
    (!is.na(value) & toupper(value) == "BOUNDARY LINE")
}
boundary_layer_rows <- sum(boundary_row)
china <- sf::st_make_valid(china[!boundary_row, , drop = FALSE])
china <- sf::st_transform(china, 4326)
china_mask <- sf::st_union(sf::st_transform(china, MAP_CRS))

# ---- Fresh deterministic demonstration sites ------------------------------
set.seed(SITE_SEED)
candidate_points <- sf::st_sample(china_mask, size = 1200, exact = TRUE)
candidate_xy <- sf::st_coordinates(sf::st_transform(candidate_points, 4326))
candidates <- data.frame(lon = candidate_xy[, 1], lat = candidate_xy[, 2])
candidates$region <- ifelse(
  candidates$lat >= REGION_SPLIT_LAT,
  ifelse(candidates$lon < REGION_SPLIT_LON, "Northwest", "Northeast"),
  ifelse(candidates$lon < REGION_SPLIT_LON, "Southwest", "Southeast")
)

selected_sites <- lapply(names(TARGET_COUNTS), function(region_name) {
  pool <- candidates[candidates$region == region_name, , drop = FALSE]
  if (nrow(pool) < TARGET_COUNTS[[region_name]]) {
    stop("Not enough candidate sites in region: ", region_name)
  }
  pool[seq_len(TARGET_COUNTS[[region_name]]), , drop = FALSE]
})
sites <- do.call(rbind, selected_sites)
sites$region <- factor(sites$region, levels = names(TARGET_COUNTS))
sites$site_id <- sprintf("CN%02d", seq_len(nrow(sites)))

# Simulated covariates and response; the generating model is fully visible.
set.seed(RESPONSE_SEED)
sites$mat_c <- 24 - 0.62 * (sites$lat - 15) +
  stats::rnorm(nrow(sites), mean = 0, sd = 1.3)
sites$precip_mm <- pmax(
  30,
  80 + 21 * (sites$lon - 72) + stats::rnorm(nrow(sites), mean = 0, sd = 110)
)
sites$response <- 12 + 1.35 * sites$mat_c + 0.014 * sites$precip_mm +
  stats::rnorm(nrow(sites), mean = 0, sd = 3.5)

sites_sf <- sf::st_as_sf(
  sites,
  coords = c("lon", "lat"),
  crs = 4326,
  remove = FALSE
) |>
  sf::st_transform(MAP_CRS)
inside_land <- lengths(sf::st_within(sites_sf, china_mask)) == 1L

stopifnot(
  nrow(sites) == sum(TARGET_COUNTS),
  all(inside_land),
  !anyNA(sites[c("lon", "lat", "region", "mat_c", "precip_mm", "response")]),
  !anyDuplicated(sites$site_id)
)

# Simulated monthly trajectory: site response scaled by a regional seasonal
# cycle that peaks in July, plus independent monthly noise.
monthly <- expand.grid(
  site_id = sites$site_id,
  month = 1:12,
  KEEP.OUT.ATTRS = FALSE,
  stringsAsFactors = FALSE
)
monthly <- merge(
  monthly,
  sites[c("site_id", "region", "response")],
  by = "site_id"
)
set.seed(MONTH_SEED)
monthly$value <- monthly$response *
  (1 + SEASONAL_AMPLITUDE[as.character(monthly$region)] *
     sin(2 * pi * (monthly$month - 4) / 12)) +
  stats::rnorm(nrow(monthly), mean = 0, sd = 2)

group_ci <- function(values) {
  n_value <- length(values)
  standard_error <- stats::sd(values) / sqrt(n_value)
  critical_value <- stats::qt(0.975, df = n_value - 1L)
  c(
    n = n_value,
    mean = mean(values),
    lower = mean(values) - critical_value * standard_error,
    upper = mean(values) + critical_value * standard_error
  )
}

region_summary <- do.call(rbind, lapply(levels(sites$region), function(g) {
  data.frame(region = g, t(group_ci(sites$response[sites$region == g])))
}))
region_summary$region <- factor(region_summary$region,
                                levels = names(TARGET_COUNTS))

monthly_summary <- do.call(rbind, lapply(levels(monthly$region), function(g) {
  do.call(rbind, lapply(1:12, function(m) {
    rows <- monthly$region == g & monthly$month == m
    data.frame(region = g, month = m, t(group_ci(monthly$value[rows])))
  }))
}))
monthly_summary$region <- factor(monthly_summary$region,
                                 levels = names(TARGET_COUNTS))

# Standardized linear model for panel e; scaling makes effects comparable.
effect_model <- stats::lm(
  response ~ scale(mat_c) + scale(precip_mm) + scale(lat),
  data = sites
)
effect_ci <- stats::confint(effect_model)
effect_table <- data.frame(
  term = c("MAT", "Precipitation", "Latitude"),
  estimate = stats::coef(effect_model)[-1],
  lower = effect_ci[-1, 1],
  upper = effect_ci[-1, 2]
)
effect_table$term <- factor(effect_table$term, levels = rev(effect_table$term))

relationship_model <- stats::lm(response ~ mat_c, data = sites)
relationship_r2 <- summary(relationship_model)$r.squared
relationship_p <- summary(relationship_model)$coefficients[2, 4]

cat("China five-panel data audit\n")
print(data.frame(
  rows = nrow(sites),
  missing = sum(is.na(sites)),
  duplicate_ids = sum(duplicated(sites$site_id)),
  outside_land = sum(!inside_land),
  monthly_rows = nrow(monthly),
  monthly_missing = sum(is.na(monthly$value))
))
print(region_summary, row.names = FALSE, digits = 4)
print(effect_table, row.names = FALSE, digits = 3)
figure_note <- paste(
  "Figure note: all sites, covariates, responses, and monthly values are",
  "simulated with fixed seeds (sites", SITE_SEED, "; response",
  RESPONSE_SEED, "; monthly", MONTH_SEED, "). Group statistics are means",
  "with 95% t confidence intervals; the ribbon in panel d is the 95% t CI",
  "of the monthly regional mean (n = 7 sites per region). Panel e shows",
  "OLS coefficients of standardized predictors with 95% CIs. No site,",
  "response, or monthly rows were excluded and no transformation was",
  "applied; panel b hides duplicate boxplot outlier glyphs only because",
  "every raw observation is already drawn as a jittered point. Region",
  "axis labels NW/NE/SW/SE abbreviate the full names in the map legend.\n"
)
cat(figure_note)
map_note <- paste(
  "Map note: ggmapcn", as.character(utils::packageVersion("ggmapcn")),
  "bundled province data, projection", MAP_PROJECTION, "=", MAP_CRS, ";",
  boundary_layer_rows, "rows labelled BOUNDARY LINE were separated from",
  "the filled province polygons and drawn with ggmapcn's dedicated",
  "boundary layer; administrative boundaries are for figure demonstration",
  "and must be replaced or verified for a real study.\n"
)
cat(map_note)

# ---- Complete visible theme ------------------------------------------------
publication_theme <-
  ggplot2::theme_classic(base_size = TEXT_PT, base_family = FONT_FAMILY) +
  ggplot2::theme(
    text = ggplot2::element_text(
      family = FONT_FAMILY, size = TEXT_PT, colour = "black"
    ),
    axis.text = ggplot2::element_text(
      family = FONT_FAMILY, size = TEXT_PT, colour = "black"
    ),
    axis.title = ggplot2::element_text(
      family = FONT_FAMILY, size = TEXT_PT, colour = "black"
    ),
    legend.text = ggplot2::element_text(
      family = FONT_FAMILY, size = TEXT_PT, colour = "black"
    ),
    legend.title = ggplot2::element_text(
      family = FONT_FAMILY, size = TEXT_PT, colour = "black"
    ),
    plot.tag = ggplot2::element_text(
      family = FONT_FAMILY, size = TAG_PT, face = "bold", colour = "black",
      margin = ggplot2::margin(0, 0, TAG_CLEARANCE_MM, 0, "mm")
    ),
    panel.border = ggplot2::element_rect(
      colour = "black", fill = NA, linewidth = LINE_MM
    ),
    axis.line = ggplot2::element_blank(),
    axis.ticks = ggplot2::element_line(colour = "black", linewidth = LINE_MM),
    panel.grid = ggplot2::element_blank(),
    panel.background = ggplot2::element_rect(fill = "white", colour = NA),
    plot.background = ggplot2::element_rect(fill = "white", colour = NA),
    legend.background = ggplot2::element_rect(fill = NA, colour = NA),
    legend.box.background = ggplot2::element_blank(),
    legend.key = ggplot2::element_rect(fill = NA, colour = NA),
    plot.margin = ggplot2::margin(2, 2, 2, 2, "mm")
  )

map_layers <- function() {
  list(
    ggmapcn::geom_mapcn(
      data = china,
      admin_level = "province",
      crs = MAP_CRS,
      fill = "#F2F2F2",
      color = "#B8B8B8",
      linewidth = LINE_MM * 0.7
    ),
    ggmapcn::geom_boundary_cn(
      crs = MAP_CRS,
      mainland_color = "grey35",
      mainland_size = LINE_MM,
      coastline_color = "#78A6C8",
      coastline_size = LINE_MM * 0.8,
      ten_segment_line_color = "grey35",
      ten_segment_line_size = LINE_MM,
      province_color = "#D0D0D0",
      province_size = LINE_MM * 0.55
    )
  )
}

# ---- Panel a: map with one solid circular glyph per site -------------------
p_map <- ggplot2::ggplot() +
  map_layers() +
  ggplot2::geom_sf(
    data = sites_sf,
    ggplot2::aes(fill = region),
    shape = 21,
    size = 2.4,
    stroke = LINE_MM,
    colour = "black"
  ) +
  ggplot2::scale_fill_manual(
    values = REGION_COLOURS,
    breaks = names(REGION_COLOURS),
    name = "Region"
  ) +
  ggplot2::scale_x_continuous(
    breaks = GRATICULE_LON,
    labels = function(x) decimal_degree(x, "E")
  ) +
  ggplot2::scale_y_continuous(
    breaks = GRATICULE_LAT,
    labels = function(y) decimal_degree(y, "N")
  ) +
  ggplot2::coord_sf(
    crs = MAP_CRS,
    xlim = MAIN_XLIM,
    ylim = MAIN_YLIM,
    default_crs = sf::st_crs(4326),
    label_axes = "--EN",
    expand = FALSE
  ) +
  ggplot2::labs(
    tag = "a",
    x = NULL,
    y = NULL,
    alt = paste(
      "China province map with 28 simulated demonstration sites drawn as",
      "identical solid circles whose colours mark four quadrant regions;",
      "a graticule with decimal-degree labels on the left and bottom edges",
      "frames the panel; a transparent legend sits in the empty lower-left",
      "map area and the",
      "South China Sea inset sits in the lower-right corner."
    )
  ) +
  publication_theme +
  ggplot2::theme(
    axis.title = ggplot2::element_blank(),
    panel.grid.major = ggplot2::element_line(
      colour = "grey88", linewidth = LINE_MM * 0.5
    ),
    legend.position = "inside",
    legend.position.inside = c(0.02, 0.02),
    legend.justification = c(0, 0),
    legend.direction = "vertical",
    legend.background = ggplot2::element_rect(fill = NA, colour = NA),
    legend.box.background = ggplot2::element_blank(),
    legend.key = ggplot2::element_rect(fill = NA, colour = NA),
    legend.key.size = grid::unit(3.0, "mm"),
    legend.margin = ggplot2::margin(0, 0, 0, 0, "mm")
  )

p_inset <- ggplot2::ggplot() +
  map_layers() +
  ggplot2::coord_sf(
    crs = MAP_CRS,
    xlim = INSET_XLIM,
    ylim = INSET_YLIM,
    default_crs = sf::st_crs(4326),
    expand = FALSE
  ) +
  publication_theme

panel_range <- function(panel_parameters, axis = c("x", "y")) {
  axis <- match.arg(axis)
  for (name in c(paste0(axis, "_range"), paste0(axis, ".range"))) {
    value <- panel_parameters[[name]]
    if (is.numeric(value) && length(value) == 2L && all(is.finite(value))) {
      return(as.numeric(value))
    }
  }
  axis_parameters <- panel_parameters[[axis]]
  if (!is.null(axis_parameters)) {
    for (name in c("continuous_range", "range")) {
      value <- axis_parameters[[name]]
      if (is.numeric(value) && length(value) == 2L && all(is.finite(value))) {
        return(as.numeric(value))
      }
    }
  }
  stop("Could not read rendered ", axis, " range.")
}

panel_width_over_height <- function(plot_object) {
  parameters <- ggplot2::ggplot_build(plot_object)$layout$panel_params[[1]]
  diff(panel_range(parameters, "x")) / diff(panel_range(parameters, "y"))
}

assert_graticule_labelled(
  p_map,
  expected_x = decimal_degree(GRATICULE_LON, "E"),
  expected_y = decimal_degree(GRATICULE_LAT, "N")
)
map_ratio <- panel_width_over_height(p_map)
inset_ratio <- panel_width_over_height(p_inset)
inset_width <- INSET_HEIGHT * inset_ratio / map_ratio
inset_left <- INSET_RIGHT - inset_width
inset_top <- INSET_BOTTOM + INSET_HEIGHT
# Invariants only. Literal ratio constants are properties of one viewport, so
# a copied script with a different extent would die on a number unrelated to
# its own figure; the measured values are printed in the audit instead.
stopifnot(
  inset_left >= 0,
  inset_top <= 1,
  is.finite(map_ratio),
  is.finite(inset_ratio),
  inset_width > 0,
  inset_width <= 1
)

inset_map <- p_inset +
  ggplot2::theme(
    panel.border = ggplot2::element_blank(),
    axis.text = ggplot2::element_blank(),
    axis.title = ggplot2::element_blank(),
    axis.ticks = ggplot2::element_blank(),
    legend.position = "none",
    plot.margin = ggplot2::margin(0, 0, 0, 0, "mm")
  )
inset_frame <- ggplot2::ggplot() +
  ggplot2::theme_void() +
  ggplot2::theme(
    plot.background = ggplot2::element_rect(
      fill = NA, colour = "black", linewidth = LINE_MM
    ),
    plot.margin = ggplot2::margin(0, 0, 0, 0, "mm")
  )

p_map_final <- p_map +
  patchwork::inset_element(
    inset_map,
    left = inset_left,
    bottom = INSET_BOTTOM,
    right = INSET_RIGHT,
    top = inset_top,
    align_to = "panel"
  ) +
  patchwork::inset_element(
    inset_frame,
    left = inset_left,
    bottom = INSET_BOTTOM,
    right = INSET_RIGHT,
    top = inset_top,
    align_to = "panel"
  )

# ---- Panel b: distribution (raw jittered points + boxplot) -----------------
p_distribution <- ggplot2::ggplot(
  sites,
  ggplot2::aes(region, response)
) +
  ggplot2::geom_boxplot(
    ggplot2::aes(colour = region),
    fill = NA,
    width = 0.55,
    linewidth = DATA_LINE_MM,
    outlier.shape = NA
  ) +
  ggplot2::geom_point(
    ggplot2::aes(colour = region),
    position = ggplot2::position_jitter(
      width = 0.13, height = 0, seed = SITE_SEED
    ),
    shape = 16,
    size = 1.6,
    alpha = 0.8
  ) +
  ggplot2::scale_colour_manual(values = REGION_COLOURS, guide = "none") +
  ggplot2::scale_x_discrete(labels = REGION_SHORT) +
  ggplot2::labs(
    tag = "b",
    x = "Region",
    y = "Simulated productivity index (arbitrary units)",
    alt = paste(
      "Boxplots and all raw jittered values of the simulated productivity",
      "index for seven sites in each of four China regions."
    )
  ) +
  publication_theme +
  ggplot2::theme(legend.position = "none")

# ---- Panel c: relationship (scatter + pooled linear fit) -------------------
relationship_label <- sprintf(
  "R\u00b2 = %.2f, p %s",
  relationship_r2,
  ifelse(relationship_p < 0.001, "< 0.001",
         sprintf("= %.3f", relationship_p))
)
p_relationship <- ggplot2::ggplot(
  sites,
  ggplot2::aes(mat_c, response)
) +
  ggplot2::geom_smooth(
    method = "lm",
    formula = y ~ x,
    se = TRUE,
    colour = "black",
    fill = "grey75",
    alpha = 0.45,
    linewidth = DATA_LINE_MM
  ) +
  ggplot2::geom_point(
    ggplot2::aes(colour = region),
    shape = 16,
    size = 1.6,
    alpha = 0.85
  ) +
  ggplot2::scale_colour_manual(values = REGION_COLOURS, guide = "none") +
  ggplot2::annotate(
    "text",
    x = -Inf, y = Inf,
    hjust = -0.08, vjust = 1.6,
    label = relationship_label,
    family = FONT_FAMILY,
    size = TEXT_GG
  ) +
  ggplot2::labs(
    tag = "c",
    x = "Simulated mean annual temperature (\u00b0C)",
    y = "Simulated productivity index (arbitrary units)",
    alt = paste(
      "Scatter plot of the simulated productivity index against simulated",
      "mean annual temperature for 28 sites, coloured by region, with one",
      "pooled ordinary least squares fit and its 95 percent confidence band."
    )
  ) +
  publication_theme +
  ggplot2::theme(legend.position = "none")

# ---- Panel d: monthly trajectory (mean line + 95% t CI ribbon) -------------
# Direct region labels replace a duplicate legend.
# Anti-overlap spacing for the stacked direct labels is derived from the
# physical geometry rather than a hard-coded fraction: a TEXT_PT-point label
# is TEXT_PT / 72 * 25.4 mm tall on a panel panel_height_mm high, so the
# minimum clear distance in data units is
# clearance * label_height_mm / panel_height_mm * axis_span. A floor clamp
# lifts the whole stack if the cascade pushes the lowest label out of the
# drawn range. This holds in any layout without per-layout tuning.
LABEL_CLEARANCE <- 1.25
place_direct_labels <- function(panel_height_mm) {
  positions <- monthly_summary[monthly_summary$month == 12, ]
  positions <- positions[order(-positions$mean), ]
  value_span <- diff(range(c(monthly_summary$lower, monthly_summary$upper)))
  label_height_mm <- TEXT_PT / 72 * 25.4
  minimum_gap <- LABEL_CLEARANCE * label_height_mm / panel_height_mm *
    value_span
  positions$label_y <- positions$mean
  for (i in seq_len(nrow(positions))[-1]) {
    upper_bound <- positions$label_y[i - 1] - minimum_gap
    if (positions$label_y[i] > upper_bound) {
      positions$label_y[i] <- upper_bound
    }
  }
  label_floor <- min(monthly_summary$lower) - 0.02 * value_span
  undershoot <- label_floor - min(positions$label_y)
  if (undershoot > 0) {
    positions$label_y <- positions$label_y + undershoot
  }
  positions$label <- REGION_SHORT[as.character(positions$region)]
  positions
}
label_positions <- place_direct_labels(STAT_ROW_HEIGHT_MM)

p_monthly <- ggplot2::ggplot(
  monthly_summary,
  ggplot2::aes(month, mean, colour = region, fill = region)
) +
  ggplot2::geom_ribbon(
    ggplot2::aes(ymin = lower, ymax = upper),
    colour = NA,
    alpha = 0.16
  ) +
  ggplot2::geom_line(linewidth = DATA_LINE_MM) +
  ggplot2::geom_text(
    data = label_positions,
    ggplot2::aes(x = 12.35, y = label_y, label = label, colour = region),
    inherit.aes = FALSE,
    hjust = 0,
    family = FONT_FAMILY,
    size = TEXT_GG,
    show.legend = FALSE
  ) +
  ggplot2::scale_colour_manual(values = REGION_COLOURS, guide = "none") +
  ggplot2::scale_fill_manual(values = REGION_COLOURS, guide = "none") +
  ggplot2::scale_x_continuous(
    limits = c(0.6, 13.6),
    breaks = c(2, 4, 6, 8, 10, 12),
    labels = month.abb[c(2, 4, 6, 8, 10, 12)]
  ) +
  ggplot2::labs(
    tag = "d",
    x = "Month",
    y = "Simulated monthly index (arbitrary units)",
    alt = paste(
      "Monthly regional means of the simulated index with 95 percent t",
      "confidence ribbons for four China regions; lines end with direct",
      "region labels instead of a duplicate legend."
    )
  ) +
  publication_theme +
  ggplot2::theme(legend.position = "none")

# ---- Panel e: standardized model effects with null line --------------------
p_effects <- ggplot2::ggplot(
  effect_table,
  ggplot2::aes(estimate, term)
) +
  ggplot2::geom_vline(
    xintercept = 0,
    linetype = "22",
    colour = "grey35",
    linewidth = LINE_MM
  ) +
  ggplot2::geom_errorbar(
    ggplot2::aes(xmin = lower, xmax = upper),
    orientation = "y",
    width = 0.16,
    linewidth = DATA_LINE_MM,
    colour = "black"
  ) +
  ggplot2::geom_point(size = 2.1, colour = "black") +
  ggplot2::labs(
    tag = "e",
    x = "Standardized effect on\nproductivity index",
    y = NULL,
    alt = paste(
      "Ordinary least squares coefficients of standardized temperature,",
      "precipitation, and latitude with 95 percent confidence intervals",
      "and a dashed zero reference line."
    )
  ) +
  publication_theme +
  ggplot2::theme(legend.position = "none")

# ---- Compose: one flat spanned grid, lowercase tags ------------------------
compose_figure <- function(map_row_height_mm) {
  patchwork::wrap_plots(
    a = p_map_final,
    b = p_distribution,
    c = p_relationship,
    d = p_monthly,
    e = p_effects,
    design = DESIGN,
    widths = COLUMN_WIDTHS,
    heights = grid::unit(c(map_row_height_mm, STAT_ROW_HEIGHT_MM), "mm")
  ) &
    ggplot2::theme(
      plot.tag = ggplot2::element_text(
        family = FONT_FAMILY, size = TAG_PT, face = "bold", colour = "black",
        margin = ggplot2::margin(0, 0, TAG_CLEARANCE_MM, 0, "mm")
      )
    )
}

panel_plots <- list(
  a = p_map, b = p_distribution, c = p_relationship, d = p_monthly, e = p_effects
)
panel_alt_texts <- vapply(panel_plots, function(plot_object) {
  ggplot2::ggplot_build(plot_object)
  alt_text <- ggplot2::get_labs(plot_object)$alt
  stopifnot(length(alt_text) == 1L, nzchar(alt_text))
  alt_text
}, character(1))

# ---- Measure the five data rectangles at final size ------------------------
# Slot viewports sit at the shallowest panel depth; the fixed-aspect map also
# exposes an inner viewport that is the true black rectangle.
# Pass 1: measure column geometry with a provisional height, then set the map
# row height so the fixed-aspect map exactly fills its spanned slot.
provisional <- rfigure_measure_panels(
  compose_figure(85),
  FIGURE_WIDTH_MM,
  220,
  "png",
  expected_panels = 5
)
map_slot_width <- provisional$slots$width_mm[provisional$slots$panel == "a"]
row_gap_mm <- provisional$slots$bottom_mm[provisional$slots$panel == "a"] -
  provisional$slots$top_mm[provisional$slots$panel == "c"]
MAP_ROW_HEIGHT_MM <- map_slot_width / map_ratio
FIGURE_HEIGHT_MM <- OUTER_TOTAL_MM + MAP_ROW_HEIGHT_MM + row_gap_mm +
  STAT_ROW_HEIGHT_MM
cat(sprintf(
  "Calibration: map slot width %.3f mm, map row height %.3f mm, row gap %.3f mm, figure height %.3f mm\n",
  map_slot_width, MAP_ROW_HEIGHT_MM, row_gap_mm, FIGURE_HEIGHT_MM
))

composite <- compose_figure(MAP_ROW_HEIGHT_MM)

# The PNG device is the calibration and enforcement target; SVG geometry
# is measured and reported for information only.
check_geometry <- function(measured, enforce = TRUE) {
  slots <- measured$slots
  # Match by containment, not by area: theme(aspect.ratio) panels expose inner
  # viewports too, so the largest one is not necessarily the map's.
  map_inner <- rfigure_match_inner(measured$slots, measured$inner, "a")
  stopifnot(nrow(map_inner) == 1L)

  # Row and column coherence, derived from the measured edges rather than
  # from a deviation list written for this one design.
  grid_report <- rfigure_check_grid(slots, tolerance_mm = ALIGNMENT_TOLERANCE_MM)
  fill <- rfigure_check_fixed_fill(
    slots[slots$panel == "a", , drop = FALSE],
    map_inner,
    tolerance_mm = ALIGNMENT_TOLERANCE_MM
  )
  worst <- max(attr(grid_report, "max_spread_mm"), fill$deviation_mm)
  if (!attr(grid_report, "passed") || !fill$passed) {
    alignment_message <- paste(
      "Panel alignment failed: worst deviation",
      sprintf("%.3f mm", worst),
      "(map slot fill", sprintf("%.3f mm)", fill$deviation_mm)
    )
    if (enforce) {
      print(grid_report[grid_report$spread_mm > ALIGNMENT_TOLERANCE_MM, ],
            row.names = FALSE, digits = 4)
      stop(alignment_message)
    }
    cat("Informational (SVG, not enforced):", alignment_message, "\n")
  }

  area_share <- rfigure_panel_area_share(
    slots, FIGURE_WIDTH_MM, FIGURE_HEIGHT_MM,
    inner = map_inner, inner_replaces = "a"
  )
  if (area_share < MIN_PANEL_AREA_SHARE) {
    area_message <- paste("Panel area share is too small:",
                          sprintf("%.3f", area_share))
    if (enforce) stop(area_message)
    cat("Informational (SVG, not enforced):", area_message, "\n")
  }
  map_rendered_ratio <- map_inner$width_mm / map_inner$height_mm
  if (abs(map_rendered_ratio - map_ratio) > 0.02) {
    ratio_message <- paste("Rendered map ratio drifted:",
                           sprintf("%.4f", map_rendered_ratio))
    if (enforce) stop(ratio_message)
    cat("Informational (SVG, not enforced):", ratio_message, "\n")
  }
  data.frame(
    device = unique(slots$device),
    panel_area_share = area_share,
    map_rendered_ratio = map_rendered_ratio,
    maximum_alignment_deviation_mm = worst
  )
}

png_measured <- rfigure_measure_panels(
  composite, FIGURE_WIDTH_MM, FIGURE_HEIGHT_MM, "png", expected_panels = 5
)
svg_measured <- rfigure_measure_panels(
  composite, FIGURE_WIDTH_MM, FIGURE_HEIGHT_MM, "svg", expected_panels = 5
)
geometry_results <- rbind(
  check_geometry(png_measured),
  check_geometry(svg_measured, enforce = FALSE)
)

# ---- Explicit protected export ---------------------------------------------
if (file.exists(OUTPUT_PNG)) stop("Refusing to overwrite: ", OUTPUT_PNG)
if (file.exists(OUTPUT_SVG)) stop("Refusing to overwrite: ", OUTPUT_SVG)

ggplot2::ggsave(
  OUTPUT_PNG,
  composite,
  device = ragg::agg_png,
  width = FIGURE_WIDTH_MM,
  height = FIGURE_HEIGHT_MM,
  units = "mm",
  dpi = FIGURE_DPI,
  bg = "white"
)
ggplot2::ggsave(
  OUTPUT_SVG,
  composite,
  device = svglite::svglite,
  width = FIGURE_WIDTH_MM,
  height = FIGURE_HEIGHT_MM,
  units = "mm",
  bg = "white"
)

stopifnot(
  file.info(OUTPUT_PNG)$size > 0,
  file.info(OUTPUT_SVG)$size > 0
)
print(rbind(png_measured$slots, svg_measured$slots),
      row.names = FALSE, digits = 4)
print(rbind(png_measured$inner[1, ], svg_measured$inner[1, ]),
      row.names = FALSE, digits = 4)
print(geometry_results, row.names = FALSE, digits = 4)
cat(sprintf(
  "map_ratio=%.4f inset_ratio=%.4f inset_width=%.4f\n",
  map_ratio, inset_ratio, inset_width
))
# ---- Sidecar caption file: figure-level disclosures live beside the image
OUTPUT_TXT <- file.path(SCRIPT_DIR, "five_panel_china_demo.caption.txt")
if (file.exists(OUTPUT_TXT)) stop("Refusing to overwrite: ", OUTPUT_TXT)
caption_lines <- c(
  "China five-panel synthesis (demonstration figure, simulated data)",
  "",
  paste0("Panel ", names(panel_alt_texts), ": ", unname(panel_alt_texts)),
  "",
  trimws(figure_note),
  "",
  trimws(map_note),
  "",
  sprintf(
    "Geometry (PNG, enforced): panel area share %.3f; maximum panel alignment deviation %.4f mm.",
    geometry_results$panel_area_share[[1]],
    geometry_results$maximum_alignment_deviation_mm[[1]]
  ),
  sprintf(
    "Geometry (SVG, informational): panel area share %.3f; maximum panel alignment deviation %.4f mm.",
    geometry_results$panel_area_share[[2]],
    geometry_results$maximum_alignment_deviation_mm[[2]]
  ),
  sprintf("Canvas %.1f x %.1f mm at %d dpi.",
          FIGURE_WIDTH_MM, FIGURE_HEIGHT_MM, FIGURE_DPI),
  "",
  paste(
    "Software:", R.version.string,
    "| ggplot2", as.character(utils::packageVersion("ggplot2")),
    "| patchwork", as.character(utils::packageVersion("patchwork")),
    "| sf", as.character(utils::packageVersion("sf"))
  )
)
writeLines(enc2utf8(caption_lines), OUTPUT_TXT, useBytes = TRUE)
stopifnot(file.info(OUTPUT_TXT)$size > 0)

cat("PASS\n", OUTPUT_PNG, "\n", OUTPUT_SVG, "\n", sep = "")
