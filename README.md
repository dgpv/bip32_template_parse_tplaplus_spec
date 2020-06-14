# TLA+ specification for BIP32 path template parser finite state machine

This repository contains the [TLA+](https://lamport.azurewebsites.net/tla/tla.html)
specification of the parser for BIP32 path templates described in [bip-path-templates.mediawiki](bip-path-templates.mediawiki)

The specification can be found in `bip32_template_parse.tla`

Default values for constants can be found in `MC.tla`

Operators to show hyperproperties can be found in `HyperProperties.tla`

## Test data

During model checking, test data can be generated. After generation, it can be processed with included `generate_test_data.py` to generate JSON file.

The `make test_data` command invokes `generate_test_data.py` with appropriate arguments.

For non-FSM based implementations, using `SPECIFICATION SpecWithDeferredErrors` in `bip32_template_parse.cfg` is advised for better test data. With this spec, some errors are ignored on first encounter, and this allows to build test template strings that have errors in the middle, rather than only at the end. `generate_test_data.py` also performs additional filtering in this case to remove test strings that are not likely to be valuable for testing non-FSM based implementation.

## Working with TLA spec from command line

To run `TLC` on the spec via included Makefile instead of
TLA+ toolbox in unix-like environment, you need `tla2tools.jar`
from https://github.com/tlaplus/tlaplus/releases or your local
TLA+ toolbox installation.

Set environment variable `TLATOOLSDIR` to the path where
`tla2tools.jar` is located.

Make sure you have `java` in your `PATH`

run `make check` to apply `TLC` checker

run `make pdf` to generate PDF file for the TLA+ specification
(you need pdflatex to be in your `PATH` for that)

Note that when running checking from the command line, you will
not be able to do convenient exploration of the state log in case some
invariant or temporal property is violated. TLA+ toolbox has
the functionality where you can evaluate TLA+ expressions in
the context of each state in the log, but there are currently
no tools to do this from the command line or with text UI.

## Authors and contributors

The specification was created by Dmitry Petukhov (https://github.com/dgpv/)
