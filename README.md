# geo-arrow-spec

Specifications for storing geospatial data in Apache Arrow and Apache Parquet.

The [Apache Arrow](https://arrow.apache.org/) project specifies a standardized
language-independent columnar memory format. It enables shared computational
libraries, zero-copy shared memory and streaming messaging, interprocess
communication, etc and is supported by many programming languages. The Feather
file format is an on-disk representation of this memory format.

[Apache Parquet](https://parquet.apache.org/) is an efficient, columnar storage
format (originating from the Hadoop ecosystem). It is a widely used file format
for tabular data, and its implementation for C-based languages (Python, R) is
included in the Apache Arrow project.

Geospatial data often comes in tabular format, with one (or multiple) column
with feature geometries and additional columns with feature attributes. 

Defining a standard way to store geospatial data in the Arrow memory layout
can help interoperability between different tools and enable fast data
transfer:

- Ensure that different tools can read Parquet or Feather files with geospatial
  data and correctly interpret the geometry information. Concrete example: we
  want that the R `sf` package can read a parquet file produced by the Python
  `geopandas` package and vice versa.
- A standard in-memory specification for geometry data using the Arrow memory
  layout. This ensures geospatial data can be used in a growing number of
  applications that use the Arrow standard for in-memory data sharing or fast
  data transfer.

The goal of this repository is to discuss and move towards specifications
on metadata and memory layout for storing geospatial data in the Arrow memory
layout or related formats (Feather, Parquet).
