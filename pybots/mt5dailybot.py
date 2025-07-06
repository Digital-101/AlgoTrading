import tkinter as tk
from tkinter import ttk, messagebox
import MetaTrader5 as mt5
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import time

class MT5TradingBot:
    def __init__(self, root):
        self.root = root
        self.root.title("MT5 Daily Trading Bot")
        self.root.geometry("800x600")
        
        # Connection variables
        self.connected = False
        self.symbol = "XAUUSD"  # Gold trading symbol
        
        # GUI Setup
        self.setup_connection_frame()
        self.setup_trading_frame()
        self.setup_log_frame()
        
        # Initialize MT5
        self.initialize_mt5()
    
    def initialize_mt5(self):
        """Initialize MT5 connection if library is available"""
        try:
            if not mt5.initialize():
                self.log_message("MT5 initialization failed")
            else:
                self.log_message("MT5 library loaded successfully (not connected yet)")
        except Exception as e:
            self.log_message(f"Error loading MT5: {str(e)}")
    
    def setup_connection_frame(self):
        """Setup the connection frame"""
        connection_frame = ttk.LabelFrame(self.root, text="MT5 Connection", padding=10)
        connection_frame.pack(fill=tk.X, padx=10, pady=5)
        
        # Server input
        ttk.Label(connection_frame, text="Server:").grid(row=0, column=0, sticky=tk.W)
        self.server_entry = ttk.Entry(connection_frame, width=30)
        self.server_entry.grid(row=0, column=1, padx=5, pady=2)
        self.server_entry.insert(0, "YourBrokerServer")
        
        # Login input
        ttk.Label(connection_frame, text="Login:").grid(row=1, column=0, sticky=tk.W)
        self.login_entry = ttk.Entry(connection_frame, width=30)
        self.login_entry.grid(row=1, column=1, padx=5, pady=2)
        self.login_entry.insert(0, "123456")
        
        # Password input
        ttk.Label(connection_frame, text="Password:").grid(row=2, column=0, sticky=tk.W)
        self.password_entry = ttk.Entry(connection_frame, width=30, show="*")
        self.password_entry.grid(row=2, column=1, padx=5, pady=2)
        self.password_entry.insert(0, "yourpassword")
        
        # Connect button
        self.connect_button = ttk.Button(
            connection_frame, 
            text="Connect", 
            command=self.toggle_connection
        )
        self.connect_button.grid(row=3, column=0, columnspan=2, pady=5)
        
        # Connection status
        self.connection_status = ttk.Label(
            connection_frame, 
            text="Disconnected", 
            foreground="red"
        )
        self.connection_status.grid(row=4, column=0, columnspan=2)
    
    def setup_trading_frame(self):
        """Setup the trading parameters frame"""
        trading_frame = ttk.LabelFrame(self.root, text="Trading Parameters", padding=10)
        trading_frame.pack(fill=tk.X, padx=10, pady=5)
        
        # Symbol selection
        ttk.Label(trading_frame, text="Symbol:").grid(row=0, column=0, sticky=tk.W)
        self.symbol_entry = ttk.Entry(trading_frame, width=10)
        self.symbol_entry.grid(row=0, column=1, padx=5, pady=2, sticky=tk.W)
        self.symbol_entry.insert(0, "XAUUSD")
        
        # Risk management
        ttk.Label(trading_frame, text="Risk %:").grid(row=1, column=0, sticky=tk.W)
        self.risk_entry = ttk.Entry(trading_frame, width=10)
        self.risk_entry.grid(row=1, column=1, padx=5, pady=2, sticky=tk.W)
        self.risk_entry.insert(0, "1.0")
        
        # Trading hours
        ttk.Label(trading_frame, text="Start Time:").grid(row=2, column=0, sticky=tk.W)
        self.start_time_entry = ttk.Entry(trading_frame, width=10)
        self.start_time_entry.grid(row=2, column=1, padx=5, pady=2, sticky=tk.W)
        self.start_time_entry.insert(0, "09:00")
        
        ttk.Label(trading_frame, text="End Time:").grid(row=3, column=0, sticky=tk.W)
        self.end_time_entry = ttk.Entry(trading_frame, width=10)
        self.end_time_entry.grid(row=3, column=1, padx=5, pady=2, sticky=tk.W)
        self.end_time_entry.insert(0, "17:00")
        
        # Strategy selection
        ttk.Label(trading_frame, text="Strategy:").grid(row=4, column=0, sticky=tk.W)
        self.strategy_var = tk.StringVar()
        self.strategy_combobox = ttk.Combobox(
            trading_frame, 
            textvariable=self.strategy_var,
            values=["Mean Reversion", "Breakout", "Moving Average Crossover"]
        )
        self.strategy_combobox.grid(row=4, column=1, padx=5, pady=2, sticky=tk.W)
        self.strategy_combobox.current(0)
        
        # Start/Stop trading button
        self.trading_button = ttk.Button(
            trading_frame, 
            text="Start Trading", 
            command=self.toggle_trading,
            state=tk.DISABLED
        )
        self.trading_button.grid(row=5, column=0, columnspan=2, pady=5)
        
        # Trading status
        self.trading_status = ttk.Label(
            trading_frame, 
            text="Not Trading", 
            foreground="red"
        )
        self.trading_status.grid(row=6, column=0, columnspan=2)
    
    def setup_log_frame(self):
        """Setup the logging frame"""
        log_frame = ttk.LabelFrame(self.root, text="Trading Log", padding=10)
        log_frame.pack(fill=tk.BOTH, expand=True, padx=10, pady=5)
        
        # Log text area
        self.log_text = tk.Text(
            log_frame, 
            height=15, 
            wrap=tk.WORD, 
            state=tk.DISABLED
        )
        self.log_text.pack(fill=tk.BOTH, expand=True)
        
        # Scrollbar
        scrollbar = ttk.Scrollbar(log_frame, command=self.log_text.yview)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)
        self.log_text.config(yscrollcommand=scrollbar.set)
        
        # Clear log button
        clear_button = ttk.Button(
            log_frame, 
            text="Clear Log", 
            command=self.clear_log
        )
        clear_button.pack(side=tk.BOTTOM, pady=5)
    
    def toggle_connection(self):
        """Connect or disconnect from MT5"""
        if not self.connected:
            self.connect_to_mt5()
        else:
            self.disconnect_from_mt5()
    
    def connect_to_mt5(self):
        """Establish connection to MT5"""
        server = self.server_entry.get()
        login = int(self.login_entry.get())
        password = self.password_entry.get()
        
        try:
            if not mt5.initialize():
                self.log_message("MT5 initialization failed")
                return
            
            authorized = mt5.login(login, password, server)
            
            if authorized:
                self.connected = True
                self.connect_button.config(text="Disconnect")
                self.connection_status.config(text="Connected", foreground="green")
                self.trading_button.config(state=tk.NORMAL)
                self.log_message(f"Connected to MT5 account #{login}")
                
                # Get account info
                account_info = mt5.account_info()
                self.log_message(f"Balance: {account_info.balance}")
                self.log_message(f"Equity: {account_info.equity}")
                self.log_message(f"Margin: {account_info.margin}")
            else:
                self.log_message(f"Connection failed: {mt5.last_error()}")
        except Exception as e:
            self.log_message(f"Connection error: {str(e)}")
    
    def disconnect_from_mt5(self):
        """Disconnect from MT5"""
        mt5.shutdown()
        self.connected = False
        self.connect_button.config(text="Connect")
        self.connection_status.config(text="Disconnected", foreground="red")
        self.trading_button.config(state=tk.DISABLED)
        self.log_message("Disconnected from MT5")
    
    def toggle_trading(self):
        """Start or stop the trading bot"""
        if not hasattr(self, 'trading_active'):
            self.trading_active = False
        
        if not self.trading_active:
            self.start_trading()
        else:
            self.stop_trading()
    
    def start_trading(self):
        """Start the trading bot"""
        self.trading_active = True
        self.trading_button.config(text="Stop Trading")
        self.trading_status.config(text="Trading Active", foreground="green")
        self.log_message("Trading bot started")
        
        # Start trading in a separate thread to avoid freezing the GUI
        self.root.after(100, self.run_trading_loop)
    
    def stop_trading(self):
        """Stop the trading bot"""
        self.trading_active = False
        self.trading_button.config(text="Start Trading")
        self.trading_status.config(text="Not Trading", foreground="red")
        self.log_message("Trading bot stopped")
    
    def run_trading_loop(self):
        """Main trading loop"""
        if not self.trading_active:
            return
        
        try:
            # Get current time
            now = datetime.now()
            current_time = now.strftime("%H:%M")
            
            # Check if within trading hours
            start_time = self.start_time_entry.get()
            end_time = self.end_time_entry.get()
            
            if current_time >= start_time and current_time <= end_time:
                # Execute trading strategy
                self.execute_strategy()
            
            # Schedule next check (every minute)
            self.root.after(60000, self.run_trading_loop)
        except Exception as e:
            self.log_message(f"Trading error: {str(e)}")
            self.root.after(60000, self.run_trading_loop)
    
    def execute_strategy(self):
        """Execute the selected trading strategy"""
        symbol = self.symbol_entry.get()
        strategy = self.strategy_var.get()
        risk_percent = float(self.risk_entry.get()) / 100
        
        # Get current price data
        rates = mt5.copy_rates_from_pos(symbol, mt5.TIMEFRAME_M15, 0, 100)
        df = pd.DataFrame(rates)
        df['time'] = pd.to_datetime(df['time'], unit='s')
        df.set_index('time', inplace=True)
        
        # Calculate technical indicators
        df['sma_20'] = df['close'].rolling(20).mean()
        df['sma_50'] = df['close'].rolling(50).mean()
        
        # Get current positions
        positions = mt5.positions_get(symbol=symbol)
        
        # Strategy logic
        if strategy == "Mean Reversion":
            self.mean_reversion_strategy(df, symbol, risk_percent, positions)
        elif strategy == "Breakout":
            self.breakout_strategy(df, symbol, risk_percent, positions)
        elif strategy == "Moving Average Crossover":
            self.ma_crossover_strategy(df, symbol, risk_percent, positions)
    
    def mean_reversion_strategy(self, df, symbol, risk_percent, positions):
        """Mean reversion trading strategy"""
        last_close = df['close'].iloc[-1]
        sma_20 = df['sma_20'].iloc[-1]
        
        # Calculate position size based on risk
        account_info = mt5.account_info()
        risk_amount = account_info.balance * risk_percent
        point = mt5.symbol_info(symbol).point
        price_diff = abs(last_close - sma_20)
        
        if price_diff > 10 * point:  # If price deviates significantly from mean
            lot_size = round(risk_amount / price_diff, 2)
            
            if last_close > sma_20 and not any(p.type == mt5.ORDER_TYPE_SELL for p in positions):
                # Price is above mean - sell signal
                self.place_order(symbol, "sell", lot_size)
            elif last_close < sma_20 and not any(p.type == mt5.ORDER_TYPE_BUY for p in positions):
                # Price is below mean - buy signal
                self.place_order(symbol, "buy", lot_size)
    
    def breakout_strategy(self, df, symbol, risk_percent, positions):
        """Breakout trading strategy"""
        # Get recent high/low
        recent_high = df['high'].rolling(20).max().iloc[-1]
        recent_low = df['low'].rolling(20).min().iloc[-1]
        last_close = df['close'].iloc[-1]
        
        # Calculate position size
        account_info = mt5.account_info()
        risk_amount = account_info.balance * risk_percent
        point = mt5.symbol_info(symbol).point
        price_diff = abs(recent_high - recent_low)
        lot_size = round(risk_amount / price_diff, 2)
        
        if last_close > recent_high and not any(p.type == mt5.ORDER_TYPE_BUY for p in positions):
            # Breakout above resistance - buy
            self.place_order(symbol, "buy", lot_size)
        elif last_close < recent_low and not any(p.type == mt5.ORDER_TYPE_SELL for p in positions):
            # Breakout below support - sell
            self.place_order(symbol, "sell", lot_size)
    
    def ma_crossover_strategy(self, df, symbol, risk_percent, positions):
        """Moving average crossover strategy"""
        # Get current and previous values
        sma_20_now = df['sma_20'].iloc[-1]
        sma_50_now = df['sma_50'].iloc[-1]
        sma_20_prev = df['sma_20'].iloc[-2]
        sma_50_prev = df['sma_50'].iloc[-2]
        
        # Calculate position size
        account_info = mt5.account_info()
        risk_amount = account_info.balance * risk_percent
        point = mt5.symbol_info(symbol).point
        price_diff = abs(sma_20_now - sma_50_now)
        lot_size = round(risk_amount / price_diff, 2)
        
        # Check for crossover
        if sma_20_prev < sma_50_prev and sma_20_now > sma_50_now:
            # Golden cross - buy signal
            if not any(p.type == mt5.ORDER_TYPE_BUY for p in positions):
                self.place_order(symbol, "buy", lot_size)
        elif sma_20_prev > sma_50_prev and sma_20_now < sma_50_now:
            # Death cross - sell signal
            if not any(p.type == mt5.ORDER_TYPE_SELL for p in positions):
                self.place_order(symbol, "sell", lot_size)
    
    def place_order(self, symbol, order_type, lot_size):
        """Place an order in MT5"""
        symbol_info = mt5.symbol_info(symbol)
        if symbol_info is None:
            self.log_message(f"{symbol} not found")
            return
        
        if not symbol_info.visible:
            mt5.symbol_select(symbol, True)
        
        point = symbol_info.point
        price = mt5.symbol_info_tick(symbol).ask if order_type == "buy" else mt5.symbol_info_tick(symbol).bid
        deviation = 20
        
        if order_type == "buy":
            order_type_mt5 = mt5.ORDER_TYPE_BUY
            sl = price - 100 * point
            tp = price + 200 * point
        else:
            order_type_mt5 = mt5.ORDER_TYPE_SELL
            sl = price + 100 * point
            tp = price - 200 * point
        
        request = {
            "action": mt5.TRADE_ACTION_DEAL,
            "symbol": symbol,
            "volume": lot_size,
            "type": order_type_mt5,
            "price": price,
            "sl": sl,
            "tp": tp,
            "deviation": deviation,
            "magic": 123456,
            "comment": "Python script open",
            "type_time": mt5.ORDER_TIME_GTC,
            "type_filling": mt5.ORDER_FILLING_FOK,
        }
        
        result = mt5.order_send(request)
        
        if result.retcode == mt5.TRADE_RETCODE_DONE:
            self.log_message(f"{order_type.capitalize()} order executed for {lot_size} lots of {symbol}")
        else:
            self.log_message(f"Order failed, retcode={result.retcode}")
    
    def log_message(self, message):
        """Add a message to the log"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        log_line = f"[{timestamp}] {message}\n"
        
        self.log_text.config(state=tk.NORMAL)
        self.log_text.insert(tk.END, log_line)
        self.log_text.config(state=tk.DISABLED)
        self.log_text.see(tk.END)
        
        # Also print to console for debugging
        print(log_line.strip())
    
    def clear_log(self):
        """Clear the log messages"""
        self.log_text.config(state=tk.NORMAL)
        self.log_text.delete(1.0, tk.END)
        self.log_text.config(state=tk.DISABLED)

if __name__ == "__main__":
    root = tk.Tk()
    app = MT5TradingBot(root)
    root.mainloop()
