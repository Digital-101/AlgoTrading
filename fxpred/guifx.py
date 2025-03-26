import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.linear_model import LinearRegression
from sklearn.metrics import mean_squared_error
import matplotlib.pyplot as plt
from tkinter import Tk, Button, Label, filedialog, messagebox

# Function to load CSV file
def load_csv():
    file_path = filedialog.askopenfilename(
        filetypes=[("CSV files", "*.csv"), ("All files", "*.*")]
    )
    if file_path:
        try:
            data = pd.read_csv(file_path, parse_dates=['Date'], index_col='Date')
            process_data(data)
        except Exception as e:
            messagebox.showerror("Error", f"Failed to load data: {e}")

# Function to preprocess data and train model
def process_data(data):
    try:
        # Create lagged features
        for lag in range(1, 6):
            data[f'lag_{lag}'] = data['Close'].shift(lag)

        data = data.dropna()

        if data.empty:
            raise ValueError("The DataFrame is empty after preprocessing.")

        X = data[[f'lag_{lag}' for lag in range(1, 6)]]
        y = data['Close']

        X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, shuffle=False)
        model = train_model(X_train, y_train)
        y_pred = evaluate_model(model, X_test, y_test)

        # Plot results
        plot_results(y_test, y_pred)

    except Exception as e:
        messagebox.showerror("Error", str(e))

# Function to train the model
def train_model(X_train, y_train):
    model = LinearRegression()
    model.fit(X_train, y_train)
    return model

# Function to evaluate the model
def evaluate_model(model, X_test, y_test):
    y_pred = model.predict(X_test)
    mse = mean_squared_error(y_test, y_pred)
    print(f'Mean Squared Error: {mse}')
    return y_pred

# Function to plot results
def plot_results(y_test, y_pred):
    plt.figure(figsize=(12, 6))

    # Convert to numpy arrays
    y_test_values = np.array(y_test)
    y_pred_values = np.array(y_pred)

    # Debugging output
    print("y_test values:", y_test_values)
    print("y_pred values:", y_pred_values)

    if len(y_test_values) != len(y_pred_values):
        messagebox.showerror("Error", "Length mismatch between actual and predicted values.")
        return

    plt.plot(y_test_values, label='Actual', color='blue')
    plt.plot(y_pred_values, label='Predicted', color='orange', alpha=0.7)
    plt.title('EUR/USD Price Prediction')
    plt.xlabel('Date')
    plt.ylabel('Price')
    plt.legend()
    plt.show()

# Setting up the Tkinter window
def setup_window():
    window = Tk()
    window.title("EUR/USD Prediction App")
    window.geometry("400x200")

    label = Label(window, text="Upload your CSV file:")
    label.pack(pady=20)

    upload_button = Button(window, text="Upload CSV", command=load_csv)
    upload_button.pack(pady=10)

    window.mainloop()

if __name__ == "__main__":
    setup_window()
