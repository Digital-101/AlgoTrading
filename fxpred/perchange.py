def percentage_change(old_value, new_value):
    try:
        change = ((new_value - old_value) / old_value) * 100
        return round(change, 2)
    except ZeroDivisionError:
        return "Old value cannot be zero."

# Example usage:
old = 3000
new = 3444

result = percentage_change(old, new)
print(f"Percentage change from {old} to {new} is {result}%")
