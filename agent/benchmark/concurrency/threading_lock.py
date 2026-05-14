"""Threading code — expected unsupported by ESBMC-Python; orchestrator should
route to run_deadlock_detector per the paper's guidance."""
import threading

lock_a = threading.Lock()
lock_b = threading.Lock()

def worker():
    with lock_a:
        with lock_b:
            pass

def main():
    t = threading.Thread(target=worker)
    t.start()
    t.join()

main()
