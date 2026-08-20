---
name: rfigure
description: Create, revise, reproduce, export, or audit publication-ready, self-contained R/ggplot2 figure scripts for papers, theses, reports, ecology/environmental analyses, statistical results, maps, matrices, and multi-panel layouts. Use when a user asks for an R figure, public plotting code, ggplot2 code, journal-style visual, figure QA, consistent manuscript styling, or Qiongwei's established plotting style.
---

# R Figure

Create figures that preserve scientific meaning before polishing appearance. Deliver public, readable R code that another person can run without this skill directory.

## Instructions for the AI Agent

The rules below constrain the AI using this skill. They are not commands directed at the human user. The human may request filtering, sampling, alternative styling, or another analysis; implement such choices when legitimate, but keep them explicit in code and report their effect.

## Self-Contained Output Contract

Two kinds of script leave this skill, and the contract binds them differently.

### Figure scripts stay self-contained

This covers every figure that is one plot, and every panel of a multi-panel figure. A reviewer must be able to run and audit that code without this skill.

- Deliver each figure as one self-contained `.R` script unless the user explicitly requests a project/package structure.
- Put package imports, input paths, random seeds, dimensions, DPI, fonts, line widths, colors, factor orders, statistical settings, transformations, plot construction, and export calls in that script.
- Do not `source()` this skill's plotting helpers, and do not require recipients to install or locate `rfigure_helpers.R`.
- Do not hide publication parameters behind an unavailable tool or opaque wrapper. A short local function is acceptable only when its full definition and defaults are visible in the same delivered script.

### Composition scripts may reference this skill

Assembling finished panels is a different job from making them. Reviewers read the panel code; almost nobody reads the stitching code, and many recipients assemble panels by hand in PowerPoint or Illustrator instead. So the assembly step may reuse this skill's geometry code rather than copying it into every deliverable.

- A composition script may `source()` `scripts/rfigure_layout.R` for rendered-geometry measurement and layout checks. That file holds measurement and checking only: no themes, palettes, scales, statistics, or export parameters.
- Deliver the panel scripts alongside the composition script, so every plotted value remains auditable without this skill.
- Keep the composition's own parameters visible in the composition script: design string, widths and heights, tags, canvas size, DPI, and the export calls.
- Print the measured geometry to the console and into the sidecar caption, so the QA numbers survive for a reader who never runs the helper.
- If the recipient must be able to re-run the assembly with no dependency on this skill, inline the helper instead and say so.
- Keep the rest of `scripts/` for maintainer regression tests. Read them for implementation details, then inline what a figure script needs.

## Load Only What the Task Needs

- Read `references/style-and-export.md` for the self-contained parameter/theme/export template, fonts, dimensions, and layout mechanics.
- Read `references/figure-patterns.md` for distributions, relationships, model effects, rankings, composition, matrices, time series, facets, large data, or annotations.
- Read `references/maps-and-spatial.md` for spatial figures, especially China maps, `coord_sf()`, and South China Sea insets.
- Read `references/quality-and-accessibility.md` before final delivery or when reviewing an existing figure.

## Agent Guardrails for Scientific Integrity

1. Preserve the supplied raw data and transformation code. Never invent, selectively hide, or silently drop observations, groups, variables, uncertainty, missingness, or inconvenient results.
2. Do not silently subsample final evidence. Rasterize, bin, aggregate with a declared scientific rule, or show density instead. If the user requests a sampled preview, fix the seed and label it as a preview.
3. State filtering, exclusions, normalization, smoothing, binning, model, uncertainty definition, sample size, and unit of replication when they affect the figure.
4. Use honest scales. Bars/areas normally include zero; disclose axis breaks or nonzero limits; label log transforms and the handling of zero/negative values; avoid dual axes unless justified.
5. Use final physical dimensions from the start. Verify current journal requirements when a target venue is named; otherwise label dimensions as provisional.
6. Inspect rendered outputs. A script running without errors is not visual QA.

## Qiongwei Style Baseline

