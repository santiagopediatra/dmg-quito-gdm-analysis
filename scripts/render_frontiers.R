library(magick)
library(xml2)

dir.create("figures", showWarnings = FALSE)
sources <- c("scripts/figura1_flujo.gv", "scripts/figura2_vias.gv")
widths_mm <- c(85, 180)
for (index in seq_along(sources)) {
  stem <- file.path("figures", paste0("Figure", index))
  svg_file <- paste0(stem, ".svg")
  pdf_file <- paste0(stem, ".pdf")
  tif_file <- paste0(stem, ".tif")
  if (file.exists(tif_file)) {
    backup <- paste0(stem, "_old.tif")
    if (file.exists(backup)) stop("Backup already exists: ", backup)
    stopifnot(file.rename(tif_file, backup))
  }
  status <- system2("dot", c("-Tsvg", sources[index], "-o", svg_file))
  stopifnot(status == 0)
  document <- read_xml(svg_file)
  root <- xml_root(document)
  viewport <- as.numeric(strsplit(xml_attr(root, "viewBox"), " +")[[1]])
  width_pt <- widths_mm[index] / 25.4 * 72
  height_pt <- viewport[4]
  stopifnot(height_pt / 72 * 25.4 <= 225, viewport[3] <= width_pt)
  xml_set_attr(root, "width", paste0(widths_mm[index], "mm"))
  xml_set_attr(root, "height", paste0(height_pt, "pt"))
  xml_set_attr(root, "viewBox", paste(c(-(width_pt - viewport[3]) / 2, 0, width_pt, height_pt), collapse = " "))
  graph <- xml_find_first(root, ".//*[local-name()='g' and @class='graph']")
  scale <- as.numeric(sub(".*scale\\(([0-9.]+).*", "\\1", xml_attr(graph, "transform"))) * min(1, floor(width_pt) / width_pt)
  fonts <- as.numeric(xml_attr(xml_find_all(root, ".//*[@font-size]"), "font-size"))
  strokes <- as.numeric(xml_attr(xml_find_all(root, ".//*[@stroke-width]"), "stroke-width"))
  stopifnot(min(fonts) * scale >= 8, min(strokes) * scale >= 2)
  write_xml(document, svg_file)
  rsvg::rsvg_pdf(svg_file, pdf_file)
  status <- system2("python3", c("scripts/set_pdf_page.py", pdf_file, width_pt, height_pt))
  stopifnot(status == 0)
  rendered <- image_read_pdf(pdf_file, density = 600)
  rendered <- image_background(rendered, "white", flatten = TRUE)
  rendered <- image_convert(rendered, colorspace = "sRGB", type = "TrueColor", depth = 8)
  image_write(rendered, tif_file, format = "tiff", compression = "lzw", density = "600x600")
  cat(stem, "| minimum final font:", min(fonts) * scale, "pt | minimum final stroke:", min(strokes) * scale, "pt\n")
}

for (f in c("figures/Figure1.tif", "figures/Figure2.tif")) {
  i <- image_read(f); info <- image_info(i)
  cat(f, info$width, "x", info$height, "px | colorspace:", info$colorspace,
      "| ancho mm a 600 dpi:", round(info$width / 600 * 25.4, 1), "\n")
}
