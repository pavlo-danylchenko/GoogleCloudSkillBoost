#!/bin/bash
set -euo pipefail

# Create ML Models with BigQuery ML: Challenge Lab

echo "======================================================================"
echo "            Task 0. Detecting project IDs, regions and zones"
echo "                     Setting up the environment"
echo "======================================================================"

gcloud services enable \
    bigquery.googleapis.com

export ZONE=$(gcloud compute project-info describe \
    --format="value(commonInstanceMetadata.items[google-compute-default-zone])")
export REGION=$(echo $ZONE | cut -d '-' -f 1-2)

echo $ZONE
echo $REGION

gcloud config set compute/zone $ZONE
gcloud config set compute/region $REGION
gcloud config set run/region $REGION


echo "======================================================================"
echo "       Task 1. Create a new dataset and machine learning model"
echo "======================================================================"
bq --location=$REGION mk --dataset $DEVSHELL_PROJECT_ID:ecommerce

bq query --use_legacy_sql=false \
"
CREATE OR REPLACE MODEL \`ecommerce.customer_classification_model\`
    OPTIONS
    (
    model_type='logistic_reg',
    labels = ['will_buy_on_return_visit']
    )
    AS

    #standardSQL
    SELECT
    * EXCEPT(fullVisitorId)
    FROM

    # features
    (SELECT
        fullVisitorId,
        IFNULL(totals.bounces, 0) AS bounces,
        IFNULL(totals.timeOnSite, 0) AS time_on_site
    FROM
        \`data-to-insights.ecommerce.web_analytics\`
    WHERE
        totals.newVisits = 1
        AND date BETWEEN '20160801' AND '20170430')
    JOIN
    (SELECT
        fullvisitorid,
        IF(COUNTIF(totals.transactions > 0 AND totals.newVisits IS NULL) > 0, 1, 0) AS will_buy_on_return_visit
    FROM
        \`data-to-insights.ecommerce.web_analytics\`
    GROUP BY fullvisitorid)
    USING (fullVisitorId);
"


echo "======================================================================"
echo "         Task 2. Evaluate classification model performance"
echo "======================================================================"
bq query --use_legacy_sql=false \
"
SELECT
  roc_auc,
  CASE
    WHEN roc_auc > .9 THEN 'good'
    WHEN roc_auc > .8 THEN 'fair'
    WHEN roc_auc > .7 THEN 'decent'
    WHEN roc_auc > .6 THEN 'not great'
  ELSE 'poor' END AS model_quality
FROM
  ML.EVALUATE(MODEL \`ecommerce.customer_classification_model\`,  (

SELECT
  * EXCEPT(fullVisitorId)
FROM

  # features
  (SELECT
    fullVisitorId,
    IFNULL(totals.bounces, 0) AS bounces,
    IFNULL(totals.timeOnSite, 0) AS time_on_site
  FROM
    \`data-to-insights.ecommerce.web_analytics\`
  WHERE
    totals.newVisits = 1
    AND date BETWEEN '20170501' AND '20170630')
  JOIN
  (SELECT
    fullvisitorid,
    IF(COUNTIF(totals.transactions > 0 AND totals.newVisits IS NULL) > 0, 1, 0) AS will_buy_on_return_visit
  FROM
      \`data-to-insights.ecommerce.web_analytics\`
  GROUP BY fullvisitorid)
  USING (fullVisitorId)
));
"

echo "======================================================================"
echo "Task 3. Improve model performance with Feature Engineering and Evaluate"
echo "      the model to see if there is better predictive power"
echo "======================================================================"
bq query --use_legacy_sql=false \
"
CREATE OR REPLACE MODEL \`ecommerce.improved_customer_classification_model\`
OPTIONS
  (model_type='logistic_reg', labels = ['will_buy_on_return_visit']) AS
WITH all_visitor_stats AS (
SELECT
  fullvisitorid,
  IF(COUNTIF(totals.transactions > 0 AND totals.newVisits IS NULL) > 0, 1, 0) AS will_buy_on_return_visit
FROM \`data-to-insights.ecommerce.web_analytics\`
GROUP BY fullvisitorid
)
SELECT * EXCEPT(unique_session_id) FROM (
  SELECT
      CONCAT(fullvisitorid, CAST(visitId AS STRING)) AS unique_session_id,
      will_buy_on_return_visit,
      MAX(CAST(h.eCommerceAction.action_type AS INT64)) AS latest_ecommerce_progress,
      IFNULL(totals.bounces, 0) AS bounces,
      IFNULL(totals.timeOnSite, 0) AS time_on_site,
      IFNULL(totals.pageviews, 0) AS pageviews,
      trafficSource.source,
      trafficSource.medium,
      channelGrouping,
      device.deviceCategory,
      IFNULL(geoNetwork.country, '') AS country
  FROM \`data-to-insights.ecommerce.web_analytics\`,
    UNNEST(hits) AS h
    JOIN all_visitor_stats USING(fullvisitorid)
  WHERE 1=1
    AND totals.newVisits = 1
    AND date BETWEEN '20160801' AND '20170430'
  GROUP BY
  unique_session_id,
  will_buy_on_return_visit,
  bounces,
  time_on_site,
  totals.pageviews,
  trafficSource.source,
  trafficSource.medium,
  channelGrouping,
  device.deviceCategory,
  country
);
"


bq query --use_legacy_sql=false \
"
SELECT roc_auc, accuracy FROM ML.EVALUATE(MODEL \`ecommerce.improved_customer_classification_model\`, (
  WITH all_visitor_stats AS (
  SELECT
    fullvisitorid,
    IF(COUNTIF(totals.transactions > 0 AND totals.newVisits IS NULL) > 0, 1, 0) AS will_buy_on_return_visit
  FROM \`data-to-insights.ecommerce.web_analytics\`
  GROUP BY fullvisitorid
  )
  SELECT * EXCEPT(unique_session_id) FROM (
    SELECT
        CONCAT(fullvisitorid, CAST(visitId AS STRING)) AS unique_session_id,
        will_buy_on_return_visit,
        MAX(CAST(h.eCommerceAction.action_type AS INT64)) AS latest_ecommerce_progress,
        IFNULL(totals.bounces, 0) AS bounces,
        IFNULL(totals.timeOnSite, 0) AS time_on_site,
        IFNULL(totals.pageviews, 0) AS pageviews,
        trafficSource.source,
        trafficSource.medium,
        channelGrouping,
        device.deviceCategory,
        IFNULL(geoNetwork.country, '') AS country
    FROM \`data-to-insights.ecommerce.web_analytics\`,
      UNNEST(hits) AS h
      JOIN all_visitor_stats USING(fullvisitorid)
    WHERE 1=1
      AND totals.newVisits = 1
      AND date BETWEEN '20170501' AND '20170630'
    GROUP BY
    unique_session_id,
    will_buy_on_return_visit,
    bounces,
    time_on_site,
    totals.pageviews,
    trafficSource.source,
    trafficSource.medium,
    channelGrouping,
    device.deviceCategory,
    country
  )
));
"


echo "======================================================================"
echo "    Task 4. Predict which new visitors will come back and purchase"
echo "======================================================================"
bq query --use_legacy_sql=false \
"
CREATE OR REPLACE MODEL \`ecommerce.finalized_classification_model\`
OPTIONS
  (model_type='logistic_reg', labels = ['will_buy_on_return_visit']) AS
WITH all_visitor_stats AS (
SELECT
  fullvisitorid,
  IF(COUNTIF(totals.transactions > 0 AND totals.newVisits IS NULL) > 0, 1, 0) AS will_buy_on_return_visit
FROM \`data-to-insights.ecommerce.web_analytics\`
GROUP BY fullvisitorid
)
SELECT * EXCEPT(unique_session_id) FROM (
  SELECT
      CONCAT(fullvisitorid, CAST(visitId AS STRING)) AS unique_session_id,
      will_buy_on_return_visit,
      MAX(CAST(h.eCommerceAction.action_type AS INT64)) AS latest_ecommerce_progress,
      IFNULL(totals.bounces, 0) AS bounces,
      IFNULL(totals.timeOnSite, 0) AS time_on_site,
      IFNULL(totals.pageviews, 0) AS pageviews,
      trafficSource.source,
      trafficSource.medium,
      channelGrouping,
      device.deviceCategory,
      IFNULL(geoNetwork.country, '') AS country
  FROM \`data-to-insights.ecommerce.web_analytics\`,
    UNNEST(hits) AS h
    JOIN all_visitor_stats USING(fullvisitorid)
  WHERE 1=1
    AND totals.newVisits = 1
    AND date BETWEEN '20160801' AND '20170430'
  GROUP BY
  unique_session_id,
  will_buy_on_return_visit,
  bounces,
  time_on_site,
  totals.pageviews,
  trafficSource.source,
  trafficSource.medium,
  channelGrouping,
  device.deviceCategory,
  country
);
"


bq query --use_legacy_sql=false \
"
SELECT
  *
FROM
  ml.PREDICT(MODEL \`ecommerce.finalized_classification_model\`,
   (
   WITH all_visitor_stats AS (
SELECT
  fullvisitorid,
  IF(COUNTIF(totals.transactions > 0 AND totals.newVisits IS NULL) > 0, 1, 0) AS will_buy_on_return_visit
  FROM \`data-to-insights.ecommerce.web_analytics\`
  GROUP BY fullvisitorid
)

  SELECT * EXCEPT(unique_session_id) FROM (

    SELECT
        CONCAT(fullvisitorid, CAST(visitId AS STRING)) AS unique_session_id,

        # labels
        will_buy_on_return_visit,

        MAX(CAST(h.eCommerceAction.action_type AS INT64)) AS latest_ecommerce_progress,

        # behavior on the site
        IFNULL(totals.bounces, 0) AS bounces,
        IFNULL(totals.timeOnSite, 0) AS time_on_site,
        IFNULL(totals.pageviews, 0) AS pageviews,

        # where the visitor came from
        trafficSource.source,
        trafficSource.medium,
        channelGrouping,

        # mobile or desktop
        device.deviceCategory,

        # geographic
        IFNULL(geoNetwork.country, \"\") AS country

    FROM \`data-to-insights.ecommerce.web_analytics\`,
      UNNEST(hits) AS h

      JOIN all_visitor_stats USING(fullvisitorid)

    WHERE 1=1
      # only predict for new visits
      AND totals.newVisits = 1
      AND date BETWEEN \"20170701\" AND \"20170801\" # predict 1 month

    GROUP BY
    unique_session_id,
    will_buy_on_return_visit,
    bounces,
    time_on_site,
    totals.pageviews,
    trafficSource.source,
    trafficSource.medium,
    channelGrouping,
    device.deviceCategory,
    country
  )
  )
)
ORDER BY
  predicted_will_buy_on_return_visit DESC;
"

echo "======================================================================"
echo "                          JOB is DONE !!!"
echo "======================================================================"