- Use Arial 8 pt for ordinary Latin text. Use one explicit CJK sans family for Chinese text.
- Use 9–10 pt bold lowercase `a`, `b`, `c`, ... as the default panel tags. Use uppercase only when the user or venue requires it.
- Keep at least 1 mm clearance between a panel tag and any neighbouring axis decoration; giving `plot.tag` a small bottom margin (for example 1.2 mm) is the default mechanism.
- Use a white panel and plot background.
- Draw one black four-sided 1 pt panel border. Do not add separate axis lines.
- Treat the 1 pt frame/ticks/reference lines as structure. Draw fitted lines, box outlines, and error bars at least 1.7× heavier.
- Keep structure black/grey and reserve restrained color for data meaning.
- When group identity matters, encode it with color plus shape, linetype, pattern, direct labels, or facets. Spatial site maps are the deliberate exception: default all site classes to the same solid circular glyph and distinguish classes with a named color palette; do not turn map sites into mixed circles, squares, and triangles unless the user explicitly requests shapes. Preserve clarity with legend text, direct labels, or redundant grouping in the accompanying statistical panels.
- Give every geographic map a graticule with decimal-degree tick labels such as `114.0°E` and `35.5°N`, drawn with labels and ticks on the left and bottom edges only. The graticule carries orientation, so do not add a north arrow by default; add one only when the user asks. Keep the graticule subordinate to the evidence: thin light-grey lines under the data, never a heavy grid competing with boundaries or sites. Drop this furniture only for a locator inset, a deliberately bare schematic, or an explicit user request, and disclose the choice.
- Prefer legends inside genuine, inspected whitespace within the data rectangle. For spatial panels, make an interior legend fully transparent and borderless (`fill = NA`, `colour = NA`) so it visually belongs to the map; verify that map features remain readable behind and around it. If no safe interior space exists, use direct labels, a right-side/shared guide area, or another deliberate layout. Avoid top/bottom legends as the default because they shrink panel height; never cover evidence to save space.
- In a regular multi-panel grid, align the black data-panel rectangles, not merely the outer plot canvases. Panels in the same column must share left/right edges; panels in the same row must share top/bottom edges.
- Do not obtain alignment by shrinking the evidence into small, flat panels. At final size, verify both the rendered panel aspect and how much of the figure is occupied by data panels.
- Default to one figure-level caption or notes outside the image instead of repeating prose captions beneath every subfigure. Keep per-panel captions only when the venue or scientific meaning requires them.
- Add `labs(alt = ...)` for delivered plots; complex figures also need a longer description or source-data alternative.

Start every delivered script with visible parameters:

```r
library(ggplot2)

FONT_FAMILY <- "Arial"
TEXT_PT     <- 8
TAG_PT      <- 9
TEXT_GG     <- TEXT_PT / ggplot2::.pt   # .pt = 72.27 / 25.4
LINE_MM     <- 25.4 / 72
DATA_LINE_MM <- LINE_MM * 1.8

FIG_WIDTH_MM  <- 85
FIG_HEIGHT_MM <- 65
FIG_DPI       <- 600
RANDOM_SEED   <- 20260818

paper_palette <- c(
  Reference = "#6B6B6B",
  Treatment = "#0072B2"
)
```

Keep every consequential value in this block or beside the operation it controls. Avoid unexplained magic numbers.

## Workflow

### 1. Define the evidence and destination

Record the scientific question, audience, variables and units, sample/replicate structure, estimator and uncertainty, missing/censored values, transformations, target width, source paths, and output formats.

If the user supplies data but no question or requested figure type, ask what they are trying to learn before selecting a plot. Cosmetic edits and explicit plot requests do not require a new analysis plan.

### 2. Audit data before plotting

Write visible checks into the delivered script: row count, missing/non-finite counts, factor levels/order, duplicate identifiers, zero variance, invalid log values, and rows excluded by each filter. Print or save the results. Do not rely on a hidden audit helper.

### 3. Choose the encoding

| Evidence | Preferred starting point |
|---|---|
| Distribution/group difference | raw points + box/violin/interval as justified |
| Relationship | scatter + declared fit/CI; 1:1 line only when scientifically relevant |
| Model effect | coefficient/forest/marginal-effect plot with null line |
| Ranking | sorted dot/bar/lollipop with metric named |
| Composition | stacked/grouped display only for part-to-whole questions |
| Matrix | heatmap with explicit orientation, ordering, center, and missing color |
| Time/sequence | lines/ribbons or points/intervals; preserve missing-data gaps |
| Spatial | neutral basemap, one CRS, restrained boundaries, focal data on top |
| Multi-panel synthesis | facet shared variables; patchwork different geometries/axes |

Read the matching reference before coding uncommon or fragile layouts.

### 4. Build with explicit styles

