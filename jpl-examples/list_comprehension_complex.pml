#define CAPACITY 1
#define NONE 255 // Using 255 to represent None in byte

byte counter;

proctype Up() {
    do
    :: (counter <= 10) ->
        atomic {
            counter = counter + 1;
            printf("Up: counter = %d\n", counter)
        }
    :: else -> skip
    od
}


proctype Down() {
    do
    :: (counter > 0) ->
        atomic {
            counter = counter - 1;
            printf("Down: counter = %d\n", counter)
        }
    :: else -> skip
    od
}


proctype Checker() {
    do
    :: (counter < 0 || counter > 10) ->
        assert(0)
    :: else -> skip
    od
}


init {
    counter = 5; 
    run Up();
    run Down();
    run Checker();
}
