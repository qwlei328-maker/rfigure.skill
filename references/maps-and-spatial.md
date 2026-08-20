# Self-Contained Maps and Spatial Figures

Use this reference for `sf`, projections, sampling-site overlays, graticules, insets, scale bars, and multi-map layouts. Deliver the map as one public R script with no dependency on rfigure helper files.

## Contents

- Spatial integrity rules
- Coordinate systems and cropping
- Choosing and customizing the projection
- Map furniture: graticule and decimal labels
- Complete China map script
- Rendered-panel inset ratio
- Map plus statistical panel
- Export and inspection

## Spatial Integrity Rules for the AI

1. Keep every geometry's CRS explicit and transform layers to a common projected CRS.
2. Use `coord_sf(xlim = ..., ylim = ..., default_crs = sf::st_crs(4326))` for longitude/latitude windows. Do not crop an `sf` map with `xlim()` or `ylim()`.
3. Do not calculate distance or area directly from EPSG:4326 coordinates.
4. State map source, administrative level, boundary vintage, projection, and disputed-boundary treatment.
5. Transform site coordinates with `st_as_sf(..., crs = 4326)` and retain original longitude/latitude columns when useful.
6. Encode site classes with a stable named color palette while keeping every map site as the same solid circle by default. Do not map class to point shape unless the user explicitly asks for shapes. Use clear legend text, direct labels, or the companion statistical panels for redundant identification when needed.
7. Give every geographic map a graticule with decimal-degree labels on the left and bottom edges. Omit it only for a locator inset, a deliberately bare schematic, or an explicit user request, and disclose the omission. Do not add a north arrow by default: the graticule already carries orientation. Add one only when the user asks, and remember that under `default_crs = sf::st_crs(4326)` a plain `annotate()` layer takes longitude/latitude, not projected metres.
8. Keep the projection in one visible parameter so the recipient can change it without editing the layers, and name it in the disclosure.
9. Inspect coastlines, islands, borders, labels, sites, graticule labels, and inset placement in the exported file.
10. Prefer legends inside genuine ocean or other unused panel space. Make an interior map legend fully transparent and borderless, including its keys, then verify that it covers no islands, sites, boundaries, labels, or inset. If no safe map space exists, use a right-side/shared guide rather than a top/bottom legend.

These constraints tell the AI how to avoid silently misrepresenting spatial evidence. A human may choose another valid CRS, extent, boundary source, or sampling rule; the AI must implement and disclose that choice.

## Coordinate Systems and Cropping

The projection belongs in one visible parameter, chosen by the map's purpose and extent, never left implicit:

```r
# Named projections; the delivered script keeps this table visible so a
# recipient can switch MAP_CRS in one line.
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

MAP_PROJECTION <- "china_albers"   # a registry name, or any PROJ string / EPSG
MAP_CRS <- if (MAP_PROJECTION %in% names(MAP_PROJECTIONS)) {
  MAP_PROJECTIONS[[MAP_PROJECTION]]
} else {
  MAP_PROJECTION
}
```

Defaults by scope, all overridable by the user:

| Map scope | Default | Why |
|---|---|---|
| World, showing site positions | `plate_carree` | rectangular, so the panel frame fits the map and the graticule can be dropped while the axis labels survive |
| World, any area or density claim | `behrmann` | equal-area and still rectangular, so the frame stays honest and so does the area |
| World, when the oval look is wanted | `robinson` or `equal_earth` | the conventional whole-world compromise shapes; then keep the graticule or draw the oval outline (below) |
| China / mid-latitude country | `china_albers` | equal-area conic matched to the country's latitude band; the convention for national Chinese maps |
| Local study area | a projected national or UTM zone CRS | metric distance and area within the study extent |

`plate_carree` is not equal-area: high latitudes are inflated, and Greenland and Russia read far larger than they are. Use it for a map that only locates sites, and switch to `behrmann` the moment the panel carries a quantity per unit area.

Rules:

- Implement whatever CRS the user names, including one this table would not have chosen, and disclose it. The user's cartographic choice is legitimate; silently substituting another projection is not.
- Match the projection to the claim, not to habit. Use an equal-area projection whenever area, density, or per-unit-area quantities are read off the map; a compromise projection such as Robinson distorts area and must not carry a density claim.
- Robinson and Equal Earth are pseudocylindrical world projections. On a single mid-latitude country they waste space, shear the outline, and are unconventional; prefer a conic there unless the user asks otherwise.
- Never use EPSG:3857 (Web Mercator) for measurement or for any area comparison.
- Re-check the graticule breaks after changing the projection: a projection change moves which meridians and parallels reach the labelled bottom and left edges.

When `default_crs` is EPSG:4326, the `coord_sf()` limits are longitude/latitude:

```r
coord_sf(
  crs = MAP_CRS,
  default_crs = st_crs(4326),
  xlim = c(72, 142),
  ylim = c(12, 56),
  expand = FALSE
)
```

Select a study-region projection when area, distance, density, or spatial-model interpretation matters.

## Map Furniture: Graticule and Decimal Labels

A geographic panel carries two pieces of furniture by default: a graticule and decimal-degree tick labels on the left and bottom edges. Both are structure, not data: keep them thin and grey, and visually subordinate to boundaries and sites. A north arrow is not part of the default set, because a labelled graticule already tells the reader which way north is; add one only on request.

The graticule may be removed when the projection is rectangular, which keeps the labels; on a curved-graticule projection removing it silently removes most of the latitude labels as well. See "Frame and graticule" under World and Global Maps.

