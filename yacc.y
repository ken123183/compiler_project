%{
//LINUX terminal color codes.
#define RESET   "\033[0m"
#define WHITE   "\033[1m\033[37m"      /* White */
#define YELLOW  "\033[1m\033[33m"      /* Yellow */
#define BLUE    "\033[1m\033[34m"      /* Blue */


#define TRACE
#ifdef TRACE
#define Trace(t)        std::cout << BLUE << "Trace: " << WHITE << t << RESET <<std::endl
#else
#define Trace(t)        std::cout << ""
#endif

#include <iostream>
#include <stdlib.h>
#include <stack>
#include <fstream>
#include "lex.yy.c"

using namespace std;

ident* nowIdent; // now ident
symbolTable* nowScope; // now scope
symbolTable* fatherScope; // out scope
vector<int> para; //parameters

string filename = ""; // filename
string rawFilename = ""; // rawfilename

bool assignValue = false; // can Assign ?

ofstream fout; // file output
int outputs = 0; // nubmer of tabs (4 spaces) 

bool elseBranch = false; // has else branch?
bool canWrite = true; // can Write ?

int branchIndex = 0; // branch index
stack<int> branchStack; //branch stack

int selectOper = 0; //select operator for groups

int intValue = 0;
double realValue = 0.0;
bool boolValue = true;
char charValue = ' ';
std::string strValue = "";

void yyerror(std::string msg) {
    std::cerr << YELLOW << filename << ":" << linenum << ": warning: " << WHITE << msg << RESET << std::endl;
}

void yyerror(std::string msg, int customLinenum) {
    std::cerr << YELLOW << filename << ":" << customLinenum << ": warning: " << WHITE << msg << RESET << std::endl;
}

void writeOut(ofstream &f1, std::string str) {	
    if (str.rfind("L", 0) != 0) {	
        // L(num): labels	
        for (int i = 0; i < outputs; i++) str = "    " + str;	
    }	
    std::cout << str << std::endl;	
    f1 << str << std::endl;	
}	
std::string adjStrVal(std::string str) //j	
{	
    std::string result = "";	
	for (int i = 0; i < str.length(); i++)	
	{	
		switch (str[i])	
		{		
        case '\r':	
            result += "\\r";	
			break;	
		case '\t':	
            result += "\\t";	
			break;
        case '\b':	
            result += "\\b";	
			break;
		case '\n':	
            result += "\\n";	
			break;	
		case '\f':	
            result += "\\f";	
			break;	
		case '\'':	
            result += "\\\'";	
			break;	
		case '\"':	
            result += "\\\"";	
			break;	
		case '\\':	
            result += "\\\\";	
			break;	
		default:	
            result += string(1, str[i]) ;	
			break;	
		}	
	}	
	return result;	
}	


%}
%union {
    int intVal;
    char charVal;
    char* strVal;
    float realVal;
    bool boolVal;
}
/* tokens */
/* type */
%token <intVal> INTEGER_VAL 
%token <realVal> REAL_VAL 
%token <charVal> CHAR_VAL 
%token <strVal> STRING_VAL
%type <boolVal> BOOL_VAL
/* DELIMITER */
/*      ,   :     .    ;    (      )      [      ]      {      } */
%token COMM COLO PERI SEMI PARE_L PARE_R SQUE_L SQUE_R BRAC_L BRAC_R
/* ARITHMETIC */
/*       +   -    *     /    %  */
%token PLUS MINU MULT DIVI REMA
/* ASSIGNMENT */
/*      = */
%token ASSI
/* RELATIONAL */
/*       <     >     <=    >=    !=    == */
%token RL_LT RL_GT RL_LE RL_GE RL_NE RL_EQ
/* COMPOUND OPERATORS */
/*       +=       -=      *=     /=   */
%token CP_PLUS CP_MINU CP_MULT CP_DIVI
/* LOGICAL */
/*      &   |  ! */
%token AND OR NOT
/* ARROW & DOTS */
/*       ->   .. */
%token ARROW DOTS
/* KEYWORDS */
%token BOOL BREAK CHAR CASE CLASS CONTINUE DECLARE DO ELSE EXIT FALSE FLOAT
%token FOR FUN IF INT LOOP PRINT PRINTLN RETURN STRING TRUE VAL VAR WHILE READ IN

%token <strVal> IDENT

%left OR
%left AND
%left NOT
%left RL_LT RL_GT RL_LE RL_GE RL_NE RL_EQ
%left PLUS MINU
%left MULT DIVI REMA
%nonassoc U_MINU

%type <intVal> types
%type <intVal> typeOrEmpty
%type <intVal> assignOrEmpty
%type <intVal> constExp
%type <intVal> arrayRef
%type <intVal> functionInvocation
%type <intVal> expression




%%
program: class;

class: CLASS IDENT BRAC_L { 
            Trace("class: create an new symbolTable.");
            nowScope = new symbolTable($2, NULL);
            
            writeOut(fout, "class " + string($2));
            writeOut(fout, "{");
            outputs++;
         }
         classStatements BRAC_R {
             nowIdent = nowScope->lookup("main", false);
             if (nowIdent == NULL) {
                 yyerror("class need a main entry method.", 0);
             } 
             else if (nowIdent->type > METHOD_TYPE_BOOL || nowIdent->type < METHOD_TYPE_FUNC ) {
                 yyerror("identifier main must be method-type", 0);
             }
             
             outputs--;
             writeOut(fout, "}");
             fout.close();
         };

classStatements: /* empty */
                | classStatement classStatements;

classStatement: varConstDec
                | methodDec;

