import backtrader as bt
import yfinance as yf

# Create a subclass of Strategy to define the indicators and logic
class SmaCross(bt.Strategy):
    params = dict(pfast=10, pslow=30)

    def __init__(self):
        sma1 = bt.ind.SMA(period=self.p.pfast)
        sma2 = bt.ind.SMA(period=self.p.pslow)
        self.crossover = bt.ind.CrossOver(sma1, sma2)

    def next(self):
        if not self.position:
            if self.crossover > 0:
                self.buy()
        elif self.crossover < 0:
            self.close()

cerebro = bt.Cerebro()

# Create a data feed with yfinance
data = bt.feeds.PandasData(dataname=yf.download('MSFT', start='2024-07-01', end='2024-09-30'))

cerebro.adddata(data)
cerebro.addstrategy(SmaCross)
cerebro.run()
cerebro.plot()
