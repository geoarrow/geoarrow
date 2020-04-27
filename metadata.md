# Metadata Schema - Version 0.1.0

In order to ensure interoperability between implementations of the Arrow in-memory format
and associated storage formats such as Parquet and Feather, it is necessary to
include additional top-level metadata.

This information includes:

-   spatial properties of each geometry column
-   name of the primary geometry column

## Schema stability

This is the first major draft of this metadata schema. It is intended to help
test implementation details and gather feedback from the community. As such,
this version does not make any stability promises that will be upheld in future
versions. We encourage you to offer feedback on this schema and implement
tests using it. We do not encourage you to use this version of the schema
or associated implementations in production settings until future versions of
this schema.

## Metadata structure

Metadata is to be stored as a JSON-encoded UTF-8 string under the "geo" key within the
top-level metadata object of the in-memory Arrow schema or file format.

For clarity, the following shows the unencoded JSON structure:

```python
"geo": {
        "columns": {...},  # REQUIRED: see below
        "creator": {
            "library": "<library name>",  # REQUIRED
            "version": "<library version>",  # REQUIRED
        },
        "primary_column": "<primary geometry column name>",  # REQUIRED
        "schema_version": "0.1.0"  # REQUIRED
    }
```

Each geometry column in the dataset must be included in the `columns` field above
with the following content, keyed by the column name:

```python
"<column_name>": {
    "bbox": [<xmin>, <ymin>, (zmin), <xmax>, <ymax>, (zmax)],  # OPTIONAL
    "crs": "<WKT representation of CRS>",  # REQUIRED
    "encoding": "WKB",  # REQUIRED
}
```

## Bounding boxes

Bounding boxes are used to help define the spatial extent of each geometry column.
Implementations of this schema may choose to use those bounding boxes to filter
partitions (sub-datasets) of a dataset. For example, Parquet supports partitions
as individual files ([reference](https://arrow.apache.org/docs/python/parquet.html?highlight=pyarrow%20parquet%20partition#partitioned-datasets-multiple-files)).

These must be encoded with the minimum and maximum values of each dimension:

-   2D: `[<xmin>, <ymin>, <xmax>, <ymax>]`
-   3D: `[<xmin>, <ymin>, <zmin>, <xmax>, <ymax>, <zmax>]`

## Coordinate Reference System (CRS) encoding

The `crs` key must always be present.

The value of this key may be `null` to indicate that there is no CRS assigned
to this column.

If non-null, CRS information must be encoded using Well-Known Text
([WKT](https://proj.org/faq.html#what-is-the-best-format-for-describing-coordinate-reference-systems).

Multiple dialects of WKT exist, including:

-   GDAL WKT
-   ESRI WKT
-   WKT2:2015 (ISO 19162:2015)
-   WKT2:2018 (ISO 19162:2018)

Any WKT encoding used must be supported by the
[Proj](https://proj.org/index.html) library.

## Geometry encoding

Because each geometry-oriented library, such as [GEOS](https://github.com/libgeos/geos)
generally has its own internal representation of geometry in memory, it is
necessary to use a serialization format for storing geometry data within
Arrow or related file formats.

Well-Known Binary (WKB) is currently the only supported geometry encoding and
is recommended for widest cross-language / cross-library portability.

Other dialects of WKB, such as EWKB, are not currently supported under this schema.

Other encodings may be introduced in future versions of this schema.

## Example

```json
"geo": {
        "columns": {
            "geometry": {
                "bbox": [-180, -80, 180, 80],
                "crs": "GEOGCS[\"WGS 84\",DATUM[\"WGS_1984\",SPHEROID[\"WGS 84\",6378137,298.257223563,AUTHORITY[\"EPSG\","7030"]],AUTHORITY[\"EPSG\","6326"]],PRIMEM[\"Greenwich\",0,AUTHORITY[\"EPSG\",\"8901\"]],UNIT[\"degree\",0.01745329251994328,AUTHORITY[\"EPSG\",\"9122\"]],AUTHORITY[\"EPSG\",\"4326\"]]",
                "encoding": "WKB",
            }
        },
        "creator": {
            "library": "geopandas",
            "version": "0.7.0",
        },
        "primary_column": "geometry",
        "version": "1.0.0"
    }
```
