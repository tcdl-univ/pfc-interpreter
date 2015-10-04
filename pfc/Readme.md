# COP 4555 - Homework 5

## Due Monday, April 11

## Interpreter 1

In this homework, you will develop an SML interpreter for a small functional language called PCF, which stands for _Programming language for Computable Functions_. The language is relatively simple, but more sophisticated than the arithmetic expressions considered in Homework 4 since it includes functions. The syntax of PCF programs is given by the following BNF grammar:

<pre>  e ::= x | n | true | false | succ | pred | iszero |
        if e then e else e | fn x => e | e e | rec x => e | (e)
</pre>

In the above, <tt>x</tt> stands for an identifier; <tt>n</tt> stands for a non-negative integer literal; <tt>true</tt> and <tt>false</tt> are the boolean literals; <tt>succ</tt> and <tt>pred</tt> are unary functions that add <tt>1</tt> and subtract <tt>1</tt> from their input, respectively; <tt>iszero</tt> is a unary function that returns <tt>true</tt> if its argument is <tt>0</tt> and <tt>false</tt> otherwise; <tt>if e1 then e2 else e3</tt> is a conditional expression; <tt>fn x => e</tt> is a function with parameter <tt>x</tt> and body <tt>e</tt>; <tt>e e</tt> is a function application; <tt>rec x => e</tt> is used for defining recursive functions (we'll explain this later); and <tt>(e)</tt> allows parentheses to be used to control grouping.

It should be clear to you that the above grammar is quite ambiguous. For example, should <tt>fn f => f f</tt> be parsed as <tt>fn f => (f f)</tt> or as <tt>(fn f => f) f</tt>? We can resolve such ambiguities by adopting the following conventions (which are the same as in SML):

*   Function application associates to the left. For example, <tt>e f g</tt> is <tt>(e f) g</tt>, not <tt>e (f g)</tt>.
*   Function application binds tighter than <tt>if</tt>, <tt>fn</tt>, and <tt>rec</tt>. For example, <tt>fn f => f 0</tt> is <tt>fn f => (f 0)</tt>, not <tt>(fn f => f) 0</tt>.

As in Interpreter 0, we don't want to interpret concrete syntax directly. Instead, the interpreter will work on an _abstract syntax tree_ representation of the program; these abstract syntax trees will be values in the following SML datatype:

<pre>  datatype term = AST_ID of string | AST_NUM of int | AST_BOOL of bool
    | AST_SUCC | AST_PRED | AST_ISZERO | AST_IF of term * term * term
    | AST_FUN of string * term | AST_APP of term * term
    | AST_REC of string * term | AST_ERROR of string
</pre>

As before, this definition mirrors the BNF grammar given above; for instance, the constructor <tt>AST_ID</tt> makes a string into an identifier, and the constructor <tt>AST_FUN</tt> makes a string representing the formal parameter and a term representing the body into a function. Note that there is no abstract syntax for <tt>(e)</tt>; the parentheses are just used to control grouping. Also, there is an additional kind of term, <tt>AST_ERROR</tt>, which will be used for reporting runtime errors.

Recall that in Interpreter 0 you had to build the abstract syntax trees for arithmetic expressions by hand, a quite tedious process. For this assignment, I am providing you with a parser that automatically converts from concrete PCF syntax to an abstract syntax tree. The parser is available [here](parser.sml), or you can copy it from <tt>~smithg/parser.sml</tt> to your directory. Include the command

<pre>  use "parser.sml";
</pre>

at the beginning of the file containing your interpreter. This defines the datatype <tt>term</tt> as well as two useful functions, <tt>parsestr</tt> and <tt>parsefile</tt>. Function <tt>parsestr</tt> takes a string and returns the corresponding abstract syntax; for example

<pre>  - parsestr "iszero (succ 7)";
  val it = AST_APP (AST_ISZERO,AST_APP (AST_SUCC,AST_NUM 7)) : term
</pre>

Function <tt>parsefile</tt> takes instead the name of a file and parses its contents. (By the way, the parser is a recursive-descent parser, as discussed in class; you may find it interesting to study how it works.)

You are to write an SML function <tt>interp</tt> that takes an abstract syntax tree represented as a <tt>term</tt> and returns the result of evaluating it, which will also be a <tt>term</tt>. The evaluation should be done according to the rules given below. (Rules in this style are known in the research literature as a _natural semantics_.) The rules are based on _judgments_ of the form _e_ <tt>=></tt> _v_, which means that term _e_ evaluates to value _v_ (and then can be evaluated no further). For the sake of readability, we describe the rules below using the concrete syntax of PCF programs; remember that your <tt>interp</tt> program will actually need to work on abstract syntax trees, which are SML values of type <tt>term</tt>.

The first few rules are uninteresting; they just say that basic PCF values evaluate to themselves:

<tt>(1) n => n</tt>, for any non-negative integer literal <tt>n</tt>

<tt>(2) true => true</tt> and <tt>false => false</tt>

<tt>(3) error s => error s</tt>

<tt>(4) succ => succ</tt>, <tt>pred => pred</tt>, and <tt>iszero => iszero</tt>.

The interesting evaluation rules are a bit more complicated, because they involve _hypotheses_ as well as a _conclusion_. For example, here's one of the rules for evaluating an if-then-else:

<pre>         b => true         e1 => v
 (5)	---------------------------
         if b then e1 else e2 => v
</pre>

In such a rule, the judgments above the horizontal line are _hypotheses_ and the judgment below is the _conclusion_. We read the rule from the bottom up: "if the expression is an if-then-else with components <tt>b</tt>, <tt>e1</tt>, and <tt>e2</tt>, and <tt>b</tt> evaluates to <tt>true</tt> and <tt>e1</tt> evaluates to <tt>v</tt>, then the entire expression evaluates to <tt>v</tt>". Of course, we also have the symmetric rule

<pre>         b => false        e2 => v
 (6)    ----------------------------
         if b then e1 else e2 => v
</pre>

The following rules define the behavior of the built-in functions:

<pre>         e1 => succ        e2 => n
 (7)    ----------------------------
             e1 e2 => n+1

         e1 => pred        e2 => 0       e1 => pred   e2 => n+1  
 (8)    ---------------------------     --------------------------
             e1 e2 => 0                         e1 e2 => n

         e1 => iszero   e2 => 0          e1 => iszero   e2 => n+1
 (9)	------------------------        ---------------------------
              e1 e2 => true                   e1 e2 => false
</pre>

(In these rules, <tt>n</tt> stands for a non-negative integer.)

For example, to evaluate

<pre>  if iszero 0 then 1 else 2
</pre>

we must, by rules <tt>(5)</tt> and <tt>(6)</tt>, first evaluate <tt>iszero 0</tt>. By rule <tt>(9)</tt> (and rules <tt>(4)</tt> and <tt>(1)</tt>), this evaluates to <tt>true</tt>. Finally, by rule <tt>(5)</tt> (and rule <tt>(1)</tt>), the whole program evalutes to <tt>1</tt>.

**Part a.** As a first step, use these rules to write an interpreter, <tt>interp: term -> term</tt>, for the subset of the language that does not include terms of the form <tt>AST_ID</tt>, <tt>AST_FUN</tt>, or <tt>AST_REC</tt>. If your interpreter is given such a term, it can return an error term, such as <tt>AST_ERROR "not yet implemented"</tt>. (You also will need to return error terms for _type errors_ like <tt>succ true</tt>.)

**Part b.** Interpreters need a way of passing parameters to user-defined functions; here we will accomplish this by means of _textual substitution_. In our discussion, we will use the notation <tt>e[x := t]</tt> to denote the textual substitution of <tt>t</tt> for all free occurrences of <tt>x</tt> within <tt>e</tt>. For example, <tt>(succ x)[x:=1]</tt> is <tt>(succ 1)</tt>. Write an SML function <tt>subst</tt> that takes a <tt>term e</tt>, a <tt>string x</tt> representing an identifier, and a <tt>term t</tt>, and returns <tt>e</tt> with all free occurrences of <tt>x</tt> (actually <tt>AST_ID x</tt>) replaced by <tt>t</tt>. For example,

<pre>  - subst (AST_APP (AST_SUCC,AST_ID "x")) "x" (AST_NUM 1);
  val it = AST_APP (AST_SUCC,AST_NUM 1) : term
</pre>

Do _not_ substitute for _bound_ occurrences of identifiers. For instance, substituting <tt>3</tt> for <tt>x</tt> in

<pre>  ((fn x => succ x) (pred x))
</pre>

should result in <tt>((fn x => succ x) (pred 3))</tt>; the formal parameter <tt>x</tt> and its occurrences in the function body should not be affected by the substitution.

_Hint_: Just as in **Part a**, use pattern-matching on each constructor of the abstract syntax tree, calling <tt>subst</tt> recursively when you need to.

**Part c.** Using your substitution function, extend your <tt>interp</tt> function from **Part a** to include <tt>AST_FUN</tt> terms. The evaluation of terms involving <tt>AST_FUN</tt> should be done according to the rules given below.

Just like the built-in functions (<tt>succ</tt>, <tt>pred</tt>, and <tt>iszero</tt>), functions defined using <tt>fn</tt> evaluate to themselves:

<pre> (10)    (fn x => e) => (fn x => e)	  
</pre>

Computations occur when you _apply_ these functions to arguments. The following rule defines _call-by-value_ (or _eager_) function application, also used by SML: if the function is of the form <tt>fn x => e</tt>, evaluate the operand to a value <tt>v1</tt>, substitute <tt>v1</tt> in for the formal parameter <tt>x</tt> in <tt>e</tt>, and then evaluate the modified body:

<pre>            e1 => (fn x => e)      e2 => v1    e[x:=v1] => v
 (11)    --------------------------------------------------------
                              e1 e2 => v
</pre>

For instance, in evaluating the application

<pre>  ((fn x => succ x) (succ 0))
</pre>

we first note that the function is already fully evaluated, so we evaluate <tt>(succ 0)</tt> to <tt>1</tt>, and then plug this in for <tt>x</tt> in the body, <tt>succ x</tt>, of the function, obtaining <tt>succ 1</tt>, which evaluates to <tt>2</tt>.

Notice that while terms of the form <tt>AST_ID s</tt> can appear whenever <tt>s</tt> is a formal parameter, we never need to _evaluate_ such terms, because they are always replaced by the <tt>subst</tt> function before we evaluate the function body.

Any <tt>AST_ID s</tt> term that _does_ remain in the function body at the time of evaluation represents an _unbound identifier_; your interpreter should return an <tt>AST_ERROR</tt> term in this case.

**Part d.** Surprisingly enough, evaluating recursive terms turns out to be quite easy. First let's talk about what a term of the form <tt>rec x => e</tt> actually means. It corresponds to the definition of a recursive function called <tt>x</tt>. Let's work with an example. The term

<pre>  rec sum => fn x => fn y => if iszero x then y else sum (pred x) (succ y)
</pre>

corresponds to the following recursive SML function declaration

<pre>  fun sum x y = if x = 0 then y else sum (x - 1) (y + 1)
</pre>

Thus, in <tt>rec x => e</tt>, we see that <tt>x</tt> is the name of the recursive function and <tt>e</tt> (which should be a <tt>fn</tt> term) gives the parameters and body of the function.

The rule for evaluating a recursive term is amazingly simple. Just evaluate the body of the term, where all occurrences of the recursively defined identifier are replaced by the entire <tt>rec</tt> term.

<pre>                  e[x:=(rec x => e)] => v
 (12)            --------------------------
                    (rec x => e) => v
</pre>

It turns out that this is all that is needed to make recursion work!

_Notes:_

2.  While this program is broken up into four parts in order to help you make progress through it, you should just turn in a single <tt>interp</tt> function that interprets the entire PCF language. (But don't forget to turn in <tt>subst</tt> as well.)
3.  The parser actually parses a slightly richer language than I've presented here. In particular, it extends the BNF for PCF shown above above with the rule

    <pre>   e ::= let x = e in e end
    </pre>

    allowing <tt>let</tt> expressions as in SML. For example,

    <pre>   let z = 2 in succ z end
    </pre>

    is allowed by the parser.

    Rather than creating an <tt>AST_LET</tt> term for such expressions (which would require more code in the interpreter), the parser treats <tt>let</tt> expressions as _syntactic sugar_. In particular, the parser treats

    <pre>  let x = e1 in e2 end
    </pre>

    as if it were

    <pre>  (fn x => e2) e1
    </pre>

    Thus the example above will be parsed as

    <pre>   AST_APP (AST_FUN ("z",AST_APP (AST_SUCC,AST_ID "z")),AST_NUM 2)
    </pre>

    A bit of thought should convince you that this function application has exactly the same meaning as the <tt>let</tt> expression. Thus you may use let clauses in creating examples to test your interpreter, without having to write any new interpreter code.

    Also, the parser allows PCF programs to contain comments, which begin with the character <tt>#</tt> and extend to the end of the current line.

4.  Here is a skeleton file to help you to get started: [interp1.sml](interp1.sml). And here are some sample PCF programs for you to try out: [twice.pcf](twice.pcf), [minus.pcf](minus.pcf), [factorial.pcf](factorial.pcf), [fibonacci.pcf](fibonacci.pcf), and [lists.pcf](lists.pcf). These files are also available from my directory <tt>~smithg</tt>.

* * *

Back to

*   [COP 4555 home page](http://www.cs.fiu.edu/~smithg/cop4555/)
*   [Geoffrey Smith's home page](http://www.cs.fiu.edu/~smithg/)

<address>[smithg@cs.fiu.edu](mailto:smithg@cs.fiu.edu)</address>