------------------------------MODULE HyperProperties ---------------------------
EXTENDS bip32_template_parse, TLC

slot_last_output == 0
slot_valid_template_strings == 1
slot_valid_template_tuples == 2

ASSUME TLCSet(slot_last_output, <<>>)
ASSUME TLCSet(slot_valid_template_strings, {})
ASSUME TLCSet(slot_valid_template_tuples, {})

FilteredPrintT(tuple) ==
    TLCGet(slot_last_output) /= tuple => /\ PrintT(tuple)
                                         /\ TLCSet(slot_last_output, tuple)

ShowValid == ParseSucceeded
             => FilteredPrintT(
                    <<input_string, fsm_state, skipped_error_state, template>>)

ShowInvalid == /\ ParseFailed
               /\ \/ skipped_error_state[1] = StateInvalid
                  \/ fsm_state = StateNormalFinish
                  \* When we allow to skip some errors, we filter out some of
                  \* the failed states, because they might ne not very interesting,
                  \* like when we got two of the same errors in a row
               => FilteredPrintT(
                        <<input_string, fsm_state, skipped_error_state, template>>)

EncodingIsUnambiguous ==
    /\ Assert( TEMPLATE_FORMAT_UNAMBIGOUS,
               "expects TEMPLATE_FORMAT_UNAMBIGOUS=TRUE" )
    /\ ParseSucceeded
       => LET valid_strings == TLCGet(slot_valid_template_strings)
              valid_tuples == TLCGet(slot_valid_template_tuples)
           IN input_string \notin valid_strings
              => /\ Assert(
                      template \notin valid_tuples, 
                      <<"templates must be unique if the encoding is unambiguous",
                         input_string, template, valid_tuples>> )
                 /\ TLCSet(slot_valid_template_strings, valid_strings
                                                        \union { input_string })
                 /\ TLCSet(slot_valid_template_tuples, valid_tuples
                                                       \union { template })

=============================================================================
