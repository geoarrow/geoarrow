# GeoArrow: an Arrow-native storage format for vector geometries

Spatial information can be represented as a collection of discrete objects
using points, lines and polygons, i.e. vector data. The
[Simple Feature Access](https://www.ogc.org/standards/sfa) standard provides
a widely used abstraction, defining a set of geometries: Point, LineString,
Polygon, MultiPoint, MultiLineString, MultiPolygon, GeometryCollection. Next
to a geometry, simple features can also have non-spatial attributes that
describe the feature.

The [Apache Arrow](https://arrow.apache.org/) project specifies a
standardized language-independent columnar memory format. It enables shared
computational libraries, zero-copy shared memory and streaming messaging,
interprocess communication, etc and is supported by many programming
languages. The Arrow columnar memory model is suited to store both vector
features and its attribute data. This document specifies how such vector
features can be stored in Arrow (and Arrow-compatible) data structures.

## Motivation

Standard ways to represent or serialize vector geometries include WKT (e.g.
"POINT (0 0)"), WKB and GeoJSON. Each of those representations have a
considerable (de)serialization cost, neither do they have a compute-friendly
memory layout.

The goal of this specification is to store geometries in an Arrow-compatible
format that has 1) low (de)serialization overhead and 2) once in memory is
cheap to convert to geospatial libraries (e.g. GEOS or JTS) or easy to
directly operate on (e.g. directly working with the coordinate values).

Benefits of using the proposed Arrow-native format:

- Cheap access to the raw coordinate values for all geometries.
- Columnar data layout.
- Full data type system of Arrow is available for attribute data.

More specifically, the Arrow geometry specification stores the raw coordinates
values in contiguous arrays with enough metadata (offsets) to reconstruct or
interpret as actual geometries.

