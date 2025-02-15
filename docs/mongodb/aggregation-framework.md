
## Introduction

Aggregation framework is just another find method we could say but it has some other advantages too. In aggregation framework we basically create pipeline of steps which operates on datas of that collection.


Aggregation Pipeline
```js
db.listingsAndReviews.aggregate([
    {
        $match: {
            number_of_reviews: { $gte: 100 } // Listings with more than 100 reviews
        } 
    },
    {
        $group : {
            _id : "$property_type",        // Group by property type
            count: { $sum : 1 },           // Total listings
            reviewCount: { $sum : "$number_of_reviews" },        // Total reviews
            avgPrice: { $avg : "$price" }, // Average price
        },
    },
    {
        $project: {
            _id: 1,
            count: 1,
            reviewCount: 1,
            avgPrice: { $ceil : "$avgPrice" } // Round up avgPrice
        }
    },
    {
        $match: {
            reviewCount: { $gte: 10000 } // Listings by property with more than 10000 total reviews
        } 
    },
    {
        $sort : { 
            count : -1, // Sort by count descending
            avgPrice: 1 // Sort by avgPrice ascending
        }
    }
])
```

`$lookup (Join)`
```js
db.accounts.aggregate([
   {
      $lookup:
        {
          from: "transactions",         // join with 'transactions' collection
          localField: "account_id",     // field from the 'accounts' collection
          foreignField: "account_id",   // field from the 'transactions' collection
          as: "customer_orders"         // output array field
        }
   },
   {
      $match: { $expr: { $lt: [ {$size: "$customer_orders"}, 5 ] } } // filter for documents where 'customer_orders' is < 5
   },
])

```