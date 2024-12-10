
# GeoArrow Extension Type Definitions

The memory layout specification provides an encoding for geometry types
using the Arrow Columnar format; however, it does not provide a route by
which columns can be recognized as geometry columns when interacting with
Arrow bindings (e.g., Arrow C++, PyArrow, or the arrow package for R).
Similarly, it does not provide a route by which geometry metadata (e.g.,
coordinate reference system) can be attached at the column level.
Whereas the GeoParquet metadata standard defines table-level metadata
intended for geospatial-aware consumers of a file, this specification
defines Array-level metadata intended for geospatial-aware consumers
of individual Arrays (e.g., a library implementing a geospatial algorithm)
or for non-geospatial aware consumers of a table containing such an
Array (e.g., a compute engine that can select columns and/or filter rows).

Arrow's concept of [extension types](https://arrow.apache.org/docs/format/Columnar.html#extension-types)
allows types with additional semantics to be built on top of a built-in
Arrow data type. Extension types are implemented using two metadata fields:
`ARROW:extension:name` and `ARROW:extension:metadata`. Whereas the
built-in Arrow data types used to store geometry is defined in the
[memory format specification](format.md), this document specifies how
the name and metadata should be set to communicate additional
information.

## Extension names

When GeoArrow-encoded Arrays have the `ARROW:extension:name` metadata
field set, it should be set to one of:

- `geoarrow.point`
- `geoarrow.linestring`
- `geoarrow.polygon`
- `geoarrow.multipoint`
- `geoarrow.multilinestring`
- `geoarrow.multipolygon`
- `geoarrow.geometry`
- `geoarrow.geometrycollection`
- `geoarrow.box`
- `geoarrow.wkb`
- `geoarrow.wkt`

These names correspond to the memory layouts and value constraints described in
[GeoArrow memory layout specification](format.md); however, it should be noted
that multiple concrete memory layouts exist for each extension name.
The `ARROW:extension:name`
and `ARROW:extension:metadata` metadata fields must only be set for the Array at
the top level (i.e., child arrays must not carry an extension name or metadata).

## Extension metadata

When GeoArrow-encoded Arrays have the `ARROW:extension:metadata` metadata
field set, it must be serialized as a UTF-8 encoded JSON object. The extension
metadata specification is intentionally aligned with the
[GeoParquet column metadata specifification](https://github.com/opengeospatial/geoparquet/blob/v1.1.0/format-specs/geoparquet.md#metadata).
The following keys in the JSON metadata object are supported:

- `crs`: One of:

    - A JSON object describing the coordinate reference system (CRS)
      using [PROJJSON](https://proj.org/specifications/projjson.html).
    - A string containing a serialized CRS representation. This option
      is intended as a fallback for producers (e.g., database drivers or
      file readers) that are provided a CRS in some form but do not have the
      means to convert it to PROJJSON.
    - Omitted, indicating that the producer does not have any information about
      the CRS.

  For maximum compatibility, producers should write PROJJSON. Producers should not
  write an escaped JSON object to the `crs` key (i.e., when serializing an unknown
  string to the `crs` key, producers should check for a valid JSON object and should
  not escape the input and write it as a string).

  Note that regardless of the axis order specified by the CRS, axis order will be interpreted
  according to the wording in the
  [GeoPackage WKB binary encoding](https://www.geopackage.org/spec130/index.html#gpb_format):
  axis order is always (longitude, latitude) and (easting, northing)
  regardless of the the axis order encoded in the CRS specification.

- `crs_type`: An optional string disambiguating the value of the `crs` field.
  Must be omitted or a string value of:

  - `"projjson"`: Indicates that the `"crs"` field was written as
    [PROJJSON](https://proj.org/specifications/projjson.html).
  - `"wkt2:2019"`: Indicates that the `"crs"` field was written as
    [WKT2:2019](https://www.ogc.org/publications/standard/wkt-crs/).
  - `"authority_code"`: Indicates that the `"crs"` field contains an identifier
    in the form `AUTHORITY:CODE`. This should only be used as a last resort
    (i.e., producers should prefer writing a complete description of the CRS).
  - `"srid"`: Indicates that the `"crs"` field contains an opaque identifier
    that requires the consumer to communicate with the producer outside of
    this metadata. This should only be used as a last resort for database
    drivers or readers that have no other option.

  The `"crs_type"` should be omitted if the producer cannot guarantee the validity
  of any of the above values (e.g., if it just serialized a CRS object
  specifically into one of these representations).

- `edges`: A value of `"spherical"` instructs consumers that edges follow a
  spherical path rather than a planar one. If this value is omitted, edges will
  be interpreted as planar. This metadata key is only applicable to a
  `geoarrow.linestring`, `geoarrow.polygon`, `geoarrow.multilinestring`,
  `geoarrow.multipolygon`, `geoarrow.box`, `geoarrow.wkb`, or `geoarrow.wkt`
  array and should be omitted for an Array with any other extension name.

If all metadata keys are omitted, the `ARROW:extension:metadata` should
also be omitted.

## Concrete examples of extension type metadata

**Point without CRS**

Storage type without extension: `FixedSizeList<xy: double>[2]`

The metadata for the outer array would be as follows:

- `ARROW:extension:name`: `geoarrow.point`

**LineString with CRS**

Storage type without extension: `List<vertices: FixedSizeList<xy: double>[2]>`

The metadata for the outer array would be as follows:

- `ARROW:extension:name`: `geoarrow.linestring`
- `ARROW:extension:metadata`: `{"crs": {"$schema":"https://proj.org/schemas/v0.4/projjson.schema.json","type":"GeographicCRS","name":"WGS 84","datum":{"type":"GeodeticReferenceFrame","name":"World Geodetic System 1984","ellipsoid":{"name":"WGS 84","semi_major_axis":6378137,"inverse_flattening":298.257223563},"id":{"authority":"EPSG","code":6326}},"coordinate_system":{"subtype":"ellipsoidal","axis":[{"name":"Longitude","abbreviation":"lon","direction":"east","unit":"degree"},{"name":"Latitude","abbreviation":"lat","direction":"north","unit":"degree"}]}}}`
