% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/parameters.R
\name{expand_parameters}
\alias{expand_parameters}
\title{expand existing parameter set}
\usage{
expand_parameters(ip, ...)
}
\arguments{
\item{...}{named vectors or expressions to expand existing parameter sets}
}
\description{
this expands each existing parameter set with a combinatoric
expansion of the provided parameters. provided parameters can
be numeric vectors or expressions that can reference existing parameters
}
\seealso{
Other parameters: 
\code{\link{mutate_parameters}()},
\code{\link{set_parameters}()}
}
\concept{parameters}
