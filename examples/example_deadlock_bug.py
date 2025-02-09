import threading

class SharedResource:
    def __init__(self):
        self.mutex = threading.Lock()
        self.lock = threading.Lock()
        self.A_count = 0
        self.B_count = 0

def thread_A(resource):
    # First section
    resource.mutex.acquire()
    resource.A_count += 1
    if resource.A_count == 1:
        resource.lock.acquire()
    resource.mutex.release()

    # Second section
    resource.mutex.acquire()
    resource.A_count -= 1
    if resource.A_count == 0:
        resource.lock.release()
    resource.mutex.release()

def thread_B(resource):
    # First section
    resource.mutex.acquire()
    resource.B_count += 1
    if resource.B_count == 1:
        resource.lock.acquire()
    resource.mutex.release()

    # Second section
    resource.mutex.acquire()
    resource.B_count -= 1
    if resource.B_count == 0:
        resource.lock.release()
    resource.mutex.release()

def main():
    resource = SharedResource()

    # Create threads
    t1 = threading.Thread(target=thread_A, args=(resource,))
    t2 = threading.Thread(target=thread_B, args=(resource,))

    # Start threads
    t1.start()
    t2.start()

    # Wait for completion
    t1.join()
    t2.join()

if __name__ == "__main__":
    main()
