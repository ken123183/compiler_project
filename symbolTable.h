#include <iostream>
#include <string>
#include <vector>
#include <map>

#define MAX_LINE_LENG 256
#define TYPE_COUNT 5
#define METHOD_TYPE_NOT_DEFINE -9
#define TYPE_NOT_DEFINE -8
#define PARAM_NOT_EXIST -7
#define TYPE_ERROR -1
#define NON_TYPE 0
#define METHOD_TYPE_FUNC 1
#define METHOD_TYPE_INTEGER 2
#define METHOD_TYPE_REAL 3
#define METHOD_TYPE_CHAR 4
#define METHOD_TYPE_STRING 5
#define METHOD_TYPE_BOOL 6
#define CONST_INTEGER 7
#define CONST_REAL 8
#define CONST_CHAR 9
#define CONST_STRING 10
#define CONST_BOOL 11
#define INTEGER_VAR 12
#define REAL_VAR 13
#define CHAR_VAR 14
#define STRING_VAR 15
#define BOOL_VAR 16
#define INTEGER_ARRAY 17
#define REAL_ARRAY 18
#define CHAR_ARRAY 19
#define STRING_ARRAY 20
#define BOOL_ARRAY 21


class ident {
public:
    ident();
    ident(std:: string name, int type);
    ~ident();

    // ID name
    std::string name;

    // ID data type 
    int type;
    
    // FOR METHOD_TYPE: to store params' type
    // FOR OTHER: empty
    std::vector<int> args;
    
    // getstatic, iload, sipush, iconst, invokestatic 
    std::string bc1;
    
    // putstatic, istore
    std::string bc2;
    
    /* Insert Method Param data type */
    void addParam(int type);
};

class ident;
class symbolTable {
public:
    symbolTable();
    symbolTable(std::string scopeName, symbolTable* fatherTable);
    ~symbolTable();
    
    // scope name (class <name>, fun <method_name>)
    std::string scopeName;

    // map to store this scope identifiers
    std::map<std::string, ident*> idents;
    
    // used for scope relation, point to symbolTable of outer scope
    symbolTable* fatherTable;

    // used to check this symbolTable return type
    int returnType;
    
    // local var index;
    int vIndex;
    
    // return or NOT
    bool checkReturn;
    
    /* insert identifier in symbol table */
    void insert(std::string s, int type);

    /* lookup identifier is in symbolTable or outer scope table then return */
    ident* lookup(std::string s, bool searchFather);

    /* create child symbolTable and set father table is self */
    symbolTable* createChild(std::string s);
    
    friend class ident;
};
