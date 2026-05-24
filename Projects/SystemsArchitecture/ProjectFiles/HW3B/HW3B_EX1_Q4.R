getwd()

# Load required packages
library(dplyr)      # For filter, mutate, select
library(tidyr)      # For expand_grid
library(readr)      # For write_csv
library(archr)      # For enumerate functions

# ============================================================
# SECTION 1: ENUMERATE EACH DECISION INDIVIDUALLY
# ============================================================
# ------------------------------------------------------------
# D1 - Propulsion Topology (Standard Form)
# ------------------------------------------------------------
d1 = enumerate_sf(n = c(3), .did = 1)

# ------------------------------------------------------------
# D2 - Battery Pack Chemistry (Standard Form)
# ------------------------------------------------------------
d2 = enumerate_sf(n = c(3), .did = 2)

# ------------------------------------------------------------
# D3 - Number of Electric Motors (Standard Form)
# ------------------------------------------------------------
d3 = enumerate_sf(n = c(3), .did = 3)

# ------------------------------------------------------------
# D4 - Motor-to-Airframe Position (Down-selecting)

# 6 candidate positions (binary — selected=1 or not=0):
# ADG constraints from D1 and D3 applied during combination
# ------------------------------------------------------------
d4 = enumerate_ds(n = 6, k = 6, .did = 4) %>%
  # Add count column — total positions selected
  # Used to enforce D3 motor count constraint
  mutate(count = d4_1 + d4_2 + d4_3 + d4_4 + d4_5 + d4_6)

# ------------------------------------------------------------
# D5 - FCC Redundancy Level (Standard Form)
# ------------------------------------------------------------
d5 = enumerate_sf(n = c(3), .did = 5)

# ------------------------------------------------------------
# D6 - Avionics Integration (Standard Form)
# ------------------------------------------------------------
d6 = enumerate_sf(n = c(2), .did = 6)

# ------------------------------------------------------------
# D7 - Subsystem LRU Decomposition (Partitioning)
# 6 functional blocks to partition into LRU packages:
# ADG NOTE: D5 constrains valid k:
# ------------------------------------------------------------
# Enumerate k=2 partitions
# min_times=c(1,1): each group must have at least 1 block
# max_times=c(5,5): each group can have at most 5 blocks
d7_k2 = enumerate_partition(n = 6, k = 2, .did = 7,
                            min_times = c(1, 1),
                            max_times = c(5, 5)) %>%
  mutate(k_val = 2) %>%
  # This removes all duplicates
  filter(d7_1 == 0)

# Enumerate k=3 partitions
# min_times=c(1,1,1): each group must have at least 1 block
# max_times=c(4,4,4): each group can have at most 4 blocks
d7_k3 = enumerate_partition(n = 6, k = 3, .did = 7,
                            min_times = c(1, 1, 1),
                            max_times = c(4, 4, 4)) %>%
  mutate(k_val = 3) %>% 
  # This removes all duplicates
  filter(d7_1 == 0) %>%
  filter(d7_2 != 2) %>%
  filter(!(d7_2 == 0 & d7_3 == 2)) %>%
  filter(!(d7_2 == 0 & d7_3 == 0 & d7_4 == 2)) %>%
  filter(!(d7_2 == 0 & d7_3 == 0 & d7_4 == 0 & d7_5 == 2)) %>%
  filter(!(d7_2 == 0 & d7_3 == 0 & d7_4 == 0 & d7_5 == 0 & d7_6 == 2))

# Combine k=2 and k=3 partitions
d7 = bind_rows(d7_k2, d7_k3)
cat("D7 total before D5 constraint:", nrow(d7), "\n") # Expected 121

# ------------------------------------------------------------
# D8 - CAPS Installation (Standard Form)
# ------------------------------------------------------------
d8 = enumerate_sf(n = c(2), .did = 8)

# ============================================================
# SECTION 2: COMBINE DECISIONS AND APPLY ADG CONSTRAINTS
# ============================================================
# Order of operations matches 
#   D1 → D4 (position availability)
#   D3 → D4 (motor count)
#   D5 → D7 (LRU group count)
#Resulting columns : d1 d2 d3 d4_1 d4_2 d4_3 d4_4 d4_5 d4_6 d5 d6 d7_1 d7_2 d7_3 d7_4 d7_5 d7_6 d8
# ============================================================

arch = expand_grid(d1, d2, d3) %>%
  
  # --------------------------------------------------------
# Add D4 — apply D1→D4 and D3→D4 ADG constraints
# --------------------------------------------------------
expand_grid(., d4) %>%
  
  filter(
    # --- ADG CONSTRAINT: D1 → D4 ---
    # Series hybrid (d1=0):
    # Nose position unavailable — ICE/generator
    # physically occupies the nose structural bay
    !(d1 == 0 & d4_5 == 1),
    
    # Parallel hybrid (d1=1):
    # Nose position unavailable — mechanical gearbox
    # shaft exits at nose station
    !(d1 == 1 & d4_5 == 1),
    
    # Turboelectric (d1=2):
    # Nose unavailable — turbine intake at nose
    # Tail unavailable — turbine exhaust at tail
    !(d1 == 2 & d4_5 == 1),
    !(d1 == 2 & d4_6 == 1),
    
    # --- ADG CONSTRAINT: D3 → D4 ---
    # D3 determines exact number of motors to place
    # D3=0 (1 motor): exactly 1 position selected
    !(d3 == 0 & count != 1),
    
    # D3=1 (2 motors): exactly 2 positions selected
    !(d3 == 1 & count != 2),
    
    # D3=2 (4 motors): exactly 4 positions selected
    !(d3 == 2 & count != 4)
  ) %>%
  
  # Remove helper count column — no longer needed
  select(-count) %>%
  
  # --------------------------------------------------------
# Add D5 &D6— no constraints applied yet
# D5→D7 constraint applied when D7 is added below
# --------------------------------------------------------
expand_grid(., d5) %>%
  expand_grid(., d6) %>%
  
  # --------------------------------------------------------
# Add D7 — apply D5→D7 ADG constraint
# --------------------------------------------------------
expand_grid(., d7) %>%
  
  filter(
    # --- ADG CONSTRAINT: D5 → D7 ---
    # D5=Simplex(0): both k=2 and k=3 valid
    # No filtering needed for Simplex
    
    # D5=Dual(1): only k=3 valid
    # 2 FCCs must be in separate LRU packages
    # k=2 cannot accommodate FCC separation requirement
    !(d5 == 1 & k_val == 2),
    
    # D5=Triple(2): only k=3 valid
    # 3 FCCs must each be in separate LRU packages
    # k=2 cannot accommodate 3 separate FCC packages
    !(d5 == 2 & k_val == 2)
  ) %>%
  
  # Remove helper k_val column — no longer needed
  select(-k_val) %>%
  
  # Add D8 — independent, no ADG constraints
  expand_grid(., d8)


# ============================================================
# SECTION 3: OUTPUT AND VERIFICATION
# ============================================================

# Print total — should match manual calculation of 184,212
cat("Total number of valid architectures:", nrow(arch), "\n")

# View first few architectures
head(arch)

# Save to CSV file
write_csv(arch, "output_ex1_Q4.csv")

# Cleanup
rm(list = ls())

