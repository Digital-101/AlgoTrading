def xauusd_pip_value_in_zar(pips, pip_size=0.1, exchange_rate_zar_per_usd=0.05375):
    # USD value per pip for 1 lot of XAUUSD with 0.1 pip size = $0.10
    usd_value_per_pip = 0.10
    total_usd = pips * usd_value_per_pip

    # Convert ZAR/USD to USD/ZAR
    usd_to_zar = 1 / exchange_rate_zar_per_usd
    total_zar = total_usd * usd_to_zar

    return round(total_zar, 2)

# Example usage
pips = 40
pip_value_zar = xauusd_pip_value_in_zar(pips)
print(f"{pips} pips on XAUUSD = {pip_value_zar} ZAR")
