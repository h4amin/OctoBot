#!/bin/bash
set -e

echo "Installing OctoBot..."
pip install -r requirements.txt --quiet
pip install -r requirements-backtesting.txt --quiet 2>/dev/null || true
pip install requests pandas scikit-learn joblib --quiet

echo "Creating backtesting data folder..."
mkdir -p backtesting/data

echo "Downloading real 2024–2025 15m Kraken data (public, no API key)..."
python - <<'PY'
import requests, pandas as pd, time, os, numpy as np
os.makedirs('backtesting/data', exist_ok=True)

pairs = ["BTC/USDT","ETH/USDT","SOL/USDT","ADA/USDT"]
base = "https://api.kraken.com/0/public/OHLC"

for pair in pairs:
    symbol = pair.replace("/","")
    print(f"Downloading real {pair} 15m data...")
    all_df = []
    since = int(pd.Timestamp("2024-01-01").timestamp())
    while True:
        url = f"{base}?pair={symbol}&interval=15&since={since}"
        r = requests.get(url).json()
        if r["error"]: break
        df = pd.DataFrame(r["result"][symbol], columns=["ts","open","high","low","close","vwap","volume","count"])
        df = df[["ts","open","high","low","close","volume"]].astype({"open":float,"high":float,"low":float,"close":float,"volume":float})
        df["timestamp"] = pd.to_datetime(df["ts"], unit='s')
        all_df.append(df)
        if len(df) < 1000: break
        since = int(df["ts"].iloc[-1])
        time.sleep(1)
    if all_df:
        final = pd.concat(all_df).drop_duplicates().sort_values("timestamp")
        final = final[["timestamp","open","high","low","close","volume"]]
        final.to_csv(f'backtesting/data/{pair.replace("/","")}-15m.csv', index=False)
        print(f"{pair} saved ({len(final)} candles)")
PY

echo "Running offline backtest on real Kraken data..."
python octobot_script.py backtesting \
  --config config.json \
  --strategy AIAdaptiveStrat \
  --timeframe 15m \
  --days 730 \
  --no-confirm

echo "Backtest complete! Weekly loop started..."
while true; do
  sleep 604800
  echo "Weekly self-improvement..."
  python octobot_script.py backtesting --config config.json --strategy AIAdaptiveStrat --optimize --epochs 80 --no-confirm
done
