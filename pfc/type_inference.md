# COP 4555 - Homework 6

## Due Wednesday, April 20

## Type Inference for PCF

Your PCF interpreter does not do any static typechecking of PCF programs. Instead, your interpreter treats PCF as a _dynamically typed language_, which means that it checks _at runtime_ whether the operands of each operation are of the appropriate type. For example, the program

<pre>  (fn b => if b then 5 else succ true) true
</pre>

is accepted by the interpreter, producing result <tt>AST_NUM 5</tt>, while the program

<pre>  (fn b => if b then 5 else succ true) false
</pre>

fails at runtime with a message like <tt>"succ needs an integer argument"</tt>.

In this homework, we will make PCF into a _statically typed language_ by developing a program to do _type inference_ for PCF programs. As in SML, type inference will be done using _unification_.

We begin by giving the type system for PCF that we wish to enforce. First of all, we will use the following set of types:

<pre>  t ::= 'a | int | bool | t -> t | (t)
</pre>

Here <tt>'a</tt> is a _type variable_, used for polymorphic types. As in SML, we'll assume that <tt>-></tt> associates to the right. These types will be represented as the following SML datatype:

<pre>  datatype typ = VAR of string | INT | BOOL | ARROW of typ * typ
</pre>

Typing is done with respect to an _environment_ <tt>E</tt>, which is a mapping from identifiers to types; the environment gives the types of any free identifiers in the expression. Thus the form of _typing judgment_ that we use is

<pre>  E |- e : t
</pre>

which can be read "from environment <tt>E</tt>, it follows that expression <tt>e</tt> has type <tt>t</tt>".

Next we describe the actual typing rules. Here's the rule for typing identifiers:

<pre>      	      E(x) = t
  (ID)        ----------
              E |- x : t
</pre>

And here are the rules for integer literals and booleans:

<pre>  (NUM)       E |- n : int

  (BOOL)      E |- true : bool

	      E |- false : bool
</pre>

Here are the rules for the built-in operators:

<pre>  (BASE)      E |- succ : int -> int

	      E |- pred : int -> int

	      E |- iszero : int -> bool
</pre>

Next we have the rule for <tt>if-then-else</tt>:

<pre>      	      E |- e1 : bool  E |- e2 : t  E |- e3 : t
  (IF)        ----------------------------------------
              E |- if e1 then e2 else e3 : t
</pre>

Notice that this rule requires both branches of the <tt>if-then-else</tt> to have the same type.

Now we come to the rules for functions.

<pre>      	      E[x : t1] |- e : t2
  (-> INTRO)  -------------------------
              E |- fn x => e : t1 -> t2
</pre>

The <tt>(-> INTRO)</tt> rule uses the notation <tt>E[x : t1]</tt> to denote an _updated environment_ that is the same as <tt>E</tt> except that it maps <tt>x</tt> to <tt>t1</tt>. What this rule says, intuitively, is that if <tt>e</tt> has type <tt>t2</tt> under the assumption that <tt>x</tt> has type <tt>t1</tt>, then <tt>fn x => e</tt> has type <tt>t1 -> t2</tt> without that assumption.

Here's the rule for function application:

<pre>      	      E |- e1 : t1 -> t2  E |- e2 : t1
  (-> ELIM)   --------------------------------
              E |- e1 e2 : t2
</pre>

(Notice that, if we focus only on the types, this rule is just the rule of logic known as _modus ponens_.)

Finally we have the rule for recursive terms:

<pre>      	      E[x : t] |- e : t
  (REC)       -------------------
              E |- rec x => e : t
</pre>

If we remember that <tt>rec x => e</tt> defines a recursive function called <tt>x</tt> with definition <tt>e</tt>, then it makes sense to require <tt>x</tt> and <tt>e</tt> to have the same type.

It can be shown that these typing rules are _sound_ in following sense: if <tt>e</tt> is a PCF program that is well typed under these rules, then <tt>e</tt> is guaranteed not to have any runtime type errors. More precisely, if <tt>e</tt> is well typed, then <tt>interp e</tt> never returns <tt>AST_ERROR s</tt>; it either successfully returns a value, or fails to terminate.

Here's an example typing derivation; we will derive the following typing for the <tt>twice</tt> function:

<pre>  [] |- fn f => fn x => f (f x) : ('a -> 'a) -> 'a -> 'a
</pre>

(Note that <tt>[]</tt> denotes the _empty environment_.) By rule (ID), we have

