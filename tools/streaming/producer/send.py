import os, json, random, datetime as dt
from azure.eventhub import EventHubProducerClient, EventData

conn = os.environ["EH_CONN"]
producer = EventHubProducerClient.from_connection_string(conn)

now = dt.datetime.utcnow()

def make_trip(i):
    fare = round(random.uniform(6.0, 25.0), 2)
    tip  = round(random.uniform(0.0, 6.0), 2)
    tot  = round(fare + tip, 2)
    return {
        "vendor_id": "CMT",
        "pickup_datetime": (now + dt.timedelta(seconds=i)).isoformat() + "Z",
        "dropoff_datetime": (now + dt.timedelta(seconds=i+600)).isoformat() + "Z",
        "passenger_count": random.randint(1, 4),
        "trip_distance": round(random.uniform(0.5, 8.0), 2),
        "fare_amount": fare,
        "tip_amount": tip,
        "total_amount": tot,
        "payment_type": "CRD",
        "rate_code_id": 1,
        "store_and_fwd_flag": "N"
    }

events = [EventData(json.dumps(make_trip(i))) for i in range(5)]
with producer:
    producer.send_batch(events)

print(f"sent {len(events)} events")
