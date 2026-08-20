#!/usr/bin/env Rscript

# rfigure_layout.R - composition-time geometry for multi-panel figures.
#
# Scope, deliberately narrow: this file measures and checks the rendered
# geometry of an assembled composition. It contains no themes, palettes,
# scales, statistics, or export parameters, because those must stay visible
# in the delivered figure scripts themselves.
#
# A composition script may source this file (see the Self-Contained Output
# Contract in SKILL.md): reviewers read the per-panel figure scripts, not the
# stitching code, and many recipients assemble panels by hand anyway. Every
# panel script must still be self-contained on its own.
#
# Nothing here assumes a particular panel count or layout. Rows and columns
# are derived from the measured rectangles, so the same code serves a two
# panel pair, a 2 x 2 grid, a five-panel map synthesis, or a nine-panel sweep.
#
# Functions:
#   rfigure_measure_panels()      rendered panel rectangles, in millimetres
#   rfigure_check_grid()          row/column edge coherence, any layout
#   rfigure_panel_area_share()    data-panel area as a share of the canvas
#   rfigure_check_fixed_fill()    does a fixed-aspect panel fill its slot
#   rfigure_check_ratio_band()    are panel ratios inside a declared band
#   rfigure_match_inner()         the inner rectangle belonging to one slot

# ---- Measurement -----------------------------------------------------------

# Returns list(slots, inner). `slots` holds one row per top-level panel
# viewport, ordered in reading order (top row first, then left to right).
#
# The `panel` column is a POSITIONAL label, not the tag patchwork drew: it is
# assigned a, b, c, ... after sorting by measured position. For a design whose
# reading order matches the tag order this is the same thing; when it does not,
# pass `tag_labels` in measured reading order to name the rectangles yourself.
# Verify before trusting a per-panel lookup, for example by asserting that the
# rectangle you call the map has the map's rendered ratio. `inner` holds the
# nested viewports that fixed-aspect panels such as coord_sf() draw inside
# their slot; it is NULL when no panel has one.
rfigure_measure_panels <- function(plot_object, width_mm, height_mm,
                                   device = c("png", "svg"),
                                   expected_panels = NULL,
                                   tag_labels = NULL,
                                   order_tolerance_mm = 0.1) {
  device <- match.arg(device)
  for (package in c("grid", "grDevices")) {
    if (!requireNamespace(package, quietly = TRUE)) {
      stop("Package '", package, "' is required.", call. = FALSE)
    }
  }
  if (device == "png" && !requireNamespace("ragg", quietly = TRUE)) {
    stop("Package 'ragg' is required for device = \"png\".", call. = FALSE)
  }
  if (device == "svg" && !requireNamespace("svglite", quietly = TRUE)) {
    stop("Package 'svglite' is required for device = \"svg\".", call. = FALSE)
  }

  temporary_file <- tempfile(fileext = paste0(".", device))
  if (device == "png") {
    ragg::agg_png(
      temporary_file, width = width_mm, height = height_mm,
      units = "mm", res = 96, background = "white"
    )
  } else {
    svglite::svglite(
      temporary_file, width = width_mm / 25.4, height = height_mm / 25.4,
      bg = "white"
    )
  }
  open_device <- grDevices::dev.cur()
  on.exit({
    if (grDevices::dev.cur() == open_device) grDevices::dev.off()
    if (file.exists(temporary_file)) unlink(temporary_file)
  }, add = TRUE)

  grid::grid.newpage()
  grid::grid.draw(plot_object)
  grid::grid.force()
  listing <- grid::grid.ls(
    viewports = TRUE, grobs = FALSE, fullNames = TRUE, print = FALSE
  )
  is_panel <- grepl("^viewport\\[panel", listing$name) &
    !grepl("panel-area", listing$name)
  if (!any(is_panel)) stop("No panel viewports found.", call. = FALSE)
  minimum_depth <- min(listing$vpDepth[is_panel])
  is_slot <- is_panel & listing$vpDepth == minimum_depth
  is_inner <- grepl("^viewport\\[panel\\.", listing$name) &
    listing$vpDepth > minimum_depth

  strip_name <- function(value) sub("^viewport\\[(.*)\\]$", "\\1", value)
  box_for <- function(name, path) {
    grid::upViewport(0)
    parents <- vapply(
      strsplit(path, "::", fixed = TRUE)[[1]], strip_name, character(1)
    )
    for (parent in parents[-1]) grid::downViewport(parent, strict = TRUE)
    grid::downViewport(strip_name(name), strict = TRUE)
    lower <- grid::deviceLoc(
      grid::unit(0, "npc"), grid::unit(0, "npc"), valueOnly = TRUE
    )
    upper <- grid::deviceLoc(
      grid::unit(1, "npc"), grid::unit(1, "npc"), valueOnly = TRUE
    )
    grid::upViewport(0)
    data.frame(
      left_mm = lower$x * 25.4, bottom_mm = lower$y * 25.4,
      right_mm = upper$x * 25.4, top_mm = upper$y * 25.4
    )
  }

  finish <- function(boxes) {
    boxes$width_mm <- boxes$right_mm - boxes$left_mm
    boxes$height_mm <- boxes$top_mm - boxes$bottom_mm
    boxes$ratio <- boxes$width_mm / boxes$height_mm
    boxes$device <- device
    boxes
  }

  slots <- finish(do.call(rbind, Map(
    box_for, listing$name[is_slot], listing$vpPath[is_slot]
  )))
  # Reading order: top row first, then left to right. Panels that share a row
  # can differ by floating-point noise (1e-14 mm), which would otherwise decide
  # the order, so snap the sort keys to a physical tolerance first.
  sort_key <- function(values) round(values / order_tolerance_mm)
  slots <- slots[order(-sort_key(slots$top_mm), sort_key(slots$left_mm)), ,
                 drop = FALSE]
  # wrap_elements(), insets, and nested compositions can expose two coincident
  # viewports at the same depth for one visible panel. Collapse exact repeats
  # so the panel count reflects what a reader sees.
  key <- sprintf(
    "%.3f|%.3f|%.3f|%.3f",
    slots$left_mm, slots$bottom_mm, slots$right_mm, slots$top_mm
  )
  slots <- slots[!duplicated(key), , drop = FALSE]
  rownames(slots) <- NULL
  if (!is.null(expected_panels) && nrow(slots) != expected_panels) {
    stop(
      "Measured ", nrow(slots), " panel rectangles but expected ",
      expected_panels,
      ". wrap_elements(), inset_element(), free(), or a nested composition ",
      "can add panel viewports; identify the extra rectangle before trusting ",
      "any geometry check.",
      call. = FALSE
    )
  }
  if (is.null(tag_labels)) {
    tag_labels <- if (nrow(slots) <= length(letters)) {
      letters[seq_len(nrow(slots))]
    } else {
      as.character(seq_len(nrow(slots)))
    }
  }
  if (length(tag_labels) != nrow(slots)) {
    stop(
      "Measured ", nrow(slots), " panels but received ", length(tag_labels),
      " tag labels.", call. = FALSE
    )
  }
  slots$panel <- tag_labels

  inner <- NULL
  if (any(is_inner)) {
    inner <- finish(do.call(rbind, Map(
      box_for, listing$name[is_inner], listing$vpPath[is_inner]
    )))
    inner <- inner[order(-inner$top_mm, inner$left_mm), , drop = FALSE]
    rownames(inner) <- NULL
  }
  list(slots = slots, inner = inner, canvas = c(width_mm, height_mm))
}