### Graticule and decimal-degree labels

With `default_crs = sf::st_crs(4326)`, the graticule breaks are longitude/latitude even when the panel is projected. Set them explicitly, keep `label_axes = "--EN"` so only the bottom carries longitude and only the left carries latitude, and format both with a fixed number of decimals:

```r
GRATICULE_LON <- seq(80, 140, by = 15)   # degrees east
GRATICULE_LAT <- seq(20, 50, by = 10)    # degrees north
GRATICULE_DECIMALS <- 1

decimal_degree <- function(values, hemisphere) {
  sprintf(paste0("%.", GRATICULE_DECIMALS, "f\u00b0%s"), values, hemisphere)
}

p_map <- p_map +
  scale_x_continuous(
    breaks = GRATICULE_LON,
    labels = function(x) decimal_degree(x, "E")
  ) +
  scale_y_continuous(
    breaks = GRATICULE_LAT,
    labels = function(y) decimal_degree(y, "N")
  ) +
  coord_sf(
    crs = MAP_CRS,
    xlim = MAIN_XLIM,
    ylim = MAIN_YLIM,
    default_crs = st_crs(4326),
    label_axes = "--EN",
    expand = FALSE
  ) +
  theme(
    panel.grid.major = element_line(
      colour = "grey88", linewidth = LINE_MM * 0.5
    ),
    axis.text = element_text(
      family = FONT_FAMILY, size = TEXT_PT, colour = "black"
    ),
    axis.ticks = element_line(colour = "black", linewidth = LINE_MM),
    axis.title = element_blank()
  )
```

Rules:

- Do not blank `axis.text` on a geographic panel that is meant to be read as a map; blank it only on an inset or an explicitly bare schematic.
- Use decimal degrees, not degree-minute-second, and use the same decimal count for both axes in one figure.
- Choose break spacing that leaves labels unambiguous at final size; five to six labels per axis is usually enough on a national map.
- Verify that every graticule break actually produces a drawn label. On a conic projection an outer meridian can leave the panel through the **side** edge instead of the bottom; `coord_sf()` still draws that grey line but prints no label, and the script exits cleanly. With `xlim = c(72, 142)`, `seq(80, 140, by = 15)` leaves `140` drawn and unlabelled, while `seq(80, 130, by = 10)` is clean. Check the labels the axes really rendered, not the geometry of the graticule lines: on a pseudocylindrical world map no parallel ever reaches the left edge, yet every latitude label is drawn, so a geometric touch test rejects correct world maps.

```r
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
```

- Keep the graticule under the data. `panel.grid.major` draws below layers by default; do not raise it with a data-layer `geom_sf()` of graticule lines.
- Hemisphere suffixes must match the extent. A map crossing the equator or the prime meridian needs signed values or per-value suffixes, not a blanket `"N"`/`"E"`.

### The degree sign must be an escape

Under a C locale, R converts an unmarked non-ASCII string to native encoding before it reaches the device, and every non-ASCII byte becomes a period: `80.0\u00b0E` written as a literal degree character renders as `80.0..E`, and `R` with a literal superscript two renders as `R..`. Writing `\u00b0` and `\u00b2` as escapes makes the R parser mark the string UTF-8, and it renders correctly regardless of locale. Assert it rather than trusting a visual check alone:

```r
stopifnot(Encoding(decimal_degree(80, "E")) == "UTF-8")
```

The same applies to any CJK text, the plus-minus sign, and en dashes in labels.

## Complete China Map Script

The following code is deliberately self-contained. All style, map-loading, panel-ratio, inset, and export parameters are visible in the same file.

