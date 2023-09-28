
# GeoArrow Specification

This repository contains a specification for storing geospatial data in Apache Arrow
and Arrow-compatible data structures and formats.

The [Apache Arrow](https://arrow.apache.org/) project specifies a standardized
language-independent columnar memory format. It enables shared computational libraries,
zero-copy shared memory and streaming messaging, interprocess communication, and is
supported by many programming languages and data libraries.

Spatial information can be represented as a collection of discrete objects using points,
lines and polygons (i.e., vector data). The
[Simple Feature Access](https://www.ogc.org/standards/sfa) standard provides a widely
used abstraction, defining a set of geometries: Point, LineString, Polygon, MultiPoint,
MultiLineString, MultiPolygon, and GeometryCollection. Next to a geometry, simple features
can also have non-spatial attributes that describe the feature.

Geospatial data often comes in tabular format, with one or more columns with
feature geometries and additional columns with feature attributes. The Arrow columnar
memory model is well-suited to store both vector features and
their attribute data. The GeoArrow specification defines how the vector features
(geometries) can be stored in Arrow (and Arrow-compatible) data structures.

This repository contains the specifications for:

- The memory layout for storing geometries in an Arrow array ([format.md](./format.md))
- The Arrow extension type definitions that ensure type-level metadata (e.g., CRS) is
  propagated when used in Arrow implementations ([extension-types.md](./extension-types.md))

Defining a standard and efficient way to store geospatial data in the Arrow memory
layout enables interoperability between different tools and ensures geospatial tools can
leverage the growing Apache Arrow ecosystem:

- Efficient, columnar file formats. Leveraging the performant and compact storage of
  Apache Parquet as a vector data format in geospatial tools using
  [GeoParquet](https://github.com/opengeospatial/geoparquet/)
- Accelerated between-process geospatial data exchange using Apache Arrow IPC message
  format and Apache Arrow Flight
- Zero-copy in-process geospatial data transport using the Apache Arrow C Data Interface
  (e.g., GDAL)
- Shared libraries for geospatial data type representation and computation for query
  engines that support columnar data formats (e.g., Velox, DuckDB, and Acero)

### Relationship with GeoParquet

The GeoParquet specification originally started in this repo, but was moved out into its
own repo (https://github.com/opengeospatial/geoparquet), leaving this repo to focus on
the Arrow-specific specifications (Arrow layout and extension type metadata). Whereas
GeoParquet is a file-level metadata specification, GeoArrow is a field-level metadata
and memory layout specification that applies to in-memory (e.g., an Arrow array), on disk (e.g., using
Parquet readers/writers provided by an Arrow implementation), and over the wire (e.g.,
using the Arrow IPC format).

## Implementations

* [geoarrow-c](https://github.com/geoarrow/geoarrow-c): geospatial type system and
  generic coordinate-shuffling library written in C with bindings in C++, R, and Python
* [geoarrow-rs](https://github.com/geoarrow/geoarrow-rs/): Rust implementation of the
  GeoArrow specification and bindings to GeoRust algorithms for efficient spatial
  operations on GeoArrow memory. Includes JavaScript (WebAssembly) bindings.
* [geoarrow-python](https://github.com/geoarrow/geoarrow-python): Python bindings to geoarrow-c
  and geoarrow-rs that provide integrations with libraries like pyarrow, pandas, and
  geopandas.
* [geoarrow-wasm](https://github.com/geoarrow/geoarrow-rs/blob/main/js/README.md):
  WebAssembly module based on geoarrow-rs
