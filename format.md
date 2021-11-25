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
"POINT (0 0)"), WKB and GeoJSON.
Each of those has a considerable deserialization cost for only accessing the
actual coordinate values. And don't have a memory layout friendly for
compute.

Benefits of using the proposed Arrow-native format:

- Cheap access to the raw coordinate values for all geometries
- Columnar data layout
- Full data type system of Arrow is available for attribute data.

The goal of the Arrow geometry specification is to store the raw coordinates
values with enough metadata to be able to reconstruct.

FlatGeoBuf (add link) also achieves this, but is record-oriented, while Arrow
is column-oriented.


## Format

The terminology for array types in this section is based on the
[Arrow Columnar Format specification](https://arrow.apache.org/docs/format/Columnar.html).

GeoArrow proposes a packed columnar data format for the fundamental geometry types.

GeoArrow uses packed coordinate and offset arrays to define objects.

The inner level is always a FixedSizeList array storing the interleaved
coordinate values (`[x, y, x, y, ...]`, stored as a single array of length
`2 * N`). For any geometry type except Point, this inner level is nested in
one or multiple
[variable sized list](https://arrow.apache.org/docs/format/Columnar.html#variable-size-list-layout)
arrays. In practice, this means we have additional arrays storing the offsets
that denote where a new geometry, a new geometry part, or a new polygon ring
starts.

**Point**

* `FixedSizeList<double>[2]`

For an array of Point geometries, only a single array is used of interleaved
coordinates.

**MultiPoint**

* `List<FixedSizeList<double>[2]>`

An array of MultiPoints is represented as a nested list array, where each outer
list is a single MultiPoint (i.e. a list of xy coordinates).

**MultiLineString**

* `List<List<FixedSizeList<double>[2]>>`


**MultiPolygon**

* `List<List<List<FixedSizeList<double>[2]>>>`


### Missing values (nulls)

Arrow supports missing values through a validity bitmap, and for nested data
types every level can be nullable. For this specification, only the outer
level is allowed to have nulls, and all other levels should be non-nullable.

In practice this means you can have a missing geometry, but not a geometry
with a null part or coordinate (for example, a polygon with a null ring).

Note that this doesn't strictly prohibit having NaN values in the
coordinates, although this has limited use.

### Empty geometries

Except for Points, empty geometries can be faithfully represented as an
empty inner list.

Empty points can be represented as `POINT (NaN NaN)`.


### GeometryCollections

(for now out of scope, potentially as union)


### Mixed Geometry types


Of the same type (eg Polygon and MultiPolygon) -> can be stored together in
MultiPolygon, with the convention that a length-1 MultiPolygon represents a
Polygon.


## Open Questions

* Need the flexibility to switch between interleaved xy vs separate xy? (i.e. fixed size list vs struct array as innner level)
* Storing z interleaved with xy or separate?
* Separate types of LineString and Polygon?
* How to handle GeometryCollections?
* How to handle arrays with mixed geometry types?


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

(Note: for actual offset in coordinates array, you need offsets * 2 in case of 2-dimensional data)


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