------------------------- MODULE bip32_template_parse --------------------------

EXTENDS Naturals, Sequences, TLC

CONSTANT HARDENED_INDEX_START
ASSUME HARDENED_INDEX_START >= 1

CONSTANT EXTRA_CHARS

CONSTANT NULL_CHAR
ASSUME NULL_CHAR \notin EXTRA_CHARS

CONSTANT MAX_SECTIONS
ASSUME MAX_SECTIONS >= 1

CONSTANT MAX_RANGES_IN_FIRST_SECTION
ASSUME MAX_RANGES_IN_FIRST_SECTION >= 1

CONSTANT MAX_RANGES_IN_OTHER_SECTIONS
ASSUME MAX_RANGES_IN_OTHER_SECTIONS >= 1

CONSTANT TEMPLATE_FORMAT_UNAMBIGOUS
ASSUME TEMPLATE_FORMAT_UNAMBIGOUS \in BOOLEAN

CONSTANT INDEX_VALUE_STRINGS_FIRST_SECTION
ASSUME \A s \in INDEX_VALUE_STRINGS_FIRST_SECTION: Len(s) > 0

CONSTANT INDEX_VALUE_STRINGS_OTHER_SECTIONS
ASSUME \A s \in INDEX_VALUE_STRINGS_OTHER_SECTIONS: Len(s) > 0

VARIABLES c, template, fsm_state, fsm_return_state, index_value,
          accepted_hardened_markers, path_section, input_string,
          input_value_string, input_value_pos, is_partial

\* Note: the following two variables only needed for the
\* 'allow one error' mode, where when we encounter one of
\* SkippableErrorStates, we ignore the error: current char is ignored,
\* and fsm_state is restored back to saved_state (which is set on each
\* state transition). This way we can generate test cases where the
\* template string is 'complete', but contains an error inside it.
\* If we always stop on error state, we get much smaller state space,
\* but non-FSM parsers or those that might process more than
\* one char at a time have less coverage with generated test data.
VARIABLES saved_state, skipped_error_state

fullState == <<c, template, fsm_state, fsm_return_state, index_value,
               accepted_hardened_markers, path_section, input_string,
               saved_state, skipped_error_state, is_partial,
               input_value_string, input_value_pos>>

unchanged_OnStateTransition ==
    <<template, index_value, accepted_hardened_markers, path_section,
      fsm_return_state>>

unchanged_OnStateTransitionWithReturn ==
    <<template, index_value, accepted_hardened_markers, path_section>>

MAX_INDEX_VALUE == HARDENED_INDEX_START - 1
INVALID_INDEX == HARDENED_INDEX_START

StateNextSection                     == "next_section"
StateSectionStart                    == "section_start"
StateRangeWithinSection              == "range_within_section"
StateSectionEnd                      == "section_end"
StateParseValue                      == "parse_value"

StateErrorUnexpectedHardenedMarker   == "error_unexpected_hardened_marker"
StateErrorUnexpectedSpace            == "error_unexpected_space"
StateErrorUnexpectedChar             == "error_unexpected_char"
StateErrorUnexpectedFinish           == "error_unexpected_finish"
StateErrorUnexpectedSlash            == "error_unexpected_slash"
StateErrorInvalidChar                == "error_invalid_char"
StateErrorIndexTooBig                == "error_index_too_big"
StateErrorIndexHasLeadingZero        == "error_index_has_leading_zero"
StateErrorPathEmpty                  == "error_path_empty"
StateErrorPathTooLong                == "error_path_too_long"
StateErrorPathSectionTooLong         == "error_path_section_too_long"
StateErrorRangesIntersect            == "error_ranges_intersect"
StateErrorRangeOrderBad              == "error_range_order_bad"
StateErrorRangeEqualsWildcard        == "error_range_equals_wildcard"
StateErrorSingleIndexAsRange         == "error_single_index_as_range"
StateErrorRangeStartEqualsEnd        == "error_range_start_equals_end"
StateErrorRangeStartNextToPrevious   == "error_range_start_next_to_previous"
StateErrorGotHardenedAfterUnhardened == "error_got_hardened_after_unhardened"
StateErrorDigitExpected              == "error_digit_expected"