```r
library(ggplot2)
library(sf)
library(patchwork)
library(ggmapcn)

# ---- Public figure parameters ---------------------------------------------
FONT_FAMILY   <- "Arial"
TEXT_PT       <- 8
TAG_PT        <- 9
TEXT_GG       <- TEXT_PT / ggplot2::.pt   # .pt = 72.27 / 25.4
LINE_MM       <- 25.4 / 72
DATA_LINE_MM  <- LINE_MM * 1.8

FIG_WIDTH_MM  <- 190
FIG_HEIGHT_MM <- 125
FIG_DPI       <- 600
RANDOM_SEED   <- 20260818

MAIN_XLIM     <- c(72, 142)
MAIN_YLIM     <- c(12, 56)
INSET_XLIM    <- c(105, 125)
INSET_YLIM    <- c(0, 25)

GRATICULE_LON      <- seq(80, 130, by = 10)
GRATICULE_LAT      <- seq(20, 50, by = 10)
GRATICULE_DECIMALS <- 1
INSET_HEIGHT  <- 0.28
INSET_RIGHT   <- 1
INSET_BOTTOM  <- 0

# ---- Projection: one visible parameter, switchable in one line -------------
MAP_PROJECTIONS <- c(
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
# Equal-area conic is the default for a national China map; "robinson" is the
# default for world maps. Any registry name, PROJ string, or EPSG code works.
MAP_PROJECTION <- "china_albers"
MAP_CRS <- if (MAP_PROJECTION %in% names(MAP_PROJECTIONS)) {
  MAP_PROJECTIONS[[MAP_PROJECTION]]
} else {
  MAP_PROJECTION
}

site_colours <- c(
  North = "#2C7FB8",
  Central = "#E08214",
  South = "#4D9221"
)

# ---- Font check ------------------------------------------------------------
available_fonts <- unique(systemfonts::system_fonts()$family)
if (!FONT_FAMILY %in% available_fonts) {
  stop("Font is unavailable: ", FONT_FAMILY)
}

# ---- Decimal-degree labels; the escape keeps the glyph UTF-8 under any locale
decimal_degree <- function(values, hemisphere) {
  sprintf(paste0("%.", GRATICULE_DECIMALS, "f\u00b0%s"), values, hemisphere)
}
stopifnot(Encoding(decimal_degree(80, "E")) == "UTF-8")

# ---- Load and validate ggmapcn province polygons ---------------------------
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
} else if (length(map_objects) == 1) {
  china <- get(map_objects[[1]], envir = map_environment, inherits = FALSE)
} else {
  stop("Could not identify the province-map object in: ", map_path)
}

if (!inherits(china, "sf")) stop("Loaded China map is not an sf object.")

boundary_row <- rep(FALSE, nrow(china))
for (column in intersect(c("name", "name_en"), names(china))) {
  value <- as.character(china[[column]])
  boundary_row <- boundary_row |
    (!is.na(value) & toupper(value) == "BOUNDARY LINE")
}
china <- st_make_valid(china[!boundary_row, , drop = FALSE])
china <- st_transform(china, 4326)

# ---- Deterministic demonstration sites sampled inside land polygons --------
china_mask <- st_union(st_transform(china, MAP_CRS))
set.seed(RANDOM_SEED)
candidate_points <- st_sample(china_mask, size = 500, exact = TRUE)
candidate_xy <- st_coordinates(st_transform(candidate_points, 4326))

candidates <- data.frame(
  lon = candidate_xy[, 1],
  lat = candidate_xy[, 2]
)
candidates$group <- cut(
  candidates$lat,
  breaks = c(-Inf, 30, 37, Inf),
  labels = c("South", "Central", "North")
)

target_counts <- c(North = 6L, Central = 7L, South = 7L)
selected_sites <- lapply(names(target_counts), function(group_name) {
  pool <- candidates[candidates$group == group_name, , drop = FALSE]
  if (nrow(pool) < target_counts[[group_name]]) {
    stop("Not enough sampled points in stratum: ", group_name)
  }
  pool[seq_len(target_counts[[group_name]]), , drop = FALSE]
})

sites <- do.call(rbind, selected_sites)
sites$group <- factor(sites$group, levels = names(target_counts))
sites$site <- sprintf("S%02d", seq_len(nrow(sites)))
sites_sf <- st_as_sf(
  sites,
  coords = c("lon", "lat"),
  crs = 4326,
  remove = FALSE
) |>
  st_transform(MAP_CRS)

stopifnot(all(lengths(st_within(sites_sf, china_mask)) == 1L))

# ---- Complete visible theme ------------------------------------------------
publication_theme <-
  theme_classic(base_size = TEXT_PT, base_family = FONT_FAMILY) +
  theme(
    text = element_text(
      family = FONT_FAMILY, size = TEXT_PT, colour = "black"
    ),
    axis.text = element_text(
      family = FONT_FAMILY, size = TEXT_PT, colour = "black"
    ),
    axis.title = element_text(
      family = FONT_FAMILY, size = TEXT_PT, colour = "black"
    ),
    legend.text = element_text(
      family = FONT_FAMILY, size = TEXT_PT, colour = "black"
    ),
    legend.title = element_text(
      family = FONT_FAMILY, size = TEXT_PT, colour = "black"
    ),
    strip.text = element_text(
      family = FONT_FAMILY, size = TEXT_PT, colour = "black"
    ),
    plot.caption = element_text(
      family = FONT_FAMILY, size = TEXT_PT, colour = "black"
    ),
    plot.tag = element_text(
      family = FONT_FAMILY, size = TAG_PT, face = "bold", colour = "black"
    ),
    panel.border = element_rect(
      colour = "black", fill = NA, linewidth = LINE_MM
    ),
    axis.line = element_blank(),
    axis.ticks = element_line(colour = "black", linewidth = LINE_MM),
    panel.grid = element_blank(),
    plot.background = element_rect(fill = "white", colour = NA),
    panel.background = element_rect(fill = "white", colour = NA),
    legend.background = element_rect(fill = NA, colour = NA),
    legend.box.background = element_blank(),
    legend.key = element_rect(fill = NA, colour = NA),
    plot.margin = margin(2, 2, 2, 2, "mm")
  )

# ---- Reused map layers, fully defined here ---------------------------------
map_layers <- function() {
  list(
    geom_mapcn(
      data = china,
      admin_level = "province",
      crs = MAP_CRS,
      fill = "#F2F2F2",
      color = "#B8B8B8",
      linewidth = LINE_MM * 0.7
    ),
    geom_boundary_cn(
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

# ---- Main and inset maps ---------------------------------------------------
p_main <- ggplot() +
  map_layers() +
  geom_sf(
    data = sites_sf,
    aes(fill = group),
    shape = 21,
    size = 2.8,
    stroke = DATA_LINE_MM,
    colour = "black"
  ) +
  scale_fill_manual(
    values = site_colours,
    breaks = names(site_colours),
    name = "Site group"
  ) +
  scale_x_continuous(
    breaks = GRATICULE_LON,
    labels = function(x) decimal_degree(x, "E")
  ) +
  scale_y_continuous(
    breaks = GRATICULE_LAT,
    labels = function(y) decimal_degree(y, "N")
  ) +
  coord_sf(
    crs = MAP_CRS,
    xlim = MAIN_XLIM,
    ylim = MAIN_YLIM,
    default_crs = st_crs(4326),
    label_axes = "--EN",
    expand = FALSE
  ) +
  labs(
    x = NULL,
    y = NULL,
    alt = paste(
      "Map of China with twenty reproducible demonstration sites",
      "grouped as north, central, and south."
    )
  ) +
  publication_theme +
  theme(
    axis.title = element_blank(),
    panel.grid.major = element_line(
      colour = "grey88", linewidth = LINE_MM * 0.5
    ),
    legend.position = "inside",
    legend.position.inside = c(0.035, 0.965),
    legend.justification = c(0, 1),
    legend.background = element_rect(fill = NA, colour = NA),
    legend.box.background = element_blank(),
    legend.key = element_rect(fill = NA, colour = NA)
  )

p_south_china_sea <- ggplot() +
  map_layers() +
  coord_sf(
    crs = MAP_CRS,
    xlim = INSET_XLIM,
    ylim = INSET_YLIM,
    default_crs = st_crs(4326),
    expand = FALSE
  ) +
  publication_theme

# ---- Measure actual rendered panel ranges ----------------------------------
panel_range <- function(panel_parameters, axis = c("x", "y")) {
  axis <- match.arg(axis)
  for (name in c(paste0(axis, "_range"), paste0(axis, ".range"))) {
    value <- panel_parameters[[name]]
    if (is.numeric(value) && length(value) == 2 && all(is.finite(value))) {
      return(as.numeric(value))
    }
  }

  axis_parameters <- panel_parameters[[axis]]
  if (!is.null(axis_parameters)) {
    for (name in c("continuous_range", "range")) {
      value <- axis_parameters[[name]]
      if (is.numeric(value) && length(value) == 2 && all(is.finite(value))) {
        return(as.numeric(value))
      }
    }
  }
  stop("Could not read the rendered ", axis, " range.")
}

panel_ratio <- function(plot) {
  built <- ggplot_build(plot)
  parameters <- built$layout$panel_params[[1]]
  x_range <- panel_range(parameters, "x")
  y_range <- panel_range(parameters, "y")
  as.numeric(diff(x_range) / diff(y_range))
}

main_ratio <- panel_ratio(p_main)
inset_ratio <- panel_ratio(p_south_china_sea)
inset_width <- INSET_HEIGHT * inset_ratio / main_ratio

inset_left <- INSET_RIGHT - inset_width
inset_top <- INSET_BOTTOM + INSET_HEIGHT
# Invariants, not viewport-specific constants: the inset must sit inside the
# panel and keep its own aspect. Do not assert literal ratios here - they are
# properties of one viewport, and any change of extent makes a copied script
# die on a number unrelated to its own figure. Print the measured values in
# the console audit instead.
stopifnot(
  inset_left >= 0,
  INSET_RIGHT <= 1,
  INSET_BOTTOM >= 0,
  inset_top <= 1,
  is.finite(main_ratio),
  is.finite(inset_ratio),
  inset_width > 0,
  inset_width <= 1
)

# ---- Use exactly the same geometry for inset and border --------------------
inset_map <- p_south_china_sea +
  theme(
    panel.border = element_blank(),
    axis.text = element_blank(),
    axis.title = element_blank(),
    axis.ticks = element_blank(),
    legend.position = "none",
    plot.margin = margin(0, 0, 0, 0, "mm")
  )

inset_frame <- ggplot() +
  theme_void() +
  theme(
    plot.background = element_rect(
      fill = NA, colour = "black", linewidth = LINE_MM
    ),
    plot.margin = margin(0, 0, 0, 0, "mm")
  )

p_final <- p_main +
  inset_element(
    inset_map,
    left = inset_left,
    bottom = INSET_BOTTOM,
    right = INSET_RIGHT,
    top = inset_top,
    align_to = "panel"
  ) +
  inset_element(
    inset_frame,
    left = inset_left,
    bottom = INSET_BOTTOM,
    right = INSET_RIGHT,
    top = inset_top,
    align_to = "panel"
  )

# ---- Explicit export -------------------------------------------------------
output_png <- "china_sites.png"
output_svg <- "china_sites.svg"
if (file.exists(output_png)) stop("Refusing to overwrite: ", output_png)
if (file.exists(output_svg)) stop("Refusing to overwrite: ", output_svg)

ggsave(
  output_png,
  plot = p_final,
  device = ragg::agg_png,
  width = FIG_WIDTH_MM,
  height = FIG_HEIGHT_MM,
  units = "mm",
  dpi = FIG_DPI,
  bg = "white"
)
ggsave(
  output_svg,
  plot = p_final,
  device = svglite::svglite,
  width = FIG_WIDTH_MM,
  height = FIG_HEIGHT_MM,
  units = "mm",
  bg = "white"
)

stopifnot(
  file.info(output_png)$size > 0,
  file.info(output_svg)$size > 0
)
message(sprintf(
  "main_ratio=%.4f inset_ratio=%.4f inset_width=%.4f",
  main_ratio, inset_ratio, inset_width
))
```

