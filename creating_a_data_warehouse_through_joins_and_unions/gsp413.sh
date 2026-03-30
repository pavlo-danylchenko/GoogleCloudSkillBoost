#!/bin/bash

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"
export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

gcloud config set compute/region $REGION
gcloud config set compute/zone $ZONE


echo "======================================================================"
echo "            Task 1. Create a new dataset to store your tables"
echo "======================================================================"
bq mk --location=US ecommerce

bq query --use_legacy_sql=false \
"
create or replace TABLE ecommerce.products AS
SELECT
*
FROM
\`data-to-insights.ecommerce.products\`;


SELECT
  SKU,
  name,
  sentimentScore,
  sentimentMagnitude
FROM
  \`data-to-insights.ecommerce.products\`
ORDER BY
  sentimentScore DESC
LIMIT 5'


SELECT
  SKU,
  name,
  sentimentScore,
  sentimentMagnitude
FROM
  \`data-to-insights.ecommerce.products\`
WHERE sentimentScore IS NOT NULL
ORDER BY
  sentimentScore
LIMIT 5;

# pull what sold on 08/01/2017
CREATE OR REPLACE TABLE ecommerce.sales_by_sku_20170801 AS
SELECT
  productSKU,
  SUM(IFNULL(productQuantity,0)) AS total_ordered
FROM
  \`data-to-insights.ecommerce.all_sessions_raw\`
WHERE date = '20170801'
GROUP BY productSKU
ORDER BY total_ordered DESC; #462 skus sold

# join against product inventory to get name
SELECT DISTINCT
  website.productSKU,
  website.total_ordered,
  inventory.name,
  inventory.stockLevel,
  inventory.restockingLeadTime,
  inventory.sentimentScore,
  inventory.sentimentMagnitude
FROM
  ecommerce.sales_by_sku_20170801 AS website
  LEFT JOIN \`data-to-insights.ecommerce.products\` AS inventory

ORDER BY total_ordered DESC;



# join against product inventory to get name
SELECT DISTINCT
  website.productSKU,
  website.total_ordered,
  inventory.name,
  inventory.stockLevel,
  inventory.restockingLeadTime,
  inventory.sentimentScore,
  inventory.sentimentMagnitude
FROM
  ecommerce.sales_by_sku_20170801 AS website
  LEFT JOIN \`data-to-insights.ecommerce.products\` AS inventory
  ON website.productSKU = inventory.SKU
ORDER BY total_ordered DESC;


# calculate ratio and filter
SELECT DISTINCT
  website.productSKU,
  website.total_ordered,
  inventory.name,
  inventory.stockLevel,
  inventory.restockingLeadTime,
  inventory.sentimentScore,
  inventory.sentimentMagnitude,
  SAFE_DIVIDE(website.total_ordered, inventory.stockLevel) AS ratio
FROM
  ecommerce.sales_by_sku_20170801 AS website
  LEFT JOIN \`data-to-insights.ecommerce.products\` AS inventory
  ON website.productSKU = inventory.SKU

# gone through more than 50% of inventory for the month
WHERE SAFE_DIVIDE(website.total_ordered,inventory.stockLevel) >= .50

ORDER BY total_ordered DESC;


CREATE OR REPLACE TABLE ecommerce.sales_by_sku_20170802
(
productSKU STRING,
total_ordered INT64
);


INSERT INTO ecommerce.sales_by_sku_20170802
(productSKU, total_ordered)
VALUES('GGOEGHPA002910', 101);


SELECT * FROM ecommerce.sales_by_sku_20170801
UNION ALL
SELECT * FROM ecommerce.sales_by_sku_20170802;


SELECT * FROM \`ecommerce.sales_by_sku_2017*\`;


SELECT * FROM \`ecommerce.sales_by_sku_2017*\`
WHERE _TABLE_SUFFIX = '0802';
"