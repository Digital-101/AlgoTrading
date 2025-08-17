import yfinance as yf
import mplfinance as mpf

ticker = input("Enter stock name: ")
df = yf.download(ticker, start='2024-08-01', end='2025-08-16')
mpf.plot(df, type='candle', style='charles',
         title=f'{ticker} Candlestick Chart', ylabel='Price')