varConstDec: VAL constDec
           | VAR varDec;

constDec: IDENT typeOrEmpty ASSI constExp { 
                    Trace("VAL Declaration:");
                    if (nowScope->lookup($1, false) == NULL) {
                        if ($2 == TYPE_NOT_DEFINE) /* typeOrEmpty is empty */
                            nowScope->insert($1, CONST_INTEGER + $4);
                        else { /* typeOrEmpty is not empty */
                            nowScope->insert($1, CONST_INTEGER + $2);
                            if ($2 != $4) yyerror("Constant declartion type not equal with value type.", linenum - 1);
                        }
                        
                        // accessBC
                        Trace("set const_declaration accessBC");
                        nowIdent = nowScope->lookup($1, false);
                        if (nowIdent != NULL) {
                            switch (nowIdent->type) {
                            case CONST_INTEGER:
                                nowIdent->bc1 = "sipush " + to_string(intValue);
                                intValue = 0;
                                break;
                            case CONST_REAL:
                                nowIdent->bc1 = "sipush " + to_string(realValue);
                                realValue = 0.0;
                                break;
                            case CONST_CHAR:
                                nowIdent->bc1 = "ldc \"" + string(1, charValue) + "\"";
                                charValue = ' ';
                                break;
                            case CONST_STRING: 
                                nowIdent->bc1 = "ldc \"" + adjStrVal(strValue) + "\"";
                                strValue = "";
                                break;
                            case CONST_BOOL:
                                if (boolValue) nowIdent->bc1 = "iconst_1";
                                else nowIdent->bc1 = "iconst_0";
                                boolValue = true;
                                break;
                            default:
                                yyerror("Const Declaration occur not const type.");
                                break;
                            }
                            Trace("set const_declaration accessBC done " + nowIdent->bc1);
                        }
                        else yyerror("const_declaration not success.");
                    }
                    else {
                        string msg = string($1) + " already declared.";
                        yyerror(msg, linenum - 1);
                    }
                 };

varDec: IDENT typeOrEmpty assignOrEmpty { 
                    Trace("VAR Declaration:");
                    if (nowScope->lookup($1, false) == NULL) { 
                        if ($2 == TYPE_NOT_DEFINE){
                            if($3 == TYPE_NOT_DEFINE){
                                /* $2 & $3 both are type_not_define */
                                nowScope->insert($1, INTEGER_VAR);
                            }
                            else{
                                /* $2 is type_not_define, $3 is not */
                                nowScope->insert($1, INTEGER_VAR + $3);
                            }
                        }
                        else{
                            if($3 == TYPE_NOT_DEFINE){
                                /* $2 is not type_not_define, $3 is */
                                nowScope->insert($1, INTEGER_VAR + $2);
                            }
                            else{
                                /* $2 & $3 both are not type_not_define */
                                if($2 != $3){
                                    /* $2 & $3 are not same type */
                                    yyerror("Variable declartion type not equal with value type.", linenum-1);
                                }
                                else nowScope->insert($1, INTEGER_VAR + $2);
                            }
                        }
                        
                        // accessBC
                        nowIdent = nowScope->lookup($1, false);
                        if (nowIdent != NULL) {
                            // set BC
                            if (nowScope->fatherTable != NULL) {
                                nowIdent->bc1 = "iload " + to_string(nowScope->vIndex);
                                nowIdent->bc2 = "istore " + to_string(nowScope->vIndex);
                                nowScope->vIndex++;

                                if (assignValue) {
                                    Trace("VAR Declaration local var assignValue");
                                    assignValue = false;
                                    switch (nowIdent->type) {
                                    case INTEGER_VAR:
                                        writeOut(fout, "sipush " + to_string(intValue));
                                        writeOut(fout, nowIdent->bc2);
                                        intValue = 0;
                                        break;
                                    case BOOL_VAR:
                                        if (boolValue) writeOut(fout, "iconst_1");
                                        else writeOut(fout, "iconst_0");
                                        writeOut(fout, nowIdent->bc2);
                                        boolValue = true;
                                        break;
                                    default:
                                        break;
                                    }
                                }
                            }
                            else {
                                nowIdent->bc1 = "getstatic int " + nowScope->scopeName + "." + nowIdent->name;
                                nowIdent->bc2 = "putstatic int " + nowScope->scopeName + "." + nowIdent->name;

                                if (assignValue) {
                                    Trace("VAR Declaration global var assignValue");
                                    assignValue = false;
                                    switch (nowIdent->type) {
                                    case INTEGER_VAR:
                                        writeOut(fout, "field static int " + nowIdent->name + " = " + to_string(intValue));
                                        intValue = 0;
                                        break;
                                    case BOOL_VAR:
                                        if (boolValue) writeOut(fout, "field static int " + nowIdent->name + " = 1");
                                        else writeOut(fout, "field static int " + nowIdent->name + " = 0");
                                        boolValue = true;
                                        break;
                                    default:
                                        break;
                                    }
                                }
                                else {
                                    writeOut(fout, "field static int " + nowIdent->name);
                                }
                            }
                            
                            // Error
                            switch (nowIdent->type) {
                            case INTEGER_VAR:
                            case BOOL_VAR:
                                break;
                            default:
                                yyerror("var_declaration occur not integer/boolean type.");
                                break;
                            }  
                        }
                        else yyerror("var_declaration not success.");
                    }
                    else { /* already decalred */
                        string msg = string($1) + " already declared.";
                        yyerror(msg, linenum - 1);
                    }
               }
        | arrayDec;

