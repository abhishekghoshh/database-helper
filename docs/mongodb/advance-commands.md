## Handy commands

**Switch to admin database and create a user:**
```js
use admin
db.createUser({"user": "root", "pwd": passwordPrompt(), "roles": ["root"]})
```

**Drop a user:**
```js
db.dropUser("root")
```

**Authenticate a user:**
```js
db.auth("user", passwordPrompt())
```

**Switch to test database:**
```js
use test
```

**Get sibling database:**
```js
db.getSiblingDB("dbname")
```

**Get current operations:**
```js
db.currentOp()
```

**Kill an operation:**
```js
db.killOp(123) // opid
```

**Lock and unlock the database:**
```js
db.fsyncLock()
db.fsyncUnlock()
```

**Get collection names and information:**
```js
db.getCollectionNames()
db.getCollectionInfos()
db.printCollectionStats()
```

**Get database statistics:**
```js
db.stats()
```

**Get replication information:**
```js
db.getReplicationInfo()
db.printReplicationInfo()
```

**Get server information:**
```js
db.hello()
db.hostInfo()
```

**Shutdown the server:**
```js
db.shutdownServer()
```

**Get server status:**
```js
db.serverStatus()
```

**Get and set profiling level:**
```js
db.getProfilingStatus()
db.setProfilingLevel(1, 200) // 0 == OFF, 1 == ON with slowms, 2 == ON
```

**Enable and disable free monitoring:**
```js
db.enableFreeMonitoring()
db.disableFreeMonitoring()
db.getFreeMonitoringStatus()
```

**Create a view:**
```js
db.createView("viewName", "sourceColl", [{$project:{department: 1}}])
```

## Change Streams

**Watch for changes in a collection:**
```js
watchCursor = db.coll.watch([ { $match : {"operationType" : "insert" } } ])
while (!watchCursor.isExhausted()){
   if (watchCursor.hasNext()){
      print(tojson(watchCursor.next()));
   }
}
```

## Replica Set

**Get replica set status:**
```js
rs.status()
```

**Initialize a replica set:**
```js
rs.initiate({
  "_id": "RS1",
  members: [
    { _id: 0, host: "mongodb1.net:27017" },
    { _id: 1, host: "mongodb2.net:27017" },
    { _id: 2, host: "mongodb3.net:27017" }
  ]
})
```

**Add a member to the replica set:**
```js
rs.add("mongodb4.net:27017")
```

**Add an arbiter to the replica set:**
```js
rs.addArb("mongodb5.net:27017")
```

**Remove a member from the replica set:**
```js
rs.remove("mongodb1.net:27017")
```

**Get replica set configuration:**
```js
rs.conf()
```

**Get replica set hello information:**
```js
rs.hello()
```

**Print replication information:**
```js
rs.printReplicationInfo()
rs.printSecondaryReplicationInfo()
```

**Reconfigure the replica set:**
```js
rs.reconfig(config)
rs.reconfigForPSASet(memberIndex, config, { options })
```

**Set read preference:**
```js
db.getMongo().setReadPref('secondaryPreferred')
```

**Step down the primary:**
```js
rs.stepDown(20, 5) // (stepDownSecs, secondaryCatchUpPeriodSecs)
```

## Sharded Cluster

**Print sharding status:**
```js
db.printShardingStatus()
```

**Get sharding status:**
```js
sh.status()
```

**Add a shard to the cluster:**
```js
sh.addShard("rs1/mongodb1.example.net:27017")
```

**Shard a collection:**
```js
sh.shardCollection("mydb.coll", {zipcode: 1})
```

**Move a chunk to a different shard:**
```js
sh.moveChunk("mydb.coll", { zipcode: "53187" }, "shard0019")
```

**Split a chunk at a specific point:**
```js
sh.splitAt("mydb.coll", {x: 70})
```

**Split a chunk based on a query:**
```js
sh.splitFind("mydb.coll", {x: 70})
```

**Start and stop the balancer:**
```js
sh.startBalancer()
sh.stopBalancer()
```

**Enable and disable balancing for a collection:**
```js
sh.disableBalancing("mydb.coll")
sh.enableBalancing("mydb.coll")
```

**Get and set balancer state:**
```js
sh.getBalancerState()
sh.setBalancerState(true/false)
```

**Check if the balancer is running:**
```js
sh.isBalancerRunning()
```

**Start and stop auto-merger:**
```js
sh.startAutoMerger()
sh.stopAutoMerger()
```

**Enable and disable auto-merger:**
```js
sh.enableAutoMerger()
sh.disableAutoMerger()
```

**Update zone key range:**
```js
sh.updateZoneKeyRange("mydb.coll", {state: "NY", zip: MinKey }, { state: "NY", zip: MaxKey }, "NY")
```

**Remove range from zone:**
```js
sh.removeRangeFromZone("mydb.coll", {state: "NY", zip: MinKey }, { state: "NY", zip: MaxKey })
```

**Add and remove shard from zone:**
```js
sh.addShardToZone("shard0000", "NYC")
sh.removeShardFromZone("shard0000", "NYC")
```