"""
Load the raw CSV into SQLite, run the cleaning and aggregation SQL,
and export an Excel workbook that Power BI can import.

Usage:  python scripts/build_database.py
"""
import sqlite3
from pathlib import Path

import pandas as pd
from openpyxl import load_workbook
from openpyxl.utils import get_column_letter
from openpyxl.worksheet.table import Table, TableStyleInfo

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data" / "raw_mumbai_pm_daily.csv"
DB = ROOT / "database" / "mumbai_aqi.db"
XLSX = ROOT / "output" / "Mumbai_AQI_Analysis.xlsx"

SHEETS = {  # Excel sheet name -> SQL table
    "Clean_Data": "clean_readings",
    "Monthly_Station": "agg_monthly_station",
    "Season_Station": "agg_season_station",
    "Station_Summary": "agg_station_summary",
    "AQI_Category_Monthly": "agg_category_monthly",
}


def format_excel(path):
    """Turn each sheet into a filterable Excel table with sensible column widths."""
    wb = load_workbook(path)
    for ws in wb.worksheets:
        ref = f"A1:{get_column_letter(ws.max_column)}{ws.max_row}"
        table = Table(displayName=ws.title, ref=ref)
        table.tableStyleInfo = TableStyleInfo(name="TableStyleMedium2", showRowStripes=True)
        ws.add_table(table)
        ws.freeze_panes = "A2"
        for col_cells in ws.columns:
            width = max(len(str(c.value)) if c.value is not None else 0 for c in col_cells)
            ws.column_dimensions[col_cells[0].column_letter].width = min(max(width + 2, 10), 30)
    wb.save(path)


def main():
    DB.parent.mkdir(parents=True, exist_ok=True)
    XLSX.parent.mkdir(parents=True, exist_ok=True)
    if DB.exists():
        DB.unlink()
    conn = sqlite3.connect(DB)

    # 1. Load raw data as text so messy values survive the load
    raw = pd.read_csv(RAW, dtype=str, keep_default_na=False)
    raw.to_sql("raw_readings", conn, index=False)
    print(f"Raw rows loaded:        {len(raw):,}")

    # 2. Clean and aggregate in SQL
    for script in ["01_clean.sql", "02_aggregates.sql"]:
        conn.executescript((ROOT / "sql" / script).read_text())
        print(f"Ran sql/{script}")

    clean_n = conn.execute("SELECT COUNT(*) FROM clean_readings").fetchone()[0]
    nulls = conn.execute(
        "SELECT SUM(pm25 IS NULL), SUM(pm10 IS NULL) FROM clean_readings").fetchone()
    print(f"Clean station-day rows: {clean_n:,}  (missing PM2.5: {nulls[0]}, missing PM10: {nulls[1]})")

    print("\nAverage by station (whole period):")
    print(pd.read_sql("SELECT * FROM agg_station_summary", conn).to_string(index=False))

    # 3. Export to Excel for Power BI
    with pd.ExcelWriter(XLSX, engine="openpyxl") as writer:
        for sheet, table in SHEETS.items():
            df = pd.read_sql(f"SELECT * FROM {table}", conn)
            if "reading_date" in df.columns:
                df["reading_date"] = pd.to_datetime(df["reading_date"])
            df.to_excel(writer, sheet_name=sheet, index=False)
    conn.close()
    format_excel(XLSX)
    print(f"\nDatabase  -> {DB}")
    print(f"Workbook  -> {XLSX}")


if __name__ == "__main__":
    main()
