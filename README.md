# ExBanking

ExBanking is an Elixir application designed to handle basic banking operations, such as user creation, balance inquiries,
deposits, withdrawals, and transfers between users.
The application leverages the power of concurrent processes provided by the BEAM VM, ensuring high performance and scalability.

## Installation

To use ExBanking, clone the repository and fetch the dependencies:

```sh
git clone https://github.com/yourusername/ex_banking.git
cd ex_banking
mix deps.get
```

## Usage

Run the application:

```sh
mix run --no-halt
```

You can interact with the application using the provided functions:

### Creating a User

```elixir
ExBanking.create_user("Alice")
# => :ok
```

### Getting a Balance

```elixir
ExBanking.get_balance("Alice", "USD")
# => {:ok, 0.0}
```

### Depositing Money

```elixir
ExBanking.deposit("Alice", 100, "USD")
# => {:ok, 100.0}
```

### Withdrawing Money

```elixir
ExBanking.withdraw("Alice", 50, "USD")
# => {:ok, 50.0}
```

### Sending Money

```elixir
ExBanking.create_user("Bob")
ExBanking.send("Alice", "Bob", 25, "USD")
# => {:ok, 25.0, 25.0}
```

## Design Overview

### Concurrency

- In every single moment of time the system should handle 10 or less operations for every individual user (user is a string passed as the first argument to API functions). If there is any new operation for this user and he/she still has 10 operations in pending state - new operation for this user should immediately return too_many_requests_to_user error until number of requests for this user decreases < 10
- The system should be able to handle requests for different users in the same moment of time
- Requests for user A should not affect to performance of requests to user B (maybe except send function when both A and B users are involved in the request)

