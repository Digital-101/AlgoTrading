def xauusd_margin_calculator(trade_size=1, xauzar_rate=60978.83110, leverage=300):
    margin_in_zar = (trade_size * xauzar_rate) / leverage
    return round(margin_in_zar, 2)

# Example usage
margin_zar = xauusd_margin_calculator()
print(f"Margin required for 1 lot on XAUUSD with 300:1 leverage = {margin_zar} ZAR")