assignOrEmpty: /* empty */ { $$ = TYPE_NOT_DEFINE; }
            | ASSI constExp { $$ = $2; assignValue = true;};

typeOrEmpty: /* empty */ { $$ = TYPE_NOT_DEFINE; }
            | COLO types { $$ = $2; };

types: INT { $$ = 0; }
     | FLOAT { $$ = 1; }
     | CHAR { $$ = 2; }
     | STRING { $$ = 3; }
     | BOOL { $$ = 4; };

constExp: INTEGER_VAL { 
                $$ = 0; 
                intValue = $1;
                }
        | REAL_VAL { 
                $$ = 1; 
                realValue = $1; 
                }
        | CHAR_VAL { 
                $$ = 2; 
                charValue = $1; 
                }
        | STRING_VAL { 
                $$ = 3; 
                strValue = string($1);
                }
        | BOOL_VAL { 
                $$ = 4; 
                boolValue = $1; 
                };

BOOL_VAL: TRUE { $$ = true; } 
        | FALSE { $$ = false; }
        ;

methodDec: FUN IDENT { 
                    Trace("Method Declartion:");
                    if (nowScope->lookup($2, false) != NULL) {
                        canWrite = false;
                        string msg = string($2) + " already declared.";
                        yyerror(msg);
                        nowScope = nowScope->createChild("temp_method"); 
                    }
                    else {
                        nowScope->insert($2, METHOD_TYPE_NOT_DEFINE); 
                        nowIdent = nowScope->lookup($2, false);
                        nowScope = nowScope->createChild($2); 
                    }
                }
            PARE_L argumentsOrEmpty PARE_R 
            returnTypeOrEmpty{
                Trace("method_declartion set accessBC and bytecode");

                // return type
                string returnTypeStr = "void ";
                switch (nowIdent->type) {
                case METHOD_TYPE_FUNC:
                    break;
                case METHOD_TYPE_INTEGER:
                case METHOD_TYPE_BOOL:
                    returnTypeStr = "int ";
                    break;
                default:
                    yyerror("method_declartion return type not integer/boolean/void type.");
                    break;
                }

                // method name and formal arguments
                string nameArguments = nowIdent->name;
                nameArguments += "(";
                for (int i = 0; i < nowIdent->args.size(); i++) {
                    if (i) nameArguments += ", ";
                    switch (nowIdent->args[i]) {
                    case INTEGER_VAR:
                    case BOOL_VAR:
                        nameArguments += "int";
                        break;
                    default:
                        nameArguments += "int";
                        yyerror("method_declartion formal argument type not integer/boolean type.");
                        break;
                    }
                }
                nameArguments += ")";
                    
                // set accessBC
                nowIdent->bc1 = "invokestatic " + returnTypeStr + nowScope->fatherTable->scopeName + "." + nameArguments;
                    
                // declartion bytecode
                if (nowIdent->name == "main") {
                    writeOut(fout, "method public static void main(java.lang.String[])"); 
                    if (nowIdent->args.size() > 0) yyerror("main function cannot overwrite formal argument.");
                }
                else writeOut(fout, "method public static " + returnTypeStr + nameArguments);
                writeOut(fout, "max_stack 15");
                writeOut(fout, "max_locals 15");
                writeOut(fout, "{");
                outputs++;    
            } 
            block{
                if (!nowScope->checkReturn) writeOut(fout, "return");

                outputs--;
                writeOut(fout, "}");
                
                fatherScope = nowScope->fatherTable;
                delete nowScope;
                nowScope = fatherScope;
                
                canWrite = true;
            };

argumentsOrEmpty: /* empty */ 
                | formalArguments;

formalArguments: formalArgument 
                | formalArgument COMM formalArguments;

formalArgument: IDENT COLO types { 
                        Trace("method params:");
                        nowIdent->addParam(INTEGER_VAR + $3);
                        Trace("size: " + to_string(nowIdent->args.size()));

                        nowScope->insert($1, INTEGER_VAR + $3);
                        ident* argIdent = nowScope->lookup($1, false);
                        if (argIdent != NULL) {
                            argIdent->bc1 = "iload " + to_string(nowScope->vIndex);
                            argIdent->bc2 = "istore " + to_string(nowScope->vIndex);
                            nowScope->vIndex++;
                        }
                        else yyerror("method_formal_argument occur error");
                    };


returnTypeOrEmpty: /* empty */ { 
                            nowScope->returnType = METHOD_TYPE_FUNC;
                            nowIdent->type = METHOD_TYPE_FUNC;
                         }
                         | COLO types { 
                            nowScope->returnType = METHOD_TYPE_INTEGER + $2;
                            nowIdent->type = METHOD_TYPE_INTEGER + $2;
                         };

arrayDec: IDENT COLO types SQUE_L INTEGER_VAL SQUE_R { 
                    Trace("ARRAY Declartion:");
                    if (nowScope->lookup($1, false) != NULL) {
                        string msg = string($1) + " already declared.";
                        yyerror(msg, linenum - 1);
                    }
                    else nowScope->insert($1, INTEGER_ARRAY + $3); 
                };

block: { Trace("block:"); } BRAC_L blockStatements BRAC_R;

blockStatements: /* empty */
                | blockStatement blockStatements;

blockStatement: varConstDec | statements;

statements: statement1 // variable assign 
         | statement2 // array value assign
         | statement3 // print or println
         | statement4 // read ident
         | statement5 // return 
         | conditionalStatement 
         | whileLoopStatement
         | forLoopStatement
         | procedureInvocation; 

