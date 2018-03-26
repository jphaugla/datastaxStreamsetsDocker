# DataStax with Streamsets
Purpose of this project is to serve as an example for how to implement DataStax and Streamsets using docker images provided by DataStax, streamsets and open source Kafka.

Four docker images  are used:   
DataStax Server, Kafka, zookeeper, and streamsets data collector. The DataStax will be a two node cluster.  
The two nodes are needed to test the ability of streamsets to cope with the replication factor used in datastax handling and consolidating the separate replication writes to each node to one addition to the kafka topic.
This set of nodes barely run on a macbook pro with 16GB of RAM.  Close all apps not in use to allow this to execute.  Deleting the second dse node allows the rest of the containers to run comfortably.  

The DataStax images are well documented at this github location  [https://github.com/datastax/docker-images/]()

A large portion of this demo is based on this kafka/streamsets tutorial:

https://github.com/streamsets/tutorials/tree/master/tutorial-2

## Getting Started
1. Prepare Docker environment
2. Pull this github into a directory  `git clone https://github.com/jphaugla/datastaxStreamsetsDocker.git`
3. Follow notes from DataStax Docker github to pull the needed DataStax images.  Directions are here:  [https://github.com/datastax/docker-images/#datastax-platform-overview]().  Don't get too bogged down here.  The pull command is provided with this github in pull.sh. It is requried to have the docker login and subscription complete before running the pull.  The included docker-compose.yaml handles most everything else.
4. Open terminal, then: `docker-compose up -d`
5. Verify DataStax is working for both hosts:
```
docker exec dse cqlsh -u cassandra -p cassandra -e "desc keyspaces";
```
```
docker exec dse2 cqlsh -u cassandra -p cassandra -e "desc keyspaces"
```
6. Add avro tables and keyspace for later DSE Search testing:
```
docker cp src/create_table.cql dse:/opt/dse
docker exec dse cqlsh -f /opt/dse/create_table.cql
```

## enable change data capture

export the cassandra.yaml file for each node, edit the yaml for each node to enable change data capture, and restart the docker nodes

1. export the cassandra.yaml from one node into the appropriate nodes conf file`
```
docker cp dse:/opt/dse/resources/cassandra/conf/cassandra.yaml conf;
```
```
docker cp dse2:/opt/dse/resources/cassandra/conf/cassandra.yaml conf2
```
2. edit each cassandra.yaml file to enable change data capture.  Set cdc_enabled to true and uncommand the cdc_total_spacke_in_mb and cdc_free_space_check_intreval_ms.  Reference the cassandra.diff file for details.
3. Enable change data capture on the avro.cctest table
```
docker exec dse cqlsh -e "alter table avro.cctest with cdc=true"
```
4. restart the docker containers using:
```
docker-compose down
```
```
docker-compose up -d
```

## Add Streamsets Pipelines

As an alternative to creating these pipelines, the pipelines are exported in the exports directory.

Streamsets pipeline documentation can be found here:

https://streamsets.com/documentation/datacollector/latest/help/#datacollector/UserGuide/Pipeline_Design/What_isa_Pipeline.html

A pipeline describes the flow of data from the origin system to destination systems and defines how to transform the data along the way.

We will have a pipeline to pull data from an avro file and add it to kafka.  Then, a second pipeline will pull data from kafka and write to DataStax Cassandra

This is close to what we will be doing except we will use Cassandra as the Destination instead of ElasticSearch and Amazon S3.

I also used Kafka 0.10

this provides the overview
https://github.com/streamsets/tutorials/tree/master/tutorial-2

Then the detail for each pipeline is here:

No changes needed for the avro to Kafka pipleline.  This document is from an older version of streamsets but the differences are minor.

https://github.com/streamsets/tutorials/blob/master/tutorial-2/directory_to_kafkaproducer.md


Since the second pipeline is going to ElasticSearch and Amazon S3, changes are needed to instead write to Cassandra

https://github.com/streamsets/tutorials/blob/master/tutorial-2/kafkaconsumer_to_multipledestinations.md

for this pipeline, we need some changes.  Follow these steps as documented:

1. Defining the source
2. Field Converter
3. Jython Evaluator

but skip the remaining steps.  Since we are using the card number as part of our primary key, we don't want to mask the card number.

4. Add the Cassandra Destination and connect it to the Jython Evaluator.  It should look like this:

![Streamsets Pipeline](README.photos/StreamsetsCassandraPipeline.png)

Add the following Required Fields in the Cassandra Destination General Tab (without this step the pipeline will not populate Cassandra)
![Streamsets Pipeline](README.photos/StreamsetsCassandraRequired.png)

In the Cassandra Destination "Cassandra" Tab:
1. Add "dse" as the contact point
2. V4 as the protocol version

Map the cassandra table as below:

![Streamsets Pipeline](README.photos/StreamsetsCassandraColumns.png)
5. Ensure Data flowed into the cassandra table
```
docker exec dse cqlsh -e "select * from avro.cctest"
```
6. Verify change data capture data has been written to the cdc directory.  Must do a nodetool flush to ensure data is written
```
docker exec dse nodetool flush
docker exec dse ls /var/lib/cassandra/cdc_raw
```

