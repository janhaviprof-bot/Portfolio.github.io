# ============================================================
# Load required libraries
# ============================================================
library(readr)
library(dplyr)
library(tidyr)
library(scales)
library(ggplot2)

# PNGs are written under output/ (created if needed). Plots are still printed when
# a graphics device is available (RStudio, interactive R). Rscript alone gets files + console.

OUTPUT_DIR <- file.path(getwd(), "output")
dir.create(OUTPUT_DIR, showWarnings = FALSE, recursive = TRUE)

save_plot <- function(plot, filename, width = 8, height = 5, dpi = 150) {
  path <- file.path(OUTPUT_DIR, filename)
  ggsave(path, plot, width = width, height = height, dpi = dpi)
  message("Saved: ", path)
}

# ============================================================
# Read the architecture enumeration from CSV
# ============================================================
arch_enum <- read_csv("output_ex1_Q4.csv", show_col_types = FALSE)
head(arch_enum)

# ============================================================
# Notes on architecture encoding
# ============================================================
# d7_1 to d7_6: which partition (1,2,3) each high-level function belongs to
# d4_1 to d4_6: motor at each position (nose=d4_5, tail=d4_6)
# d1 to d8: other design decisions

# ============================================================
# Metric value tables
# ============================================================
OperatingCost <- matrix(
  c(
    180, 240, 420,
    180, 170, 360,
    150, 165, 200,
    160, 185, NA,
    140, 175, 230,
    160, 210, NA,
    155, 170, NA,
    195, 160, NA
  ),
  nrow = 8,
  byrow = TRUE
)

PropulsionReliability <- matrix(
  c(
    99.6, 99.3, 97.8,
    99.5, 99.7, 99.9,
    98.8, 99.5, 99.3,
    99.1, 99.4, NA,
    98.5, 99.5, 99.95,
    99.2, 99.1, NA,
    99.1, 99.2, NA,
    99.8, 98.9, NA
  ),
  nrow = 8,
  byrow = TRUE
)
PropulsionReliability <- PropulsionReliability / 100

SystemDurability <- matrix(
  c(
    9.0, 8.0, 7.0,
    7.5, 8.5, 9.0,
    8.0, 9.0, 8.5,
    8.5, 9.5, NA,
    7.0, 8.5, 10.0,
    8.0, 9.0, NA,
    8.0, 8.5, NA,
    9.0, 8.0, NA
  ),
  nrow = 8,
  byrow = TRUE
)

CertificationSchedule <- matrix(
  c(
    2.0, 3.0, 6.0,
    1.5, 1.5, 5.0,
    1.5, 2.5, 4.0,
    2.0, 2.5, NA,
    1.5, 3.0, 4.5,
    2.0, 3.5, NA,
    2.0, 3.0, NA,
    3.5, 2.0, NA
  ),
  nrow = 8,
  byrow = TRUE
)

