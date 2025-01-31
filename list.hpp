#ifndef SS_LIST_HPP
#define SS_LIST_HPP

namespace shedskin {

// Forward declarations
template<class K, class V> class dict;
template<class T> class set;
template<class T> class list;

template<class T>
class list : public pyobj {
private:
    struct Node {
        T data;
        Node* next;
        Node(const T& value) : data(value), next(nullptr) {}
    };
    
    Node* head;
    Node* tail;
    __ss_int size_;

public:
    // Classe pour l'itération
    class for_in_loop {
    public:
        Node* current;
        for_in_loop(Node* n) : current(n) {}
        for_in_loop() : current(nullptr) {}
        bool has_next() const { return current != nullptr; }
        T next() {
            if (!current) throw std::runtime_error("No more elements");
            T value = current->data;
            current = current->next;
            return value;
        }
    };

    // Constructeurs
    list() : head(nullptr), tail(nullptr), size_(0) {}
    
    list(__ss_int count, const T& value) : head(nullptr), tail(nullptr), size_(0) {
        for(__ss_int i = 0; i < count; i++) {
            append(value);
        }
    }

    list(__ss_int count, const T& v1, const T& v2) : head(nullptr), tail(nullptr), size_(0) {
        if(count > 0) append(v1);
        if(count > 1) append(v2);
    }

    list(__ss_int count, const T& v1, const T& v2, const T& v3) : head(nullptr), tail(nullptr), size_(0) {
        if(count > 0) append(v1);
        if(count > 1) append(v2);
        if(count > 2) append(v3);
    }

    list(__ss_int count, const T& v1, const T& v2, const T& v3, const T& v4) : head(nullptr), tail(nullptr), size_(0) {
        if(count > 0) append(v1);
        if(count > 1) append(v2);
        if(count > 2) append(v3);
        if(count > 3) append(v4);
    }

    list(__ss_int count, const T& v1, const T& v2, const T& v3, const T& v4, const T& v5) : head(nullptr), tail(nullptr), size_(0) {
        if(count > 0) append(v1);
        if(count > 1) append(v2);
        if(count > 2) append(v3);
        if(count > 3) append(v4);
        if(count > 4) append(v5);
    }

    ~list() {
        clear();
    }

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

    void clear() {
        while (head) {
            Node* temp = head;
            head = head->next;
            delete temp;
        }
        tail = nullptr;
        size_ = 0;
    }

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

    T __getitem__(__ss_int index) const {
        if (index < 0) {
            index = size_ + index;
        }
        if (index < 0 || index >= size_) {
            throw std::runtime_error("Index out of range");
        }
        
        Node* current = head;
        for (__ss_int i = 0; i < index; i++) {
            current = current->next;
        }
        return current ? current->data : T();
    }

    list<T>* __slice__(__ss_int length, __ss_int start, __ss_int stop, __ss_int step) const {
        list<T>* result = new list<T>();
        
        if (start < 0) start = size_ + start;
        if (stop < 0) stop = size_ + stop;
        
        start = (start < 0) ? 0 : (start >= size_ ? size_ : start);
        stop = (stop < 0) ? 0 : (stop >= size_ ? size_ : stop);
        
        if (step == 0) throw std::runtime_error("slice step cannot be zero");
        
        for (__ss_int i = start; i < stop; i += step) {
            result->append(__getitem__(i));
        }
        
        return result;
    }

    __ss_int __len__() const { return size_; }
    Node* get_head() const { return head; }

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

    list<T>* __add__(const list<T>* other) const {
        list<T>* result = new list<T>();
        
        Node* current = head;
        while (current) {
            result->append(current->data);
            current = current->next;
        }
        
        if (other) {
            current = other->head;
            while (current) {
                result->append(current->data);
                current = current->next;
            }
        }
        
        return result;
    }

    list<T>* __mul__(__ss_int n) const {
        list<T>* result = new list<T>();
        if (n <= 0) return result;
        
        for (__ss_int i = 0; i < n; i++) {
            Node* current = head;
            while (current) {
                result->append(current->data);
                current = current->next;
            }
        }
        
        return result;
    }

    list<T>* sorted() const {
        list<T>* result = new list<T>(*this);
        if (size_ <= 1) return result;

        T* arr = new T[size_];
        Node* current = head;
        for (__ss_int i = 0; i < size_; i++) {
            arr[i] = current->data;
            current = current->next;
        }
        
        for (__ss_int i = 0; i < size_ - 1; i++) {
            for (__ss_int j = 0; j < size_ - i - 1; j++) {
                if (arr[j] > arr[j + 1]) {
                    T temp = arr[j];
                    arr[j] = arr[j + 1];
                    arr[j + 1] = temp;
                }
            }
        }
        
        result->clear();
        for (__ss_int i = 0; i < size_; i++) {
            result->append(arr[i]);
        }
        
        delete[] arr;
        return result;
    }
};

// Fonctions globales
template<typename T>
__ss_int len(const list<T>* lst) {
    return lst ? lst->__len__() : 0;
}

template<typename T>
bool __eq(const list<T>* a, const list<T>* b) {
    if (!a || !b) return false;
    return a->equals(b);
}

template<typename T>
list<T>* sorted(list<T>* lst, __ss_int a=0, __ss_int b=0, __ss_int c=0) {
    if (!lst) return new list<T>();
    return lst->sorted();
}

template<typename T>
bool all(const list<T>* lst) {
    if (!lst) return false;
    for (__ss_int i = 0; i < lst->__len__(); i++) {
        if (!lst->__getitem__(i)) return false;
    }
    return true;
}

} // namespace shedskin

// Classe list_comp_0 globale
class list_comp_0 {
public:
    shedskin::list<__ss_int>* list1;
    __ss_int __last_yield;
    bool __stop_iteration;
    __ss_int x;  // Variable pour FOR_IN
    shedskin::list<__ss_int>::for_in_loop __3;

    list_comp_0(shedskin::list<__ss_int>* lst) : 
        list1(lst), 
        __last_yield(-1),
        __stop_iteration(false),
        __3(lst ? lst->get_head() : nullptr) {}

    __ss_bool __get_next() {
        static bool initialized = false;
        if (!initialized) {
            initialized = true;
            if (__3.has_next()) {
                x = __3.next();
                return x != 0;
            }
            __stop_iteration = true;
        }
        return false;
    }
};

bool all(list_comp_0* lst) {
    if (!lst) return false;
    while (!lst->__stop_iteration) {
        if (!lst->__get_next()) return false;
    }
    return true;
}

#endif