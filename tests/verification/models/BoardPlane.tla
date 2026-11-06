--------------------------- MODULE BoardPlane ---------------------------
EXTENDS Naturals, TLC
CONSTANTS CheckConstrained, CheckNarrowFold
VARIABLES s, last
vars == <<s, last>>

Layout(w, l, r, side, tab, det) ==
    LET constrained == IF CheckConstrained THEN w < 1232 ELSE FALSE
        lOpen == ~det /\ l /\ ~(constrained /\ r /\ side = "right")
        rOpen == r /\ ~(constrained /\ l /\ side = "left")
        takeover == IF det THEN "right"
                    ELSE IF w < 800 THEN
                        IF rOpen THEN "right"
                        ELSE IF lOpen THEN "left"
                        ELSE "none"
                    ELSE "none"
    IN [width |-> w, left |-> l, right |-> r, last |-> side, tab |-> tab, detail |-> det,
        leftOpen |-> lOpen, rightOpen |-> rOpen, takeover |-> takeover]

Init ==
    /\ s = Layout(1440, FALSE, FALSE, "right", "inspector", FALSE)
    /\ last = "Init"

FoldSide(side) ==
    IF s.width < 800 /\ CheckNarrowFold
    THEN Layout(s.width, FALSE, FALSE, s.last, s.tab, FALSE)
    ELSE IF side = "left"
         THEN Layout(s.width, FALSE, s.right, s.last, s.tab, FALSE)
         ELSE Layout(s.width, s.left, FALSE, s.last, s.tab, FALSE)

NextState(e) ==
    CASE e = "OpenLeft" -> Layout(s.width, TRUE, s.right, "left", s.tab, FALSE)
    [] e = "OpenRight" -> Layout(s.width, s.left, TRUE, "right", s.tab, FALSE)
    [] e = "FoldLeft" -> FoldSide("left")
    [] e = "FoldRight" -> FoldSide("right")
    [] e = "ToggleLeft" ->
        IF s.leftOpen THEN FoldSide("left")
        ELSE Layout(s.width, TRUE, s.right, "left", s.tab, FALSE)
    [] e = "ToggleRight" ->
        IF s.rightOpen THEN FoldSide("right")
        ELSE Layout(s.width, s.left, TRUE, "right", s.tab, FALSE)
    [] e = "TabInspector" -> Layout(s.width, s.left, TRUE, "right", "inspector", FALSE)
    [] e = "TabAssistant" -> Layout(s.width, s.left, TRUE, "right", "assistant", FALSE)
    [] e = "Detail" -> Layout(s.width, s.left, TRUE, "right", s.tab, ~s.detail)
    [] e = "ResizeWide" -> Layout(1440, s.left, s.right, s.last, s.tab, s.detail)
    [] e = "ResizeMedium" -> Layout(1000, s.left, s.right, s.last, s.tab, s.detail)
    [] OTHER -> Layout(390, s.left, s.right, s.last, s.tab, s.detail)

Events == {
    "OpenLeft", "OpenRight", "FoldLeft", "FoldRight",
    "ToggleLeft", "ToggleRight", "TabInspector", "TabAssistant",
    "Detail", "ResizeWide", "ResizeMedium", "ResizeNarrow"
}

Step == \E e \in Events :
    /\ s' = NextState(e)
    /\ last' = e

SingleSideWhenConstrained ==
    (s.width < 1232) => ~(s.leftOpen /\ s.rightOpen)

NarrowFoldReturnsToWork ==
    (last \in {"FoldLeft", "FoldRight"} /\ s.width < 800) =>
        (s.takeover = "none" /\ ~s.leftOpen /\ ~s.rightOpen)

AssistantActionSelectsTab ==
    (last = "TabAssistant") => (s.tab = "assistant" /\ s.rightOpen)

Spec == Init /\ [][Step]_vars
=============================================================================
