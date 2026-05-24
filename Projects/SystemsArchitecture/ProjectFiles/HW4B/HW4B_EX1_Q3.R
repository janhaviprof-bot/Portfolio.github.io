# ============================================================
# Load required libraries
# ============================================================
library(readr)   # For reading CSV files
library(dplyr)   # For data manipulation

# ============================================================
# Read the architecture enumeration from CSV
# ============================================================
setwd(getwd())   # Ensure working directory is current directory
arch_enum <- read_csv("output_ex1_Q4.csv")   # Read CSV file containing architectures

# View first few rows
head(arch_enum)

# ============================================================
# Notes on architecture encoding
# ============================================================
# d7_1 to d7_6: indicates which partition (1,2,3) each high-level function belongs to
# d4_1 to d4_6: indicates whether a motor is placed at the position (nose=d4_5, tail=d4_6)
# d1 to d8: other design decisions

# ============================================================
# Optionally, randomly select architectures for analysis
# ============================================================
# num_arch = 5
# sample_arch <- arch_enum %>% sample_n(num_arch)
# head(sample_arch)
# print(sample_arch)

# ============================================================
# Manually define 3 specific architectures
# ============================================================
# num_arch = 3
# sample_arch <- data.frame(
#   d1  = c(0, 0, 0),
#   d2  = c(1, 2, 0),
#   d3  = c(1, 1, 0),
#   d4_1= c(0, 1, 0),
#   d4_2= c(0, 1, 0),
#   d4_3= c(0, 0, 1),
#   d4_4= c(1, 0, 0),
#   d4_5= c(0, 0, 0),
#   d4_6= c(1, 0, 0),
#   d5  = c(2, 0, 0),
#   d6  = c(0, 0, 0),
#   d7_1= c(0, 0, 0),
#   d7_2= c(1, 1, 1),
#   d7_3= c(2, 0, 1),
#   d7_4= c(0, 2, 2),
#   d7_5= c(0, 1, 2),
#   d7_6= c(2, 0, 2),
#   d8  = c(0, 0, 1)
# )
num_arch = 1

sample_arch <- data.frame(
  d1  = 0,
  d2  = 1,
  d3  = 0,
  d4_1= 0,
  d4_2= 1,
  d4_3= 0,
  d4_4= 0,
  d4_5= 0,
  d4_6= 0,
  d5  = 0,
  d6  = 0,
  d7_1= 0,
  d7_2= 1,
  d7_3= 1,
  d7_4= 1,
  d7_5= 1,
  d7_6= 0,
  d8  = 1
)
# View manually defined architectures
print(sample_arch)

# ============================================================
# Define metric values for overall system
# ============================================================

# Operating Cost ($/hr) for each design decision
OperatingCost <- matrix(
  c(
    180, 240, 420,    # D1: Propulsion Topology
    180, 170, 360,    # D2: Battery Pack Chemistry
    150, 165, 200,    # D3: Number of Electric Motors
    160, 185, NA,     # D4: Motor-to-Airframe Position
    140, 175, 230,    # D5: FCC Redundancy Level
    160, 210, NA,     # D6: Avionics Integration
    155, 170, NA,     # D7: Subsystem LRU Decomposition
    195, 160, NA      # D8: Ballistic Parachute (CAPS)
  ),
  nrow = 8,
  byrow = TRUE
)

# Propulsion Reliability (%) for each design decision
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
PropulsionReliability <- PropulsionReliability / 100   # Convert % to fraction

# System Durability (yrs)
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

# Certification Schedule (yrs)
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
# Calculate total operating cost for each architecture
# ============================================================
total_cost <- numeric(num_arch)  # Initialize vector to store results

for (i in 1:num_arch) {
  
  # --- D1, D2, D3 costs ---
  cost <- OperatingCost[1, sample_arch$d1[i]+1] +
    OperatingCost[2, sample_arch$d2[i]+1] +
    OperatingCost[3, sample_arch$d3[i]+1]
  
  # --- D4 costs: wings vs nose/tail positions ---
  d4_wing <- c("d4_1","d4_2","d4_3","d4_4")
  d4_nose_tail <- c("d4_5","d4_6")
  
  wing_cost <- sum(as.numeric(sample_arch[i, d4_wing]) * OperatingCost[4, 1])
  nose_tail_cost <- sum(as.numeric(sample_arch[i, d4_nose_tail]) * OperatingCost[4, 2])
  
  cost <- cost + wing_cost + nose_tail_cost
  
  # --- D5, D6 costs ---
  cost <- cost + OperatingCost[5, sample_arch$d5[i]+1] +
    OperatingCost[6, sample_arch$d6[i]+1]
  
  # --- D7 cost based on partitioning ---
  d7_values <- as.numeric(sample_arch[i, paste0("d7_",1:6)])
  d7_val <- ifelse(any(d7_values==2), 1, 0)
  cost <- cost + OperatingCost[7, d7_val+1]
  
  # --- D8 cost ---
  cost <- cost + OperatingCost[8, sample_arch$d8[i]+1]
  
  # Save total cost
  total_cost[i] <- cost
}

total_cost   # Display results

# ============================================================
# Calculate Certification Schedule Metric
# ============================================================
schedule <- numeric(nrow(sample_arch))

