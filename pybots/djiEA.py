import MetaTrader5 as mt5
import yfinance as yf
import pandas as pd
import numpy as np
from statsmodels.tsa.arima.model import ARIMA
from datetime import datetime, timedelta
import time

# MT5 Initialization
if not mt5.initialize():
    print("initialize() failed")
    mt5.shutdown()

def fetch_data(symbol, start_date):
    data = yf.download(symbol, start=start_date, end=datetime.now().strftime('%Y-%m-%d'))
    return data['Close'].asfreq('B')  # Business days frequency

def forecast(symbol):
    # Fetch historical data
    us30_data = fetch_data(symbol, '2024-10-10')
    
    # Fit ARIMA model
    model = ARIMA(us30_data, order=(5, 1, 0))
    model_fit = model.fit()
    
    # Forecast for the next month (20 business days)
    forecast_steps = 20
    forecast_results = model_fit.get_forecast(steps=forecast_steps)
    forecast = forecast_results.predicted_mean
    return forecast

def place_order(symbol, order_type, volume=0.1):
    if order_type == 'buy':
        order = mt5.ORDER_BUY
    elif order_type == 'sell':
        order = mt5.ORDER_SELL
    else:
        return
    
    request = {
        "action": mt5.TRADE_ACTION_DEAL,
        "symbol": symbol,
        "volume": volume,
        "type": order,
        "price": mt5.symbol_info_tick(symbol).ask if order_type == 'buy' else mt5.symbol_info_tick(symbol).bid,
        "sl": 0,
        "tp": 0,
        "deviation": 10,
        "magic": 123456,
        "comment": "ARIMA EA",
        "type_time": mt5.ORDER_TIME_GTC,
        "type_filling": mt5.ORDER_FILLING_IOC,
    }
    
    result = mt5.order_send(request)
    return result

def main():
    symbol = '^DJI'
    
    while True:
        forecast_values = forecast(symbol)
        last_price = fetch_data(symbol, '2024-10-10')[-1]  # Get the last available price
        
        if forecast_values[0] > last_price:
            print("Placing Buy Order")
            place_order(symbol, 'buy')
        else:
            print("Placing Sell Order")
            place_order(symbol, 'sell')

        time.sleep(86400)  # Sleep for a day (86400 seconds)

if __name__ == "__main__":
    main()

# Shutdown MT5
mt5.shutdown()
