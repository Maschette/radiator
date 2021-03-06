% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/read_rad.R
\name{write_rad}
\alias{write_rad}
\title{Write tidy genomic data file or close GDS file}
\usage{
write_rad(data, path)
}
\arguments{
\item{data}{An object in the global environment: tidy data frame or GDS connection file}

\item{path}{(optional) For tidy data frame, the path to write the data on disk.}
}
\value{
A file written in the working directory or nothing if it's a GDS connection file.
}
\description{
When dataset is a tidy data frame, the function provides a
fast way to write a radiator \code{.rad} file.
The function uses \code{\link[fst]{write_fst}} with a compression level of 85,
that work well with RADseq dataset.
When the object is a CoreArray Genomic Data Structure
(\href{https://github.com/zhengxwen/gdsfmt}{GDS}) file system, the function
set filters (variants and samples) based on the info found in the file and
close the connection with the GDS file.


Used internally in \href{https://github.com/thierrygosselin/radiator}{radiator}
and \href{https://github.com/thierrygosselin/assigner}{assigner}
and might be of interest for users.
}
\examples{
\dontrun{
require(SeqArray)
radiator::write_rad(data = tidy.data, path = "data.shark.rad")
radiator::write_rad(data = gds.object)
}
}
\seealso{
\href{https://github.com/fstpackage/fst}{fst} and \href{https://github.com/zhengxwen/gdsfmt}{GDS}
}
\author{
Thierry Gosselin \email{thierrygosselin@icloud.com}
}