Replace demonstration sites with observed coordinates for scientific use. Retain the original coordinates, CRS, filters, and source metadata in the public script.

## Rendered-Panel Inset Ratio

Measure the panel that ggplot2 actually builds. Do not project only four longitude/latitude corners and take their bounding box: curved projected boundaries can extend beyond those corners.

The complete script above defines `panel_range()` and `panel_ratio()` locally, then calculates:

```r
main_ratio <- panel_ratio(p_main)
inset_ratio <- panel_ratio(p_south_china_sea)
inset_width <- INSET_HEIGHT * inset_ratio / main_ratio
```

The function definitions and all placement values remain visible in the same file.

For ordinary fixed-aspect maps placed beside flexible plots, leave patchwork widths/heights as `NA`. Use `-1null` for a fixed-aspect-aware flexible unit. If strict alignment and fixed aspect conflict, use `patchwork::free()` or `wrap_elements()` deliberately and inspect the result.

## World and Global Maps

A world map behaves differently from a national one in three ways that break assumptions carried over from the China examples. All numbers below are rendered panel width/height measured on ggplot2 4.0.3, Natural Earth `scale = "small"`.

### It is much wider than any ordinary panel

| Projection | lat -90 to 90 | lat -60 to 85 | lat -60 to 75 |
|---|---|---|---|
| Robinson | 1.97 | 2.29 | 2.42 |
| Equal Earth | 2.06 | 2.23 | 2.30 |
| Mollweide | 2.00 | 2.26 | 2.39 |
| Plate Carree | 2.00 | 2.48 | 2.67 |

