aws marketplacecommerceanalytics generate-data-set `
--data-set-type "customer_subscriber_hourly_monthly_subscriptions" `
--data-set-publication-date "2020-04-15T00:00:00" `
--role-name-arn "arn:aws:iam::775488040364:role/MarketplaceCommerceAnalyticsRole" `
--destination-s3-bucket-name "marketplace-commerce-analytics-lansa" `
--destination-s3-prefix "test-prefix" `
--sns-topic-arn "arn:aws:sns:us-east-1:775488040364:marketplace-commerce-analytics-lansa" `
--region "us-east-1"