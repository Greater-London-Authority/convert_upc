# given a set of prior values for gross flows of the same direction by type (base_international and base_domestic),
# and a target total gross flow, return the maximum likelihood combination of gross flows that satisfy the target
# flow probabilities are modelled as Poisson distributions, with lambda values set as the base flows

# the jump_scale parameter affects the maximum size of the adjustment steps as the algorithm tries to converge
# on an optimum solution. lower values of jump_scale may be faster, but potentially less reliable.
# Always use a value greater than 1

# the relative_international_confidence parameter determines how adjustments are prioritised between international and domestic
# a value of 1 represents equal confidence in the base values for each and the output flows will have the same proportional
# distribution as the inputs.
# For values < 1, adjustments to international flows will be prioritised. For values >1 adjustments to domestic flows will be prioritised

#TODO add warning to flag when input base flows are 0

split_gross_flows <- function(base_international, base_domestic, target_total,
                              relative_international_confidence = 1,
                              jump_scale = 10) {

  # as flows are modelled as Poisson distributions, values must be integers for the main part of the modelling process
  base_international <- abs(base_international)
  base_domestic <- abs(base_domestic)
  base_total <- round(base_international + base_domestic, 0)
  change_net = target_total - base_total

  max_iterations <- ceiling(2 * abs(change_net))

  new_international <- round(base_international, 0)
  new_domestic <- round(base_domestic, 0)

  #starting from the base flows, make adjustments to the gross flows until target net flow is reached
  j <- 1
  while((abs(target_total - (new_international + new_domestic)) > 0.5) & (j <= max_iterations)){

    #total adjustment remaining to reach target net flow
    distance_from_target <- target_total - (new_international + new_domestic)
    direction_to_target <- distance_from_target/abs(distance_from_target)

    #adjustment to be made in this loop
    int_adjust <- direction_to_target * ceiling(abs(distance_from_target/jump_scale))

    #test whether making adjustment to inflow or outflow has bigger impact on combined likelihood
    #make adjustment to flow that gives smallest decrease
    p_international_adjust <- relative_international_confidence * dpois(new_international + int_adjust, base_international, log = TRUE) + dpois(new_domestic, base_domestic, log = TRUE)
    p_domestic_adjust <- relative_international_confidence * dpois(new_international, base_international, log = TRUE) + dpois(new_domestic + int_adjust, base_domestic, log = TRUE)

    if(p_international_adjust > p_domestic_adjust) {
      new_international <- new_international + int_adjust
    } else {
      new_domestic <- new_domestic + int_adjust
    }

    j <- j + 1
  }

  #TODO I've pretty much just done and find and replace of the original here for the sake of testing - need to revisit

  #allocate any remaining (probably fractional) difference from target net to individual flows
  #in a way that avoids possibility of negative gross glows
  remainder = target_total - (new_international + new_domestic)

  if(new_international >= new_domestic){
    new_international <- new_international + remainder
  } else {
    new_domestic = new_domestic + remainder
  }

  c_out <- list(c("new_international" = new_international, "new_domestic" = new_domestic))

  return(c_out)
}

#function is not naturally vectorised
split_gross_flows = Vectorize(split_gross_flows, SIMPLIFY = TRUE)
