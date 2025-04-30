def compound_profit_calculator(initial_balance, rate_per_period, periods):
    final_balance = initial_balance * (1 + rate_per_period / 100) ** periods
    return round(final_balance, 2)

# Example usage
initial_balance = 3000
rate_per_period = 15  # 15% gain per period
periods = 6

final_balance = compound_profit_calculator(initial_balance, rate_per_period, periods)
profit = final_balance - initial_balance
print(f"Final balance after {periods} periods: {final_balance} ZAR")
print(f"Total profit after {periods} periods: {profit} ZAR")
