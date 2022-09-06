class ident
+std::string bc1 // record getstatic, iload, sipush, iconst, invokestatic
+std::string bc2 // record putstatic, istore

class symbolTable
+bool checkReturn //return or NOT
+int vIndex //record local var inedx

yacc.y
+branchStack // record branch
+writeOut // Code Generation