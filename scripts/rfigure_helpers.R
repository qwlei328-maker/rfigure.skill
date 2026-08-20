# Reusable helpers for rfigure.skill. Source this file from figure scripts.

qw_require <- function(package) {
  if (!requireNamespace(package, quietly = TRUE)) {
    stop(sprintf("Package '%s' is required.", package), call. = FALSE)
  }
  invisible(TRUE)
}

qw_constants <- function(base_pt = 8, tag_pt = 9, line_pt = 1,
                         data_line_multiplier = 1.8) {
  stopifnot(
    is.numeric(base_pt), length(base_pt) == 1L, base_pt > 0,
    is.numeric(tag_pt), length(tag_pt) == 1L, tag_pt >= base_pt,
    is.numeric(line_pt), length(line_pt) == 1L, line_pt > 0,
    is.numeric(data_line_multiplier), length(data_line_multiplier) == 1L,
    data_line_multiplier >= 1.7
  )
  mm_per_pt <- 25.4 / 72
  list(
    text_pt = base_pt,
    tag_pt = tag_pt,
    text_gg = base_pt / 2.845276,
    line = line_pt * mm_per_pt,
    data_line = line_pt * mm_per_pt * data_line_multiplier
  )
}

qw_find_font <- function(candidates = c("Arial", "Liberation Sans")) {
  qw_require("systemfonts")
  available <- unique(systemfonts::system_fonts()$family)
  hit <- candidates[candidates %in% available]
  if (length(hit)) hit[[1L]] else NA_character_
}

qw_assert_font <- function(family = "Arial", register_liberation = TRUE) {
  qw_require("systemfonts")
  if (family %in% systemfonts::system_fonts()$family) return(invisible(family))

  if (identical(family, "Arial") && isTRUE(register_liberation)) {
    roots <- c("/usr/share/fonts", "/usr/local/share/fonts")
    roots <- roots[dir.exists(roots)]
    candidates <- unlist(lapply(
      roots,
      list.files,
      pattern = "^LiberationSans-Regular\\.(ttf|otf)$",
      recursive = TRUE,
      full.names = TRUE,
      ignore.case = TRUE
    ), use.names = FALSE)
    if (length(candidates)) {
      systemfonts::register_font("Arial", plain = candidates[[1L]])
    }
  }

  if (!family %in% systemfonts::system_fonts()$family) {
    stop(
      sprintf("Font '%s' is unavailable. Install it or choose an explicit fallback.", family),
      call. = FALSE
    )
  }
  invisible(family)
}

qw_cjk_family <- function(candidates = c(
  "Source Han Sans SC", "Noto Sans SC", "Noto Sans CJK SC", "PingFang SC"
)) {
  family <- qw_find_font(candidates)
  if (is.na(family)) {
    stop("No supported CJK sans font was found.", call. = FALSE)
  }
  family
}

theme_qw_pub <- function(base_pt = 8, family = "Arial", line_pt = 1) {
  qw_require("ggplot2")
  cst <- qw_constants(base_pt = base_pt, line_pt = line_pt)

  ggplot2::theme_classic(base_size = base_pt, base_family = family) +
    ggplot2::theme(
      text = ggplot2::element_text(
        family = family, size = base_pt, colour = "black"
      ),
      axis.text = ggplot2::element_text(
        family = family, size = base_pt, colour = "black"
      ),
      axis.title = ggplot2::element_text(
        family = family, size = base_pt, colour = "black"
      ),
      legend.text = ggplot2::element_text(
        family = family, size = base_pt, colour = "black"
      ),
      legend.title = ggplot2::element_text(
        family = family, size = base_pt, colour = "black"
      ),
      strip.text = ggplot2::element_text(
        family = family, size = base_pt, colour = "black"
      ),
      plot.caption = ggplot2::element_text(
        family = family, size = base_pt, colour = "black"
      ),
      panel.border = ggplot2::element_rect(
        colour = "black", fill = NA, linewidth = cst$line
      ),
      axis.line = ggplot2::element_blank(),
      axis.ticks = ggplot2::element_line(
        colour = "black", linewidth = cst$line
      ),
      panel.grid = ggplot2::element_blank(),
      plot.background = ggplot2::element_rect(fill = "white", colour = NA),
      panel.background = ggplot2::element_rect(fill = "white", colour = NA),
      legend.background = ggplot2::element_rect(fill = "white", colour = NA),
      legend.key = ggplot2::element_rect(fill = "white", colour = NA),
      legend.margin = ggplot2::margin(1, 2, 1, 2, "mm"),
      legend.key.size = grid::unit(3, "mm"),
      plot.margin = ggplot2::margin(2, 2, 2, 2, "mm")
    )
}

