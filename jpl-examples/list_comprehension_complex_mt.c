#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <assert.h>

#define MAX_ACTIONS 2
#define MAX_ENABLED_ACTIONS 2

// Global counter as in the original
int counter = 5;

// Action type definitions
typedef struct Action {
    bool (*pre)(void);
    void (*act)(void);
} Action;

// Function declarations
bool down_pre(void);
void down_act(void);
bool up_pre(void);
void up_act(void);

// Down implementation
bool down_pre(void) {
    return counter > 0;
}

void down_act(void) {
    counter -= 1;
    assert(counter >= 0);
    printf("counting down: %d\n", counter);
}

// Up implementation
bool up_pre(void) {
    return counter < 10;
}

void up_act(void) {
    counter += 1;
    assert(counter <= 10);
    printf("counting up: %d\n", counter);
}

// List comprehension equivalent
int list_comp(Action* actions, Action* enabled_actions, int actions_size) {
    int enabled_count = 0;
    for(int i = 0; i < actions_size; i++) {
        if(actions[i].pre()) {
            enabled_actions[enabled_count++] = actions[i];
        }
    }
    return enabled_count;
}

int main(void) {
    // Initialize actions
    Action actions[MAX_ACTIONS] = {
        {down_pre, down_act},
        {up_pre, up_act}
    };
    
    Action enabled_actions[MAX_ENABLED_ACTIONS];
    
    while(1) {
        int enabled_count = list_comp(actions, enabled_actions, MAX_ACTIONS);
        
        if(enabled_count > 0) {
            int action_nr = rand() % enabled_count;
            printf("length=%d action=%d\n", enabled_count, action_nr);
            enabled_actions[action_nr].act();
        }
    }
    
    return 0;
}