<pre>(1)  [f : 'a -> 'a, x : 'a] |- f : 'a -> 'a
</pre>

and

<pre>(2)  [f : 'a -> 'a, x : 'a] |- x : 'a
</pre>

Hence by rule <tt>(-> ELIM)</tt> on <tt>(1)</tt> and <tt>(2)</tt> we have

<pre>(3)  [f : 'a -> 'a, x : 'a] |- f x : 'a
</pre>

Then by rule <tt>(-> ELIM)</tt> on <tt>(1)</tt> and <tt>(3)</tt> we have

<pre>(4)  [f : 'a -> 'a, x : 'a] |- f (f x) : 'a
</pre>

Now by rule <tt>(-> INTRO)</tt> on <tt>(4)</tt> we get

<pre>(5)  [f : 'a -> 'a] |- fn x => f (f x) : 'a -> 'a
</pre>

Finally, by rule <tt>(-> INTRO)</tt> on <tt>(5)</tt> we get

<pre>(6)  [] |- fn f => fn x => f (f x) : ('a -> 'a) -> 'a -> 'a
</pre>

Now we turn to the question of _type inference_. Given an environment <tt>E</tt> and a PCF expression <tt>e</tt>, how can we infer a _principal type_ for <tt>e</tt>? For most of the typing rules, this is pretty straightforward---for example, <tt>(ID)</tt> says that we just look up the type of an identifier in the environment, and <tt>(NUM)</tt> says that the type of an integer literal is <tt>int</tt>. But <tt>(-> INTRO)</tt> is different. It says that to find the type of <tt>fn x => e</tt> in environment <tt>E</tt>, we first need to find the type of <tt>e</tt> in the updated environment <tt>E[x : t1]</tt>. But how do we know what <tt>t1</tt> should be?

The answer is that we don't. So what we do in typing <tt>fn x => e</tt> is to update the environment with the assumption <tt>x : 'a</tt>, where <tt>'a</tt> is a new type variable, and then try to find a type for <tt>e</tt>. But in the process of typing <tt>e</tt>, we may discover that <tt>'a</tt> needs to be _refined_ to some more specific type, such as <tt>bool -> 'b</tt>. (For example, we would make this refinement if <tt>e</tt> contained the application <tt>x true</tt>.) Hence our type inference algorithm will return not just a type, but also a _substitution_ (which maps types to types) that reflects any of these discovered refinements. These substitutions are deduced by using an algorithm known as _unification_. In the example above, we initially assume that the type of <tt>x</tt> is <tt>'a</tt>. If we see an application <tt>x true</tt>, then we know that the type of <tt>x</tt> must be of the form <tt>bool -> 'b</tt>, where <tt>'b</tt> is a new type variable. So what we do is to call <tt>unify('a, bool -> 'b)</tt>; this returns the _most general substitution_ that makes these two types the same. (It raises an exception if no such substitution exists.)

This approach to type inference leads to an algorithm known in the literature as algorithm <tt>W</tt>. This algorithm was published by Robin Milner in 1978, but it is now usually credited also to Roger Hindley. As indicated above, algorithm <tt>W</tt> takes as input an environment <tt>E</tt> and an expression <tt>e</tt>, and produces as output a substitution <tt>s</tt> and a type <tt>t</tt>, where <tt>s</tt> includes any refinements that need to be made to <tt>E</tt> in order for <tt>e</tt> to be well typed.

For example, <tt>W([x : 'a], x true)</tt> returns <tt>(['a := bool -> 'b], 'b)</tt>. This tells us that we need to refine the environment <tt>E</tt> to <tt>[x : bool -> 'b]</tt> in order for <tt>x true</tt> to be well typed:

<pre>  [x : bool -> 'b] |- x true : 'b
</pre>

Formally, the soundness of algorithm <tt>W</tt> can be specified as follows: if <tt>W(E,e)</tt> returns <tt>(s,t)</tt>, then

<pre>  s o E |- e : t
</pre>

(Note that <tt>s o E</tt> denotes the _composition_ of <tt>s</tt> and <tt>E</tt>; since <tt>E</tt> maps identifiers to types and <tt>s</tt> maps types to types, the composition maps identifiers to types, as an environment should.)

Your job is to implement algorithm <tt>W</tt> in SML. To do this, you first need an implementation of environments and substitutions. A particularly simple and elegant approach is to represent environments as SML functions of type <tt>string -> typ</tt>, and substitutions as SML functions of type <tt>typ -> typ</tt>; with this representation, algorithm <tt>W</tt> can be coded quite cleanly. To help you get started, here is the implementation of algorithm <tt>W</tt> on <tt>if e1 then e2 else e3</tt>:

<pre>  fun W (E, AST_IF (e1, e2, e3)) =
    let val (s1, t1) = W (E, e1)
        val s2 = unify(t1, BOOL)
        val (s3, t2) = W (s2 o s1 o E, e2)
        val (s4, t3) = W (s3 o s2 o s1 o E, e3)
        val s5 = unify(s4 t2, t3)
    in
      (s5 o s4 o s3 o s2 o s1, s5 t3)
    end
</pre>

Study this code carefully, referring to rule <tt>(IF)</tt>. We first recursively find the type of <tt>e1</tt>, and then unify this type with <tt>bool</tt>. We then find the types of <tt>e2</tt> and <tt>e3</tt>, and then unify these two types. Notice that as we go along, we constantly refine the environment <tt>E</tt> with any instantiations discovered so far. (An example that illustrates the importance of doing this is <tt>fn x => if x then pred x else x</tt>. When we see <tt>x</tt> used as the guard of an <tt>if</tt>, we refine its type from <tt>'a</tt> to <tt>bool</tt>, which then makes <tt>pred x</tt> ill typed.) In the end, we compose together all these instantiations and return them, along with the final type.

Here is a skeleton file to help you with this assignment: [type.sml](type.sml). (It is also available from my directory <tt>~smithg</tt>.) The skeleton file includes quite a bit of SML code that you will find useful. In particular, I have included the <tt>unify</tt> function, a <tt>newtypevar</tt> function that lets you generate a new type variable whenever you need one, a <tt>typ2str</tt> function to convert a <tt>typ</tt> to a <tt>string</tt>, along with code for substitutions and environments. I encourage you to study the implementation of <tt>unify</tt>; unification is an important algorithm with many applications aside from type inference. (For example, unification is used crucially in the execution of the logic programming language Prolog.) Here's an example of what <tt>unify</tt> does. If we call <tt>unify</tt> on <tt>'a -> (int -> 'b)</tt> and <tt>('c -> bool) -> 'a</tt>, it returns a substitution that maps <tt>'a</tt> to <tt>int -> bool</tt>, <tt>'b</tt> to <tt>bool</tt>, and <tt>'c</tt> to <tt>int</tt>; thus the two types are unified to <tt>(int -> bool) -> (int -> bool)</tt>.

<pre>  - val t1=ARROW(VAR "a", ARROW(INT, VAR "b"));
  val t1 = ARROW (VAR "a",ARROW (INT,VAR "b")) : typ
  - val t2=ARROW(ARROW(VAR "c", BOOL), VAR "a");
  val t2 = ARROW (ARROW (VAR "c",BOOL),VAR "a") : typ
  - val s = unify(t1,t2);
  val s = fn : typ -> typ
  - s t1;
  val it = ARROW (ARROW (INT,BOOL),ARROW (INT,BOOL)) : typ
  - typ2str it;
  val it = "(int -> bool) -> int -> bool" : string
</pre>

Once you have completed the implementation of algorithm <tt>W</tt>, you should try it out on a variety of PCF programs to see what types are inferred. Here are some interesting PCF programs to try:

*   <tt>fn f => fn x => f (f x)</tt>
*   <tt>fn f => fn g => fn x => f (g x)</tt>
*   <tt>fn b => if b then 1 else 0</tt>
*   <tt>rec f => fn b => if b then 1 else f true</tt>
*   <tt>rec f => fn x => f x</tt>
*   <pre>rec m => fn x => fn y => if iszero y then x
    			 else m (pred x) (pred y)
    </pre>

*   <pre>rec even => fn n => if iszero n then true
    		    else if iszero (pred n) then false
    		    else even (pred (pred n))
    </pre>

In addition, you should try doing type inference on the sample PCF programs from HW5. But note that your type inference program may reject some of these! One cause of this is that we are treating <tt>let</tt> as syntactic sugar, which means that

<pre>  let
    twice = fn f => fn x => f (f x)
  in
    twice twice twice succ 0
  end
</pre>

is treated as

<pre>  (fn twice => twice twice twice succ 0) (fn f => fn x => f (f x)).
</pre>

But our type system will not allow <tt>twice</tt> to be used polymorphically within

<pre>  (fn twice => twice twice twice succ 0),
</pre>

so the program is rejected. (In the actual SML type system, a <tt>let</tt>-bound identifier like <tt>twice</tt> can be given a _universally quantified_ type, so that it can be used polymorphically within the body of the <tt>let</tt>.)

But even with the polymorphic <tt>let</tt>, there are still sensible programs (such as [lists.pcf](lists.pcf)) that are rejected by the type system. This fact has spurred a great deal of research into more powerful, less restrictive type systems.

Finally, you will note that your implementation of algorithm <tt>W</tt> gives terrible error messages---when it rejects a PCF program, it raises an exception that gives almost no clue about _what_ is wrong with the program and _where_ the error is located. For extra credit, you may wish to try to enhance algorithm <tt>W</tt> to give decent error messages.

* * *

Back to

*   [COP 4555 home page](http://www.cs.fiu.edu/~smithg/cop4555/)
*   [Geoffrey Smith's home page](http://www.cs.fiu.edu/~smithg/)

<address>[smithg@cs.fiu.edu](mailto:smithg@cs.fiu.edu)</address>