# ============================================================
# Compute objectives for each architecture
# ============================================================
compute_tradespace <- function(df) {
  n <- nrow(df)
  total_cost <- numeric(n)
  certification_schedule <- numeric(n)
  propulsion_reliability <- numeric(n)
  durability_years <- numeric(n)

  d4_wing <- c("d4_1", "d4_2", "d4_3", "d4_4")
  d4_nose_tail <- c("d4_5", "d4_6")
  d4_cols <- c("d4_1", "d4_2", "d4_3", "d4_4", "d4_5", "d4_6")
  d7_cols <- c("d7_1", "d7_2", "d7_3", "d7_4", "d7_5", "d7_6")

  for (i in seq_len(n)) {
    cost <- OperatingCost[1, df$d1[i] + 1] +
      OperatingCost[2, df$d2[i] + 1] +
      OperatingCost[3, df$d3[i] + 1]

    wing_cost <- sum(as.numeric(df[i, d4_wing]) * OperatingCost[4, 1])
    nose_tail_cost <- sum(as.numeric(df[i, d4_nose_tail]) * OperatingCost[4, 2])
    cost <- cost + wing_cost + nose_tail_cost

    cost <- cost + OperatingCost[5, df$d5[i] + 1] +
      OperatingCost[6, df$d6[i] + 1]

    d7_values_cost <- as.numeric(df[i, paste0("d7_", 1:6)])
    d7_val <- ifelse(any(d7_values_cost == 2), 1, 0)
    cost <- cost + OperatingCost[7, d7_val + 1]
    cost <- cost + OperatingCost[8, df$d8[i] + 1]
    total_cost[i] <- cost

    seq_time <- CertificationSchedule[1, df$d1[i] + 1] +
      CertificationSchedule[5, df$d5[i] + 1] +
      CertificationSchedule[6, df$d6[i] + 1]
    d2_time <- CertificationSchedule[2, df$d2[i] + 1]
    d3_time <- CertificationSchedule[3, df$d3[i] + 1]
    d4_selected_s <- as.numeric(df[i, d4_cols])
    d4_time_s <- max(d4_selected_s * CertificationSchedule[4, 2])
    num_partitions_s <- length(unique(df[i, d7_cols]))
    if (num_partitions_s == 3) {
      d7_time_s <- CertificationSchedule[7, 2]
    } else {
      d7_time_s <- CertificationSchedule[7, 1]
    }
    d8_time_s <- CertificationSchedule[8, df$d8[i] + 1]
    par_time <- max(d2_time, d3_time, d4_time_s, d7_time_s, d8_time_s)
    certification_schedule[i] <- max(seq_time, par_time)

    R_D1 <- PropulsionReliability[1, df$d1[i] + 1]
    R_D3 <- PropulsionReliability[3, df$d3[i] + 1]
    d4_selected_r <- as.numeric(df[i, d4_cols])
    wing_reliab <- prod(1 - d4_selected_r[1:4] * (1 - PropulsionReliability[4, 1]))
    nose_tail_reliab <- prod(1 - d4_selected_r[5:6] * (1 - PropulsionReliability[4, 2]))
    R_D4 <- 1 - (1 - wing_reliab) * (1 - nose_tail_reliab)
    R_series <- R_D1 * R_D3 * R_D4
    R_D5 <- PropulsionReliability[5, df$d5[i] + 1]
    R_D6 <- PropulsionReliability[6, df$d6[i] + 1]
    d7_values_r <- as.numeric(df[i, d7_cols])
    num_partitions_r <- length(unique(d7_values_r))
    if (num_partitions_r == 3) {
      R_D7 <- PropulsionReliability[7, 2]
    } else {
      R_D7 <- PropulsionReliability[7, 1]
    }
    R_parallel <- 1 - (1 - R_D5) * (1 - R_D6) * (1 - R_D7)
    propulsion_reliability[i] <- R_series * R_parallel

    series_values <- c(
      SystemDurability[1, df$d1[i] + 1],
      SystemDurability[2, df$d2[i] + 1],
      SystemDurability[3, df$d3[i] + 1]
    )
    d4_selected_d <- as.numeric(df[i, d4_cols])
    d4_time_d <- max(d4_selected_d * SystemDurability[4, 2])
    series_values <- c(series_values, d4_time_d)
    series_min <- min(series_values)
    parallel_values <- c(
      SystemDurability[5, df$d5[i] + 1],
      SystemDurability[6, df$d6[i] + 1]
    )
    num_partitions_d <- length(unique(df[i, d7_cols]))
    if (num_partitions_d == 3) {
      d7_time_d <- SystemDurability[7, 2]
    } else {
      d7_time_d <- SystemDurability[7, 1]
    }
    parallel_values <- c(parallel_values, d7_time_d)
    parallel_max <- max(parallel_values)
    durability_years[i] <- min(series_min, parallel_max)
  }

  tibble(
    arch_id = seq_len(n),
    total_operating_cost_per_hr = total_cost,
    certification_schedule_yrs = certification_schedule,
    propulsion_reliability = propulsion_reliability,
    system_durability_yrs = durability_years
  )
}

message("Computing objectives for ", nrow(arch_enum), " architectures...")
tradespace <- compute_tradespace(arch_enum)
print(summary(tradespace))
print(head(tradespace))