StateInvalid                         == "invalid"
StateNormalFinish                    == "normal_finish"

CommonErrorStates == {
    StateErrorUnexpectedHardenedMarker,
    StateErrorUnexpectedSpace,
    StateErrorUnexpectedChar,
    StateErrorInvalidChar,
    StateErrorUnexpectedFinish,
    StateErrorIndexTooBig,
    StateErrorIndexHasLeadingZero,
    StateErrorPathEmpty,
    StateErrorPathTooLong,
    StateErrorPathSectionTooLong,
    StateErrorRangesIntersect,
    StateErrorRangeOrderBad,
    StateErrorRangeEqualsWildcard,
    StateErrorUnexpectedSlash,
    StateErrorSingleIndexAsRange,
    StateErrorRangeStartEqualsEnd,
    StateErrorGotHardenedAfterUnhardened,
    StateErrorDigitExpected
}

UnambigousFormatErrorStates ==
    IF TEMPLATE_FORMAT_UNAMBIGOUS
    THEN { StateErrorRangeStartNextToPrevious }
    ELSE {}

ErrorStates == CommonErrorStates \union UnambigousFormatErrorStates

SkippableErrorStates == {
    StateErrorUnexpectedHardenedMarker,
    StateErrorUnexpectedSpace,
    StateErrorUnexpectedChar,
    StateErrorUnexpectedSlash,
    StateErrorInvalidChar,
    StateErrorIndexTooBig,
    StateErrorIndexHasLeadingZero,
    StateErrorDigitExpected
}

OperationalStates == {
    StateNextSection,
    StateSectionStart,
    StateRangeWithinSection,
    StateSectionEnd,
    StateParseValue
}

ValidStates == OperationalStates
               \union ErrorStates
               \union { StateNormalFinish }

DigitsTuple == <<"0", "1", "2", "3", "4", "5", "6", "7", "8", "9">>

Digits == { DigitsTuple[n]: n \in DOMAIN DigitsTuple }

\* An implementation that wants unambiguity, can allow only one
\* hardened marker, or can string-replace "'" with "h" before comparision
HardenedMarkers == IF TEMPLATE_FORMAT_UNAMBIGOUS
                   THEN { "h" }
                   ELSE { "'", "h" }

ValidChars == { "m", "/", "[", "]", "-", ",", "*" }
              \union HardenedMarkers
              \union Digits

ASSUME NULL_CHAR \notin ValidChars

\* Space is not allowed, but having separate error for
\* 'unexpected space' rather than generic 'invalid char'
\* is beneficial, helps to avoid confusion
SpaceChars == { " " }

AllChars == ValidChars \union EXTRA_CHARS \union { NULL_CHAR }
            \union SpaceChars

\* _raw here means 'without the UNCHANGED expression'
StateTransition_raw(state) ==
    /\ fsm_state' = state
    /\ saved_state' =
        IF state \in ErrorStates
        THEN fsm_state
        ELSE StateInvalid \* saved_state is not relevant for non-error states

StateTransitionWithReturn_raw(state, return_state) ==
    /\ StateTransition_raw(state)
    /\ fsm_return_state' = return_state

StateTransition(state) ==
    /\ StateTransition_raw(state)
    /\ UNCHANGED unchanged_OnStateTransition

StateTransitionWithReturn(state, return_state) ==
    StateTransitionWithReturn_raw(state, return_state)
    /\ UNCHANGED unchanged_OnStateTransitionWithReturn

