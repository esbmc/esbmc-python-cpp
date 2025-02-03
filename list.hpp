#ifndef __LIST_HPP
#define __LIST_HPP

namespace shedskin {

// Forward declarations
template<class K, class V> class dict;
template<class T> class set;
template<class T> class __iter;

template<typename T>
class list : public pyobj {
private:
    struct Node {
        T data;
        Node* next;
        Node(const T& value) : data(value), next(nullptr) {}
    };
    
    Node* head;
    Node* tail;  // Tail pointer for O(1) append
    __ss_int size_;

    void append_multiple() {}

    template<typename First, typename... Rest>
    void append_multiple(First first, Rest... rest) {
        append(first); // Ajouter l'élément actuel
        append_multiple(rest...); // Appel récursif pour ajouter les autres
    }

public:
    // Default constructor
    list() : head(nullptr), tail(nullptr), size_(0) {}
    
    // Single value constructor
    list(__ss_int count, const T& value) : head(nullptr), tail(nullptr), size_(0) {
        if(count > 0) {
            append(value);
            if(count > 1) append(value);
        }
    }
    
    // Two value constructor
    list(__ss_int count, const T& value1, const T& value2) : head(nullptr), tail(nullptr), size_(0) {
        append(value1);
        if(count > 1) append(value2);
    }

    // Three value constructor
    list(__ss_int count, const T& v1, const T& v2, const T& v3) : head(nullptr), tail(nullptr), size_(0) {
        append(v1);
        if(count > 1) append(v2);
        if(count > 2) append(v3);
    }

    template<typename... Args>
    list(__ss_int count, Args... args) : head(nullptr), tail(nullptr), size_(0) {
        if (sizeof...(args) != count) {
            throw std::invalid_argument("The number of arguments must correspond to the counter.");
        }
        append_multiple(args...);
    }

    // Copy constructor
    list(list<T>* other) : head(nullptr), tail(nullptr), size_(0) {
        if (other) {
            for (__ss_int i = 0; i < other->size(); i++) {
                append(other->__getfast__(i));
            }
        }
    }

    // Iterator constructor
    list(__iter<T>* iter) : head(nullptr), tail(nullptr), size_(0) {
        if (iter) {
            while (!iter->__stop_iteration) {
                T item = iter->__get_next();
                if (!iter->__stop_iteration) {
                    append(item);
                }
            }
        }
    }
    
    // Destructor
    ~list() {
        clear();
    }

    // Assignment operator
    list<T>& operator=(const list<T>& other) {
        if (this != &other) {
            clear();
            Node* current = other.head;
            while (current) {
                append(current->data);
                current = current->next;
            }
        }
        return *this;
    }

    // O(1) append operation using tail pointer
    void append(const T& value) {
        Node* newNode = new Node(value);
        if (!head) {
            head = tail = newNode;
        } else {
            tail->next = newNode;
            tail = newNode;
        }
        size_++;
    }

    // Get element at index
    T __getfast__(__ss_int index) const {
        if (index < 0 || index >= size_) {
            return T();
        }
        Node* current = head;
        for (__ss_int i = 0; i < index && current; i++) {
            current = current->next;
        }
        return current ? current->data : T();
    }

    // Set element at index
    void __setitem__(__ss_int index, const T& value) {
        if (index < 0 || index >= size_) {
            return;
        }
        Node* current = head;
        for (__ss_int i = 0; i < index && current; i++) {
            current = current->next;
        }
        if (current) {
            current->data = value;
        }
    }
    
    // Clear the list
    void clear() {
        while (head) {
            Node* temp = head;
            head = head->next;
            delete temp;
        }
        tail = nullptr;
        size_ = 0;
    }
    
    // Get size
    __ss_int size() const {
        return size_;
    }

    // Python-style len()
    __ss_int __len__() const {
        return size_;
    }

    // Python-style getitem
    T __getitem__(__ss_int index) const {
        if (index < 0) {
            index = size_ + index;
        }
        return __getfast__(index);
    }

    // Remove element at index
    void __remove__(__ss_int index) {
        if (index < 0) {
            index = size_ + index;
        }
        if (index < 0 || index >= size_) return;
        
        Node* current = head;
        Node* previous = nullptr;
        
        for (__ss_int i = 0; i < index && current; i++) {
            previous = current;
            current = current->next;
        }
        
        if (!current) return;

        if (previous) {
            previous->next = current->next;
            if (current == tail) {
                tail = previous;
            }
        } else {
            head = current->next;
            if (head == nullptr) {
                tail = nullptr;
            }
        }
        
        delete current;
        size_--;
    }

    // Insert element at index
    void insert(__ss_int index, const T& value) {
        if (index < 0) {
            index = size_ + index;
        }
        if (index < 0) index = 0;
        if (index >= size_) {
            append(value);
            return;
        }

        Node* newNode = new Node(value);
        if (index == 0) {
            newNode->next = head;
            head = newNode;
        } else {
            Node* current = head;
            for (__ss_int i = 0; i < index - 1; i++) {
                current = current->next;
            }
            newNode->next = current->next;
            current->next = newNode;
        }
        size_++;
    }

    // Check equality with another list
    bool equals(const list<T>* other) const {
        if (!other || size_ != other->size_) return false;
        Node* n1 = head;
        Node* n2 = other->head;
        while (n1 && n2) {
            if (!(n1->data == n2->data)) return false;
            n1 = n1->next;
            n2 = n2->next;
        }
        return true;
    }

    // Get first element
    T __getfirst__() const {
        return head ? head->data : T();
    }