# ============================================================
# Tradespace charts (2D objective space, single point color)
# ============================================================
# Cost & schedule: minimize. Reliability & durability: maximize.

theme_tradespace <- theme_minimal(base_size = 11) +
  theme(
    panel.grid.minor = element_blank(),
    plot.title = element_text(face = "bold")
  )

TRADESPACE_POINT_COLOR <- "#0D5C6B"

p_cost_rel <- ggplot(
  tradespace,
  aes(x = total_operating_cost_per_hr, y = propulsion_reliability)
) +
  geom_point(alpha = 0.22, stroke = 0, size = 0.55, color = TRADESPACE_POINT_COLOR) +
  scale_y_continuous(labels = percent_format(accuracy = 0.01)) +
  labs(
    title = "Tradespace: cost vs propulsion reliability",
    subtitle = "Cost: lower is better; reliability: higher is better",
    x = "Total operating cost ($/hr)",
    y = "Propulsion system reliability"
  ) +
  theme_tradespace

message("--- Plot: cost vs reliability ---")
save_plot(p_cost_rel, "tradespace_cost_vs_reliability.png")
print(p_cost_rel)

p_rel_dur <- ggplot(
  tradespace,
  aes(x = propulsion_reliability, y = system_durability_yrs)
) +
  geom_point(alpha = 0.22, stroke = 0, size = 0.55, color = TRADESPACE_POINT_COLOR) +
  scale_x_continuous(labels = percent_format(accuracy = 0.1)) +
  labs(
    title = "Tradespace: propulsion reliability vs system durability",
    subtitle = "Reliability and durability: higher is better",
    x = "Propulsion system reliability",
    y = "System durability (years)"
  ) +
  theme_tradespace

message("--- Plot: reliability vs durability ---")
save_plot(p_rel_dur, "tradespace_reliability_vs_durability.png")
print(p_rel_dur)

p_cost_sched <- ggplot(
  tradespace,
  aes(x = total_operating_cost_per_hr, y = certification_schedule_yrs)
) +
  geom_point(alpha = 0.22, stroke = 0, size = 0.55, color = TRADESPACE_POINT_COLOR) +
  labs(
    title = "Tradespace: cost vs certification schedule",
    subtitle = "Cost and schedule: lower is better",
    x = "Total operating cost ($/hr)",
    y = "Certification schedule (years)"
  ) +
  theme_tradespace

message("--- Plot: cost vs certification schedule ---")
save_plot(p_cost_sched, "tradespace_cost_vs_certification_schedule.png")
print(p_cost_sched)

# ============================================================
# Parallel coordinates (normalized 0–1, random sample)
# ============================================================
set.seed(1)
n_pc <- min(1200L, nrow(tradespace))
pc_df <- tradespace %>%
  slice(sample.int(nrow(tradespace), n_pc)) %>%
  mutate(
    row_id = row_number(),
    total_operating_cost_per_hr = (total_operating_cost_per_hr - min(total_operating_cost_per_hr)) /
      (max(total_operating_cost_per_hr) - min(total_operating_cost_per_hr)),
    certification_schedule_yrs = (certification_schedule_yrs - min(certification_schedule_yrs)) /
      (max(certification_schedule_yrs) - min(certification_schedule_yrs)),
    propulsion_reliability = (propulsion_reliability - min(propulsion_reliability)) /
      (max(propulsion_reliability) - min(propulsion_reliability)),
    system_durability_yrs = (system_durability_yrs - min(system_durability_yrs)) /
      (max(system_durability_yrs) - min(system_durability_yrs))
  )

pc_long <- pc_df %>%
  select(row_id, total_operating_cost_per_hr, certification_schedule_yrs,
         propulsion_reliability, system_durability_yrs) %>%
  pivot_longer(
    c(total_operating_cost_per_hr, certification_schedule_yrs,
      propulsion_reliability, system_durability_yrs),
    names_to = "objective",
    values_to = "value"
  ) %>%
  mutate(
    objective = recode(
      objective,
      total_operating_cost_per_hr = "Operating cost ($/hr)",
      certification_schedule_yrs = "Cert. schedule (yrs)",
      propulsion_reliability = "Propulsion reliability",
      system_durability_yrs = "System durability (yrs)"
    ),
    objective = factor(
      objective,
      levels = c(
        "Operating cost ($/hr)",
        "Cert. schedule (yrs)",
        "Propulsion reliability",
        "System durability (yrs)"
      )
    )
  )