Write `theme_classic()` and the complete `theme()` block directly in the delivered script. Order matters: `theme_classic()` and every other `theme_*()` preset is a **complete** theme, so adding it after your own `theme()` call discards that call entirely. `p + theme(legend.position = "inside", ...) + publication_theme` silently loses the inside legend and renders it on the right, because `theme_classic()` carries `legend.position = "right"`. Always add the preset first and your `theme()` modifications after it, and verify with `ggplot_build(p)$plot$theme$legend.position`. Apply the chosen font explicitly to text, axes, legends, strips, captions, and tags. Use `TEXT_GG` for `geom_text()`/`annotate()` because their size unit is not points.

Define named palettes and pin legend order with factors or `breaks = names(paper_palette)`. Check contrast and then visually inspect color-vision and grayscale separation; automated contrast does not certify accessibility.

Place a necessary legend inside a verified empty part of the data rectangle when possible. On ggplot2 ≥ 3.5, use `legend.position = "inside"`, explicit NPC coordinates, and justification. For a map, set `legend.background`, `legend.box.background`, and `legend.key` to transparent/borderless elements; do not draw a white card or black legend frame over the geography. For a non-spatial plot, use a readable unobtrusive background only when transparency would reduce legibility. Inspect the exported image to confirm the legend does not cover observations, intervals, labels, coastlines, focal regions, or an inset. If the panel has no safe whitespace, prefer direct labels or a right-side/shared guide instead of placing the legend above or below the panel.

### 5. Annotate only supporting evidence

Show only statistics supporting the panel purpose. Write p-value, R², and `n` formatting directly in the script, and state the model/test, interval definition, correction, and replication unit in the caption or notes. Set `inherit.aes = FALSE` for annotation-only data.

For a regular multi-panel figure, do not repeat long methodological prose below each panel. Put shared details in one figure-level note, manuscript caption, console audit, or adjacent data manifest. This preserves scientific disclosure without consuming the panel area. A panel-specific note may remain when it is genuinely unique and necessary.

### 6. Compose at final size

Use shared scales only when comparison is intended. Collect axes/guides only when scales truly match. Default to lowercase tags:

```r
PANEL_ASPECT <- 0.72
PANEL_ASPECT_TOLERANCE <- 0.005
MIN_PANEL_AREA_SHARE <- 0.40  # provisional diagnostic for this 2 x 2 design
# Do NOT pass widths/heights here. Explicit layout units make wrap_plots()
# stretch each panel to fill its slot, which silently overrides
# theme(aspect.ratio). Measured on ggplot2 4.0.3 / patchwork 1.3.2, a request
# for 0.618 renders as 0.570 with widths = c(1, 1), heights = c(1, 1) - the
# same value as setting no aspect ratio at all - and as 0.618 with the layout
# units left at their defaults.
composite <- patchwork::wrap_plots(
  p1 + theme(aspect.ratio = PANEL_ASPECT),
  p2 + theme(aspect.ratio = PANEL_ASPECT),
  p3 + theme(aspect.ratio = PANEL_ASPECT),
  p4 + theme(aspect.ratio = PANEL_ASPECT),
  ncol = 2
) +
  patchwork::plot_annotation(tag_levels = "a")
```

Use absolute row heights (`grid::unit(..., "mm")`) when the row height itself is the calibrated quantity, and `aspect.ratio` with default layout units when the panel shape is. Do not use both: they express the same constraint twice, and the layout unit wins. Verify the rendered aspect after composing; a loose tolerance hides this exact failure.

For a regular grid, use one flat `wrap_plots()` layout. Do not independently nest row layouts such as `(p1 | p2) / (p3 | p4)` when column panel edges must match; nested rows calculate their geometry separately. Apply one explicit `aspect.ratio` to every ordinary panel in the equal-frame grid.

**Canvas width rule.** Keep a multi-panel composite at or below 210 mm of total canvas width, the width of A4 paper; 170-190 mm is the usual working range. An explicitly requested golden-ratio variant is the one exception and may go wider (see below). A composite wider than the page is rescaled when it is placed into Word or a manuscript template, and that rescaling drops 8 pt text below legibility and thins the 1 pt frame. Height is not capped by this rule: a tall composite still prints at its authored width. A single figure has no canvas-size requirement, because it occupies little of the page and is rarely rescaled; size it from its evidence using the provisional sizes in `references/style-and-export.md`. State the target width before composing, and treat 210 mm as a physical page ceiling rather than evidence of any journal's compliance.

