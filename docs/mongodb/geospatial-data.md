

## Introduction

MongoDB has built-in support for **geospatial data** — storing locations (points, lines, polygons) and performing spatial queries like "find nearby", "find within area", and "find intersecting". This is widely used in apps for store locators, delivery tracking, ride-hailing, and location-based search.

We can also store and retrieve geo location `(2D)` data and use indexes on that. 

It will be stored as `[x,y]` where `x` must be the longitude and `y` must be the latitude. It follows the geoJSON format only.

**GeoJSON Types Supported:**

| GeoJSON Type | Description | Coordinates Format |
|-------------|-------------|-------------------|
| `Point` | A single location | `[longitude, latitude]` |
| `LineString` | A path/route | `[[lng1, lat1], [lng2, lat2], ...]` |
| `Polygon` | A closed area/region | `[[[lng1, lat1], ..., [lng1, lat1]]]` |
| `MultiPoint` | Multiple locations | `[[lng1, lat1], [lng2, lat2]]` |
| `MultiPolygon` | Multiple regions | Nested polygon arrays |

**Important**: MongoDB uses `[longitude, latitude]` order (not `[lat, lng]` like Google Maps). This is a common source of bugs!

```
Geospatial Query Types:

  $near              → Find points near a location (sorted by distance)
  $geoWithin         → Find points inside a polygon/circle
  $geoIntersects     → Find geometries that intersect with a given shape
  $centerSphere      → Find within a spherical radius
```

**Index Requirement:**

| Query Operator | Required Index |
|----------------|---------------|
| `$near` | `2dsphere` (required) |
| `$geoWithin` | `2dsphere` (recommended) |
| `$geoIntersects` | `2dsphere` (recommended) |

```js
// Create a 2dsphere index (required for $near, recommended for all)
db.infos.createIndex({ location: "2dsphere" })
```

---

## Storing Point Data

```js
> db.infos.insertOne({
    name : "Home" , 
    location : { 
        type : "Point" , 
        coordinates : [24.0814946,88.2408234,13.38]
    }
})

{
        "acknowledged" : true,
        "insertedId" : ObjectId("62dcff4c85a6e4bfe5a374cd")
}
```

To store the coordinates, we must follow this structure of the embed document { location : { type : "Point" , coordinates : [24.0814946,88.2408234]}}.
We can change the name of field “location”, but the structure must be same.

We can also store area or polygon
---

## Storing Polygon Data
Let’s create 4 points 
```js
const p1 = [24.08409, 88.24231]
const p2 = [24.09149, 88.24707]
const p3 = [24.08879, 88.25578]
const p4 = [24.08048, 88.24934]

> db.infos.insertOne({
        name : "Gorabazar area" , 
        location : { 
            type : "Polygon" , coordinates : [[p1,p2,p3,p4,p1]]
        }
    })
{
        "acknowledged" : true,
        "insertedId" : ObjectId("62dd0e1d85a6e4bfe5a374d3")
}
```

It is to better to create a geospatial index as most of the geospatial queries require indexing.

---

## $near — Find Nearby Points

**Intent**: Find documents near a given point, sorted by distance (closest first). Requires a `2dsphere` index.

We can check any points are near to the queried point or not. For that we have a special syntax.
```js
> db.infos.find({ 
    location : { 
        $near : { $geometry : { type : "Point", coordinates : [24,88]}}
    }
}).pretty()

{
        "_id" : ObjectId("62dcff4c85a6e4bfe5a374cd"),
        "name" : "Home",
        "location" : {
                "type" : "Point",
                "coordinates" : [
                        24.0814946,
                        88.2408234
                ]
        }
}
```

We can also specify other things along side $geometry like $maxDistance and $minDistance. The unit will be in meters.

**Distance Parameters:**