statement1: IDENT ASSIS expression { 
                Trace("statement1(variable assign):");
                Trace("linenum:" + to_string(linenum));
                nowIdent = nowScope->lookup($1, true);
                if (nowIdent != NULL) {
                    writeOut(fout, nowIdent->bc2);
                    string msg = "";
                    if (nowIdent->type >= INTEGER_VAR && nowIdent->type <= BOOL_VAR){
                        if (nowIdent->type % TYPE_COUNT != $3) {
                            msg = string($1) + "wrong data type, can't assign value.";
                            yyerror(msg, linenum - 1);
                        }
                        /* is legal */
                    }
                    else if (nowIdent->type >= METHOD_TYPE_FUNC && nowIdent->type <= METHOD_TYPE_BOOL){
                        msg = string($1) + " is function, can't assign value.";
                        yyerror(msg, linenum - 1);
                    }
                    else if (nowIdent->type >= INTEGER_ARRAY && nowIdent->type <= BOOL_ARRAY){
                        msg = string($1) + " is array, can't assign value.";
                        yyerror(msg, linenum - 1);
                    }
                    else if (nowIdent->type >= CONST_INTEGER && nowIdent->type <= CONST_BOOL){
                        msg = string($1) + " is constant, can't change value.";
                        yyerror(msg, linenum - 1);
                    }
                    else {
                        msg = string($1) + " UNKNOWN ERROR.";
                        yyerror(msg, linenum - 1);
                    }
                }
                else {
                    string msg = string($1) + " not declared.";
                    yyerror(msg, linenum - 1);
                }
           };

statement2: IDENT SQUE_L integerExp SQUE_R ASSIS expression {
                Trace("statement2(array value assign):");
                nowIdent = nowScope->lookup($1, true);
                
                if (nowIdent != NULL) {
                    if (nowIdent->type >= INTEGER_ARRAY && nowIdent->type <= BOOL_ARRAY) {
                        if (nowIdent->type % TYPE_COUNT != $6) {
                            string msg = string($1) + " data type not correct, can't assign value.";
                            yyerror(msg, linenum - 1);
                        }
                    }
                    else if (nowIdent->type >= INTEGER_VAR && nowIdent->type <= BOOL_VAR) {
                        string msg = string($1) + " is variable, not array.";
                        yyerror(msg, linenum - 1);
                    }
                    else if (nowIdent->type >= METHOD_TYPE_FUNC && nowIdent->type <= METHOD_TYPE_BOOL) {
                        string msg = string($1) + " is function, not array.";
                        yyerror(msg, linenum - 1);
                    }
                    else if (nowIdent->type >= CONST_INTEGER && nowIdent->type <= CONST_BOOL) {
                        string msg = string($1) + " is constant, not array.";
                        yyerror(msg, linenum - 1);
                    }
                    else {
                        string msg = string($1) + " UNKNOWN ERROR.";
                        yyerror(msg, linenum - 1);
                    }
                }
                else {
                    string msg = string($1) + " not declared.";
                    yyerror(msg, linenum - 1);
                }
            };

ASSIS: ASSI
     | CP_PLUS
     | CP_MINU
     | CP_MULT
     | CP_DIVI;

statement3: PRINTS {
                writeOut(fout, "getstatic java.io.PrintStream java.lang.System.out");
            } PARE_L expression PARE_R { 
                if(selectOper == 1) {
                    Trace("statement3(println with pares):");
                    if ($4 == TYPE_ERROR) yyerror("This expression cannot print.", linenum - 1);
                    // integer/boolean expression
                    if ($4 == 2 || $4 == 1 ) writeOut(fout, "invokevirtual void java.io.PrintStream.print(int)");
                    // string expression
                    else if ($4 == 0) writeOut(fout, "invokevirtual void java.io.PrintStream.print(java.lang.String)");
                    else {
                        yyerror("This expression can't print.", linenum - 1);
                        // fix the stack
                        writeOut(fout, "pop");
                        writeOut(fout, "ldc \"TYPE_ERROR\"");
                        writeOut(fout, "invokevirtual void java.io.PrintStream.print(java.lang.String)");
                    }
                }
                else if(selectOper == 2) {
                    Trace("statement3(print without pares):");
                    if ($4 == TYPE_ERROR) yyerror("This expression cannot print.", linenum - 1);
                    // integer/boolean expression
                    if ($4 == 2 || $4 == 1 ) writeOut(fout, "invokevirtual void java.io.PrintStream.println(int)");
                    // string expression
                    else if ($4 == 0) writeOut(fout, "invokevirtual void java.io.PrintStream.println(java.lang.String)");
                    else {
                        yyerror("This expression can't print.", linenum - 1);
                        // fix the stack
                        writeOut(fout, "pop");
                        writeOut(fout, "ldc \"TYPE_ERROR\"");
                        writeOut(fout, "invokevirtual void java.io.PrintStream.println(java.lang.String)");
                    }
                }
                
           }
           | PRINTS {
                writeOut(fout, "getstatic java.io.PrintStream java.lang.System.out");
           } expression {
                if(selectOper == 1) {
                    Trace("statement3(print with pares):");
                    if ($3 == TYPE_ERROR) yyerror("This expression cannot print.", linenum - 1);
                    // integer/boolean expression
                    if ($3 == 2 || $3 == 1 ) writeOut(fout, "invokevirtual void java.io.PrintStream.print(int)");
                    // string expression
                    else if ($3 == 0) writeOut(fout, "invokevirtual void java.io.PrintStream.print(java.lang.String)");
                    else {
                        yyerror("This expression can't print.", linenum - 1);
                        // fix the stack
                        writeOut(fout, "pop");
                        writeOut(fout, "ldc \"TYPE_ERROR\"");
                        writeOut(fout, "invokevirtual void java.io.PrintStream.print(java.lang.String)");
                    }
                }
                else if(selectOper == 2) {
                    Trace("statement3(println without pares):");
                    if ($3 == TYPE_ERROR) yyerror("This expression cannot print.", linenum - 1);
                    // integer/boolean expression
                    if ($3 == 2 || $3 == 1 ) writeOut(fout, "invokevirtual void java.io.PrintStream.println(int)");
                    // string expression
                    else if ($3 == 0) writeOut(fout, "invokevirtual void java.io.PrintStream.println(java.lang.String)");
                    else {
                        yyerror("This expression can't print.", linenum - 1);
                        // fix the stack
                        writeOut(fout, "pop");
                        writeOut(fout, "ldc \"TYPE_ERROR\"");
                        writeOut(fout, "invokevirtual void java.io.PrintStream.println(java.lang.String)");
                    }
                }
           };

