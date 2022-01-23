# Decorated

A D implementation of Python's decorators.

## Decorators

Python's decorators are neat tool that allows modifying the behavior of a function
without needing to do a major refactor. Of course that in Python this is even easier
due to the fact that it is a dynamically typed language. The essence of a decorator
is to *wrap* a function in another function in order to extend it's functionality.

```python
def hello(fun):
    def wrapper():
        print "hello"
        fun()
    return wrapper

@hello
def userFun():
    print "world"

userFun()
```

output:

```
hello
world
```

This simple example demonstrates the principle of a decorator. It's simply just
sytax sugar for function calls in python (similar to what we have with UFCS) but
attached to a function. The previous example would result in the following code:

```python
def hello(fun):
    def wrapper():
        print "hello"
        fun()
    return wrapper

def userFun():
    print "world"

userFun = hello(userFun)

userFun()
```

As you can the decorator unfolds into a sequence of calls and assigns the result
to the decorated function it was attached to.

## Reason

D is a very powerful language, and it's meta programming is off the charts. However,
it still suffers a bit from refactoring. I wanted to improve that a bit. I know
that it won't be **nearly** as powerful as something like this is in Pyhton, but
if it helps users to extend and add functionality to their code without changing
to much of their code base, then it's a win to my eyes.

I wanted something that was powerful, pleasant to look at, easy to read and easy
to add to existing code without much breakage. Yes, that may be wanting to much,
but I think I came up with a reasonable solution.

## D way

In D we cannot have such a simple way of doing this due to the fact of it being
a statically typed language, however, we can accomplish a very similar approach.
In D we have what it's called a [UDA](https://dlang.org/spec/attribute.html#uda).
Keeping it short, they are not the same thing as Python's decorators, but they
allow to give extra meaning to a declaration.

Lets start with the example above. You have the existent code:

```d
void userFun()
{
    "World".writeln;
}
```

And now you need to add functionality to your function. Instead of changing the
core implementation, you would have something like this:

```d
void hello(Fun)(Fun fun)
{
    return ()
    {
        "Hello".writeln;
        fun();
    };
}
```

And changing the behavior of your original function would just require a little
amount of refactoring

```d
import decorated;
import std.stdio : writeln;

void hello(Fun)(Fun fun)
{
    return ()
    {
        "Hello".writeln;
        fun();
    };
}

@hello
mixin decorated!("userFun",
{
    "World".writeln;
});

void main()
{
    userFun(); // executes the same way
}
```

That's it! Easy right? This would output:

```
Hello
World
```

Just as we wanted!

---

## Examples

### Caching an expensive function

```d
import decorated;

// just to quickly examplify, you can create your own cache method
auto cache(Fun)(Fun fun)
{
    import std.functional : memoize;
    alias mem = memoize!fun;
    return &mem;
}

// works with parameters as well
@cache
void expensive(size_t n)
{
    import std.stdio : writeln;
    // expensive algorithm...
    return n;
}

void main()
{
    expensive(5).writeln();
    expensive(5).writeln();
}
```

output:

```
expensive algorithm...
5
5
```

### Decorators with parameters

```d
// unfortunately this one must have a templated argument for the function type
auto favColor(Fun)(string color)
{
    return (Fun fun)
    {
        return ()
        {
            import std.stdio : writefln;
            color.writefln!"favorite color: %s";
            func();
        };
    };
}

auto invicible(Fun)(Fun fun)
{
    return ()
    {
        import std.stdio : writeln;
        "invicible".writeln;
        func();
    };
}

@invicible
@decor!(favColor, "black") // helper UDA for functions with arguments
mixin decorated!("blackKnight",
{
    "black knight".writeln;
});

void main()
{
    blackKnight();
}
```

output:

```
invicible
favorite color: black
black knight
```

---

## Contributions

If you enjoy, see potential, any issues or have ideas on how to improve this project
please raise an issue or PR! Those are always accepted.