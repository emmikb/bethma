require(dplyr)
require(gdata)
require(ggplot2)
require(lme4)
require(rjags)
require(ggmcmc)
require(string)
require(BEST)
require(foreign)
require(arm)
require(shinystan)

#add cauchy prior
#probably drop ui
#include other relevant variables, build full model 
#p. 375 GELMAN

#what characterizes a farmer who practiced bethma within a community 
#how bethma farmers compare to those not engaging in bethma within communities (so how does ADP1_C1-which would need to be made into a binary factor-predict yield). 
#Finally, we need to figure out why, among the communities where bethma was practiced in 2014 (7, 8, 13, 20), there is variation in the number of farmers who engaged in bethma. 

#data setup
y <- c1$ADP1_B1
#yes = 1; no = 2
y <-ifelse(y==1, 1, 0)
vname <- "Have you ever practiced bethma?"
it <- c("Minor", "Major")
n <- length(y)
dc.names <- as.vector(c1$HI4)
uq <- unique(dc.names)
n.dc <- length(uq)
dc <- rep(NA, n.dc)
for (i in 1:n.dc){
  dc[dc.names == uq[i]] <- i
  sample.size <- as.vector(table(dc))
}


model_string <- "model{
#level-1 likelihood
for (i in 1:n){
y[i] ~ dbin(mu[i], 1) 
p.bound[i] <- max(0, min(1, mu[i])) #381 gelman
logit(mu[i]) <- a[dc[i]] + b1[dc[i]]*x1[i] + b2[dc[i]]*x2[i] + b3[dc[i]]*x3[i] + b4[dc[i]]*x4[i] +
b5[dc[i]]*x5[i] + b6[dc[i]]*x6[i] + b7[dc[i]]*x7[i] + b8[dc[i]]*x8[i]
}

#if any additional priors in likelihood of y[i], specify here

#level-2 likelihood
for (j in 1: n.dc ){
a[j] ~ dt(g0, tau.a,1) #not goj, g1j
b1[j] ~ dt(b01, .001) #could do prior for spread
b2[j] ~ dt(b02, .001, 1)  #instead of fixing variance, could make tau.b, etc... to allow for correlatoin
b3[j] ~ dt(b03, .001, 1) #build all of these as hyperpriors
b4[j] ~ dt(b04, .001, 1)
b5[j] ~ dt(b05, .001, 1)
b6[j] ~ dt(b06, .001, 1)
b7[j] ~ dt(b07, .001, 1)
b8[j] ~ dt(b08, .001, 1)

}
#level-3 hyperlevel (SL)
g0 ~ dt(0, .001, 1)
b01 ~ dt(0, .001, 1)
b02 ~ dt(0, .001, 1)
b03 ~ dt(0, .001, 1)
b04 ~ dt(0,.001, 1)
b05 ~ dt(0, .001, 1)
b06 ~ dt(0, .001, 1)
b07 ~ dt(0, .001, 1)
b08 ~ dt(0, .001, 1)
tau.a <- pow(sigma.a , -2)
sigma.a ~ dunif(0, 100)  
}"

#initialize variables
inits <- function(chain) {
  list (a=rnorm(n.dc), b01 = rnorm(1), b02 = rnorm(1),
        b03 = rnorm(1), b04 = rnorm(1), b05 = rnorm(1),
        b06 = rnorm(1), b07 = rnorm(1), b08 = rnorm(1),
        g0 = rnorm(1), sigma.a = runif(1)) }

#create dataframe
data <- list(n = n, n.dc = n.dc, y = y, dc = dc, 
             x1 = c1$agrowell_user, x2 = c1$major_flag,
             x3 = c1$female, x4 = c1$sinhalese,
             x5 = c1$Standardized_SES, x6 = c1$owner, 
             x7 = c1$head_end, x8 = c1$fo)

#tell JAGS parameters to report back
parameters <- c("a", "b1", "b2", "b3", "b4", "b5", "b6", "b7", "b8", "b01", "b02", "b03", "b04", "b05", "b06", "b07", "b08", "g0", "sigma.a")

#compile jags model
model <- jags.model(textConnection(model_string),
                              data = data, 
                              inits = inits,
                              n.chains = 3,
                              n.adapt = 1000)

#take 2000 random samples of each of the 3 chains
update(model, n.iter = 5000)
model_outcome_2 <- coda.samples(model, variable.names = parameters, n.iter = 5000)
my_sso_2 <- as.shinystan(model_outcome_2)
my_sso_2 <- launch_shinystan(my_sso)


#diagnosing mixing of chains, we want good overlap of chains
samples <- ggs(model_outcome, family = '(sigma|b).*')
ggs_traceplot(samples) + theme_bw() + theme(legend.position='none', strip.background = element_blank())

#diagnosing aucotorrelation
auto.plot <- ggs_autocorrelation(samples, family = "sigma.a") +
  theme_bw() + theme(legend.position = 'none', strip.background = element_blank())
auto.plot

#if we see autocorrelation, we can thin the MC by telling it to remember only every fourth iteration
# thin.steps = 4
# model_outcome_ac <- coda.samples(model_outcome, variable.names = parameters,
#                                 n.iter = 2000, thin = thin.steps)
# auto.plot.thinned <- ggs_autocorrelation(ggs(model_outcome_ac), family = 'sigma.a') +
#   theme_bw() + 
#   theme(legend.position='none', strip.background = element_blank())
# print(auto.plot)
# print(auto.plot.thinned)

#gelman-rubin scale reduction factor (how much better would predictions be with infinite number of iterations)
gelman.diag(model_outcome)


traceplot(model_outcome)

