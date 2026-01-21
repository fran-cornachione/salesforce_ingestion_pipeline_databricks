## Salesforce Ingestion Pipeline (Lakehouse Architecture)

This projects aims to show the benefits of using a Lakehouse Architecture for pipelines, using Databricks to build a pipeline that ingests data from Salesforce

### Flow

The **Ingestion pipeline** extracts data from Salesforce into the bronze layer, then, an **ETL pipeline** processes and transforms that data in the silver layer, finally, bussiness logic is applied in the gold layer.

![img](Media\Diagram.jpg)

### Orchestration

Orchestration is managed by **Lakeflow Declarative Pipelines**, which defines the ingestion and transformation steps as a unified **DAG (Directed Acyclic Graph)**. The job uses a dependency-based scheduling model, currently running daily, ensuring the ETL starts immediately upon successful Bronze loading.

![img](Media\job_dag.png)

### The main problem this project solves:

#### Storage and Governance Duplication

- Traditional architectures require separate systems for Data Lake (e.g., S3/ADLS) and Data Warehouse (e.g., Redshift/BigQuery), leading to data redundancy and complex synchronization. A unified **Lakehouse Architecture** using **Unity Catalog** eliminates this duplication.

#### ETL and Orchestration Complexity

- Legacy pipelines require complex setup and management of separate ETL tools and orchestrators (Airflow / Fivetran / dbt).
- We leverage **Lakeflow Declarative Pipelines** to define the entire flow (Bronze **$\rightarrow$** Silver **$\rightarrow$** Gold) in a single, governed environment, simplifying scheduling and maintenance.

A unified Lakehouse is the best solution, everything is managed in one place: Connections, storage, orchestration and governance.

---

## Setting up the Ingestion Pipeline

#### 1. Connection

First, a Salesforce connection must be created:

Catalog → External Data → Connections → Create Connection

- **Connection Name:** The name of the connection (e.g: `Salesforce`, `salesforce_conn`)
- **Connection Type:** Salesforce

Then, authenticate with a Salesforce account.

#### 2. Ingestion Setup

Now, we have to create the Ingestion Pipeline:

Jobs & Pipelines → Ingestion Pipeline → Databricks Connectors → Salesforce

![img](Media\databricks_connectors.png)

- **Pipeline Name:** The name for the ingestion pipeline
- **Event Log Location:** The event log contains audit logs, data quality checks, pipeline progress, and errors

![img](Media\ingestion_setup.png)

#### 4. Source

Here, we specify what data will be ingested from Salesforce:

There are many tables that we can choose from Salesforce, in my case I used `Account`, `Opportunities`, `Contacts` and `Leads`.

#### 5. Destination

Specify where to store the ingested data in Databricks.

In this case, I created a catalog and three schemas following the **Medallion Architecture**:

```sql
CREATE CATALOG salesforce;
CREATE SCHEMA salesforce.bronze;
CREATE SCHEMA salesforce.silver;
CREATE SCHEMA salesforce.gold;
```

#### 6. Schedules and Notifications

In this step, we configure the pipeline schedules and notifications.

**Schedules**

In my case, I scheduled the pipeline to run every day at 00:00 (daily). But more advanced logic can be applied:

- **CRON Syntax:** We can use CRON if complex logic is needed, for example, running the pipeline daily, but only from Monday to Friday:

```
0 0 * * 1-5
```

- **Timezone:** A timezone can be selected, for example, `(UTC-06:00) Central TIme (US and Canada)`

**Notifications**

We can add multiple users to receive an email on pipeline **failure** or **success.**

![img](Media\notifications.png)

The ingestion pipeline can be also configured with YAML, the configuration is in the `ingestion_pipeline.yaml` file.

```yaml
resources:
  pipelines:
    pipeline_my_salesforce_pipeline:
      name: my_salesforce_pipeline
      ingestion_definition:
        connection_name: salesforce
        objects:
          - table:
              source_schema: objects
              source_table: Contact
              destination_catalog: salesforce
              destination_schema: bronze
          - table:
              source_schema: objects
              source_table: Lead
              destination_catalog: salesforce
              destination_schema: bronze
          - table:
              source_schema: objects
              source_table: Opportunity
              destination_catalog: salesforce
              destination_schema: bronze
          - table:
              source_schema: objects
              source_table: Account
              destination_catalog: salesforce
              destination_schema: bronze
        source_type: SALESFORCE
      schema: bronze
      development: false
      channel: CURRENT
      catalog: salesforce
      notifications:
        - email_recipients:
            - your_name_here@gmail.com
          alerts:
            - on-update-fatal-failure
```

---

When the pipeline is executed, we will see this:

![img](Media\ingestion_pipeline.png)

**4 Streaming tables were created** (one for each table in the ingestion stage).

Streaming tables updates only the new inserted records (`UPSERT`), if 100 leads were added yesterday, only 100 records will be processed, not the whole table.

The pipeline interface provides a real-time health check for every run:

* **Upserted (Green):** Only new or updated records from Salesforce are processed, ensuring efficient incremental loading.
* **Deleted (Orange):** Reflects records removed from the source to keep the Lakehouse synchronized.
* **Dropped (Grey):** A record is dropped when it doesn't pass a quality check (Expectation), For example, if we require an `Email` to create a Lead and it's missing, the pipeline drops that row automatically. This way, we guarantee that only high-quality data reaches the business.

---

## ETL Pipeline

To transform the raw data, I built an ETL pipeline. The transformations are performed in the Silver layer by using CTAS (`CREATE TABLE AS SELECT`).

![img](Media\Silver-Gold.png)

The DAG (Directed Acyclic Graph) shows the lineage of each View and its dependecies. This is another strenght of the medallion architecture. Gold depends on silver, and silver depends on bronze.

#### **Silver Layer: Data Cleansing & Standardization**

In this stage, raw data from Bronze is refined and cleaned.

- Selecting only necessaring columns: Some specific columns were not selected.

* Normalizing names: (e.g, john doe → John Doe)
* Rounding numeric values: (e.g, 34.999999 → 34.99)

#### Gold Layer: Bussiness Aggregations

In the Gold layer, I transformed the cleaned Silver data into a **Star Schema** designed for high-performance analytics. The primary goal was to convert raw CRM records into meaningful business metrics and structured entities.
