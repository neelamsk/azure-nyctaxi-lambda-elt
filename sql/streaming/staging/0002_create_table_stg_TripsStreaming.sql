
CREATE TABLE stg.TripsStreaming
(
  schemaVersion       NVARCHAR(100)  NULL,
  eventId             NVARCHAR(200)  NULL,
  tpepPickupDatetime  DATETIME2(3)   NOT NULL,
  tpepDropoffDatetime DATETIME2(3)   NOT NULL,
  vendorId            NVARCHAR(50)   NULL,
  passengerCount      BIGINT         NULL,
  tripDistance        FLOAT          NULL,
  puLocationId        BIGINT         NULL,
  doLocationId        BIGINT         NULL,
  fareAmount          FLOAT          NULL,
  tipAmount           FLOAT          NULL,
  tollsAmount         FLOAT          NULL,
  improvementSurcharge FLOAT         NULL,
  mtaTax              FLOAT          NULL,
  extra               FLOAT          NULL,
  totalAmount         FLOAT          NULL,
  paymentType         NVARCHAR(50)   NULL,
  source              NVARCHAR(100)  NULL,
  producerTs          DATETIME2(3)   NULL,
  enqueuedTs          DATETIME2(3)   NULL,
  durationMin         INT            NULL,
  -- ingestion metadata
  _ingestedAt         DATETIME2(3)   NOT NULL ,
  _blobPath           NVARCHAR(4000) NULL,
  _runId              NVARCHAR(200)  NULL
)
WITH (DISTRIBUTION = ROUND_ROBIN, HEAP);