ProcessDigit ==
    LET v == ( CHOOSE n \in DOMAIN DigitsTuple: DigitsTuple[n] = c ) - 1
     IN CASE index_value = 0
             -> [ ok |-> FALSE, error_state |-> StateErrorIndexHasLeadingZero ]
          [] ( \* Special case for very small MAX_INDEX_VALUE
               \* Useful for model checking,
               \* not relevant for practical implementations
               /\ MAX_INDEX_VALUE < 10
               /\ index_value = INVALID_INDEX
               /\ v > MAX_INDEX_VALUE )
             -> [ ok |-> FALSE, error_state |-> StateErrorIndexTooBig ]
          [] ( /\ index_value /= INVALID_INDEX
               /\ \/ index_value > MAX_INDEX_VALUE \div 10
                  \/ /\ index_value = MAX_INDEX_VALUE \div 10
                     /\ v > MAX_INDEX_VALUE % 10 )
             -> [ ok |-> FALSE, error_state |-> StateErrorIndexTooBig ]
          [] OTHER
             -> LET new_value == IF index_value = INVALID_INDEX
                                 THEN v
                                 ELSE index_value * 10 + v
                    check == Assert( new_value <= MAX_INDEX_VALUE,
                                     "must be prevented by earlier case checks" )
                 IN [ ok |-> check /\ TRUE, value |-> new_value ]

ParseFinishedAfterErrorWasSkipped ==
    /\ fsm_state \notin OperationalStates
    /\ skipped_error_state[1] /= StateInvalid

ParseSucceeded == /\ fsm_state = StateNormalFinish
                  /\ ~ParseFinishedAfterErrorWasSkipped

ParseFailed == \/ fsm_state \in ErrorStates
               \/ ParseFinishedAfterErrorWasSkipped

ParseFinished ==
    \/ ParseSucceeded
    \/ ParseFailed

IsPathSectionRangeOpen ==
    /\ Len(path_section) > 0
    /\ Len(path_section[Len(path_section)]) = 1

OpenPathSectionRange(value) ==
    path_section' = Append(path_section, <<value>>)

FinalizedPathSection ==
    IF IsPathSectionRangeOpen
    THEN LET last_elt == path_section[Len(path_section)]
          IN CASE Len(last_elt) > 1
                  -> Assert( Len(last_elt) = 1, "range must be open" )
               [] OTHER
                  -> [path_section
                      EXCEPT ![Len(path_section)] = <<last_elt[1],
                                                      index_value>>]
    ELSE Append(path_section, <<index_value, index_value>>)

NormalizedPathSection ==
    LET fps == FinalizedPathSection
     IN IF Len(fps) = 1
        THEN fps
        ELSE LET last == fps[Len(fps)]
                 pre_last == fps[Len(fps)-1]
                 prefix == IF Len(fps) = 2
                           THEN <<>>
                           ELSE SubSeq(fps, 1, Len(fps)-2)
              IN IF pre_last[2] + 1 = last[1]
                 THEN Append(prefix, <<pre_last[1], last[2]>>)
                 ELSE fps

CollectSection(section) ==
    /\ template' = Append(template, section)
    /\ path_section' = <<>>

HardenPathSection(section) ==
    [n \in DOMAIN section
     |-> [m \in DOMAIN section[n]
          |-> section[n][m] + HARDENED_INDEX_START]]

IsSectionHardened(section) ==
    /\ \E n \in DOMAIN section: \/ section[n][1] >= HARDENED_INDEX_START
                                \/ section[n][2] >= HARDENED_INDEX_START
    /\ Assert( \A m \in DOMAIN section:
                 /\ section[m][1] >= HARDENED_INDEX_START
                 /\ section[m][2] >= HARDENED_INDEX_START,
               "hardened/unhardened cannot be mixed within one range" )
    /\ Assert( \A m \in DOMAIN section:
                 /\ section[m][1] <= MAX_INDEX_VALUE + HARDENED_INDEX_START
                 /\ section[m][2] <= MAX_INDEX_VALUE + HARDENED_INDEX_START,
               "range values cannot exceed MAX_INDEX_VALUE+HARDENED_INDEX_START" )

UnexpectedCharState ==
    CASE c = NULL_CHAR    -> StateErrorUnexpectedFinish
      [] c \in SpaceChars -> StateErrorUnexpectedSpace
      [] c \in ValidChars -> StateErrorUnexpectedChar
      [] OTHER            -> StateErrorInvalidChar

