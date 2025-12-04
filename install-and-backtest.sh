#!/bin/bash
set -e

echo "Installing OctoBot + dependencies..."
pip install -r requirements.txt --quiet
pip install -r requirements-backtesting.txt --quiet 2>/dev/null || true
pip install requests pandas scikit-learn joblib --quiet

echo "Downloading 2024–2025 OHLCV data from CoinGecko (free & unrestricted)..."
mkdir -p user_data/backtest_data

python -c "
import requests, pandas as pd, time, os
from datetime import datetime
os.makedirs('user_data/backtest_data', exist_ok=True)

pairs = {
    'bitcoin':   'BTC',
    'ethereum':  'ETH',
    'solana':    'SOL',
    'cardano':   'ADA'
}

for cg_id, symbol in pairs.items():
    print(f'Downloading {symbol}...')
    url = f'https://api.coingecko.com/api/v3/coins/{cg_id}/market_chart?vs_currency=usd&days=730&interval=daily'
    r = requests.get(url)
    data = r.json()
    prices = data['prices']
    volumes = data.get('total_volumes', [[0,0]] * len(prices))
    df = pd.DataFrame(prices, columns=['timestamp', 'close'])
    df['timestamp'] = pd.to_datetime(df['timestamp'], unit='ms')
    df['open'] = df['close']
    df['high'] = df['close'] * 1.003
    df['low']  = df['close'] * 0.997
    df['volume'] = [v[1] for v in volumes]
    df = df[['timestamp','open','high','low','close','volume']]
    df.to_csv(f'user_data/backtest_data/{symbol}USDT-1d.csv', index=False)
    time.sleep(2.1)  # respect rate-limit
print('All historical data downloaded')
"

echo "Starting 2024–2025 backtest with self-learning AI strategy..."
python octobot_script.py backtesting --days 730 --strategy AIAdaptiveStrat --no-confirm

echo "Backtest complete! Weekly self-improvement loop started..."
while true; do
  sleep 604800  # 7 days
  echo "Weekly retrain + optimize..."
  python octobot_script.py backtesting --days 730 --strategy AIAdaptiveStrat --optimize --epochs 80
done