theme_qw_pub_cjk <- function(base_pt = 8, family = qw_cjk_family(), line_pt = 1) {
  theme_qw_pub(base_pt = base_pt, family = family, line_pt = line_pt)
}

qw_mapcn_data <- function(admin_level = c("province", "city", "county"),
                          crs = NULL) {
  qw_require("ggmapcn")
  qw_require("sf")
  admin_level <- match.arg(admin_level)
  filename <- switch(
    admin_level,
    province = "China_sheng.rda",
    city = "China_shi.rda",
    county = "China_xian.rda"
  )
  paths <- ggmapcn::check_geodata(files = filename, quiet = TRUE)
  path <- paths[!is.na(paths) & file.exists(paths)][1L]
  if (!length(path) || is.na(path)) {
    stop(sprintf("Could not locate ggmapcn data file '%s'.", filename), call. = FALSE)
  }

  env <- new.env(parent = emptyenv())
  base::load(path, envir = env)
  expected <- tools::file_path_sans_ext(basename(filename))
  objects <- ls(env, all.names = TRUE)
  object <- if (expected %in% objects) {
    get(expected, envir = env, inherits = FALSE)
  } else if (length(objects) == 1L) {
    get(objects[[1L]], envir = env, inherits = FALSE)
  } else {
    stop(sprintf("Could not identify the map object in '%s'.", path), call. = FALSE)
  }
  if (!inherits(object, "sf")) {
    stop(sprintf("The object loaded from '%s' is not an sf object.", path), call. = FALSE)
  }

  boundary <- rep(FALSE, nrow(object))
  for (name in intersect(c("name", "name_en"), names(object))) {
    value <- as.character(object[[name]])
    boundary <- boundary | (!is.na(value) & toupper(value) == "BOUNDARY LINE")
  }
  object <- sf::st_make_valid(object[!boundary, , drop = FALSE])
  if (!is.null(crs)) object <- sf::st_transform(object, crs)
  object
}

qw_panel_range <- function(panel_params, axis = c("x", "y")) {
  axis <- match.arg(axis)
  names_to_try <- c(paste0(axis, "_range"), paste0(axis, ".range"))
  for (name in names_to_try) {
    value <- panel_params[[name]]
    if (is.numeric(value) && length(value) == 2L && all(is.finite(value))) {
      return(as.numeric(value))
    }
  }

  scale <- panel_params[[axis]]
  if (!is.null(scale)) {
    for (name in c("continuous_range", "range")) {
      value <- scale[[name]]
      if (is.numeric(value) && length(value) == 2L && all(is.finite(value))) {
        return(as.numeric(value))
      }
    }
  }
  stop(sprintf("Could not read the built %s range for this panel.", axis), call. = FALSE)
}

qw_panel_ratio <- function(plot, panel = 1L) {
  qw_require("ggplot2")
  if (!inherits(plot, "ggplot")) stop("'plot' must be a ggplot object.", call. = FALSE)
  built <- ggplot2::ggplot_build(plot)
  params <- built$layout$panel_params
  if (!length(params) || panel < 1L || panel > length(params)) {
    stop("'panel' is outside the available panel range.", call. = FALSE)
  }
  x_range <- qw_panel_range(params[[panel]], "x")
  y_range <- qw_panel_range(params[[panel]], "y")
  ratio <- diff(x_range) / diff(y_range)
  if (!is.finite(ratio) || ratio <= 0) {
    stop("Built panel ratio is not finite and positive.", call. = FALSE)
  }
  as.numeric(ratio)
}

