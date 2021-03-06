module source.Parameter;

import std.algorithm;
import std.complex;
import std.conv: to;
import std.exception: assertThrown, enforce;
import std.math;
import std.datetime;
import std.random;
import std.range: iota;
import std.string: split;


import source.Matrix;


version(unittest)
{
    import std.stdio : writeln, write;
    import std.datetime;
    import core.exception;
}

abstract class Parameter {
    static private bool init = true;
    static protected auto rnd = Random(0);

    pure  @safe
    this() {}

    @safe
    this(bool random=true)
    {
        if (init) {
            rnd = Random(cast(uint) ((Clock.currTime()
                         - SysTime(unixTimeToStdTime(0))).total!"msecs"));
            init = false;
        }
    }
}

/+  Vector class.
    This is a simple vector class that add utilities
    around an array.

    Args:
        T: Type of the element of the vector.
        S: Type of the indices. It should allow us
           to deploy small vector with small indices (e.g. ushort)
           which will be useful for memory optmization in some matrix
           multiplication (e.g. permutation).
 +/
class Vector(T) : Parameter {
    T[] v;

    static if (is(Complex!T : T))
        mixin("alias Tc = "~(T.stringof[8 .. $])~";");
    else alias Tc = T;

    /// Simple constructor.
    pure @safe
    this(size_t length)
    {
        v = new T[length];
    }
 
    /// Random constructor.
    @safe
    this(size_t length, Tc randomBound)
    {
        super(true);
        v = new T[length];

        if (randomBound < 0)
            throw new Exception("'randomBound' must be >= 0");
        if (randomBound.abs == 0) {
            foreach(i; length.iota) v[i] = to!(T)(0);
        }
        else {
            static if (is(Complex!T : T)) {
                foreach(i; length.iota)
                    v[i] = complex(uniform(-randomBound, randomBound, rnd),
                                   uniform(-randomBound, randomBound, rnd));
            }
            else {
                foreach(i; length.iota)
                   v[i] = uniform(-randomBound, randomBound, rnd);
            }
        }
    }

    /// Copy-constructor
    pure @safe
    this(in Vector dupl)
    {
        this(dupl.length);
        v = dupl.v.dup;
    }

    /// Constructor from list
    pure @safe
    this(in T[] valarr)
    {
        this(valarr.length);
        v = valarr.dup;
    }


    final const pure
    @property @safe @nogc 
    size_t length() {return v.length;}

    /// Assign value by index.
    pure @nogc @safe
    void opIndexAssign(T value, size_t i)
    {
        v[i] = value;
    }

    /// Return value by index.
    const pure @nogc @safe
    T opIndex(size_t i)
    {
        return v[i];
    }
   
    /// Simple math operation without memory allocation.
    pure @safe
    void opOpAssign(string op)(in Vector!T _v)
    {
        enforce(v.length == _v.length, "Vector-Vector Dimension Mismatch.");
        mixin("v[]"~op~"=_v.v[];");
    }

    /// Return the sum of all the elements in the vector.
    @property const pure @safe
    T sum() {return v.sum;}

    /// Return a duplicate of the vector.
    @property const pure @safe
    auto dup()
    {
        auto res = new Vector(length);
        foreach(i;0 .. v.length)
            res.v[i] = v[i];

        return res;
    }

    /// Return the dot product of the vector with u.
    const pure @safe
    T dot(in Vector u)
    {return this.dot(u.v);}
    