CheckRangeCorrectness(where) ==
    LET fps == FinalizedPathSection
        IsStartEqualsEnd      == fps[Len(fps)][1] = fps[Len(fps)][2]
        IsRangeEqualsWildcard == /\ fps[Len(fps)][1] = 0
                                 /\ fps[Len(fps)][2] = MAX_INDEX_VALUE
        IsStartLargerThanEnd  == fps[Len(fps)][1] > fps[Len(fps)][2]
        IsStartBeforePrevious == /\ Len(fps) > 1 
                                 /\ fps[Len(fps)-1][1] > fps[Len(fps)][1]
        IsStartInPrevious     == /\ Len(fps) > 1 
                                 /\ fps[Len(fps)-1][1] <= fps[Len(fps)][1]
                                 /\ fps[Len(fps)-1][2] >= fps[Len(fps)][1]
        IsStartNextToPrevious == /\ Len(fps) > 1 
                                 /\ fps[Len(fps)-1][2] + 1 = fps[Len(fps)][1]
        IsSingleIndex ==
            CASE where = "range_last" -> Len(fps) = 1 /\ IsStartEqualsEnd
              [] where = "range_next" -> FALSE
     IN CASE IsSingleIndex
             -> [ ok |-> FALSE, error_state |-> StateErrorSingleIndexAsRange ]
          [] IsPathSectionRangeOpen /\ IsStartEqualsEnd
             -> [ ok |-> FALSE, error_state |-> StateErrorRangeStartEqualsEnd ]
          [] TEMPLATE_FORMAT_UNAMBIGOUS /\ IsStartNextToPrevious
             -> [ ok |-> FALSE, error_state |-> StateErrorRangeStartNextToPrevious ]
          [] IsRangeEqualsWildcard
             -> [ ok |-> FALSE, error_state |-> StateErrorRangeEqualsWildcard ]
          [] IsStartLargerThanEnd
             -> [ ok |-> FALSE, error_state |-> StateErrorRangeOrderBad ]
          [] IsStartBeforePrevious
             -> [ ok |-> FALSE, error_state |-> StateErrorRangeOrderBad ]
          [] IsStartInPrevious
             -> [ ok |-> FALSE, error_state |-> StateErrorRangesIntersect ]
          [] OTHER
             -> [ ok |-> TRUE ]

MaxRangesInSection ==
    IF Len(template) = 0 /\ c /= "/"
    THEN MAX_RANGES_IN_FIRST_SECTION
    ELSE MAX_RANGES_IN_OTHER_SECTIONS

IndexValueStringsForSection ==
    IF Len(template) = 0 /\ c /= "/"
    THEN INDEX_VALUE_STRINGS_FIRST_SECTION
    ELSE INDEX_VALUE_STRINGS_OTHER_SECTIONS

GetChar ==
    \/ /\ input_value_pos > Len(input_value_string)
       /\ c' \in AllChars \ Digits
       /\ input_value_string' = <<>>
       /\ input_value_pos' = 1
    \/ /\ input_value_pos <= Len(input_value_string)
       /\ c' = input_value_string[input_value_pos]
       /\ input_value_pos' = input_value_pos + 1
       /\ UNCHANGED input_value_string
    \/ /\ input_value_string = <<>>
       /\ input_value_string' \in IndexValueStringsForSection
       /\ c' = input_value_string'[1]
       /\ input_value_pos' = 2

GetCharAtStart ==
    \/ /\ c \in AllChars \ Digits
       /\ input_value_string = <<>>
       /\ input_value_pos = 1
    \/ /\ input_value_string \in INDEX_VALUE_STRINGS_FIRST_SECTION
       /\ input_value_pos = 2
       /\ c = input_value_string[1]


InPrefixStart == c = "m" /\ Len(input_string) = 0

InPrefixExpectSlash == ~is_partial /\ Len(input_string) = 1

InPrefix == InPrefixStart \/ InPrefixExpectSlash

