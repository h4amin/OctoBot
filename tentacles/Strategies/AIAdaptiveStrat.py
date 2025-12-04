from octobot_trading.modes import AbstractTradingMode
from octobot_trading.enums import TraderOrderType
from octobot_commons.logging import get_logger
import pandas as pd
import talib
import joblib
import os

class AIAdaptiveStrat(AbstractTradingMode):
    def __init__(self, config, exchange_manager):
        super().__init__(config, exchange_manager)
        self.logger = get_logger("AIAdaptiveStrat")
        self.model_path = "ai_model.pkl"
        self.model = joblib.load(self.model_path) if os.path.exists(self.model_path) else None

    def get_indicators(self, dataframe):
        df = dataframe.copy()
        df["rsi"] = talib.RSI(df["close"], 14)
        df["ema12"] = talib.EMA(df["close"], 12)
        df["ema26"] = talib.EMA(df["close"], 26)
        df["bb_upper"], df["bb_mid"], df["bb_lower"] = talib.BBANDS(df["close"])
        return df.dropna()

    async def create_order(self, symbol, order_type, price, amount):
        # Simple market order simulation for backtesting
        self.logger.info(f"BACKTEST ORDER: {order_type} {amount:.6f} {symbol.split('/')[0]} @ {price:.2f}")

    async def user_commands(self, command):
        if command == "retrain":
            df = self.get_indicators(self.exchange_manager.exchange_personal_data.portfolio_manager.historical_portfolio_value)
            if len(df) > 100:
                from sklearn.ensemble import RandomForestRegressor
                X = df[["rsi","ema12","ema26","bb_upper","bb_lower"]]
                y = (df["close"].shift(-24) / df["close"] - 1) * 100
                X, y = X[:-24], y[:-24]
                self.model = RandomForestRegressor(n_estimators=200)
                self.model.fit(X, y)
                joblib.dump(self.model, self.model_path)
                self.logger.info("AI model retrained and saved!")

    async def evaluate(self):
        df = self.get_indicators(self.candles_history)
        if len(df) == 0 or self.model is None:
            return

        latest = df.iloc[-1]
        pred = self.model.predict([[latest.rsi, latest.ema12, latest.ema26, latest.bb_upper, latest.bb_lower]])[0]

        if pred > 1.2 and latest.rsi < 68:
            await self.create_order(self.symbol, TraderOrderType.BUY_MARKET, latest.close, 0.02)
        elif pred < -1.0 or latest.rsi > 78:
            await self.create_order(self.symbol, TraderOrderType.SELL_MARKET, latest.close, 0.02)
