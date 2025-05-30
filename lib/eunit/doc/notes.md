<!--
%CopyrightBegin%

SPDX-License-Identifier: Apache-2.0

Copyright Ericsson AB 2023-2025. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

%CopyrightEnd%
-->
# EUnit Release Notes

This document describes the changes made to the EUnit application.

## Eunit 2.10

### Fixed Bugs and Malfunctions

- Fix so that when running tests in parallel and one test is cancelled due to a failing setup, it is report as cancelled. Before this fix the cancellation was ignored.

  Own Id: OTP-19630 Aux Id: [PR-9794]

[PR-9794]: https://github.com/erlang/otp/pull/9794

### Improvements and New Features

- [EEP-69: Nominal Types](https://www.erlang.org/eeps/eep-0069) has been implemented. As a side effect, nominal types can encode opaque types. We changed all opaque-handling logic and improved opaque warnings in Dialyzer.
  
  All existing Erlang type systems are structural: two types are seen as equivalent if their structures are the same. Type comparisons are based on the structures of the types, not on how the user explicitly defines them. For example, in the following example, `meter()` and `foot()` are equivalent. The two types can be used interchangeably. Neither of them differ from the basic type `integer()`.
  
  ````
  -type meter() :: integer().
  -type foot() :: integer().
  ````
  
  Nominal typing is an alternative type system, where two types are equivalent if and only if they are declared with the same type name. The EEP proposes one new syntax -nominal for declaring nominal types. Under nominal typing, `meter()` and `foot()` are no longer compatible. Whenever a function expects type `meter()`, passing in type `foot()` would result in a Dialyzer error.
  
  ````
  -nominal meter() :: integer().
  -nominal foot() :: integer().
  ````
  
  More nominal type-checking rules can be found in the EEP. It is worth noting that most work for adding nominal types and type-checking is in `erl_types.erl`. The rest are changes that removed the previous opaque type-checking, and added an improved version of it using nominal type-checking with reworked warnings.
  
  Backwards compatibility for opaque type-checking is not preserved by this PR. Previous opaque warnings can appear with slightly different wordings. A new kind of opaque warning `opaque_union` is added, together with a Dialyzer option `no_opaque_union` to turn this kind of warnings off.

  Own Id: OTP-19364 Aux Id: [PR-9079]

- Fixed licenses in files and added ORT curations to the following apps: otp, eldap, erl_interface, eunit, parsetools, stdlib, syntax_tools, and ERTS.

  Own Id: OTP-19478 Aux Id: [PR-9376], [PR-9402], [PR-9819]

- The license and copyright header has changed format to include an `SPDX-License-Identifier`. At the same time, most files have been updated to follow a uniform standard for license headers.

  Own Id: OTP-19575 Aux Id: [PR-9670]

[PR-9079]: https://github.com/erlang/otp/pull/9079
[PR-9376]: https://github.com/erlang/otp/pull/9376
[PR-9402]: https://github.com/erlang/otp/pull/9402
[PR-9819]: https://github.com/erlang/otp/pull/9819
[PR-9670]: https://github.com/erlang/otp/pull/9670

## Eunit 2.9.1

### Improvements and New Features

- The documentation has been migrated to use Markdown and ExDoc.

  Own Id: OTP-18955 Aux Id: [PR-8026]

[PR-8026]: https://github.com/erlang/otp/pull/8026

## Eunit 2.9

### Improvements and New Features

- With this change, EUnit timetraps can be scaled with the use of scale_timeouts
  option.

  Own Id: OTP-18771 Aux Id: PR-7635

## Eunit 2.8.2

### Improvements and New Features

- Replace size/1 with either tuple_size/1 or byte_size/1

  The [`size/1`](`size/1`) BIF is not optimized by the JIT, and its use can
  result in worse types for Dialyzer.

  When one knows that the value being tested must be a tuple,
  [`tuple_size/1`](`tuple_size/1`) should always be preferred.

  When one knows that the value being tested must be a binary,
  [`byte_size/1`](`byte_size/1`) should be preferred. However,
  [`byte_size/1`](`byte_size/1`) also accepts a bitstring (rounding up size to a
  whole number of bytes), so one must make sure that the call to `byte_size/` is
  preceded by a call to [`is_binary/1`](`is_binary/1`) to ensure that bitstrings
  are rejected. Note that the compiler removes redundant calls to
  [`is_binary/1`](`is_binary/1`), so if one is not sure whether previous code
  had made sure that the argument is a binary, it does not harm to add an
  [`is_binary/1`](`is_binary/1`) test immediately before the call to
  [`byte_size/1`](`byte_size/1`).

  Own Id: OTP-18432 Aux Id:
  GH-6672,PR-6793,PR-6784,PR-6787,PR-6785,PR-6682,PR-6800,PR-6797,PR-6798,PR-6799,PR-6796,PR-6813,PR-6671,PR-6673,PR-6684,PR-6694,GH-6677,PR-6696,PR-6670,PR-6674

## Eunit 2.8.1

### Fixed Bugs and Malfunctions

- With this change, eunit exact_execution option works with application
  primitive.

  Own Id: OTP-18264 Aux Id: PR-6322, GH-6320

## Eunit 2.8

### Improvements and New Features

- With this change, Eunit can optionally not try to execute related module with
  "\_tests" suffix. This might be used for avoiding duplicated executions when
  source and test modules are located in the same folder.

  Own Id: OTP-18181 Aux Id: ERL-97, GH-3064, PR-5461

## Eunit 2.7.1

### Improvements and New Features

- Minor internal improvements.

  Own Id: OTP-17884 Aux Id: GH-5617

## Eunit 2.7

### Improvements and New Features

- In an eunit test, when a test case times out, include a stacktrace.

  Own Id: OTP-17613 Aux Id: PR-5185

## Eunit 2.6.1

### Fixed Bugs and Malfunctions

- The `m:eunit_surefire` report handler has been updated to automatically create
  the directories needed to store the surefire xml file.

  Own Id: OTP-17300 Aux Id: PR-4695

## Eunit 2.6

### Improvements and New Features

- Fixed compiler warning.

  Own Id: OTP-16674

## Eunit 2.5

### Improvements and New Features

- Let `eunit_surefire` skip invalid XML 1.0 characters.

  Own Id: OTP-15950 Aux Id: PR-2316, ERL-991

- Add new macro ?capturedOutput for enabling to write test cases that verify
  data printed to standard out

  Own Id: OTP-16275 Aux Id: PR-2424

- Add option to limit print depth of exceptions generated by eunit test suites.

  Own Id: OTP-16549 Aux Id: PR-2532

## Eunit 2.4.1

### Improvements and New Features

- Backport of PR-2316: Strip control codes from eunit_surefire output to avoid
  generation of invalid xml

  Own Id: OTP-16380 Aux Id: ERL-991, PR-2316, PR-2487

## Eunit 2.4

### Improvements and New Features

- Remove compiler warnings from eunit.

  Own Id: OTP-16313

## Eunit 2.3.8

### Fixed Bugs and Malfunctions

- Handle `get_until` request with explicit encoding in the implementation of the
  I/O protocol.

  Own Id: OTP-16000

## Eunit 2.3.7

### Fixed Bugs and Malfunctions

- Improved documentation.

  Own Id: OTP-15190

## Eunit 2.3.6

### Improvements and New Features

- Calls to `erlang:get_stacktrace()` are removed.

  Own Id: OTP-14861

## Eunit 2.3.5

### Fixed Bugs and Malfunctions

- Removed all old unused files in the documentation.

  Own Id: OTP-14475 Aux Id: ERL-409, PR-1493

## Eunit 2.3.4

### Improvements and New Features

- Tools are updated to show Unicode atoms correctly.

  Own Id: OTP-14464

## Eunit 2.3.3

### Fixed Bugs and Malfunctions

- The surefire reports from `eunit` will no longer have names with embedded
  double quotes.

  Own Id: OTP-14287

## Eunit 2.3.2

### Fixed Bugs and Malfunctions

- The address to the FSF in the license header has been updated.

  Own Id: OTP-14084

## Eunit 2.3.1

### Fixed Bugs and Malfunctions

- When asserts were moved out to a separate header file, the automatic enabling
  of asserts when testing is enabled stopped working.

  Own Id: OTP-13892

## Eunit 2.3

### Improvements and New Features

- There is a new `debugVal/2` that gives control over the truncation depth.

  Own Id: OTP-13612

## Eunit 2.2.13

### Improvements and New Features

- Suppress Dialyzer warnings.

  Own Id: OTP-12862

## Eunit 2.2.12

### Fixed Bugs and Malfunctions

- Small documentation fixes

  Own Id: OTP-13017

## Eunit 2.2.11

### Fixed Bugs and Malfunctions

- Improve success message when 2 tests have passed

  Own Id: OTP-12952

## Eunit 2.2.10

### Fixed Bugs and Malfunctions

- The `eunit` application is now unicode safe.

  Own Id: OTP-11660

## Eunit 2.2.9

### Fixed Bugs and Malfunctions

- Make sure to install .hrl files when needed

  Own Id: OTP-12197

- Make sure the clean rule for ssh, ssl, eunit and otp_mibs actually removes
  generated files.

  Own Id: OTP-12200

## Eunit 2.2.8

### Fixed Bugs and Malfunctions

- Minor refactoring.

  Own Id: OTP-12051

## Eunit 2.2.7

### Fixed Bugs and Malfunctions

- Application upgrade (appup) files are corrected for the following
  applications:

  `asn1, common_test, compiler, crypto, debugger, dialyzer, edoc, eldap, erl_docgen, et, eunit, gs, hipe, inets, observer, odbc, os_mon, otp_mibs, parsetools, percept, public_key, reltool, runtime_tools, ssh, syntax_tools, test_server, tools, typer, webtool, wx, xmerl`

  A new test utility for testing appup files is added to test_server. This is
  now used by most applications in OTP.

  (Thanks to Tobias Schlager)

  Own Id: OTP-11744

## Eunit 2.2.6

### Fixed Bugs and Malfunctions

- Fix I/O-protocol error handling in eunit. Thanks to Yuki Ito.

  Own Id: OTP-11373

- Do not attempt to detect lists of printable characters in format. Thanks to
  Roberto Aloi.

  Own Id: OTP-11467

- Fix silent make rule (Thanks to Anthony Ramine )

  Own Id: OTP-11516

## Eunit 2.2.5

### Improvements and New Features

- Wrap eunit macros into begin ... end blocks. Thanks to Anthony Ramine.

  Own Id: OTP-11217

## Eunit 2.2.4

### Improvements and New Features

- Where necessary a comment stating encoding has been added to Erlang files. The
  comment is meant to be removed in Erlang/OTP R17B when UTF-8 becomes the
  default encoding.

  Own Id: OTP-10630

## Eunit 2.2.3

### Fixed Bugs and Malfunctions

- New option 'no_tty' to silent the default tty report.

  Recognize the new stacktrace format introduced in R15, adding location
  information. (Thanks to Klas Johansson.)

  Improve layout of error messages, printing the stack trace before the error
  term.

  Heuristically detect and report bad return values from generators and
  instantiators. E.g., "ok" will not be interpreted as a module name, and a
  warning will be printed.

  New test representation \{test,M,F\} for completeness along with
  \{generator,M,F\}. Tuples \{M,F\} are deprecated.

  Use UTF-8 as encoding in Surefire output files. (Thanks to Lukas Larsson.)

  Own Id: OTP-10173

## Eunit 2.2.2

### Improvements and New Features

- Erlang/OTP can now be built using parallel make if you limit the number of
  jobs, for instance using '`make -j6`' or '`make -j10`'. '`make -j`' does not
  work at the moment because of some missing dependencies.

  Own Id: OTP-9451

## Eunit 2.2.1

### Fixed Bugs and Malfunctions

- Generate separate surefire XMLs for each test suite

  Previously the test cases of all test suites (=modules) were put in one and
  the same surefire report XML thereby breaking the principle of least
  astonishment and making post analysis harder. Assume the following layout:

  src/x.erl src/y.erl test/x_tests.erl test/y_tests.erl

  The results for both x_tests and y_tests were written to only one report
  grouped under either module x or y (seemingly randomly).

  Now two reports, one for module x and one for y are generated. (Thanks to Klas
  Johansson)

  Own Id: OTP-9465

- Updated to EUnit version 2.2.0

  New macros assertNotMatch(Guard, Expr), assertNotEqual(Unexpected, Expr), and
  assertNotException(Class, Term, Expr).

  The debugMsg macro now also prints the pid of the current process.

  When testing all modules in a directory, tests in Module_tests.erl are no
  longer executed twice.

  The use of regexp internally has been replaced with re. (Thanks to Richard
  Carlsson)

  Own Id: OTP-9505

- Removed some never-matching clauses reported by dialyzer Updated author
  e-mails and homepages Removed cvs keywords from files Removed files that
  should not be checked in (Thanks to Richard Carlsson)

  Own Id: OTP-9591

## Eunit 2.1.7

### Fixed Bugs and Malfunctions

- Increase depth of error messages in Eunit Surefire reports

  Currently, error messages in Eunit Surefire reports are shortened just like
  when written to a terminal. However, the space limitations that constrain
  terminal output do not apply here, so it's more useful to include more of the
  error message. The new depth of 100 should be enough for most cases, while
  protecting against runaway errors. (Thanks to Magnus Henoch)

  Own Id: OTP-9220

- Don't let eunit_surefire report back to eunit when stopping

  When eunit is terminating, a stop message is sent to all listeners and eunit
  then waits for _one_ result message but previously both eunit_tty and
  eunit_surefire sent a response on error. Don't send a result message from
  eunit_surefire; let eunit_tty take care of all result reporting, both positive
  and negative to avoid race conditions and inconsistencies. (Thanks to Klas
  Johansson)

  Own Id: OTP-9269

## Eunit 2.1.6

### Fixed Bugs and Malfunctions

- Fix format_man_pages so it handles all man sections and remove warnings/errors
  in various man pages.

  Own Id: OTP-8600

## Eunit 2.1.5

### Improvements and New Features

- The documentation is now possible to build in an open source environment after
  a number of bugs are fixed and some features are added in the documentation
  build process.

  \- The arity calculation is updated.

  \- The module prefix used in the function names for bif's are removed in the
  generated links so the links will look like
  "http://www.erlang.org/doc/man/erlang.html#append_element-2" instead of
  "http://www.erlang.org/doc/man/erlang.html#erlang:append_element-2".

  \- Enhanced the menu positioning in the html documentation when a new page is
  loaded.

  \- A number of corrections in the generation of man pages (thanks to Sergei
  Golovan)

  \- The legal notice is taken from the xml book file so OTP's build process can
  be used for non OTP applications.

  Own Id: OTP-8343

## Eunit 2.1.4

### Improvements and New Features

- The documentation is now built with open source tools (xsltproc and fop) that
  exists on most platforms. One visible change is that the frames are removed.

  Own Id: OTP-8201

## Eunit 2.1.3

### Improvements and New Features

- Miscellaneous updates.

  Own Id: OTP-8190

## Eunit 2.1.2

### Improvements and New Features

- Miscellaneous updates.

  Own Id: OTP-8038

## Eunit 2.1.1

### Fixed Bugs and Malfunctions

- eunit was broken in R13B.

  Own Id: OTP-8018

## Eunit 2.1

### Improvements and New Features

- Mostly internal changes, in particular to the event protocol; fixes problems
  with timeouts that could cause eunit to hang, and makes it much easier to
  write new reporting back-ends.

  New "surefire" report backend for Maven and Bamboo.

  The test representation is no longer traversed twice (the first pass was for
  enumeration only). This eliminates some strange restrictions on how generators
  can be written, but it also means that reports cannot be quite as complete as
  before in the event of skipped tests.

  Own Id: OTP-7964

## EUnit 2.0.1

### Improvements and New Features

- Corrected the documentation build.

## EUnit 2.0

### Improvements and New Features

- This is the first version of EUnit (for unit testing of Erlang modules) by
  Richard Carlsson released in OTP.