PrefixParserFSM ==
    CASE InPrefixStart
         -> /\ is_partial' = FALSE
            /\ UNCHANGED <<fsm_state, saved_state, unchanged_OnStateTransition>>
      [] InPrefixExpectSlash
         -> IF c = "/"
            THEN UNCHANGED <<is_partial, fsm_state, saved_state,
                             unchanged_OnStateTransition>>
            ELSE /\ StateTransition(UnexpectedCharState)
                 /\ UNCHANGED is_partial


ParserFSM ==
    CASE fsm_state = StateSectionStart
         -> CASE c = "/"
                 -> StateTransition(StateErrorUnexpectedSlash)
              [] c \in { "[", "*" } /\ Len(template) = MAX_SECTIONS
                 -> StateTransition(StateErrorPathTooLong)
              [] c = "["
                 -> /\ index_value' = INVALID_INDEX
                    /\ StateTransitionWithReturn_raw(StateParseValue,
                                                     StateRangeWithinSection)
                    /\ UNCHANGED <<template, accepted_hardened_markers,
                                    path_section>>
              [] c = "*"
                 -> /\ OpenPathSectionRange(0)
                    /\ index_value' = MAX_INDEX_VALUE
                    /\ StateTransition_raw(StateSectionEnd)
                    /\ UNCHANGED <<template, accepted_hardened_markers,
                                   fsm_return_state>>
              [] c \in Digits /\ Len(template) = MAX_SECTIONS
                 -> LET res == ProcessDigit
                     IN IF res.ok
                        THEN StateTransition(StateErrorPathTooLong)
                        ELSE StateTransition(res.error_state)
              [] c \in Digits
                 -> LET res == ProcessDigit
                    IN IF res.ok
                       THEN /\ index_value' = res.value
                            /\ StateTransitionWithReturn_raw(StateParseValue,
                                                             StateSectionEnd)
                            /\ UNCHANGED <<template, accepted_hardened_markers,
                                           path_section>>
                       ELSE StateTransition(res.error_state)
              [] c = NULL_CHAR
                 -> IF Len(template) = 0
                    THEN StateTransition(StateErrorPathEmpty)
                    ELSE StateTransition(StateErrorUnexpectedSlash)
              [] OTHER -> StateTransition(UnexpectedCharState)

      [] fsm_state = StateNextSection
         -> CASE c = "/"
                 -> StateTransition(StateSectionStart)
              [] c = NULL_CHAR /\ Len(template) > MAX_SECTIONS
                 -> StateTransition(StateErrorPathTooLong)
              [] c = NULL_CHAR
                 -> StateTransition(StateNormalFinish)
              [] OTHER -> StateTransition(UnexpectedCharState)

      [] fsm_state = StateRangeWithinSection
         -> CASE c = NULL_CHAR
                 -> StateTransition(StateErrorUnexpectedFinish)
              [] index_value = INVALID_INDEX
                 -> /\ fsm_state' = IF c \in SpaceChars
                                    THEN StateErrorUnexpectedSpace
                                    ELSE StateErrorDigitExpected
                       \* The following two equality expressions
                       \* are needed to enable skipping this error state.
                       \* Error skipping is only relevant for test data
                       \* generation for non-FSM-based parser
                    /\ saved_state' = StateParseValue
                    /\ fsm_return_state' = StateRangeWithinSection
                    /\ UNCHANGED unchanged_OnStateTransitionWithReturn
              [] c = "-"
                 -> IF ~IsPathSectionRangeOpen
                    THEN /\ OpenPathSectionRange(index_value)
                         /\ index_value' = INVALID_INDEX
                         /\ StateTransitionWithReturn_raw(
                                 StateParseValue, StateRangeWithinSection)
                         /\ UNCHANGED <<template, accepted_hardened_markers>>
                    ELSE StateTransition(UnexpectedCharState)
              [] c = ","
                 -> IF Len(FinalizedPathSection) = MaxRangesInSection
                    THEN StateTransition(StateErrorPathSectionTooLong)
                    ELSE LET res == CheckRangeCorrectness("range_next")
                          IN IF res.ok
                             THEN /\ path_section' = NormalizedPathSection
                                  /\ index_value' = INVALID_INDEX
                                  /\ StateTransitionWithReturn_raw(
                                          StateParseValue,
                                          StateRangeWithinSection)
                                  /\ UNCHANGED <<template,
                                                 accepted_hardened_markers>>
                             ELSE StateTransition(res.error_state)
              [] c = "]"
                 -> LET res == CheckRangeCorrectness("range_last")
                     IN IF res.ok
                        THEN StateTransition(StateSectionEnd)
                        ELSE StateTransition(res.error_state)
              [] OTHER -> StateTransition(UnexpectedCharState)

      [] fsm_state = StateSectionEnd
         -> CASE index_value = INVALID_INDEX
                 -> Assert( index_value /= INVALID_INDEX,
                    "valid index expected" )
              [] c = NULL_CHAR /\ Len(template) = MAX_SECTIONS
                 -> StateTransition(StateErrorPathTooLong)
              [] c \in { "/", NULL_CHAR }
                 -> /\ CollectSection(NormalizedPathSection)
                    /\ index_value' = INVALID_INDEX
                    /\ StateTransition_raw(IF c = NULL_CHAR
                                           THEN StateNormalFinish
                                           ELSE StateSectionStart)
                    /\ UNCHANGED <<fsm_return_state,
                                   accepted_hardened_markers>>
              [] c \in accepted_hardened_markers
                 -> IF /\ Len(template) > 0
                       /\ ~IsSectionHardened(template[Len(template)])
                    THEN StateTransition(StateErrorGotHardenedAfterUnhardened)
                    ELSE /\ IF accepted_hardened_markers /= { c }
                            THEN accepted_hardened_markers' = { c }
                            ELSE UNCHANGED accepted_hardened_markers
                         /\ CollectSection(
                                HardenPathSection(NormalizedPathSection))
                         /\ index_value' = INVALID_INDEX
                         /\ StateTransition_raw(StateNextSection)
                         /\ UNCHANGED fsm_return_state
              [] c \in HardenedMarkers
                 -> StateTransition(StateErrorUnexpectedHardenedMarker)
              [] OTHER -> StateTransition(UnexpectedCharState)

      [] fsm_state = StateParseValue
         -> /\ Assert( c \in Digits, "this check is in top-level logic" )
            /\ LET res == ProcessDigit
                IN IF res.ok
                   THEN /\ index_value' = res.value
                        /\ UNCHANGED <<template, accepted_hardened_markers,
                                       path_section, fsm_state,
                                       saved_state, fsm_return_state>>
                   ELSE StateTransition(res.error_state)

