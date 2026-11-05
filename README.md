# PharmaFlow Foundation: an openFDA adverse-event pipeline

[![View the notebook on nbviewer][badge]][nbviewer]

A Python and SQL pipeline that pulls drug adverse-event reports from the
openFDA API, cleans them, stores them as Parquet with DuckDB and answers
"which ten drugs have the most reports?". Built during the Elevox AI Academy
Data Engineering pathway (Stage 0).

![The five charts](data/processed/charts/foundation_5_charts.png)

## How to run it

In a GitHub Codespace (Python 3.11), from the repository folder:

    pip install -r requirements.txt
    python scripts/ingest.py           # 300 raw reports from the practice API
    python scripts/clean.py            # 191 usable reports, cleaned
    python scripts/store_and_query.py  # Parquet + top 10 drugs: "Pipeline OK"

`python scripts/ingest.py --live 1000` pulls from the real openFDA API.
The SQL library runs with `python week03/session_3_3/run_library.py` and
prints "Library OK". The charts are in
[notebooks/foundation_charts.ipynb](notebooks/foundation_charts.ipynb);
to rerun it, start JupyterLab with `jupyter lab --no-browser --port=8888`
and open the link it prints.

## What is in this repository

| Folder | What it holds |
|---|---|
| [scripts/](scripts/) | the pipeline: ingest, clean, store and query |
| [queries/](queries/) | the SQL library: ten documented business questions |
| [notebooks/](notebooks/) | the five-chart analysis for Medical Affairs |
| [data/raw/](data/raw/) | the input files, never changed |
| [data/processed/](data/processed/) | results: Parquet answers and charts |
| `week01/` to `week04/` | coursework, session by session |

[badge]: https://raw.githubusercontent.com/jupyter/design/master/logos/Badges/nbviewer_badge.svg
[nbviewer]: https://nbviewer.org/github/baghelns/pharmaflow-ai/blob/main/notebooks/foundation_charts.ipynb

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