PRINTS: PRINT {selectOper = 1;}
      | PRINTLN {selectOper = 2;};

statement4: READ IDENT {
                Trace("statement4(read ident):");
                nowIdent = nowScope->lookup($2, true);
                if (nowIdent != NULL) {
                    /* show ident type and value */
                    Trace(nowIdent->name + " ,type : " + to_string(nowIdent->type));
                }
                else{
                    string msg = string($2) + " not declared.";
                    yyerror(msg, linenum - 1);
                }
           };

statement5: RETURN { /* procedure */
                Trace("statement5: RETURN");
                writeOut(fout, "return");
                symbolTable* temp = nowScope;
                while (temp->returnType == NON_TYPE) {
                    if (temp->fatherTable == NULL) break;
                    temp = temp->fatherTable;
                }
                Trace("Return scope name:" + temp->scopeName);
                temp->checkReturn = true;
                if (temp->returnType != METHOD_TYPE_FUNC) {
                    if (temp->returnType < METHOD_TYPE_INTEGER || temp->returnType > METHOD_TYPE_BOOL) {
                        string msg = "Do not return in non-method scope.";
                        yyerror(msg, linenum - 1);
                    }
                    else {
                        string msg = temp->scopeName + " need return value.";
                        yyerror(msg, linenum - 1);
                    }
                }
            }
           | RETURN expression {  /* function */
                Trace("statement5: RETURN expression");
                writeOut(fout, "ireturn");
                symbolTable* temp = nowScope;
                while (temp->returnType == NON_TYPE) {
                    if (temp->fatherTable == NULL) break;
                    temp = temp->fatherTable;
                }
                Trace("Return scope name:" + temp->scopeName);
                temp->checkReturn = true;
                if (temp->returnType < METHOD_TYPE_INTEGER || temp->returnType > METHOD_TYPE_BOOL) {
                    if (temp->returnType != METHOD_TYPE_FUNC) {
                        string msg = "Don't do return in non-method scope.";
                        yyerror(msg, linenum - 1);
                    }
                    else {
                        string msg = temp->scopeName + " no need return value.";
                        yyerror(msg, linenum - 1);
                    }
                }
                else {
                    if (temp->returnType % TYPE_COUNT != $2) {
                        string msg = "Return type error.";
                        yyerror(msg, linenum - 1);
                    }
                }
            };

conditionalStatement: { Trace("Conditional Statement:"); } IF PARE_L booleanExp 
                    PARE_R { 
                        elseBranch = false;
                        branchStack.push(branchIndex + 1);
                        branchStack.push(branchIndex);
                        branchStack.push(branchIndex + 1);
                        branchStack.push(branchIndex);
                        branchIndex += 2;

                        writeOut(fout, "ifeq L" + to_string(branchStack.top()));
                        branchStack.pop();
                    } 
                    blockOrStatement 
                    elseOrEmpty{
                        if (elseBranch) writeOut(fout, "L" + to_string(branchStack.top()) + ":");
                        branchStack.pop();
                    };

elseOrEmpty: /* empty */{
                branchStack.pop();
                writeOut(fout, "L" + to_string(branchStack.top()) + ":");
                branchStack.pop();
            } 
            | ELSE {
                elseBranch = true;
                          
                int gotoIndex = branchStack.top();
                branchStack.pop();
                int labelIndex = branchStack.top();
                branchStack.pop();

                writeOut(fout, "goto L" + to_string(gotoIndex));
                writeOut(fout, "L" + to_string(labelIndex) + ":");        
            } blockOrStatement;

blockOrStatement: {
                        Trace("block or statement:");
                        nowScope = nowScope->createChild("temp_block"); 
                  } block {
                        fatherScope = nowScope->fatherTable;
                        delete nowScope;
                        nowScope = fatherScope;
                  } 
                  | statements;

whileLoopStatement: { Trace("WHILE Loop Statement:"); } WHILE {
                            branchStack.push(branchIndex + 1);
                            branchStack.push(branchIndex);
                            branchStack.push(branchIndex + 1);
                            branchStack.push(branchIndex);
                            branchIndex += 2;

                            writeOut(fout, "L" + to_string(branchStack.top()) + ":");
                            branchStack.pop();
                    } 
                    PARE_L booleanExp PARE_R {
                            writeOut(fout, "ifeq L" + to_string(branchStack.top()));
                            branchStack.pop();
                    } blockOrStatement {
                            int gotoIndex = branchStack.top();
                            branchStack.pop();
                            int labelIndex = branchStack.top();
                            branchStack.pop();

                            writeOut(fout, "goto L" + to_string(gotoIndex));
                            writeOut(fout, "L" + to_string(labelIndex) + ":");
                    };