Choose figure width and height by rendering the whole composition, not by guessing from the outer canvas. These rules apply to any panel count: two panels side by side, a 2 × 3 sweep, a nine-panel matrix, or a map anchoring four statistical views. Panel count changes the numbers, not the method. `MIN_PANEL_AREA_SHARE <- 0.40` is a useful starting diagnostic for a 2 × 2 figure rather than a universal publishing rule; expect a lower share as panel count rises, because axis strips and inter-panel gaps multiply, and declare the threshold you actually used for this figure. Measure the sum of the four data-panel areas divided by total figure area, and measure each panel's rendered height/width. If the panels are too small or too flat, revise physical dimensions, legends, margins, and annotations before accepting the layout.

Do not distort maps, polar plots, or geometry whose fixed aspect carries meaning. A fixed-aspect panel that conflicts with the common frame belongs in a dedicated row/column, inset, or intentionally unequal layout. Read `references/style-and-export.md` for the decision rules and the final-size panel-coordinate check.

For a map joined to a statistical panel, let the map's rendered width/height guide the composition: near-square national maps often work side by side, while wide world maps usually work better above a compact horizontal statistical panel. Use fixed-aspect-aware `NA` widths/heights rather than forcing equal numeric units, then measure the actual map and statistical rectangles. Read `references/maps-and-spatial.md` for map-plus-statistics rules; a map-anchored synthesis of any panel count follows the Multi-Panel Map Synthesis standard defined there.

When the user explicitly asks for a golden-ratio variant, separate three numbers instead of enforcing one:

```r
GOLDEN_RATIO <- (1 + sqrt(5)) / 2
GOLDEN_BAND <- c(1.50, 1.75)         # accepted panel width / height
CANVAS_RATIO_TOLERANCE <- 0.005      # canvas W/H against GOLDEN_RATIO
ASPECT_FIDELITY_TOLERANCE <- 0.005   # rendered aspect against the requested one
```

- **Canvas**: keep `FIG_WIDTH_MM / FIG_HEIGHT_MM` within `CANVAS_RATIO_TOLERANCE` of `GOLDEN_RATIO`. Hitting it exactly is free, because both numbers are passed to `ggsave()`.
- **Panels**: each requested golden panel's rendered width/height must land inside `GOLDEN_BAND`, not on the point value. Report every measured ratio. The band is centred on 1.618 and runs from 3:2 to 7:4, which still reads as one harmonious wide rectangle; below 1.5 a panel starts to read as 4:3, above 1.75 as a strip.
- **Fidelity**: the rendered aspect must match the requested one within `ASPECT_FIDELITY_TOLERANCE`. This is not an aesthetic tolerance and must stay tight; it is what catches an `aspect.ratio` that patchwork silently dropped.

Do not widen the canvas merely to reach the point value. On a golden canvas the row height is capped by the canvas, so the wide end of the band buys back panel area at no cost: measured on a 190 x 117.43 mm sheet, a 2 x 2 grid gives an area share of 0.504 at 1.50, 0.544 at exactly 1.618, and 0.588 at 1.75, with panel height fixed at 43.3 mm throughout. A requested golden variant may still exceed the 210 mm composite ceiling when the geometry genuinely needs it, but try the band first: forcing exact golden panels on a 220 mm canvas produced the same 0.588 area share that 190 mm reaches inside the band. Report the width whenever it passes 210 mm, and note that such a figure is rescaled in an A4 Word page. Treat this as an optional design experiment, not a universal scientific standard. Never stretch a map to reach the ratio: preserve its CRS and coordinate scale, and reach the target through a defensible viewport, cropping choice, panel allocation, or transparent surrounding space. Report any map panel that cannot meet the requested ratio without changing the scientific extent.

### 7. Export explicitly

Write the device and dimensions in the final script and guard against accidental overwrite. Keep the guard switchable so that the mandated inspect-and-iterate loop does not require deleting files by hand between runs; the default stays refusing:

```r
OVERWRITE <- FALSE   # set TRUE only while iterating on the same figure
output_png <- "outputs/figure-1.png"
if (!OVERWRITE && file.exists(output_png)) {
  stop("Refusing to overwrite: ", output_png, " (set OVERWRITE <- TRUE to replace)")
}

ggplot2::ggsave(
  filename = output_png,
  plot = composite,
  device = ragg::agg_png,
  width = FIG_WIDTH_MM,
  height = FIG_HEIGHT_MM,
  units = "mm",
  dpi = FIG_DPI,
  bg = "white"
)
```

Use explicit `ragg::agg_tiff`, `svglite::svglite`, Quartz PDF on macOS, or a verified Cairo PDF elsewhere. Never rely on the active viewer size or implicit last plot.

