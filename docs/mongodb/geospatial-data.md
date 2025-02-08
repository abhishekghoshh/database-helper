

## Introduction

We can also store and retrieve geo location `(2D)` data and use indexes on that. 

It will be stored as `[x,y]` where `x` must be the longitude and `y` must be the latitude. It follows the geoJSON format only.

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

We can also search for the opposite query. We can find an poly where a point belongs or not.
```js
> db.infos.find({ 
    location : { 
        $geoIntersects : { 
            $geometry : { type : "Point" , coordinates : [24.089473,88.2513618] } }
    }
})
```

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


