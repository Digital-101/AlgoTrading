using System;
using cAlgo.API;
using cAlgo.API.Indicators;
using cAlgo.API.Internals;
using System.Net.Http;
using System.Threading.Tasks;

namespace cAlgo.Robots
{
    [Robot(TimeZone = TimeZones.UTC, AccessRights = AccessRights.None)]
    public class US30SignalsWithTelegram : Robot
    {
        // Parameters
        [Parameter("Fast MA Period", DefaultValue = 10)]
        public int FastMAPeriod { get; set; }

        [Parameter("Slow MA Period", DefaultValue = 20)]
        public int SlowMAPeriod { get; set; }

        [Parameter("Lot Size", DefaultValue = 0.1)]
        public double LotSize { get; set; }

        [Parameter("Stop Loss (pips)", DefaultValue = 50)]
        public double StopLoss { get; set; }

        [Parameter("Take Profit (pips)", DefaultValue = 100)]
        public double TakeProfit { get; set; }

        [Parameter("Telegram Bot Token", DefaultValue = "7831871007:AAGH8MKCwXgohoh8R8DDHIPHbBRF98mUDV4")]
        public string TelegramBotToken { get; set; }

        [Parameter("Telegram Chat ID", DefaultValue = "7482113709")]
        public string TelegramChatID { get; set; }

        // Indicators
        private MovingAverage _fastMA;
        private MovingAverage _slowMA;

        // HttpClient for Telegram API
        private HttpClient _httpClient;

        protected override void OnStart()
        {
            // Initialize indicators
            _fastMA = Indicators.MovingAverage(Bars.ClosePrices, FastMAPeriod, MovingAverageType.Simple);
            _slowMA = Indicators.MovingAverage(Bars.ClosePrices, SlowMAPeriod, MovingAverageType.Simple);

            // Initialize HttpClient
            _httpClient = new HttpClient();

            Print("US30 Signals cBot started.");
        }

        protected override void OnBar()
        {
            // Get the latest values of the moving averages
            double fastMAValue = _fastMA.Result.Last(0);
            double slowMAValue = _slowMA.Result.Last(0);

            Print($"Fast MA: {fastMAValue}, Slow MA: {slowMAValue}");

            // Buy Signal: Fast MA crosses above Slow MA
            if (fastMAValue > slowMAValue && _fastMA.Result.Last(1) <= _slowMA.Result.Last(1))
            {
                Print("Buy Signal Detected");
                ExecuteTrade(TradeType.Buy);
            }

            // Sell Signal: Fast MA crosses below Slow MA
            if (fastMAValue < slowMAValue && _fastMA.Result.Last(1) >= _slowMA.Result.Last(1))
            {
                Print("Sell Signal Detected");
                ExecuteTrade(TradeType.Sell);
            }
        }

        private void ExecuteTrade(TradeType tradeType)
        {
            // Check if there are no existing positions
            if (Positions.Count == 0)
            {
                Print("No existing positions. Attempting to place a new trade.");

                // Calculate stop loss and take profit levels
                double sl = tradeType == TradeType.Buy ? Symbol.Bid - StopLoss * Symbol.PipSize : Symbol.Ask + StopLoss * Symbol.PipSize;
                double tp = tradeType == TradeType.Buy ? Symbol.Bid + TakeProfit * Symbol.PipSize : Symbol.Ask - TakeProfit * Symbol.PipSize;

                // Execute the trade
                var tradeResult = ExecuteMarketOrder(tradeType, Symbol.Name, LotSize, "US30 Signal", sl, tp);

                if (tradeResult.IsSuccessful)
                {
                    Print("Trade executed successfully.");
                    // Send Telegram message with trade details
                    string message = tradeType == TradeType.Buy
                        ? $"📈 Buy Signal for US30\nEntry: {tradeResult.Position.EntryPrice}\nStop Loss: {sl}\nTake Profit: {tp}"
                        : $"📉 Sell Signal for US30\nEntry: {tradeResult.Position.EntryPrice}\nStop Loss: {sl}\nTake Profit: {tp}";

                    SendTelegramMessage(message);
                }
                else
                {
                    Print("Failed to execute trade: " + tradeResult.Error);
                }
            }
            else
            {
                Print("Existing positions found. Skipping new trade.");
            }
        }

        private async void SendTelegramMessage(string message)
        {
            try
            {
                string url = $"https://api.telegram.org/bot{TelegramBotToken}/sendMessage?chat_id={TelegramChatID}&text={Uri.EscapeDataString(message)}";
                HttpResponseMessage response = await _httpClient.GetAsync(url);

                if (response.IsSuccessStatusCode)
                {
                    Print("Telegram message sent: " + message);
                }
                else
                {
                    Print("Failed to send Telegram message. Status code: " + response.StatusCode);
                }
            }
            catch (Exception ex)
            {
                Print("Failed to send Telegram message: " + ex.Message);
            }
        }

        protected override void OnStop()
        {
            // Dispose HttpClient
            _httpClient.Dispose();
            Print("US30 Signals cBot stopped.");
        }
    }
}
