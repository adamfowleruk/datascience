# Data Science tools for MarkLogic

This project provides a base line of add-on functionality to MarkLogic Server. Various statistical and data
science algorithms are implemented, with multiple implementations to suit your particular needs.

A REST API invocation mechanism is provided allowing easy invocation. A library invocation mechanism is also
provided for those needing to invoke these algorithms from other libraries already inside MarkLogic Server.

## Motivation

Various customers, partners, prospects, and MarkLogic employees are interested in "Doing more with their data".
This allows them to minimise the tools they use, and to use shared compute power within a MarkLogic Server cluster
in order to process datasets they could not feasibly process on their own machines.

Others need to take snapshots of data, prepare them for statistical analaysis, generate temporary fields, and then
perform matching or other analysis, with the modified dataset being made available to other data scientists for
similar but subtlely different needs. E.g. analysing several different treatment affects within the same data set
using PSM.

## Implementation

Several implementations of each method are provided. This is largely because each user's needs will vary, but also
due to allowing the caller to take advantage of MarkLogic Server features where enabled.

One good example of this is in the use of range indexes. These allow for less than/greater than comparison, but also
for fast lexicon lookups and distributed analysis using MarkLogic User Defined Functions (UDFs). In operational
systems range indexes are usually configured for often used fields.

In a data science context, however, a range index may not be configured for the multitude of derived fields in the
prepared data set. In this scenario a different implementation needs to be provided, with the caller choosing the
appropriate method. This normally isn't an issue in a non operational batch analysis use case, where the extra storage
needs of indexing may not be a good trade off for not often used indexes.

## Implemented functions

Currently the following are available out of the box in MarkLogic Server, and are not part of this project:-


The following are implemented on top of MarkLogic Server by this project:-

- An XQuery mean brute force function
- linear model built in for linear regression over range indexes
- Log-linear regression in JavaScript, XQuery, and as a UDF
- Logistic regression in XQuery and as a UDF
- kNN in XQuery using search scoring to determine euclidean distance (requires range indexes)
- kNN in XQuery using manual euclidean calculation
- kNN in XQuery using manual euclidean calculation, but parallelised to match more ‘treated’ results in parallel on multi core machines
- A Group by UDF that allows Mean and Sum to be calculated but summarised by category

Geospatial analytics functions are currently out of scope for this project, but may be added in future.

If there are any functions you wish were implemented, please add an Issue on GitHub.
