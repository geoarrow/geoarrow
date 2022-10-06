
library(tidyverse)
library(s2)
library(magick)
library(gifski)
library(av)

n_frames <- 200

if (dir.exists("logo/spin")) {
  unlink("logo/spin", recursive = TRUE)
}

dir.create("logo/spin")

countries <- s2_union_agg(
  s2_data_countries()
)

ragg::agg_png(
  "logo/spin/spin%03d.png",
  width = 1000, height = 1000,
  background = rgb(0, 0, 0, 0)
)
par(mai = c(0, 0, 0, 0), omi = c(0, 0, 0, 0))

lat <- 0
for (lon in seq(0, 360, length.out = n_frames + 1)[-1]) {
  plot(
    double(), double(),
    asp = 1, xlim = c(-1, 1), ylim = c(-1, 1),
    axes = FALSE, xlab = "", ylab = ""
  )

  # hack!
  assign("centre", s2_lnglat(lon, lat), envir = s2:::last_plot_env)

  s2_plot(
    countries,
    lwd = 5,
    border = "black",
    col = NA,
    add = TRUE
  )
}

dev.off()

raw_hex <- image_read("logo/geoarrow-hex-base.png")

overlay_globe <- function(i = 1) {
  globe <- image_read(sprintf("logo/spin/spin%03d.png", i)) |>
    image_background("rgba(0,0,0,0)") |>
    image_rotate(-15)

  image_composite(
    raw_hex,
    globe,
    offset = "+0+950",
    gravity = "north"
  )
}

image_write(overlay_globe(), "logo/geoarrow-hex.png")

images <- lapply(1:n_frames, overlay_globe)

stacked <- do.call(c, images) |>
  image_background("rgba(255,255,255,0)")

image_write_gif(stacked, "logo/geoarrow-hex.gif", delay = 1 / 25)


stacked <- do.call(c, images) |>
  image_background("rgba(255,255,255,255)")

image_write_video(stacked, "logo/geoarrow-hex.mp4", framerate = 25)

unlink("logo/spin", recursive = TRUE)
