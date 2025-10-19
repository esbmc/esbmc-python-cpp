"""
Subtle Race Condition: Check-Then-Act Pattern

This program has a race condition that WON'T be caught by simply running it.
The final results will look correct, but the code has a dangerous race condition
that could cause problems in real-world scenarios.

The bug: Non-atomic "check-then-act" operations on shared state
"""

import threading
import time
import random

class UserAccount:
    """
    User account with balance tracking.
    Has a SUBTLE RACE CONDITION in the transfer method.
    """

    def __init__(self, account_id, initial_balance=1000):
        self.account_id = account_id
        self.balance = initial_balance
        self.transaction_count = 0

    def transfer_to(self, other_account, amount):
        """
        Transfer money to another account.

        RACE CONDITION: The check and update are not atomic!

        Thread A: checks balance (enough money)
        Thread B: checks balance (enough money)
        Thread A: subtracts amount
        Thread B: subtracts amount  (might overdraw!)

        But in this example, we carefully choose amounts so the final
        balance is always correct, hiding the race condition from simple testing.
        """
        # STEP 1: Check if we have enough money (NON-ATOMIC)
        if self.balance >= amount:
            # Simulate some processing delay
            time.sleep(0.0001)

            # STEP 2: Deduct from our account (NON-ATOMIC)
            self.balance -= amount

            # STEP 3: Add to other account (NON-ATOMIC)
            other_account.balance += amount

            self.transaction_count += 1
            return True
        return False

    def safe_transfer_to(self, other_account, amount, lock):
        """
        Safe version with proper locking
        """
        with lock:
            if self.balance >= amount:
                time.sleep(0.0001)
                self.balance -= amount
                other_account.balance += amount
                self.transaction_count += 1
                return True
        return False


def worker_thread(account_a, account_b, transfers):
    """
    Perform transfers between two accounts.
    Each transfer is small so final balance appears correct.
    """
    for _ in range(transfers):
        # Alternate direction of transfers
        if random.random() > 0.5:
            account_a.transfer_to(account_b, 10)
        else:
            account_b.transfer_to(account_a, 10)


def test_race_condition():
    """
    Test the race condition.

    Key trick: We do equal transfers in both directions, so the final
    balance will be correct even with the race condition! This hides
    the bug from simple testing.
    """
    print("="*70)
    print("SUBTLE RACE CONDITION TEST")
    print("="*70)

    # Create two accounts
    account1 = UserAccount("ACC001", initial_balance=10000)
    account2 = UserAccount("ACC002", initial_balance=10000)

    initial_total = account1.balance + account2.balance

    print(f"\nInitial state:")
    print(f"  Account 1: ${account1.balance}")
    print(f"  Account 2: ${account2.balance}")
    print(f"  Total: ${initial_total}")

    num_threads = 10
    transfers_per_thread = 100

    print(f"\nStarting transfers:")
    print(f"  Threads: {num_threads}")
    print(f"  Transfers per thread: {transfers_per_thread}")
    print(f"  (Transfers go both directions)")

    threads = []
    start_time = time.time()

    # Create worker threads
    for i in range(num_threads):
        t = threading.Thread(
            target=worker_thread,
            args=(account1, account2, transfers_per_thread)
        )
        threads.append(t)
        t.start()

    # Wait for completion
    for t in threads:
        t.join()

    elapsed = time.time() - start_time
    final_total = account1.balance + account2.balance

    print(f"\nFinal state:")
    print(f"  Account 1: ${account1.balance}")
    print(f"  Account 2: ${account2.balance}")
    print(f"  Total: ${final_total}")
    print(f"  Time: {elapsed:.2f}s")
    print(f"  Total transactions: {account1.transaction_count + account2.transaction_count}")

    # Check if money was conserved
    if final_total == initial_total:
        print(f"\n✓ Money conserved: ${initial_total} → ${final_total}")
        print(f"\n⚠️  BUT THIS CODE HAS A RACE CONDITION!")
        print(f"   The check-then-act pattern is not atomic.")
        print(f"   In production, this could cause:")
        print(f"   • Overdrafts (negative balances)")
        print(f"   • Lost transactions")
        print(f"   • Incorrect balances")
        print(f"   • Data corruption")
        print(f"\n   The bug is HIDDEN because:")
        print(f"   • Transfers are small and balanced")
        print(f"   • We got lucky with timing")
        print(f"   • Simple testing won't catch it")
    else:
        print(f"\n❌ Money NOT conserved! Race condition caused data corruption!")
        print(f"   Lost/gained: ${final_total - initial_total}")


def demonstrate_actual_bug():
    """
    Demonstrate the actual race condition with aggressive transfers.
    This version makes the bug more visible.
    """
    print("\n" + "="*70)
    print("AGGRESSIVE TEST - Making the Race Condition Visible")
    print("="*70)

    account1 = UserAccount("ACC003", initial_balance=100)
    account2 = UserAccount("ACC004", initial_balance=100)

    initial_total = account1.balance + account2.balance

    print(f"\nInitial: Account1=${account1.balance}, Account2=${account2.balance}, Total=${initial_total}")

    def aggressive_transfer(acc1, acc2):
        """Try to transfer large amounts simultaneously"""
        for _ in range(50):
            # Try to transfer most of the balance
            acc1.transfer_to(acc2, 50)
            acc2.transfer_to(acc1, 50)

    threads = []
    for i in range(5):
        t = threading.Thread(target=aggressive_transfer, args=(account1, account2))
        threads.append(t)
        t.start()

    for t in threads:
        t.join()

    final_total = account1.balance + account2.balance

    print(f"Final:   Account1=${account1.balance}, Account2=${account2.balance}, Total=${final_total}")

    if final_total != initial_total:
        print(f"\n❌ RACE CONDITION VISIBLE!")
        print(f"   Money lost/created: ${final_total - initial_total}")
    elif account1.balance < 0 or account2.balance < 0:
        print(f"\n❌ OVERDRAFT OCCURRED! (negative balance)")
    else:
        print(f"\n⚠️  Race condition exists but got lucky this time")


def explain_the_bug():
    """
    Explain what the race condition is and why it's dangerous
    """
    print("\n" + "="*70)
    print("EXPLANATION OF THE RACE CONDITION")
    print("="*70)

    print("""
The Bug: Check-Then-Act Race Condition
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

In transfer_to(), we have:

    if self.balance >= amount:      # ← CHECK (not atomic)
        time.sleep(0.0001)           # ← gap where race occurs
        self.balance -= amount       # ← ACT (not atomic)

Timeline of the race:
────────────────────────────────────────
Time    Thread A                    Thread B
────────────────────────────────────────
t0      balance = 100
t1      Check: 100 >= 50? YES
t2                                  Check: 100 >= 50? YES
t3      balance = 100 - 50 = 50
t4                                  balance = 50 - 50 = 0
────────────────────────────────────────
Both threads passed the check, but only one should have!

Why it's dangerous in production:
• Could cause negative balances (overdrafts)
• Could lose money (corruption)
• Could allow fraudulent transactions
• Could violate business rules
• Hard to debug (happens randomly)
• Won't be caught by basic testing

How to fix:
• Use locks around the entire check-then-act sequence
• Use atomic operations
• Use database transactions with proper isolation
    """)


if __name__ == "__main__":
    # Test 1: Balanced transfers (hides the bug)
    test_race_condition()

    # Test 2: Aggressive transfers (might reveal the bug)
    demonstrate_actual_bug()

    # Explanation
    explain_the_bug()