p_parallel <- ggplot(pc_long, aes(x = objective, y = value, group = row_id)) +
  geom_line(alpha = 0.08, linewidth = 0.35, color = "#2C5F6F") +
  labs(
    title = "Parallel coordinates (normalized objectives)",
    subtitle = paste0("Random sample of ", n_pc, " architectures; metrics scaled to [0, 1] within sample"),
    x = NULL,
    y = "Normalized value"
  ) +
  theme_tradespace +
  theme(axis.text.x = element_text(angle = 20, hjust = 1))

message("--- Plot: parallel coordinates (sample) ---")
save_plot(p_parallel, "tradespace_parallel_coordinates.png")
print(p_parallel)

# ============================================================
# Additional output: Pareto ranking + cost/reliability fuzzy plot + polyline
# ============================================================

pareto_layers_matrix <- function(M) {
  n <- nrow(M)
  ranks <- integer(n)
  rem <- seq_len(n)
  layer <- 1L
  while (length(rem) > 0L) {
    front <- integer(0)
    for (k in seq_along(rem)) {
      i <- rem[k]
      dominated <- FALSE
      for (j in rem) {
        if (i == j) next
        le_cost <- M[j, 1L] <= M[i, 1L]
        le_sched <- M[j, 2L] <= M[i, 2L]
        ge_rel <- M[j, 3L] >= M[i, 3L]
        ge_dur <- M[j, 4L] >= M[i, 4L]
        strict <- (M[j, 1L] < M[i, 1L]) || (M[j, 2L] < M[i, 2L]) ||
          (M[j, 3L] > M[i, 3L]) || (M[j, 4L] > M[i, 4L])
        if (le_cost && le_sched && ge_rel && ge_dur && strict) {
          dominated <- TRUE
          break
        }
      }
      if (!dominated) {
        front <- c(front, i)
      }
    }
    ranks[front] <- layer
    rem <- setdiff(rem, front)
    layer <- layer + 1L
  }
  ranks
}

obj_cols <- c(
  "total_operating_cost_per_hr", "certification_schedule_yrs",
  "propulsion_reliability", "system_durability_yrs"
)

unique_objs <- tradespace %>% distinct(across(all_of(obj_cols)))
unique_objs$pareto_rank <- pareto_layers_matrix(as.matrix(unique_objs))

tradespace_p <- tradespace %>%
  left_join(unique_objs, by = obj_cols)

# CSV: all enumerated architectures whose objective vector lies on Pareto fronts 1–3
PARETO_EXPORT_MAX_RANK <- 3L
arch_pareto_ranks <- arch_enum %>%
  mutate(arch_id = row_number()) %>%
  left_join(
    tradespace_p %>%
      select(
        arch_id,
        total_operating_cost_per_hr,
        certification_schedule_yrs,
        propulsion_reliability,
        system_durability_yrs,
        pareto_rank
      ),
    by = "arch_id"
  ) %>%
  filter(between(pareto_rank, 1L, PARETO_EXPORT_MAX_RANK)) %>%
  select(-arch_id) %>%
  relocate(pareto_rank) %>%
  arrange(pareto_rank, across(all_of(names(arch_enum))))

pareto_csv_path <- file.path(OUTPUT_DIR, "architectures_pareto_ranks_1_to_3.csv")
write_csv(arch_pareto_ranks, pareto_csv_path)
message(
  "Wrote ",
  nrow(arch_pareto_ranks),
  " rows (Pareto ranks 1–",
  PARETO_EXPORT_MAX_RANK,
  ") to ",
  normalizePath(pareto_csv_path, winslash = "/")
)

# Fuzzy frontier highlight on cost/reliability plot (rank cutoff)
PARETO_FUZZY_THRESHOLD_CR <- 10L

