import MetaTrader5 as mt5
import time
import requests
from datetime import datetime
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()
TELEGRAM_TOKEN = os.getenv("TELEGRAM_TOKEN")
TELEGRAM_CHAT_ID = os.getenv("TELEGRAM_CHAT_ID")

# Initialize MT5
if not mt5.initialize():
    print("Failed to initialize MT5")
    quit()

# Login to MT5 account
account = 12345678  # Replace with your MT5 account number
password = "your_password"  # Replace with your MT5 password
server = "your_broker_server"  # Replace with your broker's server name

if not mt5.login(account, password, server):
    print("Failed to login to MT5")
    mt5.shutdown()
    quit()

# Function to send Telegram message
def send_telegram_message(message):
    url = f"https://api.telegram.org/bot{TELEGRAM_TOKEN}/sendMessage"
    params = {
        "chat_id": TELEGRAM_CHAT_ID,
        "text": message
    }
    response = requests.get(url, params=params)
    if response.status_code != 200:
        print(f"Failed to send Telegram message: {response.text}")

# Function to check if today is Monday
def is_monday():
    return datetime.now().weekday() == 0  # 0 = Monday

# Function to get moving averages
def get_moving_averages(symbol, period_short=10, period_long=50):
    rates = mt5.copy_rates_from_pos(symbol, mt5.TIMEFRAME_M1, 0, period_long + 1)
    if rates is None:
        print(f"Failed to get rates for {symbol}")
        return None, None

    close_prices = [rate['close'] for rate in rates]
    ma_short = sum(close_prices[-period_short:]) / period_short
    ma_long = sum(close_prices[-period_long:]) / period_long
    return ma_short, ma_long

# Function to calculate lot size based on risk
def calculate_lot_size(account_balance, risk_percent=1, sl_pips=20):
    risk_amount = account_balance * (risk_percent / 100)
    lot_size = risk_amount / (sl_pips * 10)  # 1 pip = $10 for micro lot (0.01)
    return round(lot_size, 2)  # Round to 2 decimal places

# Function to place a trade with SL and TP
def place_trade(symbol, action, lot_size=0.01, sl_pips=20, risk_reward_ratio=2):
    symbol_info = mt5.symbol_info(symbol)
    if symbol_info is None:
        print(f"Symbol {symbol} not found")
        return

    if action == "buy":
        order_type = mt5.ORDER_TYPE_BUY
        price = mt5.symbol_info_tick(symbol).ask
        sl = price - sl_pips * mt5.symbol_info(symbol).point
        tp = price + (sl_pips * risk_reward_ratio) * mt5.symbol_info(symbol).point
    elif action == "sell":
        order_type = mt5.ORDER_TYPE_SELL
        price = mt5.symbol_info_tick(symbol).bid
        sl = price + sl_pips * mt5.symbol_info(symbol).point
        tp = price - (sl_pips * risk_reward_ratio) * mt5.symbol_info(symbol).point
    else:
        print("Invalid action")
        return

    request = {
        "action": mt5.TRADE_ACTION_DEAL,
        "symbol": symbol,
        "volume": lot_size,
        "type": order_type,
        "price": price,
        "sl": sl,
        "tp": tp,
        "deviation": 10,
        "magic": 123456,
        "comment": "Python script open",
        "type_time": mt5.ORDER_TIME_GTC,
        "type_filling": mt5.ORDER_FILLING_IOC,
    }

    result = mt5.order_send(request)
    if result.retcode != mt5.TRADE_RETCODE_DONE:
        print(f"Failed to place {action} order: {result.comment}")
    else:
        print(f"{action.capitalize()} order placed successfully")
        send_telegram_message(
            f"{action.capitalize()} order placed for {symbol} at {price}\n"
            f"SL: {sl}, TP: {tp}"
        )

# Main trading logic
def trade(symbol="NAS100"):
    if not is_monday():
        print("Today is not Monday. No trading.")
        return

    # Get account balance
    account_info = mt5.account_info()
    if account_info is None:
        print("Failed to get account info")
        return
    account_balance = account_info.balance

    # Calculate lot size based on risk
    lot_size = calculate_lot_size(account_balance, risk_percent=1, sl_pips=20)

    ma_short, ma_long = get_moving_averages(symbol)
    if ma_short is None or ma_long is None:
        return

    if ma_short > ma_long:
        print("Buy signal detected")
        place_trade(symbol, "buy", lot_size=lot_size)
    elif ma_short < ma_long:
        print("Sell signal detected")
        place_trade(symbol, "sell", lot_size=lot_size)
    else:
        print("No clear signal")

# Run the bot
if __name__ == "__main__":
    symbol = "NAS100"  # Replace with your desired symbol
    while True:
        trade(symbol)
        time.sleep(60)  # Check every minute