    // Get last element
    T __getlast__() const {
        return tail ? tail->data : T();
    }

    // Extend list with elements from another list
    void extend(list<T>* other) {
        if (!other) return;
        Node* current = other->head;
        while (current) {
            append(current->data);
            current = current->next;
        }
    }

    // Iterator support
    class Iterator {
        Node* current;
    public:
        Iterator(Node* node) : current(node) {}
        Iterator& operator++() { if(current) current = current->next; return *this; }
        bool operator!=(const Iterator& other) { return current != other.current; }
        T& operator*() { return current->data; }
    };

    Iterator begin() { return Iterator(head); }
    Iterator end() { return Iterator(nullptr); }
    const Iterator begin() const { return Iterator(head); }
    const Iterator end() const { return Iterator(nullptr); }


    // Check if an element is in the list (Python 'in' operator)
    bool __contains__(const T& value) const {
        Node* current = head;
        while (current) {
            if (current->data == value) {
                return true;
            }
            current = current->next;
        }
        return false;
    }

    // Support for Python's sorted()
    static list<T>* __sorted__(list<T>* input_list) {
        if (!input_list) return new list<T>();
        list<T>* sorted_list = new list<T>(*input_list);
        
        // Bubble sort
        for (__ss_int i = 0; i < sorted_list->size_ - 1; i++) {
            for (__ss_int j = 0; j < sorted_list->size_ - i - 1; j++) {
                if (sorted_list->__getfast__(j) > sorted_list->__getfast__(j + 1)) {
                    T temp = sorted_list->__getfast__(j);
                    sorted_list->__setitem__(j, sorted_list->__getfast__(j + 1));
                    sorted_list->__setitem__(j + 1, temp);
                }
            }
        }
        return sorted_list;
    }

    // Support for Python slicing (list[start:end])
    list<T>* __getslice__(__ss_int start, __ss_int end) const {
        list<T>* slice = new list<T>();
        
        if (start < 0) start = size_ + start;
        if (end < 0) end = size_ + end;
        
        // Ajuster les bornes sans std::min/max
        if (start < 0) start = 0;
        if (start > size_) start = size_;
        if (end < 0) end = 0;
        if (end > size_) end = size_;
        
        Node* current = head;
        for (__ss_int i = 0; i < start && current; i++) {
            current = current->next;
        }
        
        for (__ss_int i = start; i < end && current; i++) {
            slice->append(current->data);
            current = current->next;
        }
        
        return slice;
    }

    // Support for Python slicing
    list<T>* __slice__(__ss_int length, __ss_int start, __ss_int stop, __ss_int step) const {
        list<T>* slice = new list<T>();
        
        if (start < 0) start = size_ + start;
        if (stop < 0) stop = size_ + stop;
        
        if (start < 0) start = 0;
        if (start > size_) start = size_;
        if (stop < 0) stop = 0;
        if (stop > size_) stop = size_;
        
        Node* current = head;
        for (__ss_int i = 0; i < start && current; i++) {
            current = current->next;
        }
        
        for (__ss_int i = start; i < stop && current; i++) {
            slice->append(current->data);
            current = current->next;
        }
        
        return slice;
    }

    // Operator overload for list concatenation
    list<T>* operator+(const list<T>* other) const {
        list<T>* result = new list<T>(*this);
        if (other) {
            Node* current = other->head;
            while (current) {
                result->append(current->data);
                current = current->next;
            }
        }
        return result;
    }

    // Operator overload for list replication
    list<T>* operator*(__ss_int n) const {
        list<T>* result = new list<T>();
        for (__ss_int i = 0; i < n; i++) {
            Node* current = head;
            while (current) {
                result->append(current->data);
                current = current->next;
            }
        }
        return result;
    }

    // Python-style addition
    list<T>* __add__(list<T>* other) const {
        list<T>* result = new list<T>(*this);
        if (other) {
            Node* current = other->head;
            while (current) {
                result->append(current->data);
                current = current->next;
            }
        }
        return result;
    }

    // Python-style multiplication
    list<T>* __mul__(__ss_int n) const {
        list<T>* result = new list<T>();
        for (__ss_int i = 0; i < n; i++) {
            Node* current = head;
            while (current) {
                result->append(current->data);
                current = current->next;
            }
        }
        return result;
    }
    
    // Modify the for_in_loop class inside list class (around line 263):
    class for_in_loop {
        typename list<T>::Iterator it;
        typename list<T>::Iterator end_it;
    public:
        // Ajout d'un constructeur par défaut
        for_in_loop() : it(nullptr), end_it(nullptr) {}

        // Constructeur principal
        for_in_loop(list<T>& l) : it(l.begin()), end_it(l.end()) {}

        bool __next__(T& ref) {
            if (it != end_it) {
                ref = *it;
                ++it;
                return true;
            }
            return false;
        }
    };
    
};


// Global helper functions
template<typename T>
__ss_int len(list<T>* lst) {
    return lst ? lst->__len__() : 0;
}

template<class K, class V>
__ss_int len(dict<K,V>* d) {
    return d ? d->__len__() : 0;
}

template<class T>
__ss_int len(set<T>* s) {
    return s ? s->__len__() : 0;
}

template<typename T>
bool __eq(list<T>* a, list<T>* b) {
    if (!a || !b) return false;
    return a->equals(b);
}

template<typename T>
list<T>* sorted(list<T>* lst, __ss_int start=0, __ss_int stop=0, __ss_int step=0) {
    return list<T>::__sorted__(lst);
}

} // namespace shedskin

#endif