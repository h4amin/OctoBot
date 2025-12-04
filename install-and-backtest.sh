#!/bin/bash
set -e

echo "Installing OctoBot + backtesting deps..."
pip install -r requirements.txt --quiet
pip install -r requirements-backtesting.txt --quiet 2>/dev/null || true

echo "Downloading 2024–2025 15m data from Kraken (Canada-friendly)..."
python start.py download-data \
  --exchange kraken \
  --pairs BTC/USD,ETH/USD,SOL/USD,ADA/USD \
  --timeframe 15m \
  --start-date 20240101 \
  --end-date 20251201 \
  --no-confirm

echo "Installing AI strategy tentacle..."
python start.py tentacles --install AIAdaptiveStrat

echo "Running initial 2024–2025 backtest..."
python start.py backtesting \
  --strategy AIAdaptiveStrat \
  --timeframe 15m \
  --start-date 20240101 \
  --end-date 20251201 \
  --no-confirm \
  --export trades

echo "Backtest complete! Starting weekly self-improvement loop..."
while true; do
  sleep 604800  # 7 days
  echo "Weekly retrain + optimize..."
  python start.py backtesting \
    --strategy AIAdaptiveStrat \
    --optimize \
    --epochs 100 \
    --timeframe 15m \
    --start-date 20240101 \
    --end-date $(date +%Y%m%d) \
    --no-confirm
  echo "Optimization complete - new model deployed."
done
