
# Arrow Extension Type definitions

The memory layout specification provides an encoding for geometry types using the Arrow Columnar format; however, it does not provide a route by which columns can be recognized as geometry columns when interacting with Arrow bindings (e.g., Arrow C++, PyArrow, or the arrow package for R). Similarly, it does not provide a route by which geometry metadata (e.g., coordinate reference system) can be attached at the column level. Whereas the GeoParquet metadata standard defines table-level metadata intended for geospatial-aware consumers of a file, this specification defines Array-level metadata intended for geospatial-aware consumers of individual Arrays (e.g., a library implementing a geospatial algorithm) or for non-geospaital aware consumers of a table containing such an Array (e.g., a compute engine that can select columns and/or filter rows).

## Extension names

When GeoArrow-encoded Arrays have the `ARROW:extension:name` metadata field set, it should be set to one of `geoarrow.point`, `geoarrow.linestring`, `geoarrow.polygon`, `geoarrow.multipoint`, `geoarrow.multilinestring`, `geoarrow.multipolygon`, or `geoarrow.wkb`. These names correspond to the memory layouts and value constraints described in [GeoArrow memory layout specification](format.md).

The `ARROW:extension:name` and `ARROW:extension:metadata` metadata fields must also be set for child Arrays (i.e., extension types are nested). For the extension types noted above, the nesting is as follows:

- `geoarrow.point`: `FixedSizeList<xy|xyz|xym|xyzm: double>[n_dim]`
- `geoarrow.linestring`: `List<vertices: geoarrow.point>`
- `geoarrow.polygon`: `List<rings: List<vertices: geoarrow.point>>`
- `geoarrow.multipoint`: `List<points: geoarrow.point>`
- `geoarrow.multilinestring`: `List<linestrings: geoarrow.linestring>`
- `geoarrow.multipolygon`: `List<polygons: geoarrow.polygon>`
- `geoarrow.wkb`: `Binary`, `LargeBinary`, or `FixedSizeBinary[fixed_size]`

## Extension metadata

When GeoArrow-encoded Arrays have the `ARROW:extension:metadata` metadata field set, it must be encoded using the same format as specified for [metadata in the C data interface](https://arrow.apache.org/docs/format/CDataInterface.html#c.ArrowSchema.metadata) with the constraint that the 32-bit integers that encode the length of each key and each value must be little-endian. This encoding provides the ability to store arbitrary key/value pairs where the key is a UTF-8 encoded string and the value can be an arbitrary sequence of bytes. For all currently supported keys, the value will be interpreted as a UTF-8-encoded string.

The following metadata keys are supported:

- `crs_encoding`: Contains a UTF-8-encoded string describing how the `crs` metadata field should be interpreted. Supported values of `crs_encoding` are `"wkt2"` and `"projjson"`. If this key is omitted the consumer cannot assume any specific encoding (i.e., producers can pass on CRS information in whatever form they received it). This metadata should not be present if `crs` is not present.
- `crs`: Contains a serialized version of the coordinate reference system. The string is interpreted using UTF-8 encoding. This key can be omitted if the producer does not have any information about the CRS. This metadata key is only applicable to a `geoarrow.point` or `geoarrow.wkb` Array and should be omitted for an Array with any other extension name.
- `edges`: A value of `"spherical"` instructs consumers that edges follow a spherical path rather than a planar one. If this value is omitted, edges will be interpreted as planar. This metadata key is only applicable to a `geoarrow.linestring`, `geoarrow.polygon`, or `geoarrow.wkb` array and should be omitted for an Array with any other extension name.

If all metadata keys are omitted, the `ARROW:extension:metadata` should also be omitted.

## Concrete examples of extension types

**Point with CRS**

Storage type without extensions: `FixedSizeList<xy: double>[2]`

The metadata for the outer array would be as follows:

- `ARROW:extension:name`: `geoarrow.point`
- `ARROW:extension:metadata`:
    - `crs_type`: `WKT2`
    - `crs`: `GEOGCS["WGS 84",DATUM["WGS_1984",SPHEROID["WGS 84",6378137,298.257223563],AUTHORITY["EPSG","6326"]],PRIMEM["Greenwich",0,AUTHORITY["EPSG","8901"]],UNIT["degree",0.0174532925199433,AUTHORITY["EPSG","9122"]],AXIS["Longitude",EAST],AXIS["Latitude",NORTH]]`

The serialized `ARROW:extension:metadata` would be: `b'\x02\x00\x00\x00\x08\x00\x00\x00crs_type\x04\x00\x00\x00wkt2\x03\x00\x00\x00crs\xfc\x00\x00\x00GEOGCS["WGS 84",DATUM["WGS_1984",SPHEROID["WGS 84",6378137,298.257223563],AUTHORITY["EPSG","6326"]],PRIMEM["Greenwich",0,AUTHORITY["EPSG","8901"]],UNIT["degree",0.0174532925199433,AUTHORITY["EPSG","9122"]],AXIS["Longitude",EAST],AXIS["Latitude",NORTH]]'`

**LineString with CRS**

Storage type without extensions: `List<vertices: FixedSizeList<xy: double>[2]>`

The metadata for the outer array would be as follows:

- `ARROW:extension:name`: `geoarrow.point`

The metadata for `vertices` would be as follows:

- `ARROW:extension:name`: `geoarrow.point`
- `ARROW:extension:metadata`:
    - `crs_type`: `WKT2`
    - `crs`: `GEOGCS["WGS 84",DATUM["WGS_1984",SPHEROID["WGS 84",6378137,298.257223563],AUTHORITY["EPSG","6326"]],PRIMEM["Greenwich",0,AUTHORITY["EPSG","8901"]],UNIT["degree",0.0174532925199433,AUTHORITY["EPSG","9122"]],AXIS["Longitude",EAST],AXIS["Latitude",NORTH]]`

The serialized `ARROW:extension:metadata` for `vertices` would be: `b'\x02\x00\x00\x00\x08\x00\x00\x00crs_type\x04\x00\x00\x00wkt2\x03\x00\x00\x00crs\xfc\x00\x00\x00GEOGCS["WGS 84",DATUM["WGS_1984",SPHEROID["WGS 84",6378137,298.257223563],AUTHORITY["EPSG","6326"]],PRIMEM["Greenwich",0,AUTHORITY["EPSG","8901"]],UNIT["degree",0.0174532925199433,AUTHORITY["EPSG","9122"]],AXIS["Longitude",EAST],AXIS["Latitude",NORTH]]'`
