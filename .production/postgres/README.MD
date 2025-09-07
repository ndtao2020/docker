
# Replication, Clustering, and Connection Pooling

https://elroydevops.tech/postgresql-high-availability-master-slave/
https://wiki.postgresql.org/wiki/Replication,_Clustering,_and_Connection_Pooling
https://www.linode.com/docs/guides/comparison-of-high-availability-postgresql-solutions/

# High Availability (HA) Explained

High availability is all about designing a system to remain operational for as long as possible, minimizing downtime. In the context of a database, the goal is to ensure that if the primary (master) database goes offline, a replica (standby) can be promoted to take its place almost instantly, with minimal disruption to your applications. 🐘

## Key Components in the Setup

Achieving a robust HA PostgreSQL cluster on Docker Swarm involves three main components:

1. PostgreSQL: The database itself. You'll have one primary instance that handles all write operations and one or more standby instances that replicate data from the primary.

2. Docker Swarm: The container orchestrator. Swarm manages the lifecycle of your PostgreSQL containers (which it calls services). It ensures the desired number of replicas are always running and handles networking between them.

3. Replication Manager (e.g., Patroni): A crucial tool that runs alongside PostgreSQL. It continuously monitors the health of the primary database. If the primary fails, it automatically promotes the healthiest standby to become the new primary—a process called failover. It also reconfigures other standbys to start replicating from the new primary.

# Logical Replication vs. Streaming Replication

While PostgreSQL offers both, they serve different purposes.

* Streaming Replication (Physical): This is the most common method for HA. It replicates the entire database cluster at a low level (the WAL, or Write-Ahead Log). It's fast and creates a byte-for-byte identical copy. It's perfect for simple failover.

* Logical Replication: This method is more flexible. Instead of copying the physical data changes, it replicates the logical data changes (e.g., INSERT, UPDATE, DELETE statements). This allows you to:

    * Replicate only specific tables or databases.

    * Replicate between different major versions of PostgreSQL.

    * Send data to different kinds of systems (not just other PostgreSQL instances).

For a typical HA/failover setup, streaming replication is generally preferred due to its simplicity and performance. Logical replication is used for more advanced scenarios like data integration or selective replication.

# The Failover Process Step-by-Step

Here’s what happens when the primary PostgreSQL container fails in a setup managed by Patroni on Docker Swarm:

1. Failure Detection: Patroni, running in each container, constantly communicates with a distributed consensus store (DCS) like etcd or Consul. The primary node continuously renews a "leader lock" in the DCS. If the primary container crashes or the node goes down, it fails to renew this lock.

2. Leader Election: The standby Patroni instances notice the leader lock has expired. They start an election process using the DCS to choose a new leader among themselves. The replica with the most up-to-date data is typically chosen.

3. Promotion: The winning standby promotes itself to become the new primary. It takes over the leader lock and starts accepting write connections.

4. Reconfiguration: Patroni automatically reconfigures the other standby nodes (and the old primary, if it ever comes back online) to start replicating from the newly promoted primary.

5. Application Traffic Redirected: Your application, which should be configured to connect to a service endpoint (like a DNS name managed by Swarm that points to the current primary), will automatically be routed to the new primary database. This redirection is often handled by a simple load balancer or by the application reconnecting to the same database endpoint.

The entire process is automated and typically completes within seconds, ensuring your service experiences minimal downtime.