qw_inset_geometry <- function(main_plot, inset_plot, inset_height = 0.28,
                              right = 1, bottom = 0) {
  if (!is.numeric(inset_height) || length(inset_height) != 1L ||
      !is.finite(inset_height) || inset_height <= 0 || inset_height >= 1) {
    stop("'inset_height' must be a finite number between 0 and 1.", call. = FALSE)
  }
  if (!is.numeric(right) || length(right) != 1L || !is.finite(right) ||
      !is.numeric(bottom) || length(bottom) != 1L || !is.finite(bottom)) {
    stop("'right' and 'bottom' must be finite numbers.", call. = FALSE)
  }
  main_ratio <- qw_panel_ratio(main_plot)
  inset_ratio <- qw_panel_ratio(inset_plot)
  inset_width <- inset_height * inset_ratio / main_ratio
  if (!is.finite(inset_width) || inset_width <= 0 || inset_width >= 1) {
    stop("Computed inset width is outside (0, 1).", call. = FALSE)
  }
  left <- right - inset_width
  top <- bottom + inset_height
  if (left < 0 || right > 1 || bottom < 0 || top > 1 || left >= right || bottom >= top) {
    stop("Computed inset coordinates must fit inside the main panel.", call. = FALSE)
  }
  list(
    main_ratio = main_ratio,
    inset_ratio = inset_ratio,
    inset_width = inset_width,
    inset_height = inset_height,
    left = left,
    bottom = bottom,
    right = right,
    top = top
  )
}

qw_inset_with_frame <- function(main_plot, inset_plot, inset_height = 0.28,
                                right = 1, bottom = 0, line_pt = 1,
                                frame_colour = "black") {
  qw_require("ggplot2")
  qw_require("patchwork")
  cst <- qw_constants(line_pt = line_pt)
  pos <- qw_inset_geometry(
    main_plot, inset_plot, inset_height,
    right = right, bottom = bottom
  )

  inset_map <- inset_plot +
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
        fill = NA, colour = frame_colour, linewidth = cst$line
      ),
      plot.margin = ggplot2::margin(0, 0, 0, 0, "mm")
    )

  main_plot +
    patchwork::inset_element(
      inset_map, pos$left, pos$bottom, pos$right, pos$top, align_to = "panel"
    ) +
    patchwork::inset_element(
      inset_frame, pos$left, pos$bottom, pos$right, pos$top, align_to = "panel"
    )
}

qw_p_label <- function(p, digits = 3L) {
  if (!is.numeric(p) || length(p) != 1L || !is.finite(p) || p < 0 || p > 1) {
    stop("'p' must be one finite probability in [0, 1].", call. = FALSE)
  }
  if (p < 0.001) return("italic(p) < 0.001")
  sprintf(paste0("italic(p) == %.", as.integer(digits), "f"), p)
}

qw_r2_label <- function(r2, digits = 3L) {
  if (!is.numeric(r2) || length(r2) != 1L || !is.finite(r2)) {
    stop("'r2' must be one finite value.", call. = FALSE)
  }
  sprintf(paste0("italic(R)^2 == %.", as.integer(digits), "f"), r2)
}

qw_wrap_text <- function(text, width = 80L) {
  if (!is.character(text) || length(text) != 1L || !nzchar(text)) {
    stop("'text' must be one non-empty character string.", call. = FALSE)
  }
  if (!is.numeric(width) || length(width) != 1L || !is.finite(width) || width < 20) {
    stop("'width' must be one finite number of at least 20 characters.", call. = FALSE)
  }
  paste(strwrap(text, width = as.integer(width)), collapse = "\n")
}

