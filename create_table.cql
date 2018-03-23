CREATE KEYSPACE if not exists avro WITH REPLICATION = { 'class' : 'SimpleStrategy', 'replication_factor' : '1' };
drop table avro.cctest;
CREATE TABLE avro.cctest (transaction_date text, 
card_number text, 
card_expiry_date text, 
purchase_amount double, 
description text, 
card_security_code text, 
credit_card_type text, 
PRIMARY KEY(card_number,transaction_date));