Consequences to design around rather than fight:

- Give a world map its own full-width row. It cannot share a row with panels that must stay near 1.5-1.75 without either shrinking them or stretching itself.
- Cropping the poles makes the map **wider**, not narrower. If a layout needs the least extreme aspect, the full `-90 to 90` window is the one to use.
- In a golden-ratio variant the world map is exempt: no honest extent brings it into the band. Declare the exemption, then solve the statistics row instead - fix the statistical panel ratio, iterate the row height until the columns land in the band, and let the map row take what remains.
- Never stretch the map to fit. Changing `ylim` changes the scientific extent and must be disclosed; changing the panel aspect without changing the extent is a distortion.

### Latitude labels appear even though parallels never touch the left edge

`coord_sf(label_axes = "--EN")` draws longitude labels along the bottom and latitude labels along the left for pseudocylindrical projections, although the curved parallels stop short of the panel border. Use the rendered-label assertion above; a geometric test that asks whether a graticule line reaches the edge will reject every correct world map.

### Frame and graticule: pick the projection to match the frame

A four-sided frame around a pseudocylindrical projection boxes an oval and leaves four empty corners, and the longitude labels underneath it sit at unevenly compressed spacings. The fix is to choose the projection and the furniture together, because they are not independent:

**Hiding the graticule also hides the latitude labels on a curved-graticule projection.** `coord_sf()` places sf axis labels where the graticule meets the panel edge, so on Robinson the parallels never reach the left border and blanking the grid removes their labels too. Measured left-axis label counts:

| Projection | graticule kept | `panel.grid.major = element_blank()` | `element_line(colour = NA)` |
|---|---|---|---|
| Robinson | 5 | **1** | **1** |
| Plate Carree | 5 | **5** | 5 |

Only the equator survives on Robinson, because it is the one parallel that reaches the border. So:

- **Want a clean rectangle with no interior grid but full labels?** Use a rectangular projection - `plate_carree`, or `behrmann` when area matters - and set `panel.grid.major = element_blank()`. The frame now coincides with the map's own boundary, the meridian labels are evenly spaced, and every label is drawn.
- **Want to keep Robinson or Equal Earth?** Keep the graticule. If the rectangle is the objection rather than the grid, drop `panel.border` and draw the projection outline instead (below); the labels still work because the graticule is still there.
- **Want no furniture at all?** Drop frame, graticule, and labels together. Readers can no longer locate anything, so reserve this for a schematic or a locator, and say so.
- Do not blank the graticule on a curved projection and then hand-draw the missing latitude labels; that is how a figure ends up with two overlapping label sets.

Longitude label spacing follows the projection too. Robinson compresses meridians toward the edges, so 30-degree breaks collide at final size while 60-degree breaks do not; a rectangular projection spaces them evenly and takes 30-degree breaks comfortably. Check at final size, not in the preview.

### The antimeridian: horizontal streaks across the whole map

A world map that shows one or more thin horizontal lines spanning the full panel width has polygons crossing the antimeridian being drawn the long way round. The streaks sit at the latitudes of the offending countries, which makes them easy to identify: with Natural Earth, a line near 65 degrees north is Russia and one near 17 degrees south is Fiji. It is **not** caused by the rectangular panel frame and it is not fixed by changing the projection.

Two triggers, both measured on ggplot2 4.0.3 / sf with GEOS and s2 available:

1. **`st_make_valid()` with s2 enabled**, which is the default. The bundled Natural Earth polygons are supplied already split at 180 degrees, but `sf::st_make_valid()` under `sf_use_s2(TRUE)` rejoins Russia and Fiji across the antimeridian. The same pipeline under `sf::sf_use_s2(FALSE)` renders cleanly. A script that calls `st_make_valid()` on a world layer, as every example in this reference does, inherits the problem.
2. **A central meridian away from 0**. With `lon_0 = 150`, Russia smears across the top of the map and Antarctica across the bottom even without `st_make_valid()`.

Cut the geometries along the projection's antimeridian after any validity repair and before projecting. **Turn s2 off for the cut**: with s2 enabled the cut silently fails away from the prime meridian and errors outright on the Natural Earth `small` polygons.

