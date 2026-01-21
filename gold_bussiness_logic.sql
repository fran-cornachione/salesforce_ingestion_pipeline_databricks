CREATE OR REFRESH LIVE TABLE salesforce.gold.dim_leads AS
SELECT
  Id,
  FirstName,
  LastName,
  Company,
  Country,
  State,
  Rating,
  CASE
    WHEN Rating = 'Hot'  THEN 'High'
    WHEN Rating = 'Warm' THEN 'Medium'
    WHEN Rating = 'Cold' THEN 'Low'
    ELSE 'Unknown'
  END AS RatingCategory,
  NumberOfEmployees,
  CASE
    WHEN NumberOfEmployees >= 10000 THEN 'Enterprise'
    WHEN NumberOfEmployees BETWEEN 1000 AND 9999 THEN 'Mid-Market'
    WHEN NumberOfEmployees > 0 THEN 'SMB'
    ELSE 'Unknown'
  END AS CompanySizeBucket
FROM salesforce.silver.leads_silver;

CREATE OR REFRESH LIVE TABLE salesforce.gold.fact_opportunities AS
SELECT
    Id AS OpportunityKey,
    AccountId,             
    LeadSource,
    Amount,
    StageName,
    IsWon,
    CloseDate,
    CreatedDate,

    CASE WHEN IsWon = TRUE THEN Amount ELSE 0 END AS WonAmount,
    CASE WHEN IsClosed = TRUE AND IsWon = FALSE THEN Amount ELSE 0 END AS LostAmount
FROM salesforce.silver.opportunities_silver;

CREATE OR REFRESH LIVE TABLE salesforce.gold.lead_quality_score AS
SELECT
  Id,
  CASE
    WHEN Rating = 'Hot' AND NumberOfEmployees >= 10000 THEN 'High Priority'
    WHEN Rating = 'Warm' AND NumberOfEmployees BETWEEN 1000 AND 9999 THEN 'Medium Priority'
    WHEN Rating = 'Cold' THEN 'Low Priority'
    ELSE 'No Score'
  END AS LeadQualityScore
FROM salesforce.gold.dim_leads;

CREATE OR REFRESH LIVE TABLE salesforce.gold.marketing_efficiency AS
SELECT
  LeadSource,
  COUNT_IF(IsWon = TRUE) AS OpportunitiesWon,
  SUM(WonAmount) AS TotalWonValue,
  AVG(Amount) AS AvgOpportunityValue
FROM salesforce.gold.fact_opportunities
GROUP BY LeadSource;

CREATE OR REFRESH LIVE TABLE salesforce.gold.leads_by_state AS
SELECT
  Country,
  State,
  COUNT(Id) AS Leads
FROM salesforce.gold.dim_leads
GROUP BY Country, State;