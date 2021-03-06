module decorated;

import std.traits : isCallable;

private enum isDecoratedName(string str) = {
    import std.ascii : isDigit;
    import std.uni : isAlpha;

    alias alpha = (in dchar c) => c == '_' || isAlpha(c);
    alias alphanum = (in dchar c) => alpha(c) || isDigit(c);

    if (!str.length || isDigit(str[0])) return false;

    foreach (dchar dc; str) if (!alphanum(dc)) return false;

    return true;
} ();
private enum isDecoratedFun(alias smb) = isCallable!smb || __traits(isTemplate, smb);

struct decor(alias fun, args...) if(isDecoratedFun!fun) {}

mixin template decorated(string name, alias fun)
    if (isDecoratedName!name && isDecoratedFun!fun)
{
    auto _internal_helper_(Args...)(Args args)
    {
        auto impl(attrs...)()
        {
            static if (attrs.length)
            {
                alias next = impl!(attrs[1..$]);
                static if (is(attrs[0] : decor!Args, Args...))
                {
                    static if (__traits(isTemplate, Args[0]))
                    {
                        import std.meta : Instantiate;
                        import std.traits : ReturnType;
                        alias call = Instantiate!(Args[0], ReturnType!next);

                        static if (Args.length > 1)
                            return call(Args[1..$])(next);
                        else
                            return call(next);
                    }
                    else
                    {
                        static if (Args.length > 1)
                            return Args[0](Args[1..$])(next);
                        else
                            return Args[0](next);
                    }
                }
                else return attrs[0](next);
            }
            else
            {
                // if it's a lambda we must return 'fun'
                static if (__traits(compiles, { return &fun; }))
                    return &fun;
                else
                    return fun;
            }
        }

        auto call = impl!(__traits(getAttributes, _internal_helper_))();
        static if (isCallable!(typeof(call)))
        {
            import std.traits : ParameterDefaults;
            static if (args.length)
            {
                import core.lifetime : forward;
                return call(forward!args, ParameterDefaults!fun[args.length .. $]);
            }
            else return call(ParameterDefaults!fun);
        }
        else return call;
    }

    mixin("alias "~name~" = _internal_helper_;");
}

@safe pure nothrow unittest
{
    auto myMap(F)(F f)
    {
        import std.algorithm : map;
        return f().map!"a + 1";
    }

    // https://issues.dlang.org/show_bug.cgi?id=22694
    struct S {
        import std.algorithm : filter, sum;

        @sum
        @filter!"a & 1"
        @myMap
        mixin decorated!("foo",
        {
            import std.range : iota;
            import std.array : array;
            return 10.iota.array;
        });
    }

    with (S.init)
    {
        assert(foo() == 25);
    }
}

@safe pure nothrow unittest
{
    auto hello(F)(F f)
    {
        return () {
            return "Hello "~f();
        };
    }

    auto say(T)(string text)
    {
        return (T t) {
            return () {
                return text~" "~t();
            };
        };
    }

    // https://issues.dlang.org/show_bug.cgi?id=22694
    struct S
    {
        @hello
        mixin decorated!("foo",
        {
            import std.stdio : writeln;
            return "Decorated";
        });

        @decor!(say, "D rox:")
        @hello
        mixin decorated!("bar",
        {
            return "Decorated";
        });

        auto oldBaz() { return "Decorated"; }
        @decor!(say, "D rox:")
        @hello
        mixin decorated!("baz", oldBaz);
    }

    with (S.init)
    {
        assert(foo() == "Hello Decorated");
        assert(bar() == "D rox: Hello Decorated");
        assert(baz() == "D rox: Hello Decorated");
    }
}

@safe nothrow unittest
{
    auto cache(F)(F f)
    {
        import std.functional : memoize;
        alias mem = memoize!f;
        return &mem;
    }

    // https://issues.dlang.org/show_bug.cgi?id=22694
    struct S
    {
        static size_t expensive; // simulates an expensive algorithm

        @cache
        mixin decorated!("cached", (size_t n = 1)
        {
            expensive++; // simulates an expensive algorithm
            return expensive;
        });
    }

    with (S.init)
    {
        // runs expensive stuff
        assert(cached(46) == 1);
        assert(cached(45) == 2);

        // skips the expensive stuff
        assert(cached(46) == 1);
        assert(cached(45) == 2);

        // can be used with default arguments
        assert(cached() == 3);
    }
}
