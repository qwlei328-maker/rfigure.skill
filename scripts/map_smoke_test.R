#!/usr/bin/env Rscript

options(warn = 1)

script_file <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
script_dir <- dirname(normalizePath(script_file[[1L]], mustWork = TRUE))
source(file.path(script_dir, "rfigure_helpers.R"))

for (package in c("ggplot2", "sf", "ggmapcn", "patchwork", "ragg", "svglite")) {
  qw_require(package)
}
qw_assert_font("Arial")

args <- commandArgs(trailingOnly = TRUE)
output_dir <- if (length(args)) args[[1L]] else file.path(tempdir(), "rfigure-map-smoke")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

cst <- qw_constants()
china_crs <- paste(
  "+proj=aea +lat_1=25 +lat_2=47 +lat_0=0 +lon_0=105",
  "+datum=WGS84 +units=m +no_defs"
)

china_wgs84 <- qw_mapcn_data("province", crs = 4326)
china_mask <- sf::st_union(sf::st_transform(china_wgs84, china_crs))
set.seed(20260818)
candidate_points <- sf::st_sample(china_mask, size = 500, exact = TRUE)
candidate_xy <- sf::st_coordinates(sf::st_transform(candidate_points, 4326))
candidates <- data.frame(lon = candidate_xy[, 1], lat = candidate_xy[, 2])
candidates$group <- cut(
  candidates$lat,
  breaks = c(-Inf, 30, 37, Inf),
  labels = c("South", "Central", "North")
)
target_counts <- c(North = 6L, Central = 7L, South = 7L)
selected <- lapply(names(target_counts), function(group) {
  pool <- candidates[candidates$group == group, , drop = FALSE]
  if (nrow(pool) < target_counts[[group]]) {
    stop(sprintf("Not enough sampled points in the %s stratum.", group), call. = FALSE)
  }
  pool[seq_len(target_counts[[group]]), , drop = FALSE]
})
sites <- do.call(rbind, selected)
sites$group <- factor(sites$group, levels = names(target_counts))
sites$site <- sprintf("S%02d", seq_len(nrow(sites)))
sites_sf <- sites |>
  sf::st_as_sf(coords = c("lon", "lat"), crs = 4326, remove = FALSE) |>
  sf::st_transform(china_crs)
stopifnot(all(lengths(sf::st_within(sites_sf, china_mask)) == 1L))

site_colours <- c(North = "#2C7FB8", Central = "#E08214", South = "#4D9221")
site_shapes <- c(North = 21, Central = 22, South = 24)

map_layers <- function() {
  list(
    ggmapcn::geom_mapcn(
      data = china_wgs84,
      admin_level = "province", crs = china_crs,
      fill = "#F2F2F2", color = "#B8B8B8", linewidth = cst$line * 0.7
    ),
    ggmapcn::geom_boundary_cn(
      crs = china_crs,
      mainland_color = "grey35", mainland_size = cst$line,
      coastline_color = "#78A6C8", coastline_size = cst$line * 0.8,
      ten_segment_line_color = "grey35", ten_segment_line_size = cst$line,
      province_color = "#D0D0D0", province_size = cst$line * 0.55
    )
  )
}

p_main <- ggplot2::ggplot() +
  map_layers() +
  ggplot2::geom_sf(
    data = sites_sf,
    ggplot2::aes(fill = group, shape = group),
    size = 2.8,
    stroke = cst$data_line,
    colour = "black"
  ) +
  ggplot2::scale_fill_manual(
    values = site_colours, breaks = names(site_colours), name = "Site group"
  ) +
  ggplot2::scale_shape_manual(
    values = site_shapes, breaks = names(site_shapes), name = "Site group"
  ) +
  ggplot2::coord_sf(
    crs = china_crs,
    xlim = c(72, 142),
    ylim = c(12, 56),
    default_crs = sf::st_crs(4326),
    expand = FALSE
  ) +
  ggplot2::labs(
    x = NULL,
    y = NULL,
    alt = paste(
      "Map of China with twenty reproducible example sites grouped as north, central, and south.",
      "A framed South China Sea inset is aligned to the lower-right edge of the main panel."
    )
  ) +
  theme_qw_pub() +
  ggplot2::theme(
    axis.text = ggplot2::element_blank(),
    axis.title = ggplot2::element_blank(),
    axis.ticks = ggplot2::element_blank(),
    legend.position = "inside",
    legend.position.inside = c(0.035, 0.965),
    legend.justification = c(0, 1),
    legend.background = ggplot2::element_rect(
      fill = "white", colour = "black", linewidth = cst$line * 0.7
    )
  )

p_south_china_sea <- ggplot2::ggplot() +
  map_layers() +
  ggplot2::coord_sf(
    crs = china_crs,
    xlim = c(105, 125),
    ylim = c(0, 25),
    default_crs = sf::st_crs(4326),
    expand = FALSE
  ) +
  theme_qw_pub()

geometry <- qw_inset_geometry(p_main, p_south_china_sea, inset_height = 0.28)
stopifnot(
  abs(geometry$main_ratio - 1.2831) < 0.001,
  abs(geometry$inset_ratio - 0.8750) < 0.001,
  abs(geometry$inset_width - 0.1910) < 0.001
)

final_plot <- qw_inset_with_frame(p_main, p_south_china_sea, inset_height = 0.28)
png_path <- file.path(output_dir, "china-random-sites.png")
svg_path <- file.path(output_dir, "china-random-sites.svg")

for (path in c(png_path, svg_path, paste0(png_path, ".manifest.tsv"),
               paste0(svg_path, ".manifest.tsv"))) {
  if (file.exists(path)) unlink(path)
}

qw_save(
  final_plot, png_path,
  width_mm = 190, height_mm = 125, dpi = 600,
  write_manifest = FALSE
)
qw_save(
  final_plot, svg_path,
  width_mm = 190, height_mm = 125,
  write_manifest = FALSE
)

stopifnot(file.info(png_path)$size > 0, file.info(svg_path)$size > 0)
cat("rfigure China map smoke test: PASS\n")
cat(sprintf(
  "main_ratio=%.4f inset_ratio=%.4f inset_width=%.4f\n",
  geometry$main_ratio, geometry$inset_ratio, geometry$inset_width
))
cat(sprintf("png=%s\nsvg=%s\n", png_path, svg_path))