    // TODO: use general dot product in source.Matrix.d
    const pure @safe
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
    @property const @nogc pure @safe
    auto norm(string method)()
    {
        Tc s = v[0].re*0.0f;
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

    pure @safe
    void opOpAssign(string op)(in Matrix!T M)
    if (op == "*")
    {
        this.v = M * this.v;
    }

    pure @safe
    void opOpAssign(string op)(in DiagonalMatrix!T M)
    { 
        static if (op == "*")
        {
            v[] *= M.mat[]; 
        }
        else static if (op == "/")
        {
            v[] /= M.mat[]; 
        }
        else static assert(0, "Operator "~op~" not implemented.");
    }

    pure @safe
    void opOpAssign(string op)(in PermutationMatrix!T M)
    {
        static if (op == "*")
        {
            auto tmpvec = this.dup;
            foreach(i; 0 .. length)
                v[i] = tmpvec[M.permute(i)];
        }
        else static if (op == "/")
        {
            auto tmpvec = this.dup;
            foreach(i; 0 .. length)
                v[M.permute(i)] = tmpvec[i];
        }
        else static assert(0, "Operator "~op~" not implemented.");
    }

    pure @safe
    void opOpAssign(string op)(in ReflectionMatrix!T M)
    {
        static if (op != "*" && op != "/")
            assert(0, "Operator "~op~" not implemented.");
        auto s = this.conjdot(M.vec);
        auto tmp = M.vec.dup;
        tmp *= M.invSqNormVec2*s;
        this += tmp;
    }
    
    void opOpAssign(string op)(in MatrixAbstract!T M)
    {
        /+ This should only be used to handle Matrix that
           have a template definition which can only
           be created if the type is Complex.
           E.g. compiling the unitary matrix with T=real will
           give you compile-time error. 
         +/
        auto tmptypeId = split(M.typeId, "!")[0];
        if (tmptypeId == "UnitaryMatrix") {
            static if (is(Complex!T : T)) {
                auto mat = cast(UnitaryMatrix!T) M;
                static if (op == "*") 
                {
                    mat.applyDiagonal(v, 0);
                    
                    this *= mat.fourier;

                    mat.applyReflection(v, 0);
                    this *= mat.perm;
                    mat.applyDiagonal(v, 1);
                    
                    this /= mat.fourier;
                    
                    mat.applyReflection(v, 1);
                    mat.applyDiagonal(v, 2);
                }

                else static if (op == "/") 
                {
                    mat.applyDiagonalInv(v, 2);
                    mat.applyReflection(v, 1);

                    this *= mat.fourier;

                    mat.applyDiagonalInv(v, 1);
                    this /= mat.perm;
                    mat.applyReflection(v, 0);

                    this /= mat.fourier;

                    mat.applyDiagonalInv(v, 0);
                }
                else static assert(0, "Operator "~op~" not implemented.");
            }
            else {
                assert(0, "Unitary transform can only be applied to complex"
                  ~"vector as this is what it'll return.");
            }
        }
        else if (tmptypeId == "FourierMatrix") {
            static if (is(Complex!T : T)) {
                static if (!is(Complex!T : T))
                    assert(0, "Fourier transform can only be applied to complex"
                             ~"vector as this is what it'll return.");
        
                static if (op=="*")
                    v = (cast (FourierMatrix!T) M).objFFT.fft!(Tc)(v);
                else static if (op=="/")
                    v = (cast (FourierMatrix!T) M).objFFT.inverseFft!(Tc)(v);
                else static
                    assert(0, "Operator "~op~" not implemented.");
            }
            else {
                assert(0, "Fourier transform can only be applied to complex"
                  ~"vector as this is what it'll return.");
            }
        } 
    }
 
    void opOpAssign(string op)(in BlockMatrix!T M)
    {
        static if (op == "*") {
            T[] vec = M.P * v;

            size_t blocks_in = M.size_in / M.size_blocks;
            size_t blocks_out = M.size_out / M.size_blocks;

            T[] res = new T[M.size_out];
            T[] s;
            size_t index;

            foreach(size_t b; 0 .. blocks_out) {
                // We take the first block matrix and multiply it with
                // the corresponding part of the vector.
                s = M.blocks[b] * vec[(b*M.size_blocks) .. ((b+1)*M.size_blocks)];
                // We then increment the index in case the block matrix
                // is rectangular with more columns than rows.
                index = b + blocks_out;
                while(index < blocks_in) {
                    s[] += (M.blocks[index] *
                           vec[(index*M.size_blocks) .. ((index+1)*M.size_blocks)])[];
                    index += blocks_out;
                }

                res[(b*M.size_blocks) .. ((b+1)*M.size_blocks)] = s;
            }

            v = M.Q * res;
        }

        else static if (op == "/"){
            assert(M.size_out == M.size_in, "Warning: Inverse of rectangular
                                             block matrix is not implemented");
            T[] vec = v / M.Q;

            size_t blocks_in = M.size_in / M.size_blocks;
            size_t blocks_out = M.size_out / M.size_blocks;

            T[] res = new T[M.size_out];

            foreach(size_t b; 0 .. blocks_out) {
                // We take the first block matrix and multiply it with
                // the corresponding part of the vector.
                res[(b*M.size_blocks) .. ((b+1)*M.size_blocks)] =
                    vec[(b*M.size_blocks) .. ((b+1)*M.size_blocks)] / M.blocks[b];
            }

            v = res / M.P;
        }
        else static assert(0, "Operator "~op~" not implemented.");
    }

    pure @safe
    void opOpAssign(string op)(in T scalar)
    {
        mixin("v[] "~op~"= scalar;");
    }

    const pure @safe
    T conjdot(in Vector u)
    {return this.conjdot(u.v);}

    const pure @safe
    T conjdot(in T[] u)
    {
        static if (is(Complex!T : T)) {
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
    const pure @safe
    T conjdot(in T[] u, in Vector vtmp)
    {
        static if (is(Complex!T : T)) {
            T s = complex(0);
            foreach(i; 0 .. length)
                s += u[i]*vtmp[i].conj;
            return s;
        }
        else {
            return vtmp.dot(u);
        }
    }

    pure @safe
    void conjmult(in Vector u)
    {return this.conjmult(u.v);}

    pure @safe
    void conjmult(in T[] u)
    {
        static if (is(Complex!T : T)) {
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
  write("Unittest: Vector ... ");


  assertThrown(new Vector!float(5, -1.0));

  foreach(____;0 .. 10){

    alias Vectoruf = Vector!float;
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
        auto vc = new Vector!(Complex!real)(3, 10.5f);
        auto uc = new Vector!(Complex!real)(3, 10.5f);
        auto vc1 = new Vector!(Complex!real)(vc);
        auto uc1 = new Vector!(Complex!real)(uc);

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
        auto vc = new Vector!real(3, 10.5f);
        auto uc = new Vector!real(3, 10.5f);
        auto vc1 = new Vector!real(vc);
        auto uc1 = new Vector!real(uc);

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
        alias Diag = DiagonalMatrix!float;
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
        alias Perm = PermutationMatrix!float;
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
        auto matr = new ReflectionMatrix!(Complex!real)(1_000, 1.0f);
        auto matu = new ReflectionMatrix!(Complex!real)(matr);
        //
        auto tmp = new Vector!(Complex!real)(matr.vec);
        tmp -= matu.vec;
        assert(tmp.norm!"L1" < 0.0001);

        auto v1 = new Vector!(Complex!real)(1_000, 1000.0f);
        auto w1 = new Vector!(Complex!real)(v1);
        //
        tmp = new Vector!(Complex!real)(v1);
        tmp -= w1;
        assert(tmp.norm!"L1" < 0.0001);


        v1 *= matr;
        v1 *= matu; // same as matr
        v1 -= w1; // w1 is the same as v1 before the change.

        assert(v1.norm!"L2" < 0.0001);
    }
    {
        auto matr = new ReflectionMatrix!real(1_000, 1.0f);
        auto matu = new ReflectionMatrix!real(matr);
        //
        auto tmp = new Vector!real(matr.vec);
        tmp -= matu.vec;
        assert(tmp.norm!"L1" < 0.0001);

        auto v1 = new Vector!real(1_000, 1000.0f);
        auto w1 = new Vector!real(v1);
        //
        tmp = new Vector!real(v1);
        tmp -= w1;
        assert(tmp.norm!"L1" < 0.0001);


        v1 *= matr;
        v1 *= matu; // same as matr
        v1 -= w1; // w1 is the same as v1 before the change.

        assert(v1.norm!"L2" < 0.0001);
    }

    // Fourier
    {
        alias Fourier = FourierMatrix!(Complex!double);
        auto f = new Fourier(pow(2, 11));
        auto v = new Vector!(Complex!double)(pow(2, 11), 1.0);

        auto vtmp = v.dup;
        v *= f;
        v /= f;
        v -= vtmp;
        assert(v.norm!"L2" < 0.01);
    }

    // General matrix
    {
        auto m = new Matrix!float(4, 4);
        m.mat = [1.0, 0.0, 0.0, 0.0,
                 0.0, 0.0, 2.0, 0.0,
                 0.0, 0.5, 0.0, 0.0,
                 0.0, 0.0, 0.0, 1.0];
        auto v = new Vector!float(4);
        v[0] = 38.50;
        v[1] = 13.64;
        v[2] = 90.01;
        v[3] = 27.42;

        auto w = v.dup;
        w *= m;
    }

    // Unitary matrix
    {
        auto m = new UnitaryMatrix!(Complex!double)(4, 9.0);
        auto v = new Vector!(Complex!double)(4, 1.2);

        auto k = v.dup;
        auto w = m * v;

        v *= m;
        w -= v;
        assert(w.norm!"L2" < 0.00001);
        v /= m;

        k -= v;
        assert(k.norm!"L2" < 0.00001);
    }

    // Block matrix
    {
        auto len = 1024;
        auto m1 = new PermutationMatrix!(Complex!float)(len/4, 1.0);
        auto m2 = new DiagonalMatrix!(Complex!float)(len/4, 1.0);
        auto m3 = new ReflectionMatrix!(Complex!float)(len/4, 1.0);
        auto m4 = new FourierMatrix!(Complex!float)(len/4);
        auto bm = new BlockMatrix!(Complex!float)(len, len/4,
                                                         [m1,m2,m3,m4], false);

        auto v = new Vector!(Complex!float)(len);
        foreach(i; 0 .. len)
            v[i] = complex(cast(float)(i*2 - len/2), cast(float)(len/3 - i/3.0));

        auto mem= v.dup;


        auto v2 = bm * v;
        auto v3 = v2 / bm;

        v *= bm;
        v2 -= v;
        assert(v2.norm!"L2" < 0.1);
        v /= bm;

        v -= mem;
        v3 -= mem;
        assert(v3.norm!"L2" < 0.1);
        assert(v.norm!"L2" < 0.1);

        alias Block = BlockMatrix!(Complex!float);
        auto bmrec = new Block(len, len/2, len/4, [m1,m2,m3,m4], true);
        auto vv = new Vector!(Complex!float)(len);
        foreach(i; 0 .. len)
            vv[i] = complex(cast(float)(i*2 - len/2), cast(float)(len/3 - i/3.0));

        auto mev = vv.dup;
        auto w = v.dup;

        vv *= bmrec;
        w = bmrec * mev;

        vv -= w;
        assert(vv.norm!"L2" < 0.001);
        bool error =  false;
        try {
            vv /= bmrec;
        }
        catch (AssertError e) {
            error = true;
        }
        assert(error);
    }
  }
  write("Done.\n");
}

