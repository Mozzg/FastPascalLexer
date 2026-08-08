# FastPascalLexer
Delphi class for fast pascal code parsing

Important notes:
- The lexer (TPasLexer) intentionally emits whitespace and comment tokens (tkSpace, tkCRLF, tkCRLFComment, tkCurlyComment, tkSingleLineComment, tkStarParenComment, etc.). This is by design: the lexer is suitable for code-style analysis and tools that need exact source layout information.
- Calling TPasLexer.SetData initializes the lexer's internal buffer and performs an initial NextToken call (Reset), so after SetData the current TokenID/TokenString represent the first token. Tests and callers should account for this behavior.
