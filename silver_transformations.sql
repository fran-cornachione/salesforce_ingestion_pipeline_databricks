-- Contacts
CREATE OR REFRESH LIVE TABLE 
  salesforce.silver.contacts_silver
AS SELECT
  Id,
  AccountId,
  initcap(LastName) AS LastName, -- John doe -> John Doe
  initcap(FirstName) AS FirstName, -- john Doe -> John Doe
  MailingStreet,
  MailingCity,
  MailingState,
  MailingPostalCode,
  MailingCountry,
  Phone,
  Email,
  Title,
  LeadSource,
  CreatedDate,
  LastModifiedDate
FROM
  salesforce.bronze.contact;

-- Leads
CREATE OR REFRESH LIVE TABLE 
  salesforce.silver.leads_silver
AS SELECT
  Id,
  LastName,
  FirstName,
  Title,
  Company,
  Street,
  City,
  State,
  PostalCode,
  Country,
  Phone,
  Email,
  Website,
  Status,
  Rating,
  ROUND(AnnualRevenue, 2) AS AnnualRevenue,
  NumberOfEmployees,
  CreatedDate,
  CASE
    WHEN AnnualRevenue > 1000000 THEN True
    ELSE False
  END AS 
    IsPriorityRecord
FROM 
  salesforce.bronze.lead;

-- Opportunities 
CREATE OR REFRESH LIVE TABLE
  salesforce.silver.opportunities_silver
AS SELECT
  Id,
  AccountId,
  Name,
  StageName,
  ROUND(Amount, 2) AS Amount,
  Probability,
  CloseDate,
  NextStep,
  LeadSource,
  IsClosed,
  IsWon,
  CreatedDate,
  LastModifiedDate,
  ForecastCategory
FROM
  salesforce.bronze.opportunity;