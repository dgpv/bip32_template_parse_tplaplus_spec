#!/usr/bin/env python3

import re
import sys
import json
import random
from collections import defaultdict

from typing import List, Tuple, Dict, Optional, Union

HARDENED_INDEX_START: int
MAX_INDEX_VALUE: int

skippable_error_states = [
    "error_unexpected_hardened_marker",
    "error_unexpected_space",
    "error_unexpected_char",
    "error_invalid_char",
    "error_index_too_big",
    "error_index_has_leading_zero",
    "error_digit_expected"
]

ignored_error_states = [
    "error_path_too_long",
    "error_path_section_too_long"
]

def process_line(
    line: str
) -> Optional[Tuple[str, str, Tuple[str, int], List[Tuple[int, int]]]]:

    if not line:
        return None

    line = line.replace('<<', '[')
    line = line.replace('>>', ']')
    tpl_str, state, skipped_err, tmpl = json.loads(line)

    def convert(v: int) -> int:
        if v == MAX_INDEX_VALUE:
            return 0x7FFFFFFF
        elif v == HARDENED_INDEX_START+MAX_INDEX_VALUE:
            return 0xFFFFFFFF
        elif v >= HARDENED_INDEX_START:
            return v - HARDENED_INDEX_START + 0x80000000
        else:
            return v

    tmpl = list(tuple((convert(start), convert(end))
                      for start, end in section)
               for section in tmpl)

    if state != "normal_finish" or skipped_err[0] != "invalid":
        tmpl = []

    return (tpl_str, state, skipped_err, tmpl)

def convert_tpl_str(tpl_str: str) -> str:
    tpl_str = re.sub(f"\\b{HARDENED_INDEX_START}(\\b|\\D)",
                     f"{0x80000000}\\1", tpl_str)
    tpl_str = re.sub(f"\\b(0?){MAX_INDEX_VALUE}(\\b|\\D)",
                     f"\g<1>{0x7FFFFFFF}\g<2>", tpl_str)
    return tpl_str

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} /path/to/MC.tla"
              f" /path/to/bip32_template_parse.cfg\n"
              f"       data is to be supplied on stdin\n")
        sys.exit(-1)

    with open(sys.argv[1]) as f:
        for line in f.readlines():
            if line.startswith("const_HARDENED_INDEX_START"):
                name, value_str = line.split("==")
                assert(name.strip() == "const_HARDENED_INDEX_START")
                HARDENED_INDEX_START = int(value_str)
                assert HARDENED_INDEX_START > 0
                assert HARDENED_INDEX_START <= 0x80000000
                MAX_INDEX_VALUE = HARDENED_INDEX_START-1
                break
        else:
            print(f'Cannot find "const_HARDENED_INDEX_START == <value>" '
                    f'in {sys.argv[1]}')
            sys.exit(-1)

    need_filtering: Optional[bool]
    with open(sys.argv[2]) as f:
        for line in f.readlines():
            if re.match("SPECIFICATION Spec\\s*$", line):
                need_filtering = False
                break
            if re.match("SPECIFICATION SpecWithDeferredErrors\\s*$", line):
                need_filtering = True
                break
        else:
            print(f'Cannot find "SPECIFICATION" in {sys.argv[2]}')
            sys.exit(-1)

    storage: Dict[str, Dict[str, List[Union[str, Tuple[str, str]]]]]
    storage = defaultdict(lambda: defaultdict(lambda: []))

    first_time = True

    while True:
        converted_tuple = process_line(sys.stdin.readline())
        if not converted_tuple:
            break

        (tpl_str, state, skipped_err, tmpl) = converted_tuple

        if need_filtering:
            if skipped_err[0] == "invalid" and state in skippable_error_states:
                continue

            if state in ignored_error_states:
                continue

        def collect_similar_errors_onechar(errstr: str) -> None:
            noerr_tpl_str = (tpl_str[:skipped_err[1]-1]
                             + tpl_str[skipped_err[1]:])
            storage[errstr][noerr_tpl_str].append(convert_tpl_str(tpl_str))

        def collect_similar_errors_prefix(errstr: str) -> None:
            prefix = tpl_str[:skipped_err[1]-1]
            storage[errstr][prefix].append(convert_tpl_str(tpl_str))

        one_char_filtered = [
            "error_unexpected_char",
            "error_digit_expected",
            "error_unexpected_slash"
        ]

        prefix_filtered = [
            "error_unexpected_space",
        ]

        filtered = (prefix_filtered
                    + one_char_filtered
                    + ["error_index_has_leading_zero"])

        filter_ends_with_comma = [
            "error_ranges_intersect",
            "error_range_equals_wildcard",
            "error_range_start_equals_end",
            "error_range_order_bad",
        ]

        if need_filtering:
            if skipped_err[0] == "error_index_has_leading_zero" and \
                    re.match('\[0\\d', tpl_str):
                parts = re.split('([,\-\[\]])', tpl_str)
                got_replacement = False
                result = []
                for elt in parts:
                    m = re.match('0\\d+', elt)
                    if m:
                        elt = '0'
                    elif ( not got_replacement
                           and re.match('\\d+$', elt)
                           and  random.randint(0, 1) == 0 ):
                        elt = '0' + elt
                        got_replacement = True
                    result.append(elt)
                result_str = convert_tpl_str(''.join(result))
                storage[skipped_err[0]][result_str].append(result_str)
            elif skipped_err[0] in one_char_filtered:
                collect_similar_errors_onechar(skipped_err[0])
            elif state in filter_ends_with_comma and \
                    tpl_str.endswith(","):
                continue
            elif skipped_err[0] in prefix_filtered:
                collect_similar_errors_prefix(skipped_err[0])
            elif skipped_err[0] == "invalid":
                if state == "normal_finish":
                    storage[state][""].append((convert_tpl_str(tpl_str),
                                               json.dumps(tmpl)))
                else:
                    storage[state][""].append(convert_tpl_str(tpl_str))
            else:
                storage[skipped_err[0]][""].append(convert_tpl_str(tpl_str))
        else:
            if state == "normal_finish":
                storage[state][""].append((convert_tpl_str(tpl_str),
                                           json.dumps(tmpl)))
            else:
                storage[state][""].append(convert_tpl_str(tpl_str))

    print("{")

    storage_keys = storage.keys()

    for pos, k in enumerate(storage_keys):
        if need_filtering and k in filtered:
            elts = [random.choice(vals)
                    for vals in storage[k].values()]
        else:
            elts = storage[k][""]

        lastchar = "," if pos + 1 < len(storage_keys) else ""

        print(f'"{k}": '+json.dumps(elts, indent=0) + lastchar)


    print("}")
