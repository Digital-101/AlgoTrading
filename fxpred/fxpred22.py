import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.linear_model import LinearRegression
from sklearn.metrics import mean_squared_error
import matplotlib.pyplot as plt

# Step 1: Data Collection from CSV
def fetch_data(csv_file):
    data = pd.read_csv(csv_file, parse_dates=['Date'], index_col='Date')
    print("Data Loaded:")
    print(data.head())  # Show the first few rows of the DataFrame
    print(f"Data Shape: {data.shape}")  # Show the shape of the DataFrame
    return data

# Step 2: Data Preprocessing
def preprocess_data(data):
    # Create lagged features
    for lag in range(1, 6):
        data[f'lag_{lag}'] = data['Close'].shift(lag)

    # Drop NaN values
    data = data.dropna()

    # Check the shape after preprocessing
    print(f"Data Shape after Preprocessing: {data.shape}")

    if data.empty:
        raise ValueError("The DataFrame is empty after preprocessing.")

    # Define features and target
    X = data[[f'lag_{lag}' for lag in range(1, 6)]]
    y = data['Close']
    
    return X, y

# Step 3: Train-Test Split
def train_test_split_data(X, y):
    return train_test_split(X, y, test_size=0.2, shuffle=False)

# Step 4: Model Selection and Training
def train_model(X_train, y_train):
    model = LinearRegression()
    model.fit(X_train, y_train)
    return model

# Step 5: Prediction and Evaluation
def evaluate_model(model, X_test, y_test):
    y_pred = model.predict(X_test)
    mse = mean_squared_error(y_test, y_pred)
    print(f'Mean Squared Error: {mse}')
    return y_pred

# Step 6: Visualization
def plot_results(y_test, y_pred):
    plt.figure(figsize=(12, 6))

    # Convert to numpy arrays
    y_test_values = y_test.values if isinstance(y_test, pd.Series) else np.array(y_test)
    y_pred_values = np.array(y_pred)

    # Ensure both y_test and y_pred have the same length
    if len(y_test_values) != len(y_pred_values):
        print(f"Length mismatch: y_test has {len(y_test_values)} values, y_pred has {len(y_pred_values)} values.")
        return

    plt.plot(y_test.index, y_test_values, label='Actual', color='blue')
    plt.plot(y_test.index, y_pred_values, label='Predicted', color='orange', alpha=0.7)
    plt.title('EUR/USD Price Prediction')
    plt.xlabel('Date')
    plt.ylabel('Price')
    plt.legend()
    plt.show()

# Main Function
def main():
    csv_file = 'eur_usd_data.csv'  # Replace with your CSV file path
    data = fetch_data(csv_file)

    if data.empty:
        print("The data is empty. Please check the CSV file.")
        return

    X, y = preprocess_data(data)
    X_train, X_test, y_train, y_test = train_test_split_data(X, y)
    model = train_model(X_train, y_train)
    
    # Evaluate model
    y_pred = evaluate_model(model, X_test, y_test)
    
    # Plot results
    plot_results(y_test, y_pred)

if __name__ == "__main__":
    main()
