---- MODULE MC ----

EXTENDS bip32_template_parse, TLC, HyperProperties

const_HARDENED_INDEX_START == 256
const_EXTRA_CHARS == { "o" }
const_NULL_CHAR == "Z"
const_MAX_SECTIONS == 2
\* Number of allowed ranges is different for the first and the subsequent
\* sections only for the purposes of limiting the number of possible states.
\* If an implementation limits the number of ranges in a section,
\* the expected way would be to have one MAX_RANGES_PER_SECTION constant.
const_MAX_RANGES_IN_FIRST_SECTION == 4
const_MAX_RANGES_IN_OTHER_SECTIONS == 1
const_TEMPLATE_FORMAT_UNAMBIGOUS == FALSE
const_INDEX_VALUE_STRINGS_FIRST_SECTION ==
    { <<"0","0">>, <<"0","3">>, <<"0">>, <<"1">>,
      <<"1","2","3">>, <<"2","5","5">>, <<"2","5","6">> }
const_INDEX_VALUE_STRINGS_OTHER_SECTIONS == { <<"0">> }

=============================================================================
