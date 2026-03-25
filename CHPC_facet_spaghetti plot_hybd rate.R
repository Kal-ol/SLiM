library(tidyverse)

results_dir <- "~/slim_runs/results"

# Read hybridization sweep
hyb_dirs <- list.dirs(results_dir, recursive = FALSE, full.names = TRUE) |>
  keep(~ grepl("/hyb_idx", .x))

hyb_data <- map_dfr(hyb_dirs, function(d) {
  folder <- basename(d)
  hyb_val <- sub(".*_val", "", folder)

  f <- file.path(d, "output.txt")
  if (!file.exists(f)) return(NULL)

  dat <- read_tsv(f, show_col_types = FALSE)

  dat |>
    mutate(
      hybridizationRate = as.numeric(hyb_val),
      run_id = folder
    )
})

# Convert to long format
hyb_long <- hyb_data |>
  pivot_longer(
    cols = c(offspring_p1, offspring_p2, offspring_p3),
    names_to = "population",
    values_to = "offspring"
  )

# Faceted spaghetti plot
p_facet <- ggplot(
  hyb_long,
  aes(
    x = gen,
    y = offspring,
    group = hybridizationRate,
    color = hybridizationRate
  )
) +
  geom_line(alpha = 0.6) +
  facet_wrap(~ population, scales = "free_y") +
  scale_color_viridis_c(option = "plasma") +
  labs(
    title = "Population dynamics across hybridization rates",
    x = "Generation",
    y = "Offspring count",
    color = "Hybridization rate"
  ) +
  theme_bw()

print(p_facet)

# Save
ggsave("~/slim_runs/results/hyb_facet_spaghetti.png",
       p_facet, width = 10, height = 6, dpi = 300)