forLoopStatement: FOR PARE_L IDENT {
                        Trace("For Loop Statement:");
                        nowIdent = nowScope->lookup($3, true);
                        if (nowIdent == NULL) yyerror(string($3) + " not declared.");
                        else if (nowIdent->type != INTEGER_VAR) yyerror(string($3) + " not integer.");
                    }
                    ARROW INTEGER_VAL DOTS INTEGER_VAL {
                        // push initialValue
                        writeOut(fout, "sipush " + to_string($6));
                        // store to ident
                        writeOut(fout, nowIdent->bc2);

                        branchStack.push(branchIndex + 1);
                        branchStack.push(branchIndex);
                        branchStack.push(branchIndex + 1);
                        branchStack.push(branchIndex);
                        branchIndex += 2;

                        writeOut(fout, "L" + to_string(branchStack.top()) + ":");
                        branchStack.pop();

                    } PARE_R blockOrStatement {
                        // push initialValue
                        writeOut(fout, "sipush " + to_string($8));
                        // get identValue
                        nowIdent = nowScope->lookup($3, true);
                        if (nowIdent != NULL) writeOut(fout, nowIdent->bc1);
                        else yyerror(string($3) + " not found (occur error at forloop bytecode).");
                        // ifequal exit
                        writeOut(fout, "isub");
                        writeOut(fout, "ifeq L" + to_string(branchStack.top()));
                        branchStack.pop();

                        // ident ++ and save
                        writeOut(fout, "iconst_1");
                        if (nowIdent != NULL) writeOut(fout, nowIdent->bc1);
                        else yyerror(string($3) + " not found (occur error at forloop bytecode).");
                        writeOut(fout, "iadd");
                        if (nowIdent != NULL) writeOut(fout, nowIdent->bc2);
                        else yyerror(string($3) + " not found (occur error at forloop bytecode).");

                        // goback
                        writeOut(fout, "goto L" + to_string(branchStack.top()));
                        branchStack.pop();

                        // exit label
                        writeOut(fout, "L" + to_string(branchStack.top()) + ":");
                        branchStack.pop();
                    };

functionInvocation: IDENT PARE_L paramsOrEmpty PARE_R { 
                        Trace("FUNCTION Invocation:");
                        nowIdent = nowScope->lookup($1, true);
                        if (nowIdent != NULL) {
                            writeOut(fout, nowIdent->bc1);
                            if (nowIdent->type < METHOD_TYPE_INTEGER || nowIdent->type > METHOD_TYPE_BOOL) {
                                string msg = string($1) + " not function (with return value).";
                                yyerror(msg);
                                $$ = TYPE_ERROR;
                            }
                            $$ = nowIdent->type % TYPE_COUNT;
                            string trace_msg = "nowIdent->name " + nowIdent->name + ", args.size()= " + to_string(nowIdent->args.size()) + ", para.size()= " + to_string(para.size());
                            Trace(trace_msg);
                            if (nowIdent->args.size() == para.size()) {
                                bool checkType = true;
                                for (int i = 0; i < para.size(); i++) {
                                    string trace_msg = "checkType " + to_string(i) + ", type= " + to_string(nowIdent->args[i]) + ", paraType= " + to_string(para[i]);
                                    Trace(trace_msg);
                                    if (nowIdent->args[i] % TYPE_COUNT != para[i]) {
                                        checkType = false;
                                        break;
                                    }
                                }
                                if (!checkType) {
                                    string msg = string($1) + " argument type error.";
                                    yyerror(msg);
                                }
                            }
                            else if(nowIdent->args.size() < para.size()) {
                                string msg = "Over arguments in " + string($1) +".";
                                yyerror(msg);
                            }
                            else {
                                string msg = "Few arguments in " + string($1) +".";
                                yyerror(msg);
                            }
                        }
                        else {
                            string msg = string($1) + " not declared.";
                            yyerror(msg);
                            $$ = TYPE_ERROR;
                        }
                    };

procedureInvocation: IDENT PARE_L paramsOrEmpty PARE_R {
                        Trace("PROCEDURE Invocation:");
                        nowIdent = nowScope->lookup($1, true);
                        if (nowIdent != NULL) {
                            writeOut(fout, nowIdent->bc1);
                            if (nowIdent->type != METHOD_TYPE_FUNC) {
                                string msg = string($1) + " not procedure (no return).";
                                yyerror(msg);
                            }
                            string trace_msg = "nowIdent->name " + nowIdent->name + ", args.size()= " + to_string(nowIdent->args.size()) + ", para.size()= " + to_string(para.size());
                            Trace(trace_msg);
                            if (nowIdent->args.size() == para.size()) {
                                bool checkType = true;
                                for (int i = 0; i < para.size(); ++i) {
                                    string trace_msg = "checkType " + to_string(i) + ", type= " + to_string(nowIdent->args[i]) + ", paraType= " + to_string(para[i]);
                                    Trace(trace_msg);
                                    if (nowIdent->args[i] % TYPE_COUNT != para[i]) {
                                        checkType = false;
                                        break;
                                    }
                                }
                                if (!checkType) {
                                    string msg = string($1) + " argument type error.";
                                    yyerror(msg);
                                }
                            }
                            else if(nowIdent->args.size() < para.size()) {
                                string msg = "Over arguments in " + string($1) +".";
                                yyerror(msg);
                            }
                            else {
                                string msg = "Few arguments in " + string($1) +".";
                                yyerror(msg);
                            }
                        }
                        else {
                            string msg = string($1) + " not declared.";
                            yyerror(msg);
                        }
                    };

