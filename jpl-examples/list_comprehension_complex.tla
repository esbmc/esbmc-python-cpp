---- MODULE try1 ----

EXTENDS Integers

VARIABLE counter

Down ==
    /\ counter > 0
    /\ counter' = counter - 1

Up ==
    /\ counter < 10
    /\ counter' = counter + 1

Init == counter = 5

Next ==  Down \/ Up

Spec == Init /\ [][Next]_counter

Property == 0 =< counter /\ counter =< 10

Invariant == []Property

====
