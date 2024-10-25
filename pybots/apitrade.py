import pandas as pd
import numpy as np
import yfinance as yf
import backtrader as bt
import requests
import matplotlib.pyplot as plt

# Step 1: Fetch historical data
def fetch_data(symbol, start_date, end_date):
    data = yf.download(symbol, start=start_date, end=end_date)
    return data

# Step 2: Define the trading strategy
class MovingAverageCrossover(bt.Strategy):
    params = (("short_window", 50), ("long_window", 200),)

    def __init__(self):
        self.short_ma = bt.indicators.SimpleMovingAverage(
            self.data.close, period=self.params.short_window
        )
        self.long_ma = bt.indicators.SimpleMovingAverage(
            self.data.close, period=self.params.long_window
        )

    def next(self):
        if self.short_ma[0] > self.long_ma[0]:  # Buy signal
            if not self.position:
                self.buy()
        elif self.short_ma[0] < self.long_ma[0]:  # Sell signal
            if self.position:
                self.sell()

# Step 3: Function to place an order
def place_order(api_key, token, symbol, order_type='BUY', volume=1):
    url = "https://api.yourbroker.com/v1/orders"
    headers = {
        'X-IG-API-KEY': api_key,
        'Authorization': f"Bearer {token}",
        'Content-Type': 'application/json'
    }
    payload = {
        "epic": symbol,
        "size": volume,
        "direction": order_type,
        "orderType": "MARKET"
    }
    response = requests.post(url, headers=headers, json=payload)
    return response.json()

# Main function
def main():
    # Parameters
    symbol = '^DJI'  # Dow Jones Index
    start_date = '2020-01-01'
    end_date = '2023-01-01'
    api_key = 'YOUR_API_KEY'
    token = 'YOUR_ACCESS_TOKEN'
    
    # Fetch data
    data = fetch_data(symbol, start_date, end_date)

    # Set up backtesting
    cerebro = bt.Cerebro()
    cerebro.addstrategy(MovingAverageCrossover)

    # Load data into Backtrader
    data_feed = bt.feeds.PandasData(dataname=data)
    cerebro.adddata(data_feed)

    # Run backtest
    cerebro.run()
    cerebro.plot()

    # Place an order (uncomment to execute)
    # order_response = place_order(api_key, token, 'CS.D.US30.CFD.IP', 'BUY', 1)
    # print(order_response)

if __name__ == "__main__":
    main()