# ---- Row and column coherence ---------------------------------------------

# Layout-agnostic replacement for a hand-written, per-design deviation list.
# Edges are first grouped coarsely (cluster_radius_mm), so panels that belong
# to the same grid line land together; within each group the spread must stay
# within tolerance_mm. Panels that span several columns or rows are handled
# without special cases, because only shared edges are compared.
rfigure_check_grid <- function(slots, tolerance_mm = 0.35,
                               cluster_radius_mm = 3) {
  stopifnot(is.data.frame(slots), nrow(slots) >= 1)
  cluster_spread <- function(values, labels) {
    order_index <- order(values)
    sorted <- values[order_index]
    group <- cumsum(c(TRUE, diff(sorted) > cluster_radius_mm))
    do.call(rbind, lapply(split(seq_along(sorted), group), function(index) {
      data.frame(
        panels = paste(labels[order_index][index], collapse = ""),
        n = length(index),
        position_mm = mean(sorted[index]),
        spread_mm = if (length(index) > 1L) diff(range(sorted[index])) else 0
      )
    }))
  }
  edges <- list(
    left = slots$left_mm, right = slots$right_mm,
    top = slots$top_mm, bottom = slots$bottom_mm
  )
  report <- do.call(rbind, lapply(names(edges), function(edge) {
    result <- cluster_spread(edges[[edge]], slots$panel)
    result$edge <- edge
    result[c("edge", "panels", "n", "position_mm", "spread_mm")]
  }))
  rownames(report) <- NULL
  attr(report, "max_spread_mm") <- max(report$spread_mm)
  attr(report, "tolerance_mm") <- tolerance_mm
  attr(report, "passed") <- max(report$spread_mm) <= tolerance_mm
  report
}