\* matching operator
MatchPathAgainstTemplate(path_tuple, tmpl) ==
    /\ Len(path_tuple) = Len(template)
    /\ ~( \A n \in DOMAIN path_tuple:
          \A m \in DOMAIN tmpl[n]:
             \/ path_tuple[n] < tmpl[n][m][1]
             \/ path_tuple[n] > tmpl[n][m][2] )

\* Operators to extract the low and high bounds paths from the template
RandomPathFromTemplate(tmpl) ==
    [ n \in DOMAIN tmpl
      |-> RandomElement(UNION { {tmpl[n][m][1], tmpl[n][m][2]}:
                                m \in DOMAIN tmpl[n] }) ]

(***************)
(* Invariants  *)
(***************)

TypeOK == /\ \/ fsm_state \in ValidStates
             \/ Print("invalid state", FALSE)
          /\ \/ fsm_return_state \in { StateRangeWithinSection,
                                       StateSectionEnd,
                                       StateInvalid }
             \/ Print("invalid return state", FALSE)
          /\ \/ fsm_state /= StateSectionEnd
                => \A n \in DOMAIN path_section:
                    \A m \in DOMAIN path_section[n]:
                       path_section[n][m] /= INVALID_INDEX
             \/ Print("invalid index encountered", FALSE)
          /\ \/ fsm_state = StateParseValue => fsm_return_state /= StateInvalid
             \/ Print("return state invalid when parsing value", FALSE)

PathAndSectionLengthsAreWithinBounds ==
    /\ \/ Len(template) <= MAX_SECTIONS
       \/ Print("path too long", FALSE)
    /\ \A n \in DOMAIN template:
        LET max_ranges == IF n = 1
                          THEN MAX_RANGES_IN_FIRST_SECTION
                          ELSE MAX_RANGES_IN_OTHER_SECTIONS
         IN Len(template[n]) <= max_ranges

StrictOrderOfRanges ==
   \A n \in DOMAIN template:
     LET section == template[n]
      IN \A m \in DOMAIN section:
           LET range_tuple == section[m]
            IN /\ range_tuple[1] <= range_tuple[2]
               /\ m < Len(section)
                  => range_tuple[2] < section[m+1][1]

NoHardenedAfterUnhardened ==
    \A n \in DOMAIN template:
        IsSectionHardened(template[n])
        => \/ n = 1
           \/ \A m \in 1..n-1: IsSectionHardened(template[m])

SkippedErrorStateConsistent ==
    /\ skipped_error_state[1] \in ErrorStates \union { StateInvalid }
    /\ skipped_error_state[2] <= Len(input_string)

NoAdjacentIndexRanges ==
    /\ Assert( TEMPLATE_FORMAT_UNAMBIGOUS,
               "expects TEMPLATE_FORMAT_UNAMBIGOUS=TRUE" )
    /\ \A n \in DOMAIN template:
          LET section == template[n]
          IN \A m \in DOMAIN section:
                m < Len(section) => section[m][2] + 1 > section[m][1]

ValidTemplateAlwaysMatchesPathGeneratedFromItself ==
    ParseSucceeded
    => MatchPathAgainstTemplate(RandomPathFromTemplate(template), template)

(***************)
(* Init & Next *)
(***************)

Init ==
    /\ GetCharAtStart
    /\ template = <<>>
    /\ fsm_state = StateSectionStart
    /\ fsm_return_state = StateInvalid
    /\ index_value = INVALID_INDEX
    /\ path_section = <<>>
    /\ input_string = ""
    /\ is_partial = TRUE
    /\ accepted_hardened_markers = HardenedMarkers
    /\ saved_state = StateInvalid
    /\ skipped_error_state = <<StateInvalid, 0>>

Next == 
    IF ParseFinished
    THEN UNCHANGED fullState
    ELSE IF /\ fsm_state = StateParseValue
            /\ c \notin Digits
            \* Need to switch the state early when parsing value,
            \* so we don't need to look ahead for non-digit chars
         THEN /\ Assert( fsm_return_state /= StateInvalid,
                         "return state must be specified" )
              /\ fsm_state' = fsm_return_state
              /\ fsm_return_state' = StateInvalid
              /\ saved_state' = StateInvalid
              /\ UNCHANGED <<template, accepted_hardened_markers, path_section,
                             c, input_string, skipped_error_state, index_value,
                             input_value_string, input_value_pos, is_partial>>
         ELSE /\ IF InPrefix
                 THEN PrefixParserFSM
                 ELSE ParserFSM /\ UNCHANGED is_partial
              /\ IF c /= NULL_CHAR
                 THEN /\ GetChar
                      /\ input_string' = Append(input_string, c)
                 ELSE UNCHANGED <<c, input_string,
                                  input_value_string, input_value_pos>>
              /\ UNCHANGED skipped_error_state
            
NextWithDeferredErrors ==
    IF /\ fsm_state \in SkippableErrorStates
       /\ skipped_error_state[1] = StateInvalid
    THEN /\ skipped_error_state' = <<fsm_state, Len(input_string)>>
         /\ fsm_state' = saved_state
         /\ saved_state' = StateInvalid
         /\ UNCHANGED <<unchanged_OnStateTransition, c, input_string,
                        input_value_string, input_value_pos, is_partial>>
    ELSE Next

Spec == Init /\ [][Next]_fullState

SpecWithDeferredErrors == Init /\ [][NextWithDeferredErrors]_fullState

================================================================================