paramsOrEmpty: /* empty */ 
            | { para.clear(); } params;

params: param 
      | param COMM params;

param: expression { para.push_back($1);};

LG: OR  { selectOper = 1;}
  | AND { selectOper = 2;} ;
  
RL1: RL_LT { selectOper = 1;}
   | RL_GT { selectOper = 2;}
   | RL_LE { selectOper = 3;} 
   | RL_GE { selectOper = 4;} ;

RL2: RL_NE { selectOper = 1;}
   | RL_EQ { selectOper = 2;} ;

ARITHMETIC: PLUS { selectOper = 1;}
          | MINU { selectOper = 2;}
          | MULT { selectOper = 3;}
          | DIVI { selectOper = 4;} ;

expression: expression LG expression {
              if( selectOper == 1){
                  Trace("expression OR expression:"); writeOut(fout, "ior");
              }
              else if( selectOper == 2){
                  Trace("expression AND expression:"); writeOut(fout, "iand");
              }
              if ($1 == $3 && $3 == 1){
                  $$ = $1;
              }
              else {
                  string msg = "must be boolean.";
                  yyerror(msg);
                  $$ = TYPE_ERROR;
              }
          }
          | NOT expression {
              Trace("NOT expression:" + to_string($2));
              writeOut(fout, "iconst_1");
              writeOut(fout, "ixor");
              if ($2 != 1){
                  string msg = "must be boolean.";
                  yyerror(msg);
                  $$ = TYPE_ERROR;
              }
              else $$ = $2;
          }
          | expression ARITHMETIC expression {
              if ( selectOper == 1){
                  Trace("expression PLUS expression:"); 
                  writeOut(fout, "iadd");
              }
              else if ( selectOper == 2){
                  Trace("expression MINU expression:"); 
                  writeOut(fout, "isub");
              }
              else if ( selectOper == 3){
                  Trace("expression MULT expression:"); 
                  writeOut(fout, "imul");
              }
              else if ( selectOper == 4){
                  Trace("expression DIVI expression:");
                  writeOut(fout, "idiv");
              }
              if (($1 == 0 || $1 == 2 || $1 == 3 || $1 == 4) && ($3 == 0 || $3 == 2 || $3 == 3 || $3 == 4)) {
                  if ($1 != $3) {
                      string msg = "left and right data type are not equal.";
                      yyerror(msg);
                      $$ = TYPE_ERROR;
                  }
                  else $$ = $1;
              }
              else {
                  string msg = "must be num-value or string.";
                  yyerror(msg);
                  $$ = TYPE_ERROR;
              }
          }
          | expression REMA expression {
              Trace("expression REMA expression:");
              writeOut(fout, "irem");
              if ($1 != 2 || $3 != 2) {
                  string msg = "must be integer.";
                  yyerror(msg);
                  $$ = TYPE_ERROR;
              }
              else $$ = $1;
          }
          | MINU expression %prec U_MINU {
              Trace("U_MINU expression:");
              writeOut(fout, "ineg");
              if ($2 == 2 || $2 == 3) $$ = $2;
              else {
                  string msg = "must be num-value.";
                  yyerror(msg);
                  $$ = TYPE_ERROR;
              }
          }
          | expression RL1 expression {
              if ( selectOper == 1){
                  Trace("expression RL_LT expression:");
                  writeOut(fout, "isub");	
                  writeOut(fout, "iflt L" + to_string(branchIndex));	
                  writeOut(fout, "iconst_0");	
                  writeOut(fout, "goto L" + to_string(branchIndex + 1));	
                  writeOut(fout, "L" + to_string(branchIndex) + ":");	
                  writeOut(fout, "iconst_1");	
                  writeOut(fout, "L" + to_string(branchIndex + 1) + ":");	
                  branchIndex += 2;
              }
              else if( selectOper == 2){
                  Trace("expression RL_GT expression:");
                  writeOut(fout, "isub");	
                  writeOut(fout, "ifgt L" + to_string(branchIndex));	
                  writeOut(fout, "iconst_0");	
                  writeOut(fout, "goto L" + to_string(branchIndex + 1));	
                  writeOut(fout, "L" + to_string(branchIndex) + ":");	
                  writeOut(fout, "iconst_1");	
                  writeOut(fout, "L" + to_string(branchIndex + 1) + ":");	
                  branchIndex += 2;
              }
              else if( selectOper == 3){
                  Trace("expression RL_LE expression:");
                  writeOut(fout, "isub");	
                  writeOut(fout, "ifle L" + to_string(branchIndex));	
                  writeOut(fout, "iconst_0");	
                  writeOut(fout, "goto L" + to_string(branchIndex + 1));	
                  writeOut(fout, "L" + to_string(branchIndex) + ":");	
                  writeOut(fout, "iconst_1");	
                  writeOut(fout, "L" + to_string(branchIndex + 1) + ":");	
                  branchIndex += 2;
              }
              else if( selectOper == 4){
                  Trace("expression RL_GE expression:");
                  writeOut(fout, "isub");	
                  writeOut(fout, "ifge L" + to_string(branchIndex));	
                  writeOut(fout, "iconst_0");	
                  writeOut(fout, "goto L" + to_string(branchIndex + 1));	
                  writeOut(fout, "L" + to_string(branchIndex) + ":");	
                  writeOut(fout, "iconst_1");	
                  writeOut(fout, "L" + to_string(branchIndex + 1) + ":");	
                  branchIndex += 2;
              }
              if (($1 >= 2 && $1 <= 4) && ($3 >= 2 && $3 <= 4)) {
                  if ($1 != $3) {
                      string msg = "left and right data type are not equal.";
                      yyerror(msg);
                      $$ = TYPE_ERROR;
                  }
                  else $$ = 1;
              }
              else {
                  string msg = "must be num-value.";
                  yyerror(msg);
                  $$ = TYPE_ERROR;
              }
          }
          | expression RL2 expression {
              if ( selectOper == 1){
                  Trace("expression RL_NE expression:");
                  writeOut(fout, "isub");	
                  writeOut(fout, "ifne L" + to_string(branchIndex));	
                  writeOut(fout, "iconst_0");	
                  writeOut(fout, "goto L" + to_string(branchIndex + 1));	
                  writeOut(fout, "L" + to_string(branchIndex) + ":");	
                  writeOut(fout, "iconst_1");	
                  writeOut(fout, "L" + to_string(branchIndex + 1) + ":");	
                  branchIndex += 2;
              }
              else if ( selectOper == 2){
                  Trace("expression RL_EQ expression:");
                  writeOut(fout, "isub");	
                  writeOut(fout, "ifeq L" + to_string(branchIndex));	
                  writeOut(fout, "iconst_0");	
                  writeOut(fout, "goto L" + to_string(branchIndex + 1));	
                  writeOut(fout, "L" + to_string(branchIndex) + ":");	
                  writeOut(fout, "iconst_1");	
                  writeOut(fout, "L" + to_string(branchIndex + 1) + ":");	
                  branchIndex += 2;
              }
              if (($1 >= 0 && $1 <= 4) && ($3 >=0 && $3 <= 4)) {
                  if ($1 != $3) {
                      string msg = "left and right data type are not equal.";
                      yyerror(msg);
                      $$ = TYPE_ERROR;
                  }
                  else $$ = 1;
              }
              else {
                  string msg = "must be num-value.";
                  yyerror(msg);
                  $$ = TYPE_ERROR;
              }
          }
          | STRING_VAL { $$ = 0; writeOut(fout, "ldc \"" + adjStrVal(string($1)) + "\"");}
          | BOOL_VAL{ 
                $$ = 1; 
                if ($1) writeOut(fout, "iconst_1");
                else writeOut(fout, "iconst_0");
            }
          | INTEGER_VAL { $$ = 2; writeOut(fout, "sipush " + to_string($1));}
          | REAL_VAL { $$ = 3; }
          | CHAR_VAL { $$ = 4; }
          | PARE_L expression PARE_R { $$ = $2; }
          | functionInvocation { $$ = $1; }
          | arrayRef { $$ = $1; }
          | IDENT {
                Trace("expression: IDENT:");
                nowIdent = nowScope->lookup($1, true);
                Trace($1);
                if (nowIdent != NULL) {
                    Trace(to_string(nowIdent->type));
                    writeOut(fout, nowIdent->bc1);
                    if (nowIdent->type < CONST_INTEGER || nowIdent->type > BOOL_VAR) {
                        string msg = string($1) + " not constant or variable.";
                        yyerror(msg);
                        $$ = TYPE_ERROR;
                    }
                    else $$ = nowIdent->type % TYPE_COUNT;
                }
                else {
                    string msg = string($1) + " not declared.";
                    yyerror(msg);
                    $$ = TYPE_ERROR;
                }
          };

