import MetaTrader5 as mt5
import yfinance as yf
import pandas as pd
import numpy as np
from sklearn.linear_model import LinearRegression
import time
import matplotlib.pyplot as plt

# Constants
symbol = "EURUSD"
lot = 0.1  # Size of the lot
stop_loss = 50  # Stop loss in points
take_profit = 100  # Take profit in points

# Initialize lists to track performance
trade_history = []
equity_curve = []

# Function to connect to MT5
def connect_mt5():
    if not mt5.initialize():
        print("Initialize failed")
        mt5.shutdown()

# Function to fetch historical data
def fetch_data():
    data = yf.download('EURUSD=X', start='2025-01-01', end='2025-03-01', interval='1d')
    return data

# Function to preprocess data and make predictions
def predict_price(data):
    for lag in range(1, 6):
        data[f'lag_{lag}'] = data['Close'].shift(lag)
    
    data['SMA_10'] = data['Close'].rolling(window=10).mean()
    data['SMA_30'] = data['Close'].rolling(window=30).mean()
    data = data.dropna()

    X = data[[f'lag_{lag}' for lag in range(1, 6)] + ['SMA_10', 'SMA_30']]
    y = data['Close']

    model = LinearRegression()
    model.fit(X, y)

    return model.predict(X.iloc[-1].values.reshape(1, -1))[0]

# Function to place a trade
def place_trade(predicted_price):
    current_price = mt5.symbol_info_tick(symbol).ask
    order_type = mt5.ORDER_BUY if predicted_price > current_price else mt5.ORDER_SELL

    price = current_price if order_type == mt5.ORDER_BUY else current_price
    sl = price - stop_loss * mt5.symbol_info(symbol).point if order_type == mt5.ORDER_BUY else price + stop_loss * mt5.symbol_info(symbol).point
    tp = price + take_profit * mt5.symbol_info(symbol).point if order_type == mt5.ORDER_BUY else price - take_profit * mt5.symbol_info(symbol).point

    order = {
        "action": mt5.TRADE_ACTION_DEAL,
        "symbol": symbol,
        "volume": lot,
        "type": order_type,
        "price": price,
        "sl": sl,
        "tp": tp,
        "deviation": 10,
        "magic": 234000,
        "comment": "Python script order",
        "type_time": mt5.ORDER_TIME_GTC,
        "type_filling": mt5.ORDER_FILLING_IOC,
    }

    result = mt5.order_send(order)
    if result.retcode == mt5.TRADE_RETCODE_DONE:
        trade_history.append({"type": order_type, "price": price, "tp": tp, "sl": sl})
        print("Order placed successfully.")
    else:
        print(f"Order failed: {result.retcode}")

# Function to update equity curve
def update_equity():
    balance = mt5.account_info().balance
    equity_curve.append(balance)

# Function to visualize performance
def visualize_performance():
    plt.figure(figsize=(12, 6))
    plt.plot(equity_curve, label='Equity Curve', color='blue')
    plt.title('Trading Bot Performance')
    plt.xlabel('Time (in iterations)')
    plt.ylabel('Equity')
    plt.legend()
    plt.grid()
    plt.show()

# Main function
def main():
    connect_mt5()
    while True:
        data = fetch_data()
        predicted_price = predict_price(data)
        place_trade(predicted_price)
        update_equity()
        time.sleep(60)  # Wait for 1 minute before next prediction
        if len(equity_curve) >= 100:  # Visualize after 100 iterations
            visualize_performance()

if __name__ == "__main__":
    main()