Write a figure-level sidecar caption text file (same basename plus `.caption.txt`) beside every exported figure with `writeLines(enc2utf8(lines), path, useBytes = TRUE)`, because plain `writeLines()` under a C locale turns a degree sign or CJK character into the literal placeholder `<U+00B0>`. The sidecar carries the panel alt texts, sample sizes, uncertainty definitions, seeds, exclusion and transformation notes, measured geometry, and R/package versions. Do not draw these disclosures into the image itself.

### 8. Inspect and iterate

Build the plot with `ggplot2::ggplot_build()`, verify labels/alt text from `ggplot2::get_labs()`, then inspect the exported file at final size. For composition geometry, use `scripts/rfigure_layout.R` rather than writing a private viewport walker: hand-rolled versions routinely measure patchwork's `panel-area` viewport (the whole grid region) instead of the panels and report confident nonsense. If you cannot see images in this session, say so in the delivery, and replace the visual pass with programmatic checks that go down to glyph level - read the exported PNG's pixels to confirm legend-versus-data overlap and tag clearance - rather than declaring the figure inspected. For a regular multi-panel grid, read the final composition's panel viewports and verify equal widths/heights plus common row/column edges within a declared physical tolerance; canvas-slot alignment is not sufficient. Calibrate and enforce these geometry checks against the PNG device; measure the SVG geometry and report it for information instead of failing delivery on sub-tolerance font-metric drift. Also calculate actual panel height/width and total panel-area share using visible, figure-specific thresholds. Check fonts, clipping, legends, panel proportions, line hierarchy, missingness, annotations, map/inset alignment, and metadata. Keep long shared notes outside the subfigure rectangles; if the venue requires notes inside the exported image, wrap them and increase the physical height rather than shrinking the panels.

## Compact Rules

- Show raw observations when feasible; summaries must not conceal sample size or spread.
- Name uncertainty precisely: SD, SE, 95% CI, percentile interval, posterior interval, etc.
- Use diverging color only around a meaningful center; sequential color for unsigned magnitude; cyclic color only for cyclic variables.
- Distinguish missing, zero, censored, excluded, and out-of-range values.
- Preserve gaps in time series unless interpolation/model prediction is explicit, and confirm at final size that a preserved gap is actually visible; `na.omit()` before plotting silently interpolates across it.
- Count and disclose rows that a declared `limits = ` would drop; a scale limit is a filter, not a zoom.
- Write text sidecar files with `writeLines(enc2utf8(x), path, useBytes = TRUE)`.
- Use `coord_sf(xlim = ..., ylim = ..., default_crs = ..., expand = FALSE)` for geographic limits; do not use `xlim()`/`ylim()` on sf maps.
- Cap a multi-panel composite at 210 mm of canvas width; do not cap the size of a single-panel figure, and do not cap an explicitly requested golden-ratio variant.
- Draw a map graticule from explicit `scale_x_continuous()`/`scale_y_continuous()` breaks plus `panel.grid.major`, and keep `coord_sf(label_axes = "--EN")` so only the bottom and left edges carry labels.
- Format geographic tick labels as decimal degrees with a fixed number of decimals; do not mix degree-minute-second and decimal notation in one figure.
- Do not draw a north arrow unless the user asks for one; the graticule already shows orientation.
- Keep the map projection in one visible parameter so a recipient can change it, and state the projection and why it suits the map's purpose.
- Choose a world projection to match the frame: rectangular (`plate_carree`, or `behrmann` when area matters) if the panel keeps its four-sided frame, pseudocylindrical only with its graticule or its own oval outline.
- Removing a map's graticule also removes its latitude labels on a curved-graticule projection; verify the rendered labels after changing it.
- Cut world-map polygons at the projection's antimeridian after any `st_make_valid()` call; s2 rejoins Russia and Fiji and they render as horizontal streaks across the whole map.
- Derive a hemisphere suffix from the value's sign, never from a scalar axis flag inside `ifelse()`, and leave the equator and prime meridian unsuffixed.
- Draw categorical sampling sites on maps as same-size solid circles by default (`shape = 21` with class-specific `fill`, or `shape = 16` with class-specific `colour`); do not map class to `shape` unless requested.
- Use `geom_errorbar(orientation = "y")` instead of deprecated `geom_errorbarh()`.
- Use `legend.position = "inside"` with `legend.position.inside` on ggplot2 ≥ 3.5; numeric `legend.position` is deprecated.
- Add a complete theme (`theme_classic()`, `theme_bw()`, a preset that wraps one) before your own `theme()` calls; a complete theme added afterwards discards them.
- Never combine `theme(aspect.ratio = ...)` with explicit patchwork `widths`/`heights`; the layout unit wins and the aspect request is silently dropped.
- Space stacked direct labels from physical geometry: minimum gap in data units = clearance factor × label height (mm) ÷ rendered panel height (mm) × axis span, with a floor clamp; never hard-code a fraction of the span.
- Enforce rendered-geometry checks on the PNG device; measure and report SVG geometry as informational.
- Do not claim publisher compliance, accessibility, or statistical validity from a style preset or automated check alone.