| Parameter | Unit | Description |
|-----------|------|-------------|
| `$minDistance` | meters | Minimum distance from the point |
| `$maxDistance` | meters | Maximum distance from the point |
```js
> db.infos.find({ 
    location : { 
        $near : { 
            $geometry : { type : "Point", coordinates : [24,88]}, 
            $minDistance : 10, $maxDistance : 26809}
    }
}).pretty()

> db.infos.find({ 
        location : { 
            $near : { 
                $geometry : { type : "Point", coordinates : [24,88]}, 
                $minDistance : 10, 
                $maxDistance : 26810
            }
        }
    }).pretty()
{
      "_id" : ObjectId("62dcff4c85a6e4bfe5a374cd"),
        "name" : "Home",
        "location" : {
                "type" : "Point",
                "coordinates" : [
                        24.0814946,
                        88.2408234
                ]
        }
}
```

---

## $geoWithin — Find Points Inside an Area

**Intent**: Find all points/documents that fall **inside** a given polygon or circle. Unlike `$near`, results are NOT sorted by distance.

To find a place inside any special region or not we can do this. First, we can create our own map (from google maps -> your places -> see all your maps) and create one area or polygon.

We can validate all the points are inside of these 4 coordinates or not. In map we will see these 4 points made a rectangle.

We will also insert some of the points.
```js
> db.infos.insertOne({
    name : "Murshidabad medical college" , 
    location : { type : "Point" , coordinates : [24.089473,88.2513618]}
})
> db.infos.insertOne({
    name : "Gorabazar ICI" , 
    location : { type : "Point" , coordinates : [24.0930413,88.2483631]}
})
> db.infos.insertOne({
        name : "Mary immaculate school" , 
        location : { type : "Point" , coordinates : [24.0930413,88.2483631]}
    })
> db.infos.insertOne({
        name : "Berhampore head post office" , 
        location : { type : "Point" , coordinates : [24.0947532,88.2510873]}
    })
> db.infos.insertOne({
        name : "Mohon cinema hall" , 
        location : { type : "Point" , coordinates : [24.0947532,88.2510873]}
    })
```

Again, we must follow some specific syntax for with in query.
```js
> db.infos.find({ 
    location : { 
        $geoWithin : { 
            $geometry : { type : "Polygon", coordinates : [[p1,p2,p3,p4,p1]]}
        }
    }
})
```

Keyword is $geoWithin and type is Polygon and coordinates will be in 2nd layer of nested arrays and the first and the last point should be same.

---

## $geoIntersects — Find Intersecting Geometries

**Intent**: Find documents whose geometry **intersects** with a given shape. While `$geoWithin` checks containment, `$geoIntersects` checks overlap. For points, this means "find which polygon contains this point".

We can also search for the opposite query. We can find an poly where a point belongs or not.
```js
> db.infos.find({ 
    location : { 
        $geoIntersects : { 
            $geometry : { type : "Point" , coordinates : [24.089473,88.2513618] } }
    }
})
```

---

## $centerSphere — Search Within a Radius

**Intent**: Find all points within a circular radius on a sphere (the Earth). This is useful for "find everything within X km of this point" queries.

We can also search in circle within a radius.
```js
> db.infos.find({ 
    location : { 
        $geoWithin : { 
            $centerSphere : [[24.089473, 88.2513618], 1/6378.1]}
    }
})
```
Where 1st one is the 2d coordinate and 2nd one is radius. 1 is in kilometre. 6378.1 is the constant. Check this on official documentation.

**Radius Conversion:**

| Distance | Formula |
|----------|---------|
| 1 km | `1 / 6378.1` |
| 5 km | `5 / 6378.1` |
| 10 miles | `10 / 3963.2` |

The constant `6378.1` is the Earth's radius in **kilometers**. For miles, use `3963.2`.

---

## Real-World Use Cases

| Use Case | Query Operator | Example |
|----------|---------------|---------|
| Store locator | `$near` + `$maxDistance` | Find the 5 closest stores within 10km |
| Delivery zones | `$geoWithin` (Polygon) | Check if delivery address is in service area |
| Geo-fencing | `$geoIntersects` | Detect when a user enters a defined region |
| Radius search | `$centerSphere` | Find all restaurants within 2km |


