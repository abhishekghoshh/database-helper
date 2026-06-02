let needsInitiate = false;

try {
    // If this succeeds, the replica set is already there
    rs.status();
    print("Replica set already initiated. Skipping...");
} catch (e) {
    // If it throws 'no replset config has been received', we need to initiate
    print("Replica set not found or not yet initialized. Proceeding with initiation...");
    needsInitiate = true;
}

if (needsInitiate) {
    // --- YOUR ORIGINAL CODE START ---
    rs.initiate({
      _id: "rs0",
      members: [
        { _id: 0, host: "mongo1:27017", priority: 2 }, 
        { _id: 1, host: "mongo2:27017", priority: 1 },
        { _id: 2, host: "mongo3:27017", priority: 1 }
      ]
    });
    // --- YOUR ORIGINAL CODE END ---
}

// Wait for the replica set to stabilize
let status = rs.status();
while (!status.ok || status.members.some(m => m.stateStr === "STARTUP" || m.stateStr === "STARTUP2")) {
  print("Waiting for replica set to stabilize...");
  sleep(2000);
  status = rs.status();
}
print("Replica set initialized and healthy.");