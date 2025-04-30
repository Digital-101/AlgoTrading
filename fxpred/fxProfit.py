def euraud_profit_in_zar(open_price, close_price, pip_size, zar_aud_rate, lot_size=1):
    pip_difference = close_price - open_price
    pips_gained = pip_difference / pip_size
    pip_value_aud = 10 * lot_size  # 10 AUD per pip per standard lot
    profit_aud = pips_gained * pip_value_aud
    aud_to_zar = 1 / zar_aud_rate
    profit_zar = profit_aud * aud_to_zar
    return round(profit_zar, 2)

# Example usage
profit = euraud_profit_in_zar(
    open_price=1.72061,
    close_price=1.72461,
    pip_size=0.0001,
    zar_aud_rate=0.08433,
    lot_size=1
)

print(f"Profit in ZAR: {profit}")
