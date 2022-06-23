
# Arrow Extension Type definitions

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
field set, it should be set to one of `geoarrow.point`, `geoarrow.linestring`,
`geoarrow.polygon`, `geoarrow.multipoint`, `geoarrow.multilinestring`,
`geoarrow.multipolygon`, or `geoarrow.wkb`. These names correspond
to the memory layouts and value constraints described in
[GeoArrow memory layout specification](format.md).

The `ARROW:extension:name` and `ARROW:extension:metadata` metadata fields
must also be set for child Arrays (i.e., extension types are nested).
For the extension types noted above, the nesting is as follows:

- `geoarrow.point`: `FixedSizeList<xy|xyz|xym|xyzm: double>[n_dim]`
- `geoarrow.linestring`: `List<vertices: geoarrow.point>`
- `geoarrow.polygon`: `List<rings: List<vertices: geoarrow.point>>`
- `geoarrow.multipoint`: `List<points: geoarrow.point>`
- `geoarrow.multilinestring`: `List<linestrings: geoarrow.linestring>`
- `geoarrow.multipolygon`: `List<polygons: geoarrow.polygon>`
- `geoarrow.wkb`: `Binary`, `LargeBinary`, or `FixedSizeBinary[fixed_size]`

## Extension metadata

When GeoArrow-encoded Arrays have the `ARROW:extension:metadata` metadata
field set, it must be encoded using the same format as specified for
[metadata in the C data interface](https://arrow.apache.org/docs/format/CDataInterface.html#c.ArrowSchema.metadata)
with the constraint that the 32-bit integers that encode the length of
each key and each value must be little-endian. This encoding provides
the ability to store arbitrary key/value pairs where the key is a UTF-8
encoded string and the value can be an arbitrary sequence of bytes.
For all currently supported keys, the value will be interpreted as a
UTF-8-encoded string.

The following metadata keys are supported:

- `crs`: Contains a serialized version of the coordinate reference system
  using [PROJJSON](https://proj.org/specifications/projjson.html).
  The string is interpreted using UTF-8 encoding. This key can be omitted
  if the producer does not have any information about the CRS. This
  metadata key is only applicable to a `geoarrow.point` or `geoarrow.wkb`
  Array and should be omitted for an Array with any other extension name.
  Note that axis order must be encoded according to the wording in the
  [GeoPackage WKB binary encoding](https://www.geopackage.org/spec130/index.html#gpb_format):
  axis order is always (longitude, latitude) and (easting, northing)
  regardless of the the axis order encoded in the CRS specification.
- `edges`: A value of `"spherical"` instructs consumers that edges follow
  a spherical path rather than a planar one. If this value is omitted,
  edges will be interpreted as planar. This metadata key is only applicable
  to a `geoarrow.linestring`, `geoarrow.polygon`, or `geoarrow.wkb` array
  and should be omitted for an Array with any other extension name.

If all metadata keys are omitted, the `ARROW:extension:metadata` should
also be omitted.

## Concrete examples of extension types

**Point with CRS**

Storage type without extensions: `FixedSizeList<xy: double>[2]`

The metadata for the outer array would be as follows:

- `ARROW:extension:name`: `geoarrow.point`
- `ARROW:extension:metadata`:
    - `crs`: `{"$schema":"https://proj.org/schemas/v0.4/projjson.schema.json","type":"GeographicCRS","name":"WGS 84 (CRS84)","datum_ensemble":{"name":"World Geodetic System 1984 ensemble","members":[{"name":"World Geodetic System 1984 (Transit)","id":{"authority":"EPSG","code":1166}},{"name":"World Geodetic System 1984 (G730)","id":{"authority":"EPSG","code":1152}},{"name":"World Geodetic System 1984 (G873)","id":{"authority":"EPSG","code":1153}},{"name":"World Geodetic System 1984 (G1150)","id":{"authority":"EPSG","code":1154}},{"name":"World Geodetic System 1984 (G1674)","id":{"authority":"EPSG","code":1155}},{"name":"World Geodetic System 1984 (G1762)","id":{"authority":"EPSG","code":1156}},{"name":"World Geodetic System 1984 (G2139)","id":{"authority":"EPSG","code":1309}}],"ellipsoid":{"name":"WGS 84","semi_major_axis":6378137,"inverse_flattening":298.257223563},"accuracy":"2.0","id":{"authority":"EPSG","code":6326}},"coordinate_system":{"subtype":"ellipsoidal","axis":[{"name":"Geodetic longitude","abbreviation":"Lon","direction":"east","unit":"degree"},{"name":"Geodetic latitude","abbreviation":"Lat","direction":"north","unit":"degree"}]},"scope":"Not known.","area":"World.","bbox":{"south_latitude":-90,"west_longitude":-180,"north_latitude":90,"east_longitude":180},"id":{"authority":"OGC","code":"CRS84"}}`

The serialized `ARROW:extension:metadata` would be: `b'\x01\x00\x00\x00\x03\x00\x00\x00crs(\x07\x00\x00{"$schema":"https://proj.org/schemas/v0.4/projjson.schema.json","type":"ProjectedCRS","name":"NAD83 / UTM zone 20N","base_crs":{"name":"NAD83","datum":{"type":"GeodeticReferenceFrame","name":"North American Datum 1983","ellipsoid":{"name":"GRS 1980","semi_major_axis":6378137,"inverse_flattening":298.257222101}},"coordinate_system":{"subtype":"ellipsoidal","axis":[{"name":"Geodetic latitude","abbreviation":"Lat","direction":"north","unit":"degree"},{"name":"Geodetic longitude","abbreviation":"Lon","direction":"east","unit":"degree"}]},"id":{"authority":"EPSG","code":4269}},"conversion":{"name":"UTM zone 20N","method":{"name":"Transverse Mercator","id":{"authority":"EPSG","code":9807}},"parameters":[{"name":"Latitude of natural origin","value":0,"unit":"degree","id":{"authority":"EPSG","code":8801}},{"name":"Longitude of natural origin","value":-63,"unit":"degree","id":{"authority":"EPSG","code":8802}},{"name":"Scale factor at natural origin","value":0.9996,"unit":"unity","id":{"authority":"EPSG","code":8805}},{"name":"False easting","value":500000,"unit":"metre","id":{"authority":"EPSG","code":8806}},{"name":"False northing","value":0,"unit":"metre","id":{"authority":"EPSG","code":8807}}]},"coordinate_system":{"subtype":"Cartesian","axis":[{"name":"Easting","abbreviation":"E","direction":"east","unit":"metre"},{"name":"Northing","abbreviation":"N","direction":"north","unit":"metre"}]},"scope":"Engineering survey, topographic mapping.","area":"North America - between 66\xc2\xb0W and 60\xc2\xb0W - onshore and offshore. British Virgin Islands. Canada - New Brunswick; Labrador; Nunavut; Prince Edward Island; Quebec. Puerto Rico. US Virgin Islands. United States (USA) offshore Atlantic.","bbox":{"south_latitude":15.63,"west_longitude":-66,"north_latitude":84,"east_longitude":-60},"id":{"authority":"EPSG","code":26920}}'`

**LineString with CRS**

Storage type without extensions: `List<vertices: FixedSizeList<xy: double>[2]>`

The metadata for the outer array would be as follows:

- `ARROW:extension:name`: `geoarrow.linestring`

The metadata for `vertices` would be as follows:

- `ARROW:extension:name`: `geoarrow.point`
- `ARROW:extension:metadata`:
    - `crs`: `{"$schema":"https://proj.org/schemas/v0.4/projjson.schema.json","type":"GeographicCRS","name":"WGS 84 (CRS84)","datum_ensemble":{"name":"World Geodetic System 1984 ensemble","members":[{"name":"World Geodetic System 1984 (Transit)","id":{"authority":"EPSG","code":1166}},{"name":"World Geodetic System 1984 (G730)","id":{"authority":"EPSG","code":1152}},{"name":"World Geodetic System 1984 (G873)","id":{"authority":"EPSG","code":1153}},{"name":"World Geodetic System 1984 (G1150)","id":{"authority":"EPSG","code":1154}},{"name":"World Geodetic System 1984 (G1674)","id":{"authority":"EPSG","code":1155}},{"name":"World Geodetic System 1984 (G1762)","id":{"authority":"EPSG","code":1156}},{"name":"World Geodetic System 1984 (G2139)","id":{"authority":"EPSG","code":1309}}],"ellipsoid":{"name":"WGS 84","semi_major_axis":6378137,"inverse_flattening":298.257223563},"accuracy":"2.0","id":{"authority":"EPSG","code":6326}},"coordinate_system":{"subtype":"ellipsoidal","axis":[{"name":"Geodetic longitude","abbreviation":"Lon","direction":"east","unit":"degree"},{"name":"Geodetic latitude","abbreviation":"Lat","direction":"north","unit":"degree"}]},"scope":"Not known.","area":"World.","bbox":{"south_latitude":-90,"west_longitude":-180,"north_latitude":90,"east_longitude":180},"id":{"authority":"OGC","code":"CRS84"}}`

The serialized `ARROW:extension:metadata` for `vertices` would be: `b'\x01\x00\x00\x00\x03\x00\x00\x00crs(\x07\x00\x00{"$schema":"https://proj.org/schemas/v0.4/projjson.schema.json","type":"ProjectedCRS","name":"NAD83 / UTM zone 20N","base_crs":{"name":"NAD83","datum":{"type":"GeodeticReferenceFrame","name":"North American Datum 1983","ellipsoid":{"name":"GRS 1980","semi_major_axis":6378137,"inverse_flattening":298.257222101}},"coordinate_system":{"subtype":"ellipsoidal","axis":[{"name":"Geodetic latitude","abbreviation":"Lat","direction":"north","unit":"degree"},{"name":"Geodetic longitude","abbreviation":"Lon","direction":"east","unit":"degree"}]},"id":{"authority":"EPSG","code":4269}},"conversion":{"name":"UTM zone 20N","method":{"name":"Transverse Mercator","id":{"authority":"EPSG","code":9807}},"parameters":[{"name":"Latitude of natural origin","value":0,"unit":"degree","id":{"authority":"EPSG","code":8801}},{"name":"Longitude of natural origin","value":-63,"unit":"degree","id":{"authority":"EPSG","code":8802}},{"name":"Scale factor at natural origin","value":0.9996,"unit":"unity","id":{"authority":"EPSG","code":8805}},{"name":"False easting","value":500000,"unit":"metre","id":{"authority":"EPSG","code":8806}},{"name":"False northing","value":0,"unit":"metre","id":{"authority":"EPSG","code":8807}}]},"coordinate_system":{"subtype":"Cartesian","axis":[{"name":"Easting","abbreviation":"E","direction":"east","unit":"metre"},{"name":"Northing","abbreviation":"N","direction":"north","unit":"metre"}]},"scope":"Engineering survey, topographic mapping.","area":"North America - between 66\xc2\xb0W and 60\xc2\xb0W - onshore and offshore. British Virgin Islands. Canada - New Brunswick; Labrador; Nunavut; Prince Edward Island; Quebec. Puerto Rico. US Virgin Islands. United States (USA) offshore Atlantic.","bbox":{"south_latitude":15.63,"west_longitude":-66,"north_latitude":84,"east_longitude":-60},"id":{"authority":"EPSG","code":26920}}'`