qw_data_audit <- function(data, variables, log_variables = character()) {
  if (!is.data.frame(data)) stop("'data' must be a data frame.", call. = FALSE)
  missing_columns <- setdiff(variables, names(data))
  if (length(missing_columns)) {
    stop(sprintf("Missing columns: %s", paste(missing_columns, collapse = ", ")),
         call. = FALSE)
  }
  duplicate_rows <- sum(duplicated(data))
  rows <- lapply(variables, function(name) {
    x <- data[[name]]
    numeric_x <- is.numeric(x)
    finite <- if (numeric_x) is.finite(x) else !is.na(x)
    finite_values <- x[finite]
    data.frame(
      variable = name,
      class = paste(class(x), collapse = "/"),
      n = length(x),
      missing = sum(is.na(x)),
      nonfinite = if (numeric_x) sum(!is.finite(x) & !is.na(x)) else NA_integer_,
      distinct = length(unique(finite_values)),
      duplicate_rows = duplicate_rows,
      min = if (numeric_x && length(finite_values)) min(finite_values) else NA_real_,
      max = if (numeric_x && length(finite_values)) max(finite_values) else NA_real_,
      log_invalid = if (name %in% log_variables && numeric_x) {
        sum(finite_values <= 0)
      } else {
        NA_integer_
      },
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

qw_relative_luminance <- function(colour) {
  rgb <- grDevices::col2rgb(colour) / 255
  linear <- ifelse(rgb <= 0.04045, rgb / 12.92, ((rgb + 0.055) / 1.055)^2.4)
  as.numeric(0.2126 * linear[1, ] + 0.7152 * linear[2, ] + 0.0722 * linear[3, ])
}

qw_palette_audit <- function(palette, background = "#FFFFFF", threshold = 3) {
  if (!length(palette)) stop("'palette' must contain at least one colour.", call. = FALSE)
  luminance <- qw_relative_luminance(palette)
  bg <- qw_relative_luminance(background)[[1L]]
  contrast <- (pmax(luminance, bg) + 0.05) / (pmin(luminance, bg) + 0.05)
  data.frame(
    role = if (is.null(names(palette))) as.character(seq_along(palette)) else names(palette),
    colour = unname(palette),
    contrast_vs_background = round(contrast, 3),
    passes_graphical_3_to_1 = contrast >= threshold,
    stringsAsFactors = FALSE
  )
}

qw_plot_audit <- function(plot, require_alt = TRUE, require_axis_labels = TRUE) {
  qw_require("ggplot2")
  if (!inherits(plot, "ggplot")) stop("'plot' must be a ggplot object.", call. = FALSE)
  labels <- ggplot2::get_labs(plot)
  alt <- if (exists("get_alt_text", envir = asNamespace("ggplot2"), inherits = FALSE)) {
    ggplot2::get_alt_text(plot)
  } else {
    labels$alt %||% ""
  }
  issues <- character()
  if (isTRUE(require_alt) && (!is.character(alt) || length(alt) != 1L || !nzchar(alt))) {
    issues <- c(issues, "Missing labs(alt = ...).")
  }
  if (isTRUE(require_axis_labels)) {
    if (is.null(labels$x) || !nzchar(as.character(labels$x))) {
      issues <- c(issues, "Missing x-axis label.")
    }
    if (is.null(labels$y) || !nzchar(as.character(labels$y))) {
      issues <- c(issues, "Missing y-axis label.")
    }
  }
  built <- tryCatch(ggplot2::ggplot_build(plot), error = identity)
  if (inherits(built, "error")) {
    issues <- c(issues, paste("Plot build failed:", conditionMessage(built)))
  }
  list(ok = !length(issues), issues = issues, alt = alt, labels = labels)
}

`%||%` <- function(x, y) if (is.null(x)) y else x

qw_quartz_pdf <- function(filename, width, height, bg = "white", ...) {
  grDevices::quartz(
    type = "pdf", file = filename,
    width = width, height = height, bg = bg, ...
  )
}

qw_cairo_pdf_available <- function() {
  if (!isTRUE(capabilities("cairo"))) return(FALSE)
  probe <- tempfile(fileext = ".pdf")
  initial_device <- grDevices::dev.cur()
  on.exit({
    if (grDevices::dev.cur() != initial_device) try(grDevices::dev.off(), silent = TRUE)
    if (file.exists(probe)) unlink(probe)
  }, add = TRUE)

  isTRUE(tryCatch(
    withCallingHandlers({
      grDevices::cairo_pdf(probe, width = 1, height = 1)
      graphics::plot.new()
      graphics::text(0.5, 0.5, "device probe")
      grDevices::dev.off()
      file.exists(probe) && file.info(probe)$size > 0
    }, warning = function(w) stop(conditionMessage(w), call. = FALSE)),
    error = function(e) FALSE
  ))
}

qw_pdf_device <- function() {
  if (isTRUE(capabilities("aqua"))) {
    return(list(device = qw_quartz_pdf, label = "grDevices::quartz(type='pdf')"))
  }
  if (qw_cairo_pdf_available()) {
    return(list(device = grDevices::cairo_pdf, label = "grDevices::cairo_pdf"))
  }
  stop(
    "No verified font-aware PDF device is available; export SVG instead.",
    call. = FALSE
  )
}

qw_save <- function(plot, filename, width_mm, height_mm, dpi = 600,
                    background = "white", overwrite = FALSE,
                    write_manifest = TRUE, alt = NULL) {
  qw_require("ggplot2")
  if (!inherits(plot, c("ggplot", "patchwork"))) {
    stop("'plot' must be a ggplot or patchwork object.", call. = FALSE)
  }
  if (!is.numeric(width_mm) || !is.numeric(height_mm) ||
      length(width_mm) != 1L || length(height_mm) != 1L ||
      !is.finite(width_mm) || !is.finite(height_mm) ||
      width_mm <= 0 || height_mm <= 0) {
    stop("'width_mm' and 'height_mm' must be finite positive numbers.", call. = FALSE)
  }
  if (!is.null(alt) && (!is.character(alt) || length(alt) != 1L || !nzchar(alt))) {
    stop("'alt' must be NULL or one non-empty character string.", call. = FALSE)
  }
  if (file.exists(filename) && !isTRUE(overwrite)) {
    stop(sprintf("Refusing to overwrite existing file: %s", filename), call. = FALSE)
  }
  directory <- dirname(filename)
  dir.create(directory, recursive = TRUE, showWarnings = FALSE)
  extension <- tolower(tools::file_ext(filename))

  pdf_device <- if (identical(extension, "pdf")) qw_pdf_device() else NULL
  renderer_package <- switch(
    extension,
    png =, tif =, tiff = "ragg",
    svg = "svglite",
    pdf = "grDevices",
    NA_character_
  )
  device_label <- switch(
    extension,
    png = "ragg::agg_png",
    tif =, tiff = "ragg::agg_tiff",
    svg = "svglite::svglite",
    pdf = pdf_device$label,
    NA_character_
  )
  device <- switch(
    extension,
    png = {
      qw_require("ragg")
      ragg::agg_png
    },
    tif =, tiff = {
      qw_require("ragg")
      ragg::agg_tiff
    },
    svg = {
      qw_require("svglite")
      svglite::svglite
    },
    pdf = {
      pdf_device$device
    },
    stop("Supported extensions are .png, .tif/.tiff, .svg, and .pdf.", call. = FALSE)
  )

  extra <- if (extension %in% c("tif", "tiff")) list(compression = "lzw") else list()
  do.call(
    ggplot2::ggsave,
    c(list(
      filename = filename,
      plot = plot,
      device = device,
      width = width_mm,
      height = height_mm,
      units = "mm",
      dpi = dpi,
      bg = background
    ), extra)
  )
  info <- file.info(filename)
  if (!file.exists(filename) || is.na(info$size) || info$size <= 0) {
    stop("Export did not create a non-empty file.", call. = FALSE)
  }

  if (isTRUE(write_manifest)) {
    manifest <- paste0(filename, ".manifest.tsv")
    manifest_alt <- if (!is.null(alt)) {
      alt
    } else {
      tryCatch(
        if (exists("get_alt_text", envir = asNamespace("ggplot2"), inherits = FALSE)) {
          ggplot2::get_alt_text(plot)
        } else {
          ""
        },
        error = function(e) ""
      )
    }
    values <- c(
      file = normalizePath(filename, winslash = "/", mustWork = TRUE),
      format = extension,
      device = device_label,
      width_mm = width_mm,
      height_mm = height_mm,
      dpi = if (extension %in% c("png", "tif", "tiff")) dpi else NA,
      bytes = info$size,
      created_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
      r_version = R.version.string,
      ggplot2_version = as.character(utils::packageVersion("ggplot2")),
      renderer_package = renderer_package,
      renderer_version = if (identical(renderer_package, "grDevices")) {
        as.character(getRversion())
      } else {
        as.character(utils::packageVersion(renderer_package))
      },
      alt = gsub("[\t\r\n]+", " ", manifest_alt)
    )
    utils::write.table(
      data.frame(key = names(values), value = unname(values)),
      manifest,
      sep = "\t",
      row.names = FALSE,
      quote = TRUE
    )
  }
  invisible(normalizePath(filename, winslash = "/", mustWork = TRUE))
}
