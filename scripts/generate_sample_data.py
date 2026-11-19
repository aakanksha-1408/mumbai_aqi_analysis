"""
Generate a synthetic, CPCB-style daily PM2.5 / PM10 dataset for Mumbai (2023-2024).

Why synthetic? This environment could not download from data.gov.in, so this gives
you a realistic stand-in to run the whole project right away. To use real data,
see README.md > "Swapping in real CPCB data".
"""
from pathlib import Path
import numpy as np
import pandas as pd

RNG = np.random.default_rng(42)
ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "data" / "raw_mumbai_pm_daily.csv"

STATIONS = {  # station name -> relative pollution level
    "Bandra Kurla Complex": 1.15,
    "Chembur": 1.10,
    "Kurla": 1.12,
    "Andheri East": 1.00,
    "Mazgaon": 1.05,
    "Worli": 0.95,
    "Malad": 0.92,
    "Borivali": 0.85,
}

# Mumbai pattern: worst in winter (Nov-Feb), cleanest in monsoon (Jun-Sep)
MONTH_FACTOR = {1: 1.35, 2: 1.25, 3: 1.05, 4: 0.95, 5: 0.80, 6: 0.55,
                7: 0.45, 8: 0.45, 9: 0.55, 10: 0.90, 11: 1.40, 12: 1.45}


def main():
    dates = pd.date_range("2023-01-01", "2024-12-31", freq="D")
    rows = []
    for sid, (name, level) in enumerate(STATIONS.items(), start=1):
        for d in dates:
            mean25 = 42 * level * MONTH_FACTOR[d.month]
            pm25 = max(5.0, RNG.normal(mean25, mean25 * 0.25))
            pm10 = max(10.0, pm25 * RNG.uniform(1.6, 2.1))
            rows.append({"station_id": sid, "station_name": name,
                         "reading_date": d.strftime("%Y-%m-%d"),
                         "pm25": f"{pm25:.1f}", "pm10": f"{pm10:.1f}"})

    # Everything stored as text, like a raw portal export
    df = pd.DataFrame(rows)
    n = len(df)

    def pick(frac):
        return RNG.choice(n, size=int(frac * n), replace=False)

    # Add realistic messiness for the cleaning step
    df.loc[pick(0.03), "pm25"] = "NA"        # missing readings
    df.loc[pick(0.02), "pm10"] = ""          # blank cells
    df.loc[pick(0.005), "pm25"] = "-5"       # negative value = sensor fault
    df.loc[pick(0.003), "pm10"] = "999"      # spike = sensor error
    idx = pick(0.03)
    df.loc[idx, "station_name"] = df.loc[idx, "station_name"].str.upper() + " "  # messy labels
    df = pd.concat([df, df.sample(25, random_state=7)], ignore_index=True)       # duplicate rows

    OUT.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(OUT, index=False)
    print(f"Wrote {len(df):,} rows -> {OUT}")


if __name__ == "__main__":
    main()