booleanExp: expression {
                        Trace("Boolean expression:");
                        if ($1 != 1) {
                            string msg = "This expression is not boolean.";
                            yyerror(msg);
                        } 
                  }; 

integerExp: expression { 
                        Trace("Integer expression:");
                        if ($1 != 2) {
                            string msg = "This expression is not integer.";
                            yyerror(msg);
                        }
                  };
                  
arrayRef: IDENT SQUE_L integerExp SQUE_R {
                    Trace("Array Reference:");
                    nowIdent = nowScope->lookup($1, true);
                    if (nowIdent != NULL) {
                        if (nowIdent->type >= INTEGER_ARRAY && nowIdent->type <= BOOL_ARRAY) $$ = nowIdent->type % TYPE_COUNT;
                        else {
                            string msg = "";
                            $$ = TYPE_ERROR;
                            if (nowIdent->type >= CONST_INTEGER && nowIdent->type <= CONST_BOOL) 
                                msg = string($1) + " is constant, not array.";
                            else if (nowIdent->type >= INTEGER_VAR && nowIdent->type <= BOOL_VAR) 
                                msg = string($1) + " is variable, not array.";
                            else if(nowIdent->type >= METHOD_TYPE_FUNC && nowIdent->type <= METHOD_TYPE_BOOL) 
                                msg = string($1) + " is function, not array.";
                            else msg = string($1) + " UNKNOWN ERROR.";
                            yyerror(msg);
                        }
                    }
                    else {
                        $$ = TYPE_ERROR;
                        string msg = string($1) + " not declared.";
                        yyerror(msg);
                    }
                }; 

%%
int main(int argc, char *argv[])
{
    /* open the source file */
    if (argc != 2) {
        printf ("Usage: ./parser FILENAME\n");
        exit(1);
    }
    filename = string(argv[1]);
    yyin = fopen(argv[1], "r");         /* open input file */
    
    rawFilename = filename.substr(0, filename.find_last_of("."));	
    fout.open(rawFilename + ".jasm");
    
    /* parsing */
    if (yyparse() == 1)              
        yyerror("Parsing error!");     /* syntax error */
}