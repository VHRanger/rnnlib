module source.Parameters;

import std.algorithm;
import std.complex;
import std.math;
import std.datetime;
import std.random;


import source.Matrix;

abstract class Parameter {
    static private bool init = true;
    static protected auto rnd = Random(0);

    this()
    {
        if (init) {
            rnd = Random(cast(uint) ((Clock.currTime()
                         - SysTime(unixTimeToStdTime(0))).total!"msecs"));
            init = false;
        }
    }
}

class Vector(S, T) : Parameter {
    T[] v;

    static if (T.stringof.startsWith("Complex"))
        mixin("alias Tc = "~(T.stringof[8 .. $])~";");
    else alias Tc = T;

    /// Simple constructor.
    this(S length)
    {
        v = new T[length];
    }
 
    /// Random constructor.
    this(S length, Tc randomBound)
    {
        this(length);

        static if (T.stringof.startsWith("Complex")) {
            foreach(i;0 .. v.length)
                v[i] = complex(uniform(-randomBound, randomBound, rnd),
                               uniform(-randomBound, randomBound, rnd));
        }
        else {
            foreach(i;0 .. v.length)
               v[i] = uniform(-randomBound, randomBound, rnd);
        }
    }

    /// Copy-constructor
    this(in Vector dupl)
    {
        this(dupl.length);
        v = dupl.v.dup;
    }

    /// Constructor from list
    this(in T[] valarr)
    {
        this(cast(S) valarr.length);
        v = valarr.dup;
    }


    final const
    @property @safe @nogc 
    S length() {return cast(S) v.length;}

    /// Assign value by index.
    void opIndexAssign(T value, S i)
    {
        v[i] = value;
    }

    /// Return value by index.
    const T opIndex(S i)
    {
        return v[i];
    }
   
    /// Simple math operation without memory allocation.
    void opOpAssign(string op)(in Vector u)
    {
        static if (op == "+") { v[] += u.v[]; }
        else static if (op == "-") { v[] -= u.v[]; }
        else static if (op == "*") { v[] *= u.v[]; }
        else static if (op == "/") { v[] /= u.v[]; }
        else static assert(0, "Operator "~op~" not implemented.");
    }

    /// Return the sum of all the elements in the vector.
    @property const
    T sum() {return v.sum;}

    /// Return a duplicate of the vector.
    @property const
    auto dup()
    {
        auto res = new Vector(length);
        foreach(i;0 .. v.length)
            res.v[i] = v[i];

        return res;
    }

    /// Return the dot product of the vector with u.
    const
    T dot(in Vector u)
    {return this.dot(u.v);}
    
    // TODO intel intrinsics ?
    // std.math.fma
    const
    T dot(in T[] u)
    {
        T s = 0;
        foreach(i; 0 .. length)
            s = u[i]*v[i] + s;
        return s;
    }

    /+ Return the norm of the vector using a specific
     + method in [L0, L1, L2, Linf, min].
     +/
    @property const
    auto norm(string method)()
    {
        // TODO Refactor
        // This is a hackish solution to get a zero of the
        // type in the complex number.
        static if (T.stringof.startsWith("Complex")) {
            auto s = v[0].re*0.0f;
        }
        else {
            auto s = v[0]*0.0f;
        }
        static if (method=="euclidean" || method=="L2")
        {
            foreach(e;v)
                s += pow(e.abs, 2);
            return sqrt(s);
        }
        else static if (method=="manhattan" || method=="L1") 
        {
            foreach(e;v)
                s += e.abs;
            return s;
        }
        else static if (method=="sparse" || method=="L0")
        {
            foreach(i;v)
                if (i != 0)
                    s += 1;
            return s;
        }
        else static if (method=="max" || method=="Linf")
        {
            s = v[0].abs;
            foreach(e;v)
                if(s < e.abs)
                    s = e.abs;
            return s;
        }
        else static if (method=="min")
        {
            s = v[0].abs;
            foreach(e;v)
                if(s > e.abs)
                    s = e.abs;
            return s;
        }
        else static assert(0, "Method '"~method~"' is not implemented.");
    }

    void opOpAssign(string op)(in Matrix!(S,T) M)
    if (op == "*")
    {
        this.v = M * this;
    }

    void opOpAssign(string op)(in DiagonalMatrix!(S,T) M)
    if (op == "*") { v[] *= M.mat[]; }

    void opOpAssign(string op)(in PermutationMatrix!(S,T) M)
    if (op == "*") 
    {
        auto tmpvec = this.dup;
        foreach(i; 0 .. length)
            v[i] = tmpvec[M.permute(i)];
    }

    void opOpAssign(string op)(in ReflectionMatrix!(S,T) M)
    if (op == "*") 
    {
        auto s = this.conjdot(M.vec);
        auto tmp = M.vec.dup;
        tmp *= M.invSqNormVec2*s;
        this += tmp;
    }

    void opOpAssign(string op)(in FourierMatrix!(S,T) F)
    {
        static if (!T.stringof.startsWith("Complex"))
            assert(0, "Fourier transform can only be applied to complex"
                      ~"vector as this is what it'll return.");
        
        static if (op=="*") v = F.objFFT.fft(v);
        else static if (op=="/") v = F.objFFT.inverseFft(v);
        else static assert(0, "Operator "~op~" not implemented.");
    }

    void opOpAssign(string op)(in T scalar)
    if (op == "*") 
    {
        foreach(i; 0 .. length)
            v[i] *= scalar;
    }

    const
    T conjdot(in Vector u)
    {return this.conjdot(u.v);}
    const
    T conjdot(in T[] u)
    {
        static if (T.stringof.startsWith("Complex")) {
            T s = complex(0);
            foreach(i; 0 .. length)
                s += v[i]*u[i].conj;
            return s;
        }
        else {
            return this.dot(u);
        }
    }

    // This fonction allow us to compute the conjugate dot
    // with a simple array. 
    const
    T conjdot(in T[] u, in Vector vtmp)
    {
        static if (T.stringof.startsWith("Complex")) {
            T s = complex(0);
            foreach(i; 0 .. length)
                s += u[i]*vtmp[i].conj;
            return s;
        }
        else {
            return vtmp.dot(u);
        }
    }

    void conjmult(in Vector u)
    {return this.conjmult(u.v);}
    void conjmult(in T[] u)
    {
        static if (T.stringof.startsWith("Complex")) {
            foreach(i; 0 .. u.length)
                v[i] *= u[i].conj;
        }
        else {
            this.v[] *= u[];
        }
    }
}
unittest
{
  import std.stdio : write;
  write("Unittest Vector ... ");

  foreach(____;0 .. 10){

    alias Vectoruf = Vector!(uint, float);
    {
        Vectoruf v = new Vectoruf([1.0f, 2.0f, 1000.0f]);
        v[2] = 3.75f;

        Vectoruf u = new Vectoruf(v);
        u[0] = 1.25f;

        assert(v.length == 3, "1");
        assert(u.length == 3, "2");
        assert(v.sum == 6.75f, "3");
        assert(u.sum == 7.0f, "4");
        assert(u.dot(v) == v.dot(u), "5");
        assert(u.dot(v) == 19.3125f, "6");

        auto w = u.dup;
        
        w -= u;
        assert(w.sum == 0.0f, "7");
        assert(w[2] == 0.0f, "8");

        w += v;
        assert(w.sum == v.sum, "9");
        assert(w[1] == v[1], "10");

        v /= w;
        assert(v.sum == 3.0f, "11");
        assert(v[0] == 1.0f, "12");

        v *= u;
        assert(v.sum == u.sum, "13");
        assert(v[1] == u[1], "14");

        u -= v;
        assert(u.sum == 0.0f, "15");
        assert(u[2] == 0.0f, "16");

        // u=0
        // v=u
        // w=v

        assert(v.sum == v.norm!"L1");
        assert(std.math.abs(std.math.sqrt(w.dot(w)) - w.norm!"L2") < 0.0001);
        assert(v.norm!"Linf" == 3.75f);
        u[0] = 9;
        assert(u.norm!"L0" == 1);
    }

    import std.complex : abs;
    {
        // The following test work every time if and only if
        // the period of the random number generator is odd.
        // It is the case with the one used here: Mersenne twister.
        auto vc = new Vector!(uint, Complex!real)(3, 10.5f);
        auto uc = new Vector!(uint, Complex!real)(3, 10.5f);
        auto vc1 = new Vector!(uint, Complex!real)(vc);
        auto uc1 = new Vector!(uint, Complex!real)(uc);

        vc -= uc;
        assert(vc.norm!"Linf" != complex(0));
        vc += uc;
        vc.conjmult(uc);
        Complex!real sc = complex(0.0,0.0);
        foreach(i; 0 .. vc1.length)
            sc += vc1[i]*uc1[i].conj;
        sc -= vc.sum;
        assert(sc.abs < 0.00001);
        assert(std.complex.abs(uc1.conjdot(vc1) -
                               uc1.conjdot(uc1.v, vc1)) < 0.0001);
    }
    {
        auto vc = new Vector!(uint, real)(3, 10.5f);
        auto uc = new Vector!(uint, real)(3, 10.5f);
        auto vc1 = new Vector!(uint, real)(vc);
        auto uc1 = new Vector!(uint, real)(uc);

        vc -= uc;
        assert(vc.norm!"Linf" != complex(0));
        vc += uc;
        vc.conjmult(uc);
        real sc = 0.0;
        foreach(i; 0 .. vc1.length)
            sc += vc1[i]*uc1[i];
        sc -= vc.sum;
        assert(std.math.abs(sc) < 0.00001);

        assert(std.math.abs(vc1.conjdot(uc1) - uc1.dot(vc1)) < 0.01);
        assert(std.math.abs(vc1.conjdot(uc1) - uc1.conjdot(uc1.v, vc1)) < 0.01);
    }

    /// Test with matrix.

    // Diagonal.
    {
        alias Diag = DiagonalMatrix!(uint, float);
        auto m1 = new Diag(1_000, 1.0f);
        auto v2 = new Vectoruf(m1.mat);
        auto vr = new Vectoruf(1_000, 1000.0f);
        auto ur = new Vectoruf(vr);

        assert(vr.norm!"min" == ur.norm!"min");
        vr *= m1;
        assert(vr.norm!"L2" != ur.norm!"L2");
        ur *= v2;
        assert(vr.norm!"L2" == ur.norm!"L2");
        assert(vr.norm!"min" == ur.norm!"min");
        assert(vr.norm!"L1" == ur.norm!"L1");
    }

    // Permutation
    {
        alias Perm = PermutationMatrix!(uint, float);
        auto p = new Perm(1_000, 1);
        auto vp = new Vectoruf(1_000, 0.01f);
        auto vpcop = new Vectoruf(vp);
        vp *= p;
        assert(std.math.abs(vp.norm!"L1" - vpcop.norm!"L1") < 1);
        assert(std.math.abs(vp.norm!"Linf" - vpcop.norm!"Linf") < 1);
        assert(std.math.abs(vp.norm!"min" - vpcop.norm!"min") < 1);

        foreach(i; 0 .. vp.length)
            assert(vp[i] == vpcop[p.permute(i)]);
    }

    //Reflection
    {
        // Reflection are involution, so applying 2 times the matrix to a vector
        // should give that vector
        auto matr = new ReflectionMatrix!(size_t, Complex!real)(1_000, 1.0f);
        auto matu = new ReflectionMatrix!(size_t, Complex!real)(matr);
        //
        auto tmp = new Vector!(size_t, Complex!real)(matr.vec);
        tmp -= matu.vec;
        assert(tmp.norm!"L1" < 0.0001);

        auto v1 = new Vector!(size_t, Complex!real)(1_000, 1000.0f);
        auto w1 = new Vector!(size_t, Complex!real)(v1);
        //
        tmp = new Vector!(size_t, Complex!real)(v1);
        tmp -= w1;
        assert(tmp.norm!"L1" < 0.0001);


        v1 *= matr;
        v1 *= matu; // same as matr
        v1 -= w1; // w1 is the same as v1 before the change.

        assert(v1.norm!"L2" < 0.0001);
    }
    {
        auto matr = new ReflectionMatrix!(size_t, real)(1_000, 1.0f);
        auto matu = new ReflectionMatrix!(size_t, real)(matr);
        //
        auto tmp = new Vector!(size_t, real)(matr.vec);
        tmp -= matu.vec;
        assert(tmp.norm!"L1" < 0.0001);

        auto v1 = new Vector!(size_t, real)(1_000, 1000.0f);
        auto w1 = new Vector!(size_t, real)(v1);
        //
        tmp = new Vector!(size_t, real)(v1);
        tmp -= w1;
        assert(tmp.norm!"L1" < 0.0001);


        v1 *= matr;
        v1 *= matu; // same as matr
        v1 -= w1; // w1 is the same as v1 before the change.

        assert(v1.norm!"L2" < 0.0001);
    }

    // Fourier
    {
        alias Fourier = FourierMatrix!(size_t, Complex!double);
        auto f = new Fourier(pow(2, 11));
        auto v = new Vector!(size_t, Complex!double)(pow(2, 11), 1.0);

        auto vtmp = v.dup;
        v *= f;
        v /= f;
        v -= vtmp;
        assert(v.norm!"L2" < 0.01);
    }

    // General matrix
    {
        auto m = new Matrix!(ulong, float)(4, 4);
        m.mat = [1.0, 0.0, 0.0, 0.0,
                 0.0, 0.0, 2.0, 0.0,
                 0.0, 0.5, 0.0, 0.0,
                 0.0, 0.0, 0.0, 1.0];
        auto v = new Vector!(ulong, float)(4);
        v[0] = 38.50;
        v[1] = 13.64;
        v[2] = 90.01;
        v[3] = 27.42;

        auto w = v.dup;
        w *= m;
    }
  }
  write("Done.\n");
}