# ---- Area share and fixed-aspect fill --------------------------------------

# Pass `inner` for any fixed-aspect panel so its true drawn rectangle, not its
# slot, counts toward the share.
rfigure_panel_area_share <- function(slots, canvas_width_mm, canvas_height_mm,
                                     inner = NULL, inner_replaces = NULL) {
  boxes <- slots[c("panel", "width_mm", "height_mm")]
  if (!is.null(inner) && !is.null(inner_replaces)) {
    boxes <- boxes[!(boxes$panel %in% inner_replaces), , drop = FALSE]
    boxes <- rbind(
      boxes,
      data.frame(
        panel = inner_replaces,
        width_mm = inner$width_mm,
        height_mm = inner$height_mm
      )
    )
  }
  sum(boxes$width_mm * boxes$height_mm) /
    (canvas_width_mm * canvas_height_mm)
}

# A fixed-aspect panel (coord_sf, coord_fixed, coord_polar) is centred inside
# its slot. If it does not fill the slot, the composition has empty bands the
# reader will see as broken alignment.
rfigure_check_fixed_fill <- function(slot_row, inner_row, tolerance_mm = 0.35) {
  columns <- c("left_mm", "bottom_mm", "right_mm", "top_mm")
  deviation <- max(abs(unlist(inner_row[columns] - slot_row[columns])))
  list(deviation_mm = deviation, passed = deviation <= tolerance_mm)
}

# ---- Matching inner rectangles to slots ------------------------------------

# Every fixed-aspect panel exposes a nested viewport, and theme(aspect.ratio)
# creates one too. Picking "the largest inner rectangle" therefore selects the
# wrong panel as soon as more than one panel has a fixed shape. Match by
# containment inside the slot, falling back to the nearest centre.
rfigure_match_inner <- function(slots, inner, panel, tolerance_mm = 0.5) {
  stopifnot(is.data.frame(slots), !is.null(inner), is.data.frame(inner))
  slot <- slots[slots$panel == panel, , drop = FALSE]
  if (nrow(slot) != 1L) {
    stop("Panel '", panel, "' does not identify exactly one slot.",
         call. = FALSE)
  }
  contained <- inner$left_mm >= slot$left_mm - tolerance_mm &
    inner$right_mm <= slot$right_mm + tolerance_mm &
    inner$bottom_mm >= slot$bottom_mm - tolerance_mm &
    inner$top_mm <= slot$top_mm + tolerance_mm
  candidates <- inner[contained, , drop = FALSE]
  if (!nrow(candidates)) candidates <- inner
  slot_centre <- c((slot$left_mm + slot$right_mm) / 2,
                   (slot$bottom_mm + slot$top_mm) / 2)
  distance <- sqrt(
    ((candidates$left_mm + candidates$right_mm) / 2 - slot_centre[[1]])^2 +
      ((candidates$bottom_mm + candidates$top_mm) / 2 - slot_centre[[2]])^2
  )
  candidates[which.min(distance), , drop = FALSE]
}

# ---- Ratio band ------------------------------------------------------------

# A design target such as the golden ratio is checked as a band, not a point:
# the layout has to absorb axis strips, legends, spanned panels, and any
# fixed-aspect neighbour, and forcing the point value buys nothing but empty
# canvas. Keep this separate from the fidelity check of rendered aspect
# against requested aspect, which must stay tight.
rfigure_check_ratio_band <- function(slots, band = c(1.50, 1.75),
                                     panels = NULL, epsilon = 1e-6) {
  stopifnot(is.data.frame(slots), length(band) == 2L, band[[1]] < band[[2]])
  selected <- if (is.null(panels)) slots else slots[slots$panel %in% panels, ]
  if (!nrow(selected)) stop("No panels selected for the ratio band check.")
  report <- data.frame(
    panel = selected$panel,
    ratio = selected$width_mm / selected$height_mm,
    device = selected$device
  )
  # Inclusive endpoints: a panel rendered exactly at a band edge must pass,
  # so absorb the floating-point residue instead of failing on it.
  report$inside_band <- report$ratio >= band[[1]] * (1 - epsilon) &
    report$ratio <= band[[2]] * (1 + epsilon)
  attr(report, "band") <- band
  attr(report, "passed") <- all(report$inside_band)
  report
}