## Final Checklist

- [ ] The delivered `.R` file is self-contained and does not call this skill's helper scripts.
- [ ] All plotting and export parameters are visible in the code.
- [ ] Raw data, transformations, exclusions, missingness, and random seeds are preserved and disclosed.
- [ ] Estimator, uncertainty, `n`, and replication unit are correctly represented.
- [ ] Scales, baselines, limits, smoothing, and normalization are honest.
- [ ] Arial 8 pt (or an explicit CJK family), four-sided 1 pt border, white background, and heavier data lines are consistent.
- [ ] Multi-panel tags default to lowercase `a`, `b`, `c`, ...
- [ ] Regular multi-panel grids of any panel count use one flat layout and their rendered data-panel rectangles pass row/column edge alignment checks at final size.
- [ ] The measured panel count equals the intended one; `wrap_elements()`, insets, and nested compositions can add panel viewports.
- [ ] Regular multi-panel grids also pass declared rendered-aspect and panel-area-share checks at a tolerance tight enough to catch a silently dropped `aspect.ratio`; alignment was not achieved by making the panels too small.
- [ ] Inside legends survived theme composition: the built plot really reports `legend.position = "inside"`.
- [ ] Map-plus-statistics layouts preserve the map projection, choose rows/columns from rendered geometry, and verify the shared panel edges after export.
- [ ] Categorical map sites use one solid circular shape with stable class colors by default; map legends and statistical panels preserve the same color meanings.
- [ ] Interior map legends are transparent and borderless, and visual inspection confirms they cover no geographic or analytical evidence.
- [ ] Every geographic map carries a left/bottom graticule with decimal-degree labels, or the omission is deliberate and disclosed.
- [ ] The map projection sits in one visible parameter, is named in the disclosure, and suits the map's purpose and extent.
- [ ] A multi-panel composite is at or below 210 mm wide so it needs no rescaling in Word; single-panel figures are exempt from that ceiling.
- [ ] A requested golden-ratio variant keeps the canvas near-exact, lands every requested panel inside the declared ratio band, reports all measured ratios, and does not stretch fixed-aspect geometry; if its width exceeds 210 mm, the width and its rescaling consequence are stated.
- [ ] Repeated prose is not placed below every subfigure unless it is scientifically or editorially required; shared disclosure remains available in one figure-level note or adjacent output.
- [ ] Color semantics are stable and identity is redundantly encoded where needed.
- [ ] Legends use inspected interior whitespace when available; otherwise their alternate placement is deliberate and does not unnecessarily reduce panel height.
- [ ] Axis/legend labels include full variable names and units.
- [ ] Alt text describes chart type, variables, groups, and the main visible pattern without overstating inference.
- [ ] Stacked direct labels use physically derived spacing and do not overlap at final size.
- [ ] Panel tags keep at least 1 mm clearance from neighbouring axis decorations.
- [ ] Every exported figure has a sidecar `.caption.txt` with panel descriptions, disclosures, measured geometry, and software versions, written through `enc2utf8()` with `useBytes = TRUE`.
- [ ] Every graticule break on a map panel produces a drawn axis label, checked against the rendered axis text rather than graticule geometry.
- [ ] A world map has no polygon ring crossing the antimeridian, and the exported image shows no horizontal streak.
- [ ] The world projection, the panel frame, and the graticule agree: a rectangular frame goes with a rectangular projection, and a dropped graticule was confirmed not to drop the labels.
- [ ] Longitude and latitude labels carry the hemisphere of their own sign, asserted in the script.
- [ ] Rows that a declared scale limit would silently discard were counted and disclosed.
- [ ] Physical dimensions, format, DPI, fonts, clipping, and file size were inspected.
- [ ] Live journal rules were verified when a venue-specific claim is made.