```r
cut_at_antimeridian <- function(layer, lon_0) {
  previous <- sf::sf_use_s2(FALSE)          # planar cut; restored on exit
  on.exit(sf::sf_use_s2(previous), add = TRUE)
  blade <- sf::st_sfc(
    sf::st_linestring(cbind(rep(lon_0 - 180, 181), seq(-90, 90))),
    crs = 4326
  )
  cut <- sf::st_make_valid(suppressWarnings(
    sf::st_difference(sf::st_make_valid(layer), sf::st_buffer(blade, 0.00001))
  ))
  # st_difference can return GEOMETRYCOLLECTION; st_coordinates() has no method
  # for it, so the verification below would fail on the layer it must check.
  sf::st_collection_extract(cut, "POLYGON", warn = FALSE)
}
```

Measured on sf 1.1.x with GEOS and s2 available, Natural Earth via rnaturalearth, counting features whose rings still cross the antimeridian afterwards:

| s2 during the cut | dataset | `lon_0 = 0` | `lon_0 = 178` |
|---|---|---|---|
| enabled (default) | `medium` | none | **Antarctica, Fiji, Russia** |
| enabled | `small` | **error**: `Loop 0 is not valid` | **error** |
| disabled | `medium` | none | none |
| disabled | `small` | Antarctica only | Antarctica only |

Two consequences. The cut must run with s2 disabled, otherwise it fixes only the prime-meridian case - the one case that rarely needs it. And Antarctica keeps being reported on the coarse `small` polygons because it genuinely wraps the pole; either exclude it, as a world site map usually does, or exempt it by name in the assertion and say so.

Verify by looking at the rings, not at bounding boxes. A country legitimately drawn in two pieces spans the whole globe in its bounding box, so a bbox test flags correct maps and misses broken ones; a ring that crosses the antimeridian has consecutive vertices whose longitude jumps by more than 180 degrees:

```r
antimeridian_crossers <- function(layer, id_column = "admin") {
  coords <- sf::st_coordinates(sf::st_transform(sf::st_geometry(layer), 4326))
  has_l3 <- "L3" %in% colnames(coords)
  feature <- if (has_l3) coords[, "L3"] else coords[, "L2"]
  ring <- interaction(
    coords[, "L1"], coords[, "L2"], if (has_l3) coords[, "L3"] else 1,
    drop = TRUE
  )
  jumped <- tapply(seq_len(nrow(coords)), ring, function(index) {
    any(abs(diff(coords[index, "X"])) > 180)
  })
  bad <- names(jumped)[jumped]
  sort(unique(as.character(
    layer[[id_column]][unique(feature[as.character(ring) %in% bad])]
  )))
}
stopifnot(length(setdiff(antimeridian_crossers(world), "Antarctica")) == 0)
```

On the raw layer this reports `Fiji, Russia`; after an s2-disabled cut it reports nothing on the `medium` polygons, and the streaks are gone from the export.

Two limits of this check that a first use will hit: it needs polygons, so run it after `st_collection_extract()`; and the "jump greater than 180 degrees" test assumes longitudes in the -180 to 180 frame. A layer shifted to 0-360 with `sf::st_shift_longitude()` - which is how a viewport that itself straddles the antimeridian is built - flags every country crossing the prime meridian instead. Shift the layer back, or test against the frame you actually used.

`sf::st_wrap_dateline()` is the documented tool, but on these polygons it failed with `IllegalArgumentException: Points of LinearRing do not form a closed linestring` and left the smearing in place.

### The rectangular frame is a style choice, not the bug

A pseudocylindrical projection draws an oval; the four-sided panel border boxes it and leaves four empty corners. That is a legitimate thing to dislike, but it never produces marks inside the map. If the oval outline is wanted, drop `panel.border` and draw the projected graticule frame as a layer:

```r
projection_outline <- sf::st_sfc(sf::st_polygon(list(cbind(
  c(seq(-180, 180, 0.5), rep(180, 361), seq(180, -180, -0.5), rep(-180, 361)),
  c(rep(-90, 721), seq(-90, 90, 0.5), rep(90, 721), seq(90, -90, -0.5))
))), crs = 4326)

p_map <- p_map +
  geom_sf(
    data = projection_outline, fill = NA, colour = "black", linewidth = LINE_MM
  ) +
  theme(panel.border = element_blank(), axis.ticks = element_blank())
```

Keep the axis labels; they still sit outside the oval. Note that dropping the panel border departs from the four-sided 1 pt frame used everywhere else in a figure, so apply it to every map panel in that figure or to none.

### Hemisphere suffixes: `ifelse()` on a scalar returns a scalar

A label helper that branches on the axis rather than on the value is the most common way to get every longitude labelled `W` and every latitude labelled `S`:

```r
# WRONG: `axis` has length 1, so ifelse() returns one element and recycles it;
# every break inherits the hemisphere of the first break.
decimal_degree <- function(values, axis) {
  hemisphere <- ifelse(axis == "x",
    ifelse(values < 0, "W", "E"),
    ifelse(values < 0, "S", "N"))
  sprintf("%.1f\u00b0%s", abs(values), hemisphere)
}

# RIGHT: branch on the axis with if(), vectorise only over the values.
decimal_degree <- function(values, axis = c("x", "y")) {
  axis <- match.arg(axis)
  hemisphere <- if (axis == "x") {
    ifelse(values < 0, "W", "E")
  } else {
    ifelse(values < 0, "S", "N")
  }
  ifelse(
    values == 0,
    sprintf("0\u00b0"),
    sprintf("%.1f\u00b0%s", abs(values), hemisphere)
  )
}
stopifnot(
  decimal_degree(c(-150, 0, 150), "x") ==
    c("150.0\u00b0W", "0\u00b0", "150.0\u00b0E")
)
```