[FlatGeoBuf](https://flatgeobuf.org/) is similar on various aspects, but is
record-oriented, while Arrow is column-oriented.

## Format

The terminology for array types in this section is based on the
[Arrow Columnar Format specification](https://arrow.apache.org/docs/format/Columnar.html).

GeoArrow proposes a packed columnar data format for the fundamental geometry
types, using packed coordinate and offset arrays to define geometry objects.

The inner level is always a FixedSizeList array storing the interleaved
coordinate values (`[x, y, x, y, ...]`, physically stored as a single array
of length `n_dim * n_coords`). For any geometry type except Point, this inner
level is nested in one or multiple
[variable sized list](https://arrow.apache.org/docs/format/Columnar.html#variable-size-list-layout)
arrays. In practice, this means we have additional arrays storing the offsets
that denote where a new geometry, a new geometry part, or a new polygon ring
starts.

**Point**: `FixedSizeList<double>[n_dim]`

For an array of Point geometries, only a single array is used of interleaved
coordinates. `n_dim` can be 2, 3, or 4 depending on the dimensionality of the
geometries, and the field name of the list should be "xy", "xyz", "xym" or
"xyzm", reflecting the coordinate interpretation.

**LineString**: `List<FixedSizeList<double>[n_dim]>`

An array of LineStrings is represented as a nested list array with one
level of outer nesting: each element of the array (LineString) is a
list of xy vertices. The child name of the outer list should be "vertices".

**Polygon**: `List<List<FixedSizeList<double>[n_dim]>>`

An array of Polygons is represented as a nested list array with two levels of
outer nesting: each element of the array (Polygon) is a list of rings (the
first ring is the exterior ring, optional subsequent rings are interior
rings), and each ring is a list of xy vertices. The child name of the outer
list should be "rings"; the child name of the inner list should be "vertices".

**MultiPoint**: `List<FixedSizeList<double>[n_dim]>`

An array of MultiPoints is represented as a nested list array, where each outer
list is a single MultiPoint (i.e. a list of xy coordinates). The child name of
the outer `List` should be "points".

**MultiLineString**: `List<List<FixedSizeList<double>[n_dim]>>`

An array of MultiLineStrings is represented as a nested list array with two
levels of outer nesting: each element of the array (MultiLineString) is a
list of LineStrings, which consist itself of a list xy vertices (see above).
The child name of the outer list should be "linestrings"; the child name of
the inner list should be "vertices".

**MultiPolygon**: `List<List<List<FixedSizeList<double>[n_dim]>>>`

An array of MultiPolygons is represented as a nested list array with three
levels of outer nesting: each element of the array (MultiPolygon) is a list
of Polygons, which consist itself of a list of rings (the first ring is the
exterior ring, optional subsequent rings are interior rings), and each ring
is a list of xy vertices. The child name of the outer list should be "polygons";
the child name of the middle list should be "rings"; the child name of the
inner list should be "vertices".

### Missing values (nulls)

Arrow supports missing values through a validity bitmap, and for nested data
types every level can be nullable. For this specification, only the outer
level is allowed to have nulls, and all other levels (including the inner
level with the actual coordinate values) should not contain any nulls. Those
fields can be marked explicitly as non-nullable, but this is not required.

In practice this means you can have a missing geometry, but not a geometry
with a null part or null (co)ordinate (for example, a polygon with a null
ring or a point with a null x value).

### Empty geometries

Except for Points, empty geometries can be faithfully represented as an
empty inner list.

Empty points can be represented as `POINT (NaN NaN)`.


### GeometryCollection

GeometryCollections are not yet included in the format description above,
but it is planned to add this later. GeometryCollections can be represented
using a [union type](https://arrow.apache.org/docs/format/Columnar.html#union-layout)
of the other geometry types.


### Mixed Geometry types

When having mixed single and multi geometries of the same type (for example,
Polygon and MultiPolygon), those can be stored together in a MultiPolygon
layout, with the convention that a length-1 MultiPolygon represents a
Polygon.

Truly mixed geometry types can be supported as a union of the other geometry
types, and it is planned to add a description of this later.

### Field and child names

All geometry types should have fields and child names as suggested for each,
however implementations must be able to ingest arrays with other names when the
interpretation is unambiguous (e.g., for xy and xyzm coordinate interpretations).

## Concrete examples of the memory layout

**Point**

Arrow type: `FixedSizeList<double>[2]`

For an array of Point geometries, only a single array is used of interleaved
coordinates. Since this is a fixed size list (each Point consists of 2
coordinate values), a single array of length 2*N is sufficiently informative.

Example of array with 3 points:

WKT: `["POINT (0 0)", "POINT (0 1)", "POINT (0 2)"]`

Logical representation:

```
[(0, 0), (0, 1), (0, 2)]
```

Physical representation (buffers):

* Coordinates: `[0.0, 0.0, 0.0, 1.0, 0.0, 2.0]`


**MultiPoint**

Arrow type: `List<FixedSizeList<double>[2]>`

For an array of MultiPoint geometries, the coordinates are also stored in a
single array of interleaved values (now with length >= 2*N). An additional
array of offsets indicate where the vertices of each MultiPoint start.

Example of array with 3 multipoints:

WKT: `["MULTIPOINT (0 0, 0 1, 0 2)", "MULTIPOINT (1 0, 1 1)", "MULTIPOINT (2 0, 2 1, 2 2)"]`

Logical representation:

```
[
    [(0.0, 0.0), (0.0, 1.0), (0.0, 2.0)],
    [(1.0, 0.0), (1.0, 1.0)],
    [(2.0, 0.0), (2.0, 1.0), (2.0, 2.0)]
]
```

Physical representation (buffers):

* Coordinates: `[0.0, 0.0, 0.0, 1.0, 0.0, 2.0, 1.0, 0.0, 1.0, 1.0, 2.0, 0.0, 2.0, 1.0, 2.0, 2.0]`
* Geometry offsets: `[0, 3, 5, 8]`

(Note: for offset into the coordinates array, you need the number of geometry offsets * 2 in the case of 2-dimensional data)


**MultiLineString**

Arrow type: `List<List<FixedSizeList<double>[2]>>`

Example of array with 3 multilines:

WKT: 

```
[
    "LINESTRING (0 0, 0 1, 0 2)",
    "MULTILINESTRING ((1 0, 1 1), (2 0, 2 1, 2 2))",
    "LINESTRING (3 0, 3 1)"
]
```

Logical representation:

```
[
    [[(0, 0), (0, 1), (0, 2)]],
    [
        [(1, 0), (1, 1), (1, 2)],
        [(2, 0), (2, 1), (2, 2)]
    ],
    [[(3, 0), (3, 1), (3, 2)]],
]
```

Physical representation (buffers):

* Coordinates: `[0.0, 0.0, 0.0, 1.0, 0.0, 2.0, 1.0, 0.0, 1.0, 1.0, 2.0, 0.0, 2.0, 1.0, 2.0, 2.0, 3.0, 0.0, 3.0, 1.0]`
* Part offsets (linestrings): `[0, 3, 5, 8, 10]`
* Geometry offsets: `[0, 1, 3, 4]`


**MultiPolygon**

Arrow type: `List<List<List<FixedSizeList<double>[2]>>>`

Example of array with 3 points:

WKT:

```
[
    "MULTIPOLYGON (((40 40, 20 45, 45 30, 40 40)), ((20 35, 10 30, 10 10, 30 5, 45 20, 20 35), (30 20, 20 15, 20 25, 30 20))",
    "POLYGON ((35 10, 45 45, 15 40, 10 20, 35 10), (20 30, 35 35, 30 20, 20 30))",
    "MULTIPOLYGON (((30 20, 45 40, 10 40, 30 20)), ((15 5, 40 10, 10 20, 5 10, 15 5)))"
]
```

Logical representation:

```
[
    # MultiPolygon 1
    [
        [
            [[40., 40], [20, 45], [45, 30], [40, 40]]
        ], 
        [
            [[20, 35], [10, 30], [10, 10], [30, 5], [45, 20], [20, 35]], 
            [[30, 20], [20, 15], [20, 25], [30, 20]]
        ]
    ],
    # MultiPolygon 2 (using an additional level of nesting to turn the Polygon into a MultiPolygon with one part)
    [
        [
            [[30, 10], [40, 40], [20, 40], [10, 20], [30, 10]]
        ]
    ],
    # MultiPolygon 3
    [
        [
            [[30, 20], [45, 40], [10, 40], [30, 20]]
        ], 
        [
            [[15, 5], [40, 10], [10, 20], [5, 10], [15, 5]]
        ]
    ]
]
```

Physical representation (buffers):

* Coordinates: `[40.0, 40.0, 20.0, 45.0, 45.0, 30.0, 40.0, 40.0, 20.0, 35.0, 10.0, 30.0, 10.0, 10.0, 30.0, 5.0, 45.0, 20.0, 20.0, 35.0, 30.0, 20.0, 20.0, 15.0, 20.0, 25.0, 30.0, 20.0, 30.0, 10.0, 40.0, 40.0, 20.0, 40.0, 10.0, 20.0, 30.0, 10.0, 30.0, 20.0, 45.0, 40.0, 10.0, 40.0, 30.0, 20.0, 15.0, 5.0, 40.0, 10.0, 10.0, 20.0, 5.0, 10.0, 15.0, 5.0]`
* Ring offsets: `[0, 4, 10, 14, 19, 23, 28]`
* Part offsets (polygons): `[0, 1, 3, 4, 5, 6]`
* Geometry offsets: `[0, 2, 3, 5]`
