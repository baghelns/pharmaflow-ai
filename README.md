# pharmaflow-ai
Elevox Data Engineering

## Data sources (added by the Data Manager)

- data/raw/openfda_practice_sample.json: 300 real openFDA reports, served
  by the practice API (Session 1.3)
- data/raw/adverse_events_10k.csv: 6,218 usable openFDA reports,
  2024-2026 (Week 2)

## Run the PharmaFlow Foundation pipeline
 
```
python scripts/ingest.py           # 300 raw reports from the practice API
python scripts/clean.py            # 191 usable reports, cleaned
python scripts/store_and_query.py  # Parquet + top 10 drugs: "Pipeline OK"
```