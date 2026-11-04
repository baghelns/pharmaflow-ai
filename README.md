# pharmaflow-ai
Elevox Data Engineering

## Run the PharmaFlow Foundation pipeline
 
```
python scripts/ingest.py           # 300 raw reports from the practice API
python scripts/clean.py            # 191 usable reports, cleaned
python scripts/store_and_query.py  # Parquet + top 10 drugs: "Pipeline OK"
```