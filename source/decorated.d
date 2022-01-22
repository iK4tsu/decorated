module decorated;

import std.traits : isCallable;

private enum isDecoratedName(string str) = __traits(compiles, { mixin("int "~str~";"); });
private enum isDecoratedFun(alias smb) = isCallable!smb || __traits(isTemplate, smb);

struct decor(alias fun, args...) if(isDecoratedFun!fun) {}

mixin template decorated(string name, alias fun)
    if (isDecoratedName!name && isDecoratedFun!fun)
{
    auto _internal_helper_()
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

        static if (isCallable!(typeof(impl!(__traits(getAttributes, _internal_helper_))())))
            return impl!(__traits(getAttributes, _internal_helper_))()();
        else
            return impl!(__traits(getAttributes, _internal_helper_))();
    }

    mixin("alias "~name~" = _internal_helper_;");
}

unittest
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

unittest
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

        @decor!(say, "D roks:")
        @hello
        mixin decorated!("bar",
        {
            return "Decorated";
        });

        auto oldBaz() { return "Decorated"; }
        @decor!(say, "D roks:")
        @hello
        mixin decorated!("baz", oldBaz);
    }

    with (S.init)
    {
        assert(foo() == "Hello Decorated");
        assert(bar() == "D roks: Hello Decorated");
        assert(baz() == "D roks: Hello Decorated");
    }
}