ts_back_cr <- tradespace_p %>% filter(pareto_rank >= PARETO_FUZZY_THRESHOLD_CR)
ts_fuzz_cr <- tradespace_p %>% filter(pareto_rank < PARETO_FUZZY_THRESHOLD_CR)

# 2D polylines in (cost × reliability) for ranks 1–3: unique objective pairs per rank,
# ordered along increasing cost, then decreasing reliability (trace of each front class).
pareto_front_polyline_cr <- function(ts, r) {
  ts %>%
    filter(pareto_rank == as.integer(r)) %>%
    distinct(total_operating_cost_per_hr, propulsion_reliability) %>%
    arrange(total_operating_cost_per_hr, desc(propulsion_reliability))
}

pline_r1 <- pareto_front_polyline_cr(tradespace_p, 1L)
pline_r2 <- pareto_front_polyline_cr(tradespace_p, 2L)
pline_r3 <- pareto_front_polyline_cr(tradespace_p, 3L)

# ============================================================
# Cost vs reliability tradespace (reference style: rank gradient + magenta fuzzy)
# X = cost (minimize → left is better), Y = reliability (maximize → up is better)
# ============================================================
plt_cost_reliability_pareto <- ggplot() +
  geom_point(
    data = tradespace_p,
    aes(x = total_operating_cost_per_hr, y = propulsion_reliability, color = pareto_rank),
    alpha = 0.38,
    size = 0.55,
    shape = 16
  ) +
  scale_color_gradient(
    low = "#08306B",
    high = "#E8E8E8",
    name = "Pareto rank"
  ) +
  geom_point(
    data = ts_fuzz_cr,
    aes(x = total_operating_cost_per_hr, y = propulsion_reliability),
    color = "#E91EAC",
    alpha = 0.88,
    size = 0.78,
    shape = 16,
    inherit.aes = FALSE
  ) +
  geom_path(
    data = pline_r1,
    aes(x = total_operating_cost_per_hr, y = propulsion_reliability, group = 1L),
    color = "#1E3A8A",
    linewidth = 1,
    lineend = "round",
    linejoin = "round",
    inherit.aes = FALSE
  ) +
  geom_path(
    data = pline_r2,
    aes(x = total_operating_cost_per_hr, y = propulsion_reliability, group = 1L),
    color = "#047857",
    linewidth = 0.85,
    lineend = "round",
    linejoin = "round",
    inherit.aes = FALSE
  ) +
  geom_path(
    data = pline_r3,
    aes(x = total_operating_cost_per_hr, y = propulsion_reliability, group = 1L),
    color = "#B45309",
    linewidth = 0.7,
    lineend = "round",
    linejoin = "round",
    inherit.aes = FALSE
  ) +
  scale_y_continuous(labels = percent_format(accuracy = 0.1)) +
  labs(
    title = "Cost / reliability tradespace (Pareto rank & fuzzy frontier)",
    subtitle = paste0(
      "Blue-gray = Pareto rank (dark = best). Magenta = fuzzy (rank < ",
      PARETO_FUZZY_THRESHOLD_CR,
      "). Polylines (unique cost-reliability): navy = front 1, green = front 2, amber = front 3."
    ),
    x = "Cost ($/hr)",
    y = "Reliability (propulsion)"
  ) +
  theme_tradespace +
  theme(
    legend.position = "right",
    panel.grid.major = element_line(color = "gray88")
  )

message(
  "--- Plot: cost vs reliability Pareto / fuzzy (rank < ",
  PARETO_FUZZY_THRESHOLD_CR, ") | Polyline vertices (unique cost-rel): rank1 ",
  nrow(pline_r1), ", rank2 ", nrow(pline_r2), ", rank3 ", nrow(pline_r3), " ---"
)
save_plot(
  plt_cost_reliability_pareto,
  "tradespace_cost_vs_reliability_pareto_fuzzy.png",
  width = 8.5,
  height = 5.25,
  dpi = 150
)
print(plt_cost_reliability_pareto)

message("All architecture_metrics figures in: ", normalizePath(OUTPUT_DIR, winslash = "/"))