for (i in 1:nrow(sample_arch)) {
  
  # --- Sequential chain: D1 → D5 → D6 ---
  seq_time <- CertificationSchedule[1, sample_arch$d1[i] + 1] +
    CertificationSchedule[5, sample_arch$d5[i] + 1] +
    CertificationSchedule[6, sample_arch$d6[i] + 1]
  
  # --- Parallel decisions ---
  d2_time <- CertificationSchedule[2, sample_arch$d2[i] + 1]
  d3_time <- CertificationSchedule[3, sample_arch$d3[i] + 1]
  
  # D4: maximum time among selected motor positions
  d4_cols <- c("d4_1","d4_2","d4_3","d4_4","d4_5","d4_6")
  d4_selected <- as.numeric(sample_arch[i, d4_cols])
  d4_times <- d4_selected * CertificationSchedule[4, 2]
  d4_time <- max(d4_times)
  
  # D7: schedule based on number of partitions
  d7_cols <- c("d7_1","d7_2","d7_3","d7_4","d7_5","d7_6")
  num_partitions <- length(unique(sample_arch[i, d7_cols]))
  if (num_partitions == 2) {
    d7_time <- CertificationSchedule[7, 1]
  } else if (num_partitions == 3) {
    d7_time <- CertificationSchedule[7, 2]
  } else {
    d7_time <- CertificationSchedule[7, 1]
  }
  
  # D8 schedule
  d8_time <- CertificationSchedule[8, sample_arch$d8[i] + 1]
  
  # --- Parallel time ---
  par_time <- max(d2_time, d3_time, d4_time, d7_time, d8_time)
  
  # --- Total schedule ---
  schedule[i] <- max(seq_time, par_time)
}

schedule   # Display results

# ============================================================
# Calculate Propulsion Reliability Metric
# ============================================================
n <- nrow(sample_arch)
propulsion_reliability <- numeric(n)

for (i in 1:n) {
  
  # --- Series reliability: D1 → D3 → D4 ---
  R_D1 <- PropulsionReliability[1, sample_arch$d1[i] + 1]
  R_D3 <- PropulsionReliability[3, sample_arch$d3[i] + 1]
  
  # D4 reliability (wings and nose/tail)
  d4_cols <- c("d4_1","d4_2","d4_3","d4_4","d4_5","d4_6")
  d4_selected <- as.numeric(sample_arch[i, d4_cols])
  wing_pos <- 1:4
  nose_tail_pos <- 5:6
  wing_reliab <- prod(1 - d4_selected[wing_pos] * (1 - PropulsionReliability[4, 1]))
  nose_tail_reliab <- prod(1 - d4_selected[nose_tail_pos] * (1 - PropulsionReliability[4, 2]))
  R_D4 <- 1 - (1 - wing_reliab) * (1 - nose_tail_reliab)
  
  R_series <- R_D1 * R_D3 * R_D4
  
  # --- Parallel reliability: D5, D6, D7 ---
  R_D5 <- PropulsionReliability[5, sample_arch$d5[i] + 1]
  R_D6 <- PropulsionReliability[6, sample_arch$d6[i] + 1]
  
  # D7 reliability based on partitioning
  d7_cols <- c("d7_1","d7_2","d7_3","d7_4","d7_5","d7_6")
  d7_values <- as.numeric(sample_arch[i, d7_cols])
  num_partitions <- length(unique(d7_values))
  if (num_partitions == 2) {
    R_D7 <- PropulsionReliability[7, 1]
  } else if (num_partitions == 3) {
    R_D7 <- PropulsionReliability[7, 2]
  } else {
    R_D7 <- PropulsionReliability[7, 1]
  }
  
  # Parallel reliability formula
  R_parallel <- 1 - (1 - R_D5) * (1 - R_D6) * (1 - R_D7)
  
  # Total propulsion reliability
  propulsion_reliability[i] <- R_series * R_parallel
}

propulsion_reliability   # Display results

# ============================================================
# Calculate System Durability Metric
# ============================================================
DurabilityMetric <- numeric(nrow(sample_arch))

for (i in 1:nrow(sample_arch)) {
  
  # --- Series components: D1, D2, D3, D4 ---
  series_values <- c(
    SystemDurability[1, sample_arch$d1[i] + 1],
    SystemDurability[2, sample_arch$d2[i] + 1],
    SystemDurability[3, sample_arch$d3[i] + 1]
  )
  
  # D4: selected motor positions, take max for redundancy
  d4_cols <- c("d4_1","d4_2","d4_3","d4_4","d4_5","d4_6")
  d4_selected <- as.numeric(sample_arch[i, d4_cols])
  d4_times <- d4_selected * SystemDurability[4, 2]
  d4_time <- max(d4_times)
  series_values <- c(series_values, d4_time)
  
  series_min <- min(series_values)
  
  # --- Parallel components: D5, D6, D7 ---
  parallel_values <- c(
    SystemDurability[5, sample_arch$d5[i] + 1],
    SystemDurability[6, sample_arch$d6[i] + 1]
  )
  
  # D7 durability based on partitioning
  d7_cols <- c("d7_1","d7_2","d7_3","d7_4","d7_5","d7_6")
  num_partitions <- length(unique(sample_arch[i, d7_cols]))
  if (num_partitions == 2) {
    d7_time <- SystemDurability[7, 1]
  } else if (num_partitions == 3) {
    d7_time <- SystemDurability[7, 2]
  } else {
    d7_time <- SystemDurability[7, 1]
  }
  
  parallel_values <- c(parallel_values, d7_time)
  parallel_max <- max(parallel_values)
  
  # --- Total system durability ---
  DurabilityMetric[i] <- min(series_min, parallel_max)
}

DurabilityMetric   # Display results