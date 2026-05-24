#Load Packages
library(dplyr)
library(readr)
library(tidyr)
#library(ArchR)
library(GA)
library(rmoo)

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

#Write down all possible architecture
a = expand_grid(d1 = c(0,1,2), d2 = c(0,1,2), d3 = c(0, 1, 2),
                d4_1 = c(0, 1),d4_2 = c(0, 1),d4_3 = c(0, 1),
                d4_4 = c(0, 1),d4_5 = c(0),d4_6 = c(0, 1),
                d5 = c(0, 1, 2),d6 = c(0, 1),d7_1 = c(0),
                d7_2 = c(0, 1),d7_3 = c(0, 1, 2),d7_4 = c(0, 1, 2),
                d7_5 = c(0, 1, 2),d7_6 = c(0, 1, 2),d8 = c(0, 1)) %>% as.matrix()
#

# a <- read_csv("output_ex1_Q4.csv", skip = 1)

a_sample <- a[sample(nrow(a), 10), ]
# Calculate total length of your bitstring
meta = tibble(
  # List your decisions
  did = c(1,2,3,4.1,4.2,4.3,4.4,4.5,4.6,5,6,7.1,7.2,7.3,7.4,7.5,7.6,8),
  # An example architecture
  ref = c(2,2,2,0,1,1,1,0,1,2,1,0,1,2,0,1,2,1),
  # List the lowest range of integer alternatives
  lower = c(0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
  # List the upper range of integer alternatives
  #upper = c(2,2,2,1,1,1,1,0,1,2,1,0,1,2,2,2,2,1),
  upper = c(2,2,2,1,1,1,1,1,1,2,1,1,1,2,2,2,2,1),
  # Write out total number of alternatives available,
  #n_alts = c(3,3,3,2,2,2,2,1,2,3,2,1,2,3,3,3,3,2),
  n_alts = c(3,3,3,2,2,2,2,2,2,3,2,2,2,3,3,3,3,2),
  # Calculate the total number of bits needed to represent each.
  n_bits = n_alts %>% log2() %>% ceiling()
)
# View it!
total_bits = meta %>% summarize(total = sum(n_bits)) %>% with(total)
xhat=c(2,2,2,0,1,1,1,0,1,2,1,0,1,2,0,1,2,1)

#xhat=c(2,2,2,1,1,1,1,0,1,2,1,0,1,2,2,2,2,1)
int2bit = function(xhat){
  x1 = decimal2binary(x = xhat[1], length = 2)
  x2 = decimal2binary(x = xhat[2], length = 2)
  x3 = decimal2binary(x = xhat[3], length = 2)
  x4_1 = decimal2binary(x = xhat[4], length = 1)
  x4_2 = decimal2binary(x = xhat[5], length = 1)
  x4_3 = decimal2binary(x = xhat[6], length = 1)
  x4_4 = decimal2binary(x = xhat[7], length = 1)
  x4_5 = decimal2binary(x = xhat[8], length = 1)
  x4_6 = decimal2binary(x = xhat[9], length = 1)
  x5 = decimal2binary(x = xhat[10], length = 2)
  x6 = decimal2binary(x = xhat[11], length = 1)
  x7_1 = decimal2binary(x = xhat[12], length = 1)
  x7_2 = decimal2binary(x = xhat[13], length = 1)
  x7_3 = decimal2binary(x = xhat[14], length = 2)
  x7_4 = decimal2binary(x = xhat[15], length = 2)
  x7_5 = decimal2binary(x = xhat[16], length = 2)
  x7_6 = decimal2binary(x = xhat[17], length = 2)
  x8 = decimal2binary(x = xhat[18], length = 1)
  # Bind them together!
  x = c(x1,x2,x3,x4_1,x4_2,x4_3,x4_4,x4_5,x4_6,x5,x6,x7_1,x7_2,x7_3,x7_4,x7_5,x7_6,x8)
  x # View it! (This will be more exciting when we use larger integers.)
}

bit2int = function(x){
  xhat1 = binary2decimal(x = x[1:2]) # convert first integer's set of bits
  xhat2 = binary2decimal(x = x[3:4]) # convert next integer's set of bits
  xhat3 = binary2decimal(x = x[5:6]) # convert next integer's set of bits
  xhat4_1 = binary2decimal(x = x[7])     # d4_1
  xhat4_2 = binary2decimal(x = x[8])     # d4_2
  xhat4_3 = binary2decimal(x = x[9])     # d4_3
  xhat4_4 = binary2decimal(x = x[10])    # d4_4
  xhat4_5 = binary2decimal(x = x[11])                           # fixed (only 0 allowed)
  xhat4_6 = binary2decimal(x = x[12])    # d4_6
  xhat5 = binary2decimal(x = x[13:14])   # d5
  xhat6 = binary2decimal(x = x[15])      # d6
  xhat7_1 = binary2decimal(x = x[16])                           # fixed
  xhat7_2 = binary2decimal(x = x[17])    # d7_2
  xhat7_3 = binary2decimal(x = x[18:19]) # d7_3
  xhat7_4 = binary2decimal(x = x[20:21]) # d7_4
  xhat7_5 = binary2decimal(x = x[22:23]) # d7_5
  xhat7_6 = binary2decimal(x = x[24:25]) # d7_6
  xhat8 = binary2decimal(x = x[26])      # d8
  xhat = c(
    xhat1, xhat2, xhat3,
    xhat4_1, xhat4_2, xhat4_3, xhat4_4, xhat4_5, xhat4_6,
    xhat5, xhat6,
    xhat7_1, xhat7_2, xhat7_3, xhat7_4, xhat7_5, xhat7_6,
    xhat8 ) # bind together
  return(xhat) # View it!
}
cost <- function(xhat, OperatingCost){
  
  cost <- OperatingCost[1, xhat[1]+1] +
    OperatingCost[2, xhat[2]+1] +
    OperatingCost[3, xhat[3]+1]
  
  # D4
  d4 <- xhat[4:9]
  wing_cost <- sum(d4[1:4] * OperatingCost[4,1])
  nose_tail_cost <- sum(d4[5:6] * OperatingCost[4,2])
  
  cost <- cost + wing_cost + nose_tail_cost
  
  # D5, D6
  cost <- cost + OperatingCost[5, xhat[10]+1] +
    OperatingCost[6, xhat[11]+1]
  
  # D7
  d7 <- xhat[12:17]
  d7_val <- ifelse(any(d7 == 2), 1, 0)
  cost <- cost + OperatingCost[7, d7_val+1]
  
  # D8
  cost <- cost + OperatingCost[8, xhat[18]+1]
  
  return(cost)
}
certification <- function(xhat, CertificationSchedule){
  
  seq_time <- CertificationSchedule[1, xhat[1]+1] +
    CertificationSchedule[5, xhat[10]+1] +
    CertificationSchedule[6, xhat[11]+1]
  
  d2_time <- CertificationSchedule[2, xhat[2]+1]
  d3_time <- CertificationSchedule[3, xhat[3]+1]
  
  # D4
  d4 <- xhat[4:9]
  d4_time <- max(d4 * CertificationSchedule[4,2])
  
  # D7
  d7 <- xhat[12:17]
  num_partitions <- length(unique(d7))
  
  d7_time <- ifelse(num_partitions==3,
                    CertificationSchedule[7,2],
                    CertificationSchedule[7,1])
  
  d8_time <- CertificationSchedule[8, xhat[18]+1]
  
  par_time <- max(d2_time, d3_time, d4_time, d7_time, d8_time)
  
  return(max(seq_time, par_time))
}
reliability <- function(xhat, PropulsionReliability){
  
  R_D1 <- PropulsionReliability[1, xhat[1]+1]
  R_D3 <- PropulsionReliability[3, xhat[3]+1]
  
  # D4
  d4 <- xhat[4:9]
  
  wing <- d4[1:4]
  nose <- d4[5:6]
  
  wing_rel <- prod(1 - wing * (1 - PropulsionReliability[4,1]))
  nose_rel <- prod(1 - nose * (1 - PropulsionReliability[4,2]))
  
  R_D4 <- 1 - (1 - wing_rel)*(1 - nose_rel)
  
  R_series <- R_D1 * R_D3 * R_D4
  
  # Parallel
  R_D5 <- PropulsionReliability[5, xhat[10]+1]
  R_D6 <- PropulsionReliability[6, xhat[11]+1]
  
  d7 <- xhat[12:17]
  num_partitions <- length(unique(d7))
  
  R_D7 <- ifelse(num_partitions==3,
                 PropulsionReliability[7,2],
                 PropulsionReliability[7,1])
  
  R_parallel <- 1 - (1 - R_D5)*(1 - R_D6)*(1 - R_D7)
  
  return(R_series * R_parallel)
}
durability <- function(xhat, SystemDurability){
  
  series_vals <- c(
    SystemDurability[1, xhat[1]+1],
    SystemDurability[2, xhat[2]+1],
    SystemDurability[3, xhat[3]+1]
  )
  
  # D4 engine durability in series (worst selected engine dominates)
  d4 <- xhat[4:9]
  d4_durability_map <- c(
    rep(SystemDurability[4,1], 4),  # d4_1..d4_4
    rep(SystemDurability[4,2], 2)   # d4_5..d4_6
  )
  selected_idx <- which(d4 == 1)
  if (length(selected_idx) == 0) {
    d4_time <- 0
  } else {
    d4_time <- min(d4_durability_map[selected_idx])
  }
  
  series_vals <- c(series_vals, d4_time)
  series_min <- min(series_vals)
  
  # Parallel
  parallel_vals <- c(
    SystemDurability[5, xhat[10]+1],
    SystemDurability[6, xhat[11]+1]
  )
  
  d7 <- xhat[12:17]
  num_partitions <- length(unique(d7))
  
  d7_time <- ifelse(num_partitions==3,
                    SystemDurability[7,2],
                    SystemDurability[7,1])
  
  parallel_vals <- c(parallel_vals, d7_time)
  
  return(min(series_min, max(parallel_vals)))
}

evaluate=function(xhat){
  m1=cost(xhat, OperatingCost)
  m2 = certification(xhat, CertificationSchedule)
  m3 = reliability(xhat, PropulsionReliability)
  m4 = durability(xhat, SystemDurability)
  # Bundle metrics
  metrics = c(-m1,-m2,m3,m4)
  m = matrix(data = metrics, ncol = length(metrics))
  return(m)
  
}
#function to resample between d4 based on d1 and d3
repair_d4 <- function(d1, d3, d4_1, d4_2, d4_3, d4_4, d4_5, d4_6) {
  
  repeat {
    
    # --------------------------------------------------------
    # STEP 1: Apply D1 → D4 constraints
    # --------------------------------------------------------
    
    if (d1 == 0 || d1 == 1) {
      d4_5 <- 0
    }
    
    if (d1 == 2) {
      d4_5 <- 0
      d4_6 <- 0
    }
    
    
    # --------------------------------------------------------
    # STEP 2: Required motor count
    # --------------------------------------------------------
    
    required_count <- c(1, 2, 4)[d3 + 1]
    
    
    # --------------------------------------------------------
    # STEP 3: Valid positions
    # --------------------------------------------------------
    
    valid_positions <- 1:6
    
    if (d1 == 0 || d1 == 1) {
      valid_positions <- setdiff(valid_positions, 5)
    }
    
    if (d1 == 2) {
      valid_positions <- setdiff(valid_positions, c(5, 6))
    }
    
    
    # --------------------------------------------------------
    # STEP 4: Reset and resample
    # --------------------------------------------------------
    
    d4_1 <- d4_2 <- d4_3 <- d4_4 <- d4_5 <- d4_6 <- 0
    
    chosen <- sample(valid_positions, size = required_count)
    
    if (1 %in% chosen) d4_1 <- 1
    if (2 %in% chosen) d4_2 <- 1
    if (3 %in% chosen) d4_3 <- 1
    if (4 %in% chosen) d4_4 <- 1
    if (5 %in% chosen) d4_5 <- 1
    if (6 %in% chosen) d4_6 <- 1
    
    
    # --------------------------------------------------------
    # STEP 5: Check
    # --------------------------------------------------------
    
    if ((d4_1 + d4_2 + d4_3 + d4_4 + d4_5 + d4_6) == required_count) {
      return(c(d4_1, d4_2, d4_3, d4_4, d4_5, d4_6))
    }
  }
}
repair_d7 <- function(d5, d7) {
  
  # --------------------------------------------------------
  # STEP 1: enforce symmetry rule
  # --------------------------------------------------------
  d7[1] <- 0
  
  
  # --------------------------------------------------------
  # STEP 2: if D5 requires k = 3
  # --------------------------------------------------------
  
  if (d5 %in% c(1,2)) {
    
    # force valid labels only
    d7 <- pmin(pmax(d7, 0), 2)
    
    # ensure all groups exist at least once
    groups <- unique(d7)
    
    missing <- setdiff(c(0,1,2), groups)
    
    if (length(missing) > 0) {
      
      # randomly replace some entries to introduce missing groups
      idx <- sample(2:6, length(missing))  # avoid d7_1
      
      d7[idx] <- missing
    }
  }
  
  
  # --------------------------------------------------------
  # STEP 3: repair to ensure valid partition (no empty issues)
  # --------------------------------------------------------
  
  for (g in 0:2) {
    if (!(g %in% d7)) {
      d7[sample(2:6, 1)] <- g
    }
  }
  
  
  return(d7)
}

repair_bits = function(x){
  xhat = bit2int(x)
  # Get decisions
  d1 = xhat[1]
  d2 = xhat[2]
  d3 = xhat[3]
  d4_1 = xhat[4]
  d4_2 = xhat[5]
  d4_3 = xhat[6]
  d4_4 = xhat[7]
  d4_5 = xhat[8]
  d4_6 = xhat[9]
  d5 = xhat[10]
  d6 = xhat[11]
  d7_1 = xhat[12]
  d7_2 = xhat[13]
  d7_3 = xhat[14]
  d7_4 = xhat[15]
  d7_5 = xhat[16]
  d7_6 = xhat[17]
  d8 = xhat[18]
  if(d1==3){d1<- sample(x=c(0,1,2), size=1)}#d1
  if(d2==3){d2<- sample(x=c(0,1,2), size=1)}#d2
  if(d3==3){d3<- sample(x=c(0,1,2), size=1)}#d3
  if(d4_5 ==1){d4_5 <- sample(x=c(0), size=1)} #d4_5
  if(d5 ==3){d5 <- sample(x=c(0,1,2), size=1)}#d5
  if(d7_1==1){d7_1<- sample(x=c(0), size=1)}#d7_1
  if(d7_3 ==3){d7_3<- sample(x=c(0,1,2), size=1)}#d7_3
  if(d7_4==3){d7_4<- sample(x=c(0,1,2), size=1)}#d7_4
  if(d7_5==3){d7_5<- sample(x=c(0,1,2), size=1)}#d7_5
  if(d7_6==3){d7_6<- sample(x=c(0,1,2), size=1)}#d7_6
  
  #structural constraint
  #constraint : d4_5 will always have value 0 so no additional constraint required
  #Constraint : if its electric hybrid then it cannot be at tail
  if(d1==2 & d4_6==1){d4 <- repair_d4(d1, d3, d4_1, d4_2, d4_3, d4_4, d4_5, d4_6)
  d4_1 <- d4[1]
  d4_2 <- d4[2]
  d4_3 <- d4[3]
  d4_4 <- d4[4]
  d4_5 <- d4[5]
  d4_6 <- d4[6]}
  #Constraint : Number of motors assigned should be equal to number of positions
  if ((d4_1 + d4_2 + d4_3 + d4_4 + d4_5 + d4_6) != c(1,2,4)[d3 + 1]) {
    d4 <- repair_d4(d1, d3, d4_1, d4_2, d4_3, d4_4, d4_5, d4_6)
    d4_1 <- d4[1]
    d4_2 <- d4[2]
    d4_3 <- d4[3]
    d4_4 <- d4[4]
    d4_5 <- d4[5]
    d4_6 <- d4[6]
  }
  #Constraint : when FCC redundancy is double or triple then only k=3 partition allowed
  if((d5 %in% c(1,2)) &
    (
      d7_1 != 0 |
        !(0 %in% c(d7_1,d7_2,d7_3,d7_4,d7_5,d7_6)) |
        !(1 %in% c(d7_1,d7_2,d7_3,d7_4,d7_5,d7_6)) |
        !(2 %in% c(d7_1,d7_2,d7_3,d7_4,d7_5,d7_6))
    )){d7 <- repair_d7(d5, c(d7_1,d7_2,d7_3,d7_4,d7_5,d7_6))
    
    d7_1 <- d7[1]
    d7_2 <- d7[2]
    d7_3 <- d7[3]
    d7_4 <- d7[4]
    d7_5 <- d7[5]
    d7_6 <- d7[6]}
  xhat = c(d1,d2,d3,d4_1,d4_2,d4_3,d4_4,d4_5,d4_6,d5,d6,d7_1,d7_2,d7_3,d7_4,d7_5,d7_6,d8)
  output = int2bit(xhat)
  return(output)
}

constrain= function(x){
  xhat = bit2int(x)
  # Get decisions
  d1 = xhat[1]
  d2 = xhat[2]
  d3 = xhat[3]
  d4_1 = xhat[4]
  d4_2 = xhat[5]
  d4_3 = xhat[6]
  d4_4 = xhat[7]
  d4_5 = xhat[8]
  d4_6 = xhat[9]
  d5 = xhat[10]
  d6 = xhat[11]
  d7_1 = xhat[12]
  d7_2 = xhat[13]
  d7_3 = xhat[14]
  d7_4 = xhat[15]
  d7_5 = xhat[16]
  d7_6 = xhat[17]
  d8 = xhat[18]
  constraint1 = d1==3
  constraint2 = d2==3
  constraint3 = d3==3
  constraint4 = d4_5==1
  constraint5 = d5==3
  constraint6 = d7_1==1
  constraint7 = d7_3==3
  constraint8 = d7_4==3
  constraint9 = d7_5==3
  constraint10 = d7_6==3
  
  
  #structural constraint
  #constraint : d4_5 will always have value 0 so no additional constraint required
  #Constraint : if its electric hybrid then it cannot be at tail
  constraint11 = (d1==2 & d4_6==1)
  #Constraint : Number of motors assigned should be equal to number of positions
  constraint12 = ((d4_1 + d4_2 + d4_3 + d4_4 + d4_5 + d4_6) != c(1,2,4)[d3 + 1])
  #Constraint : when FCC redundancy is double or triple then only k=3 partition allowed
  constraint13 = ((d5 %in% c(1,2)) &
    (
      d7_1 != 0 |
        !(0 %in% c(d7_1,d7_2,d7_3,d7_4,d7_5,d7_6)) |
        !(1 %in% c(d7_1,d7_2,d7_3,d7_4,d7_5,d7_6)) |
        !(2 %in% c(d7_1,d7_2,d7_3,d7_4,d7_5,d7_6))
    ))
  flag = any(
    c(
      constraint1, constraint2, constraint3, constraint4, constraint5,
      constraint6, constraint7, constraint8, constraint9, constraint10,
      constraint11, constraint12, constraint13
    ),
    na.rm = TRUE
  )
  return(flag)
}

# f1 = function(x, nobj = 4, ...){
#   #Modify architecture which is not valid
#   x= repair_bits(x)
#   # First, let's convert from binary to our integer-formatted architecture
#   xhat = bit2int(x)
#   # Seconds, let's find metrics 
#   metrics = evaluate(xhat)

#   return(metrics)
# }
f2 = function(x, nobj = 4, ...){
  # First, let's convert from binary to our integer-formatted architecture
  xhat = bit2int(x)
  # Second, let's check if constraints are violated.
  violated = isTRUE(constrain(x))
  # Third, if constraints are violated, 
  # then this architecture's metrics should not be considered.
  if(violated){
    # Return strong finite penalty to keep GA internals stable.
    metrics = matrix(data = c(-1e9, -1e9, -1e9, -1e9), nrow = 1)
  }else{
    # If constraints are NOT violated, compute the metrics.
    metrics = evaluate(xhat)
  }
  # Fourth, let's return metrics
  return(metrics)
}


custom_mutate = function(object, parent){
  nbits <- 26
  
  # rmoo passes mutation(object, i), where `parent` is usually row index i.
  # Fetch chromosome explicitly from population, then mutate.
  parent_idx <- as.integer(as.vector(parent))[1]
  
  pop <- NULL
  if (is.list(object) && !is.null(object$population)) {
    pop <- object$population
  } else if (isS4(object) && "population" %in% slotNames(object)) {
    pop <- slot(object, "population")
  }
  
  if (is.null(pop) || !is.matrix(pop) || is.na(parent_idx) ||
      parent_idx < 1 || parent_idx > nrow(pop)) {
    stop("custom_mutate could not resolve parent chromosome from index.")
  }
  
  mutation <- as.numeric(pop[parent_idx, ])
  if (length(mutation) != nbits) {
    stop(paste0("custom_mutate expected ", nbits, " bits, got ", length(mutation)))
  }
  
  # Flip one random bit.
  idx <- sample.int(nbits, 1)
  mutation[idx] <- 1 - mutation[idx]
  
  # Repair and hard-enforce output shape expected by rmoo/GA.
  mutation <- as.numeric(repair_bits(mutation))
  # Keep mutation contract strict for GA internals: exactly nbits.
  if (length(mutation) < nbits) {
    mutation <- c(mutation, rep(0, nbits - length(mutation)))
  } else if (length(mutation) > nbits) {
    mutation <- mutation[1:nbits]
  }
  mutation <- as.numeric(mutation)
  
  return(mutation)
}

#Run GA
# Calculate the total number of bits in your bitstring
#adding 2 bits since bit size is 0 at 4.5 and 7.1

total_bits = meta %>% summarize(total = sum(n_bits)) %>% with(total)
ref = generate_reference_points(m = 4, h = 10)
# Take a peek!
head(ref)

# Full binary search
o = rmoo(
  fitness = f2, type = "binary", algorithm = "NSGA-III",
  # Upper and Lower bounds on the bitstrings
  lower = rep(0, 26),
  upper = rep(1, 26),
  # Settings
  monitor = TRUE, summary = TRUE,
  nObj = 4, nBits = total_bits, popSize = 200, maxiter = 200,
  # Extras
  reference_dirs = ref, mutation = custom_mutate)

#population
cat("\n===== Population =====\n")
o@population
#Solution
cat("\n===== Solution =====\n")
o@solution
cat("\n===== Decoded Solution (bit2int) =====\n")
bit2int(o@solution)
#Summary
cat("\n===== Summary =====\n")
summary(o)

# Save final outputs to separate files
write.csv(as.data.frame(o@population), file = "final_population.csv", row.names = FALSE)
write.csv(as.data.frame(o@solution), file = "final_solution.csv", row.names = FALSE)
cat("\nSaved files: final_population.csv, final_solution.csv\n")

build_arch_metrics_table <- function(bit_matrix) {
  bit_matrix <- as.matrix(bit_matrix)
  n <- nrow(bit_matrix)
  
  arch_matrix <- matrix(NA_real_, nrow = n, ncol = 18)
  metric_matrix <- matrix(NA_real_, nrow = n, ncol = 4)
  
  for (i in seq_len(n)) {
    bits_i <- as.numeric(bit_matrix[i, ])
    xhat_i <- bit2int(bits_i)
    metrics_i <- as.numeric(evaluate(xhat_i))
    arch_matrix[i, ] <- xhat_i
    metric_matrix[i, ] <- metrics_i
  }
  
  arch_df <- as.data.frame(arch_matrix)
  names(arch_df) <- paste0("d", 1:18)
  
  metric_df <- as.data.frame(metric_matrix)
  names(metric_df) <- c("cost", "certification", "reliability", "durability")
  # evaluate() uses negative signs for optimization direction; flip back for reporting.
  metric_df$cost <- -metric_df$cost
  metric_df$certification <- -metric_df$certification
  metric_df$reliability <- metric_df$reliability * 100
  
  cbind(arch_df, metric_df)
}

# Build architecture + metrics tables for population and solution
population_table <- build_arch_metrics_table(o@population)
solution_table <- build_arch_metrics_table(o@solution)

write.csv(population_table, file = "final_population_arch_metrics.csv", row.names = FALSE)
write.csv(solution_table, file = "final_solution_arch_metrics.csv", row.names = FALSE)

cat("\nSaved files: final_population_arch_metrics.csv, final_solution_arch_metrics.csv\n")