Give the equator and the prime meridian no suffix, and assert the mapping rather than eyeballing it.

### Do not hand-draw parallel labels

`coord_sf(label_axes = "--EN")` labels the parallels on the left edge of a pseudocylindrical world map even though the curved parallels stop short of the border. Adding a manual `geom_text()` layer for them produces two overlapping sets of labels. Check what the axes rendered with the assertion in the graticule section before concluding that a label is missing.

## Map Plus Statistical Panel

Choose the composition from the rendered map geometry, not from a universal template:

- A near-square national map can sit beside a statistical panel. Measure the map panel width/height, set the statistical panel's `aspect.ratio` to the reciprocal, and use `widths = c(NA, NA)` so patchwork can honor both fixed aspects.
- A wide global map generally belongs above a compact horizontal interval/distribution panel. Use one column with `heights = c(NA, NA)`, preserve the world projection, and verify that the two data rectangles share left and right edges.
- Keep map and statistic colors semantically identical. Use one solid circular map glyph for all groups; statistical panels may use geometry appropriate to their evidence but must retain the same color meanings. If the statistical axis already names every group, suppress its duplicate legend.
- For a five-panel map synthesis, make the map the visual anchor and add four genuinely different statistical views, such as distribution, estimate/interval, relationship, and composition or ranking. Avoid four cosmetic variations of the same summary. Use lowercase `a`–`e`, keep shared disclosures outside the panel rectangles, and measure the actual black frames after export.
- Put the map legend in inspected ocean/empty space. Keep it away from sites, islands, labels, political boundaries, and any inset.
- Draw an interior map legend without a card: `legend.background = element_rect(fill = NA, colour = NA)`, `legend.box.background = element_blank()`, and transparent `legend.key`. If the labels become hard to read, move the legend to safer whitespace instead of restoring an opaque box over the map.
- Measure panel coordinates from both PNG and SVG. For side-by-side layouts check common top/bottom edges; for stacked layouts check common left/right edges.
- Handle the antimeridian before projecting a world map; see "World and Global Maps" above for the measured failure and the cut recipe. Inspect for horizontal wrap lines, duplicated polygons, clipped islands, and site displacement.
- Keep site generation or selection, sample counts, uncertainty definition, exclusions, transformations, map source, boundary vintage, CRS, and viewport explicit in the public script.

### Multi-Panel Map Synthesis

A map-anchored composite is one anchor map plus N-1 statistical views, for any N the evidence needs: a map beside one distribution panel, a map above three panels, a map with five or six. The five-panel China figure below is a worked example of a harder case, not the required shape. What follows scales with N; only the numbers change.

- Panel a is the map; the remaining panels cover distinct evidence types (for example distribution, relationship, estimate/interval, time series, model effect, ranking, or composition), never cosmetic variants of one summary. With two statistical panels pick the two that carry the argument; with six, check that each earns its space.
- Bold lowercase tags running `a`, `b`, `c`, ... to the panel count; identical solid circular site glyphs distinguished only by colour; a transparent, borderless legend inside inspected empty map space; the same colour meanings across every panel.
- Shared disclosures (n, uncertainty, seeds, exclusions, versions) go to the sidecar `.caption.txt` and the console audit, never into prose blocks beneath the panels. Write that file with `writeLines(enc2utf8(lines), path, useBytes = TRUE)`; plain `writeLines()` under a C locale emits the literal placeholder `<U+00B0>`.
- Acceptance geometry comes from `scripts/rfigure_layout.R`, which a composition script may `source()` (see the output contract in SKILL.md). Its `rfigure_measure_panels()` returns the rendered rectangles in reading order for any panel count, and `rfigure_check_grid()` derives rows and columns from the measured edges, so no per-design deviation list has to be written by hand and a spanned panel needs no special case. Pass `expected_panels` so an extra viewport from `wrap_elements()`, `inset_element()`, or a nested composition is caught rather than silently measured.
- When the statistical panels come from unrelated datasets with no shared grouping variable, the rule that colour meanings match across panels cannot apply. Reserve colour for the map's site classes, draw the statistical panels in structural black and grey, and say so in the caption rather than inventing a shared palette.
- Acceptance is measured on the rendered black data rectangles of the exported figure, with declared alignment, area-share, and aspect thresholds.

Layout mechanics, verified on ggplot2 4.0.x / patchwork 1.3.x:

1. Use one flat `wrap_plots(design = ...)` grid in which the map spans whatever columns its shape needs: `"ab"` for a map beside one panel, `"aaaabb\nccddee"` for a near-square national map with four statistical views, `"aaaaaa\nbbbccc\ndddeee"` for a wide world map above six. Never nest row layouts, whatever the panel count.
2. Give rows absolute `grid::unit(..., "mm")` heights and leave columns as relative widths. Flexible panels fill their slots exactly, so their black rectangles align with the grid automatically.
3. A fixed-aspect `coord_sf()` panel is centered inside its slot: the shallow `panel` viewport is the slot, and a nested `panel.1-1-1-1` viewport is the true drawn rectangle (`rfigure_measure_panels()` returns it as `inner`). Compose once with a provisional map-row height, measure the map slot width from the rendered grid viewports, then set the map-row height to `slot_width / map_ratio` and recompose; the map then fills its slot and its edges meet the grid lines. Check the result with `rfigure_check_fixed_fill()`.
4. Calibrate against the PNG device and enforce the geometry checks there. Measure the SVG geometry too and print it for information; font-metric differences can move SVG panel edges by a few tenths of a millimetre, and that drift alone must not block delivery.
5. When a lower-row panel straddles the boundary between two upper panels, its span absorbs the fixed axis-decoration strip between them and becomes wider than its siblings. Either choose a design whose row boundaries do not straddle (a map spanning a full row avoids this), or measure the decoration strips with one equal-width pass and solve compensated column widths before the final composition.
6. Size stacked direct labels from physical geometry (see the direct-label rule in `references/figure-patterns.md`): minimum gap in data units = clearance factor × label height (mm) ÷ rendered panel height (mm) × axis span, plus a floor clamp. When the panel height itself is calibrated at run time, rebuild the labelled panel with the calibrated height before the final composition.
7. Keep at least 1 mm clearance between each panel tag and neighbouring axis decorations; a small bottom margin on `plot.tag` is the default mechanism.
8. Non-ASCII glyphs such as the superscript two and the degree sign can be mangled by the R source parser under a C locale. Write them as the escapes `"\u00b2"` and `"\u00b0"` in delivered scripts, never as literal characters.

A complete runnable reference implementation of one such figure - a China map with inset plus four statistical panels, runtime slot calibration, physically sized direct labels, geometry checks, protected export, and sidecar caption - is maintained at `scripts/five_panel_china.R`. It is an example of the standard at N = 5, not the standard itself. Read it for implementation details; it may `source()` `scripts/rfigure_layout.R` for geometry, exactly as a delivered composition script may, but its plotting code belongs inline in a deliverable.


### Optional golden-ratio variant

Use a golden-ratio layout only when requested or clearly useful. Define and measure it explicitly:

```r
GOLDEN_RATIO <- (1 + sqrt(5)) / 2
GOLDEN_BAND <- c(1.50, 1.75)         # accepted panel width / height
CANVAS_RATIO_TOLERANCE <- 0.005      # canvas W/H against GOLDEN_RATIO
ASPECT_FIDELITY_TOLERANCE <- 0.005   # rendered aspect against the requested one
FIG_WIDTH_MM <- 190
FIG_HEIGHT_MM <- FIG_WIDTH_MM / GOLDEN_RATIO
TARGET_PANEL_ASPECT <- 1 / GOLDEN_RATIO  # ggplot height / width, band-checked
```

The canvas is held near-exact; the panels are held inside the band, not on the point value. `rfigure_check_ratio_band()` in `scripts/rfigure_layout.R` performs the panel check for any panel count.

- Check `FIG_WIDTH_MM / FIG_HEIGHT_MM` against `CANVAS_RATIO_TOLERANCE`, and every requested panel's rendered width/height against `GOLDEN_BAND`, after composition in both PNG and SVG. Keep the separate fidelity check (rendered versus requested aspect) tight: a loose one hides an `aspect.ratio` that the layout dropped.
- Preserve the map's CRS and coordinate scale. Do not set a conflicting free `aspect.ratio` merely to force a fixed-aspect `coord_sf()` panel into a golden rectangle.
- If the scientific extent is flexible, adjust a declared longitude/latitude viewport to obtain a near-golden rendered map panel without stretching geometry. If the extent is fixed, keep the honest map aspect and state that only the outer canvas or layout allocation is golden.
- Two equal landscape rectangles at the exact point ratio cannot also completely tile one landscape golden canvas; inside the band they often can. Use deliberate surrounding space, unequal/nested allocation, or a different arrangement, and report the resulting panel-area share so the design tradeoff is visible.
- When the golden request and the panel-area diagnostic collide, **the area-share diagnostic wins**: a composite whose panels are exactly golden inside a large empty canvas is a failed figure, not a design. Reach for the band before reaching for a wider canvas, declare which panels are the requested golden ones, let the remainder absorb the leftover space, and report every measured ratio.
- A panel that shares a row with a fixed-aspect map inherits the map's row height, so its ratio is whatever the layout leaves. Measure it against the band first, because a band often contains what a point target could not; exempt it explicitly alongside the map only when it still falls outside.
- The run-time calibration in the layout mechanics (measure the slot width, then set the row height to `slot_width / map_ratio`) only works while the figure height is free. On a fixed golden canvas the map slot ratio is fixed by the layout, so the map cannot fill its slot at its current extent. Invert the problem instead: probe the rendered `width / height` of a candidate viewport, then solve the declared longitude span (symmetric about the central meridian, with `uniroot()` or a short bisection) so that the honest map ratio equals the slot ratio. Verify afterwards that the scientific extent still contains every feature and site that must appear, and report the solved window.
- Keep the full width at or below 210 mm. A4 compatibility is a size ceiling, not evidence that a figure satisfies a particular journal's layout rules.

## Export and Inspection

- Use at least 600 dpi for raster maps with fine administrative boundaries unless the journal specifies otherwise.
- Prefer SVG or a verified font-aware PDF for vector workflows.
- Inspect the smallest islands, narrow borders, site symbols, legend keys, graticule labels, and inset frame at final size.
- Check dense labels in the exported device; preview text metrics can differ.
- Keep data source, CRS, physical dimensions, device, package versions, and alt text available with the figure.

Official references: [ggplot2 `coord_sf()`](https://ggplot2.tidyverse.org/reference/ggsf.html), [patchwork inset elements](https://patchwork.data-imaginist.com/reference/inset_element.html), and [patchwork layout behavior](https://patchwork.data-imaginist.com/articles/guides/layout.html).
