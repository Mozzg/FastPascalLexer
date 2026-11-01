(*******************************************************************************
*  Copyright © 2026 Pervov Evgeny                                              *
*                                                                              *
*  Licensed under the Apache License, Version 2.0 (the "License");             *
*  you may not use this file except in compliance with the License.            *
*  You may obtain a copy of the License at                                     *
*                                                                              *
*      http://www.apache.org/licenses/LICENSE-2.0                              *
*                                                                              *
*  Unless required by applicable law or agreed to in writing, software         *
*  distributed under the License is distributed on an "AS IS" BASIS,           *
*  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.    *
*  See the License for the specific language governing permissions and         *
*  limitations under the License.                                              *
*                                                                              *
*  Author: Pervov Evgeny                                                       *
*  Created: 31.10.2026                                                         *
*  Classes: -                                                                  *
*  Description: Constants, output texts and error messages of the console      *
*    benchmark of TPasLexer                                                    *
*  Version: 0.1                                                                *
*  Last modified: 31.10.2026                                                   *
*  Contributor(s):                                                             *
*    Pervov Evgeny <operationm@list.ru>                                        *
*******************************************************************************)

unit uLexerBenchmarkConsts;

interface

const
  // Process exit codes
  EXIT_CODE_SUCCESS = 0;
  EXIT_CODE_FILE_NOT_FOUND = 1;
  EXIT_CODE_INVALID_PARAMETER = 2;
  EXIT_CODE_LEXER_FAILURE = 3;
  EXIT_CODE_UNEXPECTED_ERROR = 4;

  // Command line switches, written after "-" or "/"
  SWITCH_PREFIXES = ['-', '/'];
  SWITCH_VALUE_SEPARATOR = ':';
  SWITCH_FILE = 'file';
  SWITCH_ITERATIONS = 'iterations';
  SWITCH_WARMUP = 'warmup';
  SWITCH_WARMUP_TIME = 'warmuptime';
  SWITCH_TRACE = 'trace';
  SWITCH_HELP = 'help';
  SWITCH_HELP_SHORT = '?';

  // Default benchmark settings
  DEFAULT_ITERATIONS = 500;
  DEFAULT_WARMUP_COUNT = 10;
  // Minimum warm-up duration in milliseconds. An idle core needs up to ~10 ms to reach its full clock whatever the size
  // of the input, so a warm-up of a few passes over a small file is too short; the margin covers slower power plans.
  DEFAULT_WARMUP_TIME = 200;
  // Default input file, relative to the directory of the executable
  DEFAULT_DATA_FILE = '..\UnitTests\TestData\VirtualTrees.pas';

  // Units used to convert measurements
  NANOSECONDS_PER_SECOND = 1000000000;
  NANOSECONDS_PER_MILLISECOND = 1000000;
  BYTES_PER_MEGABYTE = 1048576;
  TOKENS_PER_MILLION = 1000000;

  // Build description printed in the summary
  {$IFDEF WIN64}
  BUILD_PLATFORM = 'Win64';
  {$ELSE}
  BUILD_PLATFORM = 'Win32';
  {$ENDIF}
  {$IFDEF RELEASE}
  BUILD_CONFIG = 'Release';
  {$ELSE}
  BUILD_CONFIG = 'Debug';
  {$ENDIF}

  // Summary output, one "Key: Value" pair per line
  NUMBER_FORMAT_TIME = '0.000';
  NUMBER_FORMAT_SPEED = '0.00';
  TEXT_TITLE = 'FastPascalLexer benchmark';
  TEXT_BUILD = 'Build: %s %s';
  TEXT_PRIORITY = 'Priority: %s';
  TEXT_PRIORITY_HIGH = 'High';
  TEXT_PRIORITY_NORMAL = 'Normal';
  TEXT_POWER_THROTTLING = 'PowerThrottling: %s';
  TEXT_POWER_THROTTLING_DISABLED = 'Disabled';
  TEXT_POWER_THROTTLING_DEFAULT = 'Default';
  TEXT_FILE = 'File: %s';
  TEXT_FILE_SIZE = 'FileSizeBytes: %d';
  TEXT_CHARACTERS = 'Characters: %d';
  TEXT_TOKENS = 'Tokens: %d';
  TEXT_WARMUP = 'WarmupPasses: %d';
  TEXT_WARMUP_TIME = 'WarmupMs: %s';
  TEXT_ITERATIONS = 'Iterations: %d';
  TEXT_MIN_TIME = 'MinMs: %s';
  TEXT_MEDIAN_TIME = 'MedianMs: %s';
  TEXT_MEAN_TIME = 'MeanMs: %s';
  TEXT_MAX_TIME = 'MaxMs: %s';
  TEXT_MEDIAN_SPEED = 'MedianMBPerSecond: %s';
  TEXT_MEDIAN_TOKEN_SPEED = 'MedianMTokensPerSecond: %s';
  // Printed for every measured pass with -trace, numbered from 1 in run order
  TEXT_PASS_TIME = 'PassMs[%d]: %s';
  TEXT_RESULT_OK = 'Result: OK';
  TEXT_RESULT_FAILED = 'Result: FAILED (exit code %d)';
  TEXT_ERROR = 'Error: %s';
  TEXT_UNEXPECTED_ERROR = 'Error: %s: %s';
  TEXT_PRESS_ENTER = 'Press Enter to close the window...';

  TEXT_USAGE = 'Usage: LexerBenchmark.exe [-file <path>] [-iterations <count>] [-warmup <count>] [-warmuptime <ms>] [-trace]'
      + sLineBreak + '  -file <path>          Pascal source file to tokenize'
      + sLineBreak + '                        (default: <exe dir>\' + DEFAULT_DATA_FILE + ')'
      + sLineBreak + '  -iterations <count>   Number of measured passes, at least 1 (default: %d)'
      + sLineBreak + '  -warmup <count>       Minimum number of unmeasured warm-up passes, 0 or more (default: %d)'
      + sLineBreak + '  -warmuptime <ms>      Minimum warm-up duration in milliseconds, 0 or more (default: %d);'
      + sLineBreak + '                        the warm-up lasts until both minimums are reached'
      + sLineBreak + '  -trace                Also print the time of every measured pass in run order'
      + sLineBreak + '  -help, -?             Show this help'
      + sLineBreak + 'Switches start with "-" or "/"; a value follows as the next parameter or after a colon (-iterations:100).'
      + sLineBreak + 'Started in a console window of its own (from the IDE or Explorer), the benchmark waits for Enter before exiting.'
      + sLineBreak + 'Exit codes: 0 success, 1 input file not found, 2 invalid parameter, 3 lexer error, 4 unexpected error.';

  // Error messages
  EMESSAGE_FILE_NOT_FOUND = 'Input file "%s" does not exist.'
      + sLineBreak + 'The default input is VirtualTrees.pas of VirtualTreeView 5.3.0: download Source/VirtualTrees.pas'
      + sLineBreak + 'from https://github.com/JAM-Software/Virtual-TreeView (tag V5.3.0) into UnitTests\TestData,'
      + sLineBreak + 'or pass another Pascal source with -file <path>.';
  EMESSAGE_EMPTY_FILE = 'Input file "%s" contains no tokens.';
  EMESSAGE_UNKNOWN_SWITCH = 'Unknown command line parameter "%s". Run with -help to see the supported parameters.';
  EMESSAGE_MISSING_VALUE = 'Command line switch "%s" requires a value.';
  EMESSAGE_INVALID_COUNT = 'Value "%s" of switch "%s" is not valid, expected an integer of at least %d.';
  EMESSAGE_LEXER_EXCEPTION = 'Lexer failed on the validation pass at line %d: %s: %s';
  EMESSAGE_UNBALANCED_COUNTERS = 'Lexer finished the validation pass with unbalanced counters '
      + '(round brackets %d, square brackets %d, IF directives %d).';
  EMESSAGE_TOKEN_COUNT_CHANGED = 'Pass %d produced %d tokens, the validation pass produced %d.';

implementation

end.
