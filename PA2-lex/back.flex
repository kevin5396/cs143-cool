/*
 *  The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;
unsigned int string_length;
unsigned int comment_nest_cnt=0;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

/*
 *  Add Your own definitions here
 */
bool bufferNotFull()
{
    return string_length < MAX_STR_CONST-1;
}

%}

/*
 * Define names for regular expressions here.
 */

DARROW          =>
DIGIT         [0-9]+
ASCI          [+\-*/.@~<=\{\}\(\);:,]

%START block_comment line_comment STRING STRING_ERROR
%%


<INITIAL>\n     ++curr_lineno;
<INITIAL>"(*"           {BEGIN block_comment; ++comment_nest_cnt;}
<INITIAL>"*)"      {
    yylval.error_msg = "Unmatched *)";
    return (ERROR);
}
<INITIAL>"--"            BEGIN line_comment;
<INITIAL>\"              {
    string_buf_ptr = string_buf;
    string_length = 0;
    BEGIN STRING;
}
<INITIAL>{ASCI} return yytext[0];


<STRING_ERROR>\" BEGIN INITIAL;
<STRING_ERROR>[^\\]\n BEGIN INITIAL;
<STRING_ERROR>.|\\n
  

 /*
  *  Nested comments
  */
<block_comment>{
   "(*"        ++comment_nest_cnt;
    [^(*\n]*
    "*"+[^*)\n]*
    "("
 
    \n          curr_lineno++;
    "*"+")"     {
        --comment_nest_cnt;
        if (comment_nest_cnt < 1)
            BEGIN INITIAL; 
    }

    <<EOF>>    {
        yylval.error_msg = "EOF in comment";
        BEGIN INITIAL;
        return (ERROR);
    }
}

<line_comment>{
    [^\n]*
    \n          {curr_lineno++; BEGIN INITIAL;}
}

 /*
  *  The multiple-character operators.
  */
{DARROW}		{ return (DARROW); }

 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */

<INITTIAL>{
    (?i:class)      return (CLASS);
    (?i:else)       return (ELSE);
    (?i:fi)       return (FI);
    (?i:if)       return (IF);
    (?i:IN)       return (IN);
    (?i:INHERITS)       return (INHERITS);
    (?i:let)       return (LET);
    (?i:loop)       return (LOOP);
    (?i:pool)       return (POOL);

    (?i:then)       return (THEN);
    (?i:while)       return (WHILE);
    (?i:case)       return (CASE);
    (?i:esac)       return (ESAC);

    (?i:of)       return (OF);
    (?i:new)       return (NEW);
    (?i:isvoid)       return (ISVOID);
    (?i:not)       return (NOT);
    "<="           return (LE);

    /*  true & false, must start with lowercase  */
    t(?i:rue)  {
        cool_yylval.boolean = true;
        return (BOOL_CONST);
    }
    f(?i:alse) {
        cool_yylval.boolean = false;
        return (BOOL_CONST);
    }

    "<-"        return (ASSIGN);
}
 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for
  *  \n \t \b \f, the result is c.
  *
  */

<STRING>{
    \" {
        *string_buf_ptr = '\0';
        cool_yylval.symbol = stringtable.add_string(string_buf);
        BEGIN INITIAL;
        return (STR_CONST);
    }
    \\[btnf\\] {
        if (bufferNotFull()) {
            switch (yytext[1]) {
                case 'b': *string_buf_ptr++ = '\b';break;
                case 't': *string_buf_ptr++ = '\t';break;
                case 'f': *string_buf_ptr++ = '\f';break;
                case 'n': *string_buf_ptr++ = '\n';break;
                case '\\': *string_buf_ptr++= '\\';break;
            }
             ++string_length;
        } else {
            /* error */
            yylval.error_msg = "String constant too long.";
            BEGIN STRING_ERROR;
            return (ERROR);
            
        }
    }
    \\[a-zA-Z] {
        if (bufferNotFull()) {
            *string_buf_ptr++ = yytext[1];
            ++string_length;
        } else {
            yylval.error_msg = "String constant too long.";
            BEGIN STRING_ERROR;
            return (ERROR);
        }
    }

    \n {
        /* unescaped newline */
        yylval.error_msg = "Unterminated string constant.";
        BEGIN INITIAL;  
        return (ERROR);
    }

    \\\x00 |
    \x00 |
    \\x00 {
        printf("null-====================\n");
        yylval.error_msg = "String contains null character.";
        BEGIN STRING_ERROR;
        return (ERROR);
    }

    \\(.|\n) {
        if (bufferNotFull()) {
            *string_buf_ptr++ = yytext[1];
            ++string_length;
        } else {
            yylval.error_msg = "String constant too long.";
            BEGIN STRING_ERROR;
            return (ERROR);
        }
    }
            
    [^"\\\n\x00]+ {
        char *text = yytext;

        while ((*text) && bufferNotFull()) {
            *string_buf_ptr++ = *text++;
            ++string_length;
        }
        if (!bufferNotFull()) {
            yylval.error_msg = "String constant too long.";
            BEGIN STRING_ERROR;
            return (ERROR);
        }
    }
            
    <<EOF>>    {
        yylval.error_msg = "EOF in string constant";
        BEGIN INITIAL;
        return (ERROR);
    }

 }


 /*
  * Operators and Asci
  */

 /*
  * Whitespace
  */
\n     curr_lineno++;
[ \f\r\t\v]*

 /*
  * Identifiers
  */

<INITIAL>{
    [A-Z][A-Za-z0-9_]*   {
        cool_yylval.symbol = idtable.add_string(yytext);
        return (TYPEID);
    }

    [a-z][A-Za-z0-9_]*   {
        cool_yylval.symbol = idtable.add_string(yytext);
        return (OBJECTID);
    }

    {DIGIT} {
        cool_yylval.symbol = inttable.add_string(yytext);
        return (INT_CONST);
    }
}

<INITIAL>. {
    yylval.error_msg = yytext;
    return (ERROR);
}
%
