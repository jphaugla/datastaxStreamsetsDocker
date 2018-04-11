# DataStax with Streamsets
Purpose of this project is to serve as an example for how to implement DataStax and Streamsets using docker images provided by DataStax, streamsets and open source Kafka.

Four docker images  are used:   
DataStax Server, Kafka, zookeeper, and Streamsets data collector.   

The DataStax images are well documented at this github location  [https://github.com/datastax/docker-images/]()

Creating custom Kafka producers and consumers can be an arduous process that requires manual coding. In this tutorial, a StreamSets Data Collector is used to create data ingest pipelines to write to Kafka using a Kafka Producer.  Then, a separate StreamSets pipeline reads from Kafka with a Kafka Consumer and writes to Cassandra with no handwritten code.  This Kafka consumer performs conversions of the data before writing the data to Cassandra.

![StreamsConsumer](README.photos/StreamsSetsBoth.png)

Test data came from a streamsets tutorial github but I have copied the data into this github.
 [https://github.com/streamsets/tutorials/blob/master/sample_data/](sample_data)



## Getting Started
1. Prepare Docker environment
2. Pull this github into a directory  
    ```bash
    git clone https://github.com/jphaugla/datastaxStreamsetsDocker.git
    ```
3. Follow notes from DataStax Docker github to pull the needed DataStax images.  Directions are here:  [https://github.com/datastax/docker-images/#datastax-platform-overview]().  Don't get too bogged down here.  The pull command is provided with this github in pull.sh. It is requried to have the docker login and subscription complete before running the pull.  The included docker-compose.yaml handles most everything else.
4. To run the docker images, open terminal and type: `docker-compose up -d`
5. Verify DataStax is working for the DataStax hosts (this make take a minute or two for images and Cassandra to start):
```bash
docker exec dse cqlsh -u cassandra -p cassandra -e "desc keyspaces";
```
6. Add avro tables and keyspace for later DSE Search testing:
```bash
docker cp src/create_table.cql dse:/opt/dse;
docker exec dse cqlsh -f /opt/dse/create_table.cql
```
7. Verify table exists:
```bash
docker exec dse cqlsh -e "desc avro.cctest"
```
8. Create the directory and add the avro source file to the streamsets datacollector
```bash
docker cp src/data/ccsample streamdc:/home/sdc/tutorial/origin2;
```

## Streamsets Pipelines

As an alternative to creating these pipelines, the pipelines are exported in the exports directory.  

Streamsets pipeline documentation can be found here:

https://streamsets.com/documentation/datacollector/latest/help/#datacollector/UserGuide/Pipeline_Design/What_isa_Pipeline.html

A pipeline describes the flow of data from the origin system to destination systems and defines how to transform the data along the way.

We will have a pipeline to pull data from an avro file and add it to kafka.  Then, a second pipeline will pull data from kafka and write to DataStax Cassandra

## Open up the Streamsets Data Collector Interface

* Bring up the Streamsets Data Collector from the browser with localhost:18630 using *admin* as both the username and the password

## Add Additional Libraries to Stage Libraries section

The package manager makes stage libraries available to pipelines.  The following three stage libraries need to be added for the subsequent pipelines.

1. Click on *Package Manager* icon ![Package Manager](README.photos/icon_PackageManager.png)
2. Select Apache Kafka version (0.10.0.0 for example)
3. click the ellipsis buttons and select install
4. click *Restart Data Collector*
5. log back in to Streamsets Data collector
6. Select latest *Jython* and install, restart, login
7. Select latest *Cassandra Java Driver* and install, restart, login

## Create Kafka producer pipeline

When completed, the pipeline will look like this:
![StreamsProducer](README.photos/StreamSetsAvro.png)

### Creating a Pipeline

* Create a new Pipeline by clicking the **Create New Pipeline** button to bring up the New Pipeline dialog box.  Enter a Title and Description for the Pipeline and click **Save**.
![Streamsets Pipeline](README.photos/StreamsetsNewPipeline.png)
### Defining the Source
* Drag the **Directory** origin stage into your canvas.
* In the Configuration settings below, select the *Files* tab.
* Enter the following settings:
![Kafka Directory](README.photos/KafkaProducerDirectory.png)
 * **Files Directory** - The absolute file path to the directory containing the sample .avro files.
 * **File Name Pattern** - `cc*` - 
 *The ccdata file in the samples directory is a bzip2 compressed Avro file.*  Data Collector will automatically detect and decrypt it on the fly.

In the data format tab, choose Avro.

* In the *Post Processing* tab make sure **File Post Processing** is set to None.

*Note: The Avro files already contain the schema that the origin will pick up and decode on the fly. If you'd like to override the default schema, enter the custom schema in the Avro tab.*


### Defining the Kafka Producer

1. Drag a **Kafka** Producer Destination to the canvas and connect the Directory to the Kafka Producer
2. Click on the Kafka Producer.  
3. Go to the Kafka tab and set the Broker URI property to point to your Kafka broker e.g.`kafka1:9092`. Set Topic to the name of your Kafka topic (TestRun). And set Data Format to SDC Record.
![Kafka Producer](README.photos/KafkaProducer.png)
4. In the *Data Format* tab, choose SDC Record
*SDC Record is the internal data format that is highly optimized for use within StreamSets Data Collector (SDC). Since we are going to be using another Data Collector pipeline to read from this Kafka topic we can use SDC Record to optimize performance. If you have a custom Kafka Consumer on the other side you may want to use one of the other data formats and decode it accordingly.*
5. Click on the pipeline canvas, got to the *Error Records* tab, choose to discard the error messages

The pipeline is now ready to feed messages into Kafka.

#### Preview the Data
* Feel free to hit the Preview icon to examine the data before executing the pipeline.

#### Execute the Pipeline
* Hit the Start icon. If your Kafka server is up and running, the pipeline should start sending data to Kafka.  Watching the metrics, 10,000 rows should go to the producer.  Stop the Pipelin using the red stop rectangle.  To rerun at a later time, make sure to *reset origin* (under the ellipsis) to restart the load from the beginning.

## Create Kafka Consumer

Once stage properties are added, the pipeline will look like this:
![Streamsets Pipeline](README.photos/StreamsetsCassandraPipeline.png)

1.  Create another New Pipeline *Kafka to Cassandra*
2.  Add the **Kafka** consumer origin to the canvas
3.  Provide the following information under the **Kafka** tab of the **Kafka** origin.
![Kafka Origin](README.photos/KafkaOriginTab.png)
Choose SDC Record under the Data Format tab
4. Add the *Processor* called *Field Type Converter* to the Pipeline and connect it to the Kafka Consumer
5. For the Field Type Conversion, add the following conversion type information![Field Type Conversion](README.photos/FieldTypeConvert.png)
6. Add the *Processor* called *Jython Evaluator* and connect it to the *Field Type Converter*
7. In the *jython* tab of the *Jython Evaluator*, enter the following code
```python

for record in records:
  try:
    cc = record.value['card_number']
    if cc == '':
      error.write(record, "Credit Card Number was null")
      continue

    cc_type = ''
    if cc.startswith('4'):
      cc_type = 'Visa'
    elif cc.startswith(('51','52','53','54','55')):
      cc_type = 'MasterCard'
    elif cc.startswith(('34','37')):
      cc_type = 'AMEX'
    elif cc.startswith(('300','301','302','303','304','305','36','38')):
      cc_type = 'Diners Club'
    elif cc.startswith(('6011','65')):
      cc_type = 'Discover'
    elif cc.startswith(('2131','1800','35')):
      cc_type = 'JCB'
    else:
      cc_type = 'Other'

    record.value['credit_card_type'] = cc_type
    output.write(record)

  except Exception as e:
    # Send record to error
    error.write(record, str(e))
```
8. Add the *Destination* called *Cassandra Java Driver* and connect it to the *Field Type Converter*
9. Add the following **Required Fields** in the Cassandra Destination General Tab (without this step the pipeline will not populate Cassandra)
![Streamsets Pipeline](README.photos/StreamsetsCassandraRequired.png)
6. In the Cassandra Destination **Cassandra** Tab:  
  * Add **dse** as the contact point
  * V4 as the protocol version
![Streamsets Pipeline](README.photos/StreamsetsCassandraColumns.png)
5. Click on the pipeline canvas, got to the *Error Records* tab, choose to discard the error messages
7. Start both of the pipleines (start *Kafka to Cassandra* before starting *Avro to Cassandra*).  If records don't flow, try stopping, resetting the origin, and starting the *Avro to Kafka* pipeline while leaving the *Kafka to Cassandra* pipeline running
8. Ensure Data flowed into the cassandra table
```bash
docker exec dse cqlsh -e "select * from avro.cctest"
```
## Completed!
