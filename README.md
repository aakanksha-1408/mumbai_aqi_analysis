# Mumbai Air Quality Trend Analysis

This project cleans and analyses daily PM2.5 and PM10 readings for Mumbai using SQL. It shows how pollution changes by month, season and station, and presents the results in an Excel workbook and an interactive dashboard.

> The data is **synthetic** and is for learning and demonstration only.

## Files

- `scripts/generate_sample_data.py`: creates the sample raw data
- `scripts/build_database.py`: loads the data, runs the SQL and exports Excel
- `sql/01_clean.sql`: cleaning and AQI categories
- `sql/02_aggregates.sql`: summary tables
- `index.html`: interactive dashboard (open in a browser)
- `Mumbai_AQI_Analysis.xlsx`: sample Excel output
- `requirements.txt`: Python dependencies

## How to run

```bash
pip install -r requirements.txt
python scripts/generate_sample_data.py
python scripts/build_database.py
```

Then open `index.html` in a browser to view the dashboard.

## Output

- SQLite database with cleaned and summary tables
- Excel workbook with the cleaned data and summaries
- Dashboard with Station and Month filters, KPI cards